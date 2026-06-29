/**
 * db.js — SQLite 읽기 전담 모듈
 *
 * better-sqlite3는 동기(sync) 방식입니다.
 * GvisionWpf가 이미 DB에 쓰고 있으므로, 우리는 읽기(READ ONLY)만 합니다.
 *
 * GvisionWpf DB 테이블:
 *   histories          - 시스템/LOT/Recipe 이벤트 로그
 *   inspection_results - 매 검사 결과 (시계열 핵심 데이터)
 *   lot                - Lot 목록
 */

const Database = require('better-sqlite3');
const config = require('./config');
const fs = require('fs');
const path = require('path');

let db = null;
let dbPath = null;

/**
 * GvisionWpf가 실제로 쓰고 있는 DB 파일을 찾아 반환합니다.
 * 같은 디렉터리에서 가장 최근에 수정된 .db 파일을 자동으로 선택합니다.
 * GvisionWpf는 월별로 DB 파일을 교체할 수 있으므로 항상 최신 파일을 사용합니다.
 */
function resolveDbPath() {
  const dir = path.dirname(config.DB_PATH);
  if (!fs.existsSync(dir)) return null;

  const candidates = fs.readdirSync(dir)
    .filter(f => f.endsWith('.db') && !f.endsWith('-shm') && !f.endsWith('-wal'))
    .map(f => ({ file: path.join(dir, f), mtime: fs.statSync(path.join(dir, f)).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime);

  return candidates.length > 0 ? candidates[0].file : null;
}

let lastPathCheckTime = 0;
const PATH_CHECK_INTERVAL_MS = 60_000; // 1분마다 활성 파일 재확인

/**
 * DB 연결을 가져옵니다.
 * GvisionWpf가 DB 파일을 교체했으면 자동으로 재연결합니다.
 */
function getDb() {
  const now = Date.now();
  let currentPath = dbPath;

  // 처음 연결이거나 1분마다 활성 파일 재확인
  if (!currentPath || now - lastPathCheckTime > PATH_CHECK_INTERVAL_MS) {
    currentPath = resolveDbPath();
    lastPathCheckTime = now;
  }

  if (!currentPath) {
    console.warn(`[DB] 파일 없음: ${config.DB_PATH}`);
    console.warn('[DB] GvisionWpf가 실행된 적 있는지 확인하세요.');
    return null;
  }

  // DB 파일이 교체됐으면 기존 연결 닫고 재연결
  if (db && dbPath !== currentPath) {
    console.log(`[DB] DB 파일 변경 감지: ${dbPath} → ${currentPath}`);
    try { db.close(); } catch (_) {}
    db = null;
  }

  if (!db) {
    db = new Database(currentPath, { readonly: true });
    dbPath = currentPath;
    console.log(`[DB] 연결됨: ${currentPath}`);
  }
  return db;
}

// ─────────────────────────────────────────────
// histories 테이블 쿼리
// ─────────────────────────────────────────────

/**
 * 최근 이벤트 목록 조회
 * @param {number} limit - 가져올 개수 (기본 50)
 * @param {string|null} logType - 필터 (SystemLogs/LOTLogs/RecipeLogs 등)
 */
function getRecentEvents(limit = 50, logType = null) {
  const db = getDb();
  if (!db) return [];

  // histories 테이블 조회
  let sql = `
    SELECT Id, Time, Package, LotId, Camera, Inspection, LogType, Description, ImagePath
    FROM histories
  `;
  const params = [];

  if (logType && logType != 4) {
    // logType=2(검사) 요청 시 histories의 LogType=4(실제 검사 결과)도 포함
    const dbLogType = logType == 2 ? [2, 4] : [logType];
    sql += ` WHERE LogType IN (${dbLogType.join(',')})`;
  } else if (!logType) {
    // 전체 조회 시 histories만
  }

  sql += ` ORDER BY Id DESC LIMIT ?`;
  params.push(limit);

  // histories의 LogType=4는 실제로 검사 결과이므로 앱에는 LogType=2(검사)로 전달
  let events = db.prepare(sql).all(...params)
    .map(e => e.LogType === 4 ? { ...e, LogType: 2 } : e);

  // logType=4(LOT) 또는 전체 조회 시 lot 테이블에서 LOT 이벤트 합치기
  if (!logType || logType == 4) {
    const lots = db.prepare(`
      SELECT Id, LotNumber, Package, StartTime, EndTime FROM lot ORDER BY Id DESC LIMIT 50
    `).all();

    const lotEvents = [];
    for (const lot of lots) {
      if (lot.StartTime) {
        lotEvents.push({
          Id: `lot-start-${lot.Id}`,
          Time: lot.StartTime,
          Package: lot.Package,
          LotId: lot.Id,
          Camera: null,
          Inspection: null,
          LogType: 4,
          Description: `LOT 시작: ${lot.LotNumber} (Recipe: ${lot.Package || '-'})`,
          ImagePath: null,
        });
      }
      if (lot.EndTime) {
        lotEvents.push({
          Id: `lot-end-${lot.Id}`,
          Time: lot.EndTime,
          Package: lot.Package,
          LotId: lot.Id,
          Camera: null,
          Inspection: null,
          LogType: 4,
          Description: `LOT 종료: ${lot.LotNumber} (Recipe: ${lot.Package || '-'})`,
          ImagePath: null,
        });
      }
    }

    if (logType == 4) {
      // LOT 전용 탭: lot 이벤트만
      events = lotEvents;
    } else {
      // 전체 탭: histories + lot 이벤트 합쳐서 시간순 정렬
      events = [...events, ...lotEvents]
        .sort((a, b) => (b.Time > a.Time ? 1 : -1))
        .slice(0, limit);
    }
  }

  return events;
}

/**
 * 특정 이벤트 전후 N분의 이벤트 목록 (맥락 조회)
 * @param {string} time - 이벤트 발생 시각 (ISO string)
 * @param {number} beforeMin - 이전 몇 분
 * @param {number} afterMin - 이후 몇 분
 */
function getEventContext(time, beforeMin = 5, afterMin = 5) {
  const db = getDb();
  if (!db) return [];

  return db.prepare(`
    SELECT Id, Time, Package, LotId, Camera, Inspection, LogType, Description
    FROM histories
    WHERE Time BETWEEN datetime(?, '-${beforeMin} minutes')
                   AND datetime(?, '+${afterMin} minutes')
    ORDER BY Time ASC
  `).all(time, time);
}

// ─────────────────────────────────────────────
// inspection_results 테이블 쿼리 (시계열 핵심)
// ─────────────────────────────────────────────

/**
 * 시계열 검사 결과 조회 (그래프용)
 * @param {string} from - 시작 시각 (ISO string)
 * @param {string} to   - 종료 시각 (ISO string)
 * @param {number|null} lotId - Lot 필터
 */
function getInspectionSeries(from, to, lotId = null) {
  const db = getDb();
  if (!db) return [];

  let sql = `
    SELECT Id, LotId, RecipeName, Duration, StartTime, EndTime,
           Item, XPos, YPos, XOffset, YOffset, TOffset,
           PackageWidth, PackageHeight, HasDevice, InspectionType
    FROM inspection_results
    WHERE StartTime BETWEEN ? AND ?
  `;
  const params = [from, to];

  if (lotId !== null) {
    sql += ` AND LotId = ?`;
    params.push(lotId);
  }

  sql += ` ORDER BY StartTime ASC`;

  return db.prepare(sql).all(...params);
}

/**
 * 수율(Yield) 시계열 — 1분 단위로 집계
 * pass 건수 / 전체 건수 = 수율
 */
function getYieldSeries(from, to, lotId = null) {
  const db = getDb();
  if (!db) return [];

  let sql = `
    SELECT
      strftime('%Y-%m-%dT%H:%M:00', StartTime) AS minute,
      COUNT(*) AS total,
      SUM(CASE WHEN Item = 'PASS' THEN 1 ELSE 0 END) AS pass,
      ROUND(SUM(CASE WHEN Item = 'PASS' THEN 1.0 ELSE 0 END) / COUNT(*) * 100, 2) AS yield
    FROM inspection_results
    WHERE StartTime BETWEEN ? AND ?
  `;
  const params = [from, to];

  if (lotId !== null) {
    sql += ` AND LotId = ?`;
    params.push(lotId);
  }

  sql += ` GROUP BY minute ORDER BY minute ASC`;

  return db.prepare(sql).all(...params);
}

/**
 * 평균 처리시간(Duration) 시계열 — 1분 단위 집계
 */
function getDurationSeries(from, to, lotId = null) {
  const db = getDb();
  if (!db) return [];

  let sql = `
    SELECT
      strftime('%Y-%m-%dT%H:%M:00', StartTime) AS minute,
      ROUND(AVG(Duration), 1) AS avgDuration,
      MAX(Duration) AS maxDuration
    FROM inspection_results
    WHERE StartTime BETWEEN ? AND ?
  `;
  const params = [from, to];

  if (lotId !== null) {
    sql += ` AND LotId = ?`;
    params.push(lotId);
  }

  sql += ` GROUP BY minute ORDER BY minute ASC`;

  return db.prepare(sql).all(...params);
}

/**
 * 불량 유형별 건수 (파이/바 차트용)
 */
function getErrorBreakdown(lotId) {
  const db = getDb();
  if (!db) return [];

  return db.prepare(`
    SELECT Item AS errorType, COUNT(*) AS count
    FROM inspection_results
    WHERE LotId = ? AND Item != 'PASS'
    GROUP BY Item
    ORDER BY count DESC
  `).all(lotId);
}

/**
 * 전체 또는 오늘 기준 불량 유형별 건수
 * @param {boolean} todayOnly - true면 오늘(KST) 데이터만
 */
function getErrorBreakdownGlobal(todayOnly = false) {
  const db = getDb();
  if (!db) return [];

  const where = todayOnly
    ? `WHERE Item != 'PASS' AND date(StartTIme) = date('now', '+9 hours')`
    : `WHERE Item != 'PASS'`;

  return db.prepare(`
    SELECT Item AS errorType, COUNT(*) AS count
    FROM inspection_results
    ${where}
    GROUP BY Item
    ORDER BY count DESC
    LIMIT 10
  `).all();
}

/**
 * XY 위치별 불량 수 (히트맵용)
 */
function getFailHeatmap(lotId) {
  const db = getDb();
  if (!db) return [];

  return db.prepare(`
    SELECT XPos, YPos, COUNT(*) AS failCount
    FROM inspection_results
    WHERE LotId = ? AND Item != 'PASS'
    GROUP BY XPos, YPos
  `).all(lotId);
}

// ─────────────────────────────────────────────
// lot 테이블 쿼리
// ─────────────────────────────────────────────

/**
 * Lot 목록 조회
 */
function getLots(limit = 20) {
  const db = getDb();
  if (!db) return [];

  return db.prepare(`
    SELECT Id, Package, LotNumber, StartTime, EndTime
    FROM lot
    ORDER BY Id DESC
    LIMIT ?
  `).all(limit);
}

/**
 * 특정 Lot 상세 + 수율 통계
 */
function getLotStats(lotId) {
  const db = getDb();
  if (!db) return null;

  const lot = db.prepare(`
    SELECT Id, Package, LotNumber, StartTime, EndTime FROM lot WHERE Id = ?
  `).get(lotId);

  if (!lot) return null;

  const stats = db.prepare(`
    SELECT
      InspectionType,
      COUNT(*) AS total,
      SUM(CASE WHEN Item = 'PASS' THEN 1 ELSE 0 END) AS pass,
      ROUND(SUM(CASE WHEN Item = 'PASS' THEN 1.0 ELSE 0 END) / COUNT(*) * 100, 2) AS yield
    FROM inspection_results
    WHERE LotId = ?
    GROUP BY InspectionType
  `).all(lotId);

  const overall = db.prepare(`
    SELECT
      COUNT(*) AS total,
      SUM(CASE WHEN Item = 'PASS' THEN 1 ELSE 0 END) AS good,
      SUM(CASE WHEN Item LIKE '%NoDevice%' THEN 1 ELSE 0 END) AS noDevice,
      SUM(CASE WHEN Item LIKE '%XOut%' THEN 1 ELSE 0 END) AS xout,
      SUM(CASE WHEN Item != 'PASS' AND Item NOT LIKE '%NoDevice%' AND Item NOT LIKE '%XOut%' THEN 1 ELSE 0 END) AS reject
    FROM inspection_results
    WHERE LotId = ?
  `).get(lotId);

  return { ...lot, stats, ...overall };
}

/**
 * histories 테이블의 마지막 Id를 반환 (새 이벤트 감지용)
 */
function getLatestHistoryId() {
  const db = getDb();
  if (!db) return 0;

  const row = db.prepare(`SELECT MAX(Id) AS maxId FROM histories`).get();
  return row?.maxId ?? 0;
}

module.exports = {
  getDb,
  getRecentEvents,
  getErrorBreakdownGlobal,
  getEventContext,
  getInspectionSeries,
  getYieldSeries,
  getDurationSeries,
  getErrorBreakdown,
  getFailHeatmap,
  getLots,
  getLotStats,
  getLatestHistoryId,
};
