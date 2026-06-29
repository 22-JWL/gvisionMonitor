/**
 * poller.js — GvisionWpf 상태 폴링 + 새 이벤트 감지
 *
 * 두 가지를 주기적으로 합니다:
 *   1. GvisionWpf API(/api/status) 폴링 → 상태 변경 시 WebSocket push
 *   2. SQLite histories 테이블 폴링 → 새 row 감지 시 WebSocket push
 *
 * 왜 두 개를 따로 하냐?
 *   - 상태(모드/레시피/Lot)는 GvisionWpf API에서 가장 정확하게 옴
 *   - 이벤트(에러/Teaching 변경 등)는 SQLite에 기록됨
 */

const axios = require('axios');
const config = require('./config');
const db = require('./db');
const wsManager = require('./websocket');
const statusDb = require('./statusDb');

// 마지막으로 감지한 상태 (연결 시 즉시 전송에 사용)
let lastStatus = null;

// 마지막으로 읽은 history Id (이후 새로 추가된 것만 감지)
let lastHistoryId = 0;

// 마지막으로 감지한 lot 상태 (Id → { Id, LotNumber, EndTime })
let lastLotSnapshot = {}; // { [id]: { Id, LotNumber, EndTime } }
let lotSnapshotInitialized = false;

// ALERT로 분류할 LogType 값
// GvisionWpf ELog enum: SystemLogs=1, InspectionLogs=2, DatabaseLogs=3, LOTLogs=4, RecipeLogs=5
const ALERT_LOG_TYPES = [1, 2]; // SystemLogs(에러), InspectionLogs(검사실패)

/**
 * GvisionWpf /api/status 한 번 호출
 */
async function fetchGvisionStatus() {
  try {
    const res = await axios.get(`${config.GVISION_API_URL}/api/status`, {
      timeout: 3000,
    });
    return res.data;
  } catch (err) {
    // GvisionWpf가 꺼져있으면 여기서 에러남 → 그냥 null 반환
    return null;
  }
}

/**
 * 상태 변경 여부 비교
 * 모드/레시피/Lot번호 중 하나라도 바뀌면 변경으로 판단
 */
function hasStatusChanged(prev, next) {
  if (!prev || !next) return true;
  return (
    prev.runningMode !== next.runningMode ||
    prev.recipeName  !== next.recipeName  ||
    prev.lotNo       !== next.lotNo
  );
}

/**
 * 상태 폴링 — POLL_INTERVAL_MS마다 실행
 */
async function pollStatus() {
  const status = await fetchGvisionStatus();

  if (!status) {
    // GvisionWpf 꺼진 상태
    if (lastStatus !== null) {
      lastStatus = null;
      wsManager.broadcast({ type: 'GVISION_OFFLINE', data: {} });
      statusDb.updateStatus({ runningMode: 'OFFLINE', recipeName: '(오프라인)', lotNo: '-' });
    }
    return;
  }

  if (hasStatusChanged(lastStatus, status)) {
    console.log(`[Poller] 상태 변경 감지: mode=${status.runningMode}, recipe=${status.recipeName}, lot=${status.lotNo}`);
    lastStatus = status;
    wsManager.broadcast({ type: 'STATUS', data: status });

    // Grafana SQLite 패널이 읽을 수 있도록 현재 상태를 별도 DB에 기록
    statusDb.updateStatus({
      runningMode: status.runningMode,
      recipeName:  status.recipeName,
      lotNo:       status.lotNo,
    });
  }
}

/**
 * 이벤트 폴링 — EVENT_POLL_INTERVAL_MS마다 실행
 * histories 테이블에서 lastHistoryId 이후에 추가된 row를 찾음
 */
