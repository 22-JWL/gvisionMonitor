// /**
//  * index.js  서버 진입점
//  *
//  * 여기서 하는 일:
//  *   1. Express 앱 생성 (REST API 서버)
//  *   2. CORS 허용 (웹 브라우저에서 다른 포트로 요청할 때 필요)
//  *   3. routes 연결 (각 URL 경로별 처리기)
//  *   4. HTTP 서버 시작
//  *   5. WebSocket 서버 붙이기 (같은 포트, /ws 경로)
//  *   6. GvisionWpf 폴링 시작
//  *
//  * 왜 HTTP 서버를 Express에서 직접 안 띄우나?
//  *   app.listen()은 Express 전용 HTTP 서버를 만듭니다.
//  *   WebSocket은 http.Server에 붙여야 해서,
//  *   http.createServer(app)으로 만들고 ws, express 둘 다 공유합니다.
//  */

const express = require('express');
const http    = require('http');
const cors    = require('cors');
const path    = require('path');

const config      = require('./config');
const wsManager   = require('./websocket');
const poller      = require('./poller');

// routes
const statusRoutes      = require('./routes/status');
const eventsRoutes      = require('./routes/events');
const lotsRoutes        = require('./routes/lots');
const inspectionsRoutes = require('./routes/inspections');

// ── Express 앱 설정 ──────────────────────────────
const app = express();

// JSON 요청 본문 파싱
app.use(express.json());

// CORS: 웹 브라우저에서 다른 포트/도메인에서 이 API를 호출할 수 있게 허용
app.use(cors());

// ── API 라우트 연결 ──────────────────────────────
// /api/status       → routes/status.js
// /api/events       → routes/events.js
// /api/lots         → routes/lots.js
// /api/inspections  → routes/inspections.js
app.use('/api/status',      statusRoutes);
app.use('/api/events',      eventsRoutes);
app.use('/api/lots',        lotsRoutes);
app.use('/api/inspections', inspectionsRoutes);

// 헬스체크 (서버가 살아있는지 확인용)
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// API 목록
app.get('/', (req, res) => {
  res.json({
    name: 'GVision Monitor API',
    version: '1.0.0',
    endpoints: {
      'GET /api/status':                     '현재 장비 상태',
      'GET /api/events':                     '최근 이벤트 목록 (?limit=50&logType=4)',
      'GET /api/events/:id/context':         '특정 이벤트 전후 맥락 (?before=5&after=5)',
      'GET /api/lots':                       'Lot 목록 (?limit=20)',
      'GET /api/lots/:id/stats':             'Lot 수율 통계',
      'GET /api/inspections/series':         '원시 검사 결과 (?from=&to=&lotId=)',
      'GET /api/inspections/yield':          '수율 시계열 (1분 집계)',
      'GET /api/inspections/duration':       '처리시간 시계열 (1분 집계)',
      'GET /api/inspections/errors':         '불량 유형별 건수 (?lotId=)',
      'GET /api/inspections/heatmap':        'XY 위치별 불량 히트맵 (?lotId=)',
      'WS  ws://[ip]:4000/ws':              '실시간 이벤트 push',
    },
  });
});

// ── HTTP + WebSocket 서버 시작 ───────────────────
const server = http.createServer(app);

// WebSocket 서버를 같은 HTTP 서버에 붙임 (포트 공유)
wsManager.init(server);

server.listen(config.SERVER_PORT, '0.0.0.0', () => {
  console.log('');
  console.log('═══════════════════════════════════════');
  console.log(`  GVision Monitor Server`);
  console.log(`  http://localhost:${config.SERVER_PORT}`);
  console.log(`  ws://localhost:${config.SERVER_PORT}/ws`);
  console.log('═══════════════════════════════════════');
  console.log('');

  // 폴링 시작 (서버 준비된 후에 시작)
  poller.start();
});
