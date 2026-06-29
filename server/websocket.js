/**
 * websocket.js — WebSocket 연결 관리 및 push 전담
 *
 * WebSocket이란?
 *   HTTP는 클라이언트가 요청해야만 서버가 응답합니다 (폴링).
 *   WebSocket은 한 번 연결하면 서버가 먼저 데이터를 보낼 수 있습니다 (push).
 *
 * 사용 흐름:
 *   1. 웹/모바일이 ws://[ip]:4000/ws 에 연결
 *   2. poller.js가 새 이벤트 감지 → wsManager.broadcast() 호출
 *   3. 연결된 모든 클라이언트에게 즉시 전달
 */

const WebSocket = require('ws');

// 연결된 클라이언트 목록 (Set으로 중복 없이 관리)
const clients = new Set();

/**
 * Express HTTP 서버에 WebSocket 서버를 붙입니다.
 * @param {http.Server} httpServer
 */
function init(httpServer) {
  const wss = new WebSocket.Server({ server: httpServer, path: '/ws' });

  wss.on('connection', (ws, req) => {
    const ip = req.socket.remoteAddress;
    console.log(`[WS] 클라이언트 연결: ${ip}`);
    clients.add(ws);

    // 연결 즉시 현재 상태 전송 (poller가 가진 최신 상태)
    const { getLastStatus } = require('./poller');
    const lastStatus = getLastStatus();
    if (lastStatus) {
      ws.send(JSON.stringify({ type: 'STATUS', data: lastStatus }));
    }

    ws.on('close', () => {
      console.log(`[WS] 클라이언트 연결 해제: ${ip}`);
      clients.delete(ws);
    });

    ws.on('error', (err) => {
      console.error(`[WS] 에러: ${err.message}`);
      clients.delete(ws);
    });
  });

  console.log('[WS] WebSocket 서버 준비됨 (경로: /ws)');
}

/**
 * 연결된 모든 클라이언트에게 메시지 전송
 *
 * message 형식:
 *   { type: 'STATUS',    data: { mode, recipe, lot, ... } }
 *   { type: 'NEW_EVENT', data: { id, time, logType, description, camera } }
 *   { type: 'ALERT',     data: { id, time, logType, description, camera } }
 *
 * @param {{ type: string, data: object }} message
 */
function broadcast(message) {
  const json = JSON.stringify(message);
  let sent = 0;

  for (const client of clients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(json);
      sent++;
    }
  }

  if (sent > 0) {
    console.log(`[WS] broadcast → ${sent}명: type=${message.type}`);
  }
}

/**
 * 현재 연결된 클라이언트 수
 */
function getClientCount() {
  return clients.size;
}

module.exports = { init, broadcast, getClientCount };