function pollEvents() {
  try {
    // lastHistoryId 초기화 (첫 실행 시)
    if (lastHistoryId === 0) {
      lastHistoryId = db.getLatestHistoryId();
      console.log(`[Poller] 이벤트 기준 Id 초기화: ${lastHistoryId}`);
      return;
    }

    const activeDb = db.getDb();
    if (!activeDb) return;

    const newEvents = activeDb.prepare(`
      SELECT Id, Time, Package, LotId, Camera, Inspection, LogType, Description, ImagePath
      FROM histories
      WHERE Id > ?
      ORDER BY Id ASC
    `).all(lastHistoryId);

    if (newEvents.length === 0) return;

    // 새 이벤트를 하나씩 WebSocket으로 push
    for (const event of newEvents) {
      // histories LogType=4는 실제 검사 결과 → 앱에는 LogType=2(검사)로 전달
      const appLogType = event.LogType === 4 ? 2 : event.LogType;
      const isAlert = ALERT_LOG_TYPES.includes(appLogType);
      const msgType = isAlert ? 'ALERT' : 'NEW_EVENT';

      console.log(`[Poller] 새 이벤트 (${msgType}): Id=${event.Id}, LogType=${appLogType}, ${event.Description?.slice(0, 50)}`);

      wsManager.broadcast({ type: msgType, data: { ...event, LogType: appLogType } });
    }

    // 마지막 Id 업데이트
    lastHistoryId = newEvents[newEvents.length - 1].Id;

  } catch (err) {
    console.error('[Poller] 이벤트 폴링 오류:', err.message);
  }
}

/**
 * lot 테이블 폴링 — 새 LOT 시작 / LOT 종료 감지 후 WebSocket push
 */
function pollLots() {
  try {
    const activeDb = db.getDb();
    if (!activeDb) return;

    const rows = activeDb.prepare(`SELECT Id, LotNumber, Package, StartTime, EndTime FROM lot ORDER BY Id DESC LIMIT 20`).all();

    // 첫 실행 시 현재 상태를 스냅샷으로만 저장 (과거 lot은 이벤트로 push 안 함)
    if (!lotSnapshotInitialized) {
      for (const row of rows) {
        lastLotSnapshot[row.Id] = { Id: row.Id, LotNumber: row.LotNumber, EndTime: row.EndTime };
      }
      lotSnapshotInitialized = true;
      return;
    }

    for (const row of rows) {
      const prev = lastLotSnapshot[row.Id];

      if (!prev) {
        // 새 LOT 시작
        console.log(`[Poller] LOT 시작 감지: ${row.LotNumber}`);
        const now = new Date().toISOString().replace('T', ' ').substring(0, 19);
        wsManager.broadcast({
          type: 'NEW_EVENT',
          data: {
            Id: `lot-start-${row.Id}`,
            Time: row.StartTime || now,
            LogType: 4,
            Description: `LOT 시작: ${row.LotNumber} (Recipe: ${row.Package || '-'})`,
            LotId: row.Id,
          },
        });
        lastLotSnapshot[row.Id] = { Id: row.Id, LotNumber: row.LotNumber, EndTime: row.EndTime };

      } else if (!prev.EndTime && row.EndTime) {
        // LOT 종료
        console.log(`[Poller] LOT 종료 감지: ${row.LotNumber}`);
        const now = new Date().toISOString().replace('T', ' ').substring(0, 19);
        wsManager.broadcast({
          type: 'NEW_EVENT',
          data: {
            Id: `lot-end-${row.Id}`,
            Time: row.EndTime || now,
            LogType: 4,
            Description: `LOT 종료: ${row.LotNumber} (Recipe: ${row.Package || '-'})`,
            LotId: row.Id,
          },
        });
        lastLotSnapshot[row.Id] = { Id: row.Id, LotNumber: row.LotNumber, EndTime: row.EndTime };
      }
    }
  } catch (err) {
    console.error('[Poller] LOT 폴링 오류:', err.message);
  }
}

/**
 * 폴링 시작
 * index.js에서 서버 시작 시 한 번 호출
 */
function start() {
  console.log(`[Poller] 상태 폴링 시작 (${config.POLL_INTERVAL_MS}ms 간격)`);
  console.log(`[Poller] 이벤트 폴링 시작 (${config.EVENT_POLL_INTERVAL_MS}ms 간격)`);
  console.log(`[Poller] LOT 폴링 시작 (${config.POLL_INTERVAL_MS}ms 간격)`);

  // 즉시 한 번 실행 후 인터벌 설정
  pollStatus();
  pollEvents();
  pollLots();

  setInterval(pollStatus, config.POLL_INTERVAL_MS);
  setInterval(pollEvents, config.EVENT_POLL_INTERVAL_MS);
  setInterval(pollLots, config.POLL_INTERVAL_MS);
}

/**
 * 마지막으로 받은 상태 반환 (WebSocket 신규 연결 시 즉시 전송에 사용)
 */
function getLastStatus() {
  return lastStatus;
}

module.exports = { start, getLastStatus };
