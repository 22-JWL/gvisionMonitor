/**
 * statusDb.js — 현재 장비 상태를 저장하는 전용 SQLite DB
 *
 * GvisionWpf DB는 read-only로만 접근하므로,
 * recipe/lot 같은 string 상태 값은 별도 DB에 기록한다.
 *
 * DB 파일 위치: ../data/gvision_status.db
 * Grafana SQLite datasource(frser-sqlite-datasource)가 이 파일을 읽는다.
 */

const path = require('path');
const Database = require('better-sqlite3');

const DB_PATH = path.join(__dirname, '..', 'data', 'gvision_status.db');

let db = null;

function getDb() {
  if (db) return db;
  db = new Database(DB_PATH);

  // current_status 테이블: key/value 형태로 현재 상태 저장
  db.exec(`
    CREATE TABLE IF NOT EXISTS current_status (
      key        TEXT PRIMARY KEY,
      value      TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );

    -- 초기 값 삽입 (없을 때만)
    INSERT OR IGNORE INTO current_status (key, value, updated_at)
    VALUES
      ('recipeName', '(대기중)', datetime('now')),
      ('lotNo',      '(대기중)', datetime('now')),
      ('runningMode','OFFLINE',  datetime('now'));
  `);

  console.log(`[StatusDB] 연결됨: ${DB_PATH}`);
  return db;
}

/**
 * 현재 상태 업데이트
 * @param {string} key - 'recipeName' | 'lotNo' | 'runningMode'
 * @param {string} value
 */
function setStatus(key, value) {
  const d = getDb();
  d.prepare(`
    INSERT INTO current_status (key, value, updated_at)
    VALUES (?, ?, datetime('now'))
    ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
  `).run(key, value);
}

/**
 * 여러 상태를 한 번에 업데이트
 * @param {{ recipeName?: string, lotNo?: string, runningMode?: string }} statusObj
 */
function updateStatus(statusObj) {
  const update = getDb().prepare(`
    INSERT INTO current_status (key, value, updated_at)
    VALUES (?, ?, datetime('now'))
    ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
  `);

  const tx = getDb().transaction((obj) => {
    for (const [key, value] of Object.entries(obj)) {
      if (value !== undefined && value !== null) {
        update.run(key, String(value));
      }
    }
  });

  tx(statusObj);
}

// DB를 초기화 (서버 시작 시 즉시 연결)
getDb();

module.exports = { setStatus, updateStatus };
