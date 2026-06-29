/**
 * config.js — 서버 전체 설정값
 *
 * 경로나 포트가 바뀌면 여기만 수정하면 됩니다.
 */

const path = require('path');

module.exports = {
  // 이 백엔드 서버가 열 포트
  SERVER_PORT: 4000,

  // GvisionWpf REST API 주소 (같은 PC에서 실행 중)
  GVISION_API_URL: 'http://localhost:3000',

  // SQLite DB 파일 경로
  // GvisionWpf는 실행 폴더 기준으로 DB/Schema/DS_HanaMicron.db 를 사용
  // 아래 경로는 실제 GvisionWpf 실행파일 위치에 맞게 수정 필요
  DB_PATH: path.join(
    'C:/givision-AML/GvisionWpf/bin/x64/Debug/net9.0-windows',
    'DB/Schema/DS_HanaMicron.db'
  ),

  // GvisionWpf API 폴링 간격 (ms)
  POLL_INTERVAL_MS: 5000,

  // 이벤트 감지를 위해 histories 테이블을 얼마나 자주 확인할지 (ms)
  EVENT_POLL_INTERVAL_MS: 3000,
};
