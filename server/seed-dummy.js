/**
 * seed-dummy.js — 대시보드 동작 확인용 더미 데이터 삽입
 *
 * 실행: node server/seed-dummy.js
 * 삭제: node server/seed-dummy.js --clean
 */

const Database = require('better-sqlite3');
const DB_PATH = 'C:/givision-AML/GvisionWpf/bin/x64/Debug/net9.0-windows/DB/Schema/DS_HanaMicron.db';

const db = new Database(DB_PATH);

// ──────────────────────────────────────────
// 유틸
// ──────────────────────────────────────────
function fmt(date) {
  // SQLite DATETIME 형식: "YYYY-MM-DD HH:MM:SS"
  return date.toISOString().replace('T', ' ').replace(/\.\d+Z$/, '');
}

function addMinutes(date, min) {
  return new Date(date.getTime() + min * 60 * 1000);
}

function rand(min, max) {
  return Math.random() * (max - min) + min;
}

function randInt(min, max) {
  return Math.floor(rand(min, max + 1));
}

// ──────────────────────────────────────────
// --clean: 더미 데이터 삭제
// ──────────────────────────────────────────
if (process.argv.includes('--clean')) {
  db.prepare("DELETE FROM inspection_results WHERE LotId IN (SELECT Id FROM lot WHERE LotNumber LIKE 'DUMMY-%')").run();
  db.prepare("DELETE FROM histories WHERE LotId IN (SELECT Id FROM lot WHERE LotNumber LIKE 'DUMMY-%') OR Description IN ('GVISION START','Recipe 변경: QFN-48','Recipe 변경: BGA-256')").run();
  db.prepare("DELETE FROM lot WHERE LotNumber LIKE 'DUMMY-%'").run();
  console.log('더미 데이터 삭제 완료');
  process.exit(0);
}

// ──────────────────────────────────────────
// 기준 시각: 지금부터 3시간 전 ~ 지금
// ──────────────────────────────────────────
const now   = new Date();
const start = new Date(now.getTime() - 3 * 60 * 60 * 1000); // 3시간 전

// ──────────────────────────────────────────
// 1. Lot 2개 삽입
// ──────────────────────────────────────────
const lot1Start = fmt(start);
const lot1End   = fmt(addMinutes(start, 80));
const lot2Start = fmt(addMinutes(start, 90));
const lot2End   = fmt(addMinutes(start, 180));

const insertLot = db.prepare(`
  INSERT INTO lot (Package, LotNumber, StartTime, EndTime)
  VALUES (?, ?, ?, ?)
`);

const lot1 = insertLot.run('QFN-48', 'DUMMY-LOT-001', lot1Start, lot1End);
const lot2 = insertLot.run('BGA-256', 'DUMMY-LOT-002', lot2Start, lot2End);

const lot1Id = lot1.lastInsertRowid;
const lot2Id = lot2.lastInsertRowid;

console.log(`Lot 삽입: DUMMY-LOT-001 (id=${lot1Id}), DUMMY-LOT-002 (id=${lot2Id})`);

// ──────────────────────────────────────────
// 2. inspection_results 삽입
//    - 1분마다 약 20건씩, 3시간치
//    - 초반 PASS율 99%, 중간에 수율 하락 시뮬레이션, 회복
// ──────────────────────────────────────────
const insertInsp = db.prepare(`
  INSERT INTO inspection_results
    (LotId, RecipeName, Duration, StartTIme, EndTime, Item,
     XPos, YPos, XOffset, YOffset, TOffset,
     PackageWidth, PackageHeight, HasDevice, InspectionType)
  VALUES
    (?, ?, ?, ?, ?, ?,
     ?, ?, ?, ?, ?,
     ?, ?, ?, ?)
`);

const errorTypes = ['LEAD_OPEN', 'LEAD_SHORT', 'MISSING_BALL', 'CONTAMINATION', 'TILT'];

// LOT-001: 80분치 (start ~ start+80min)
let insertCount = 0;
for (let m = 0; m < 80; m++) {
  const minuteTime = addMinutes(start, m);
  const lotId      = lot1Id;
  const recipe     = 'QFN-48';

  // 수율: 0~20분은 99%, 30~50분은 수율 하락(94%), 60~80분 회복(98%)
  let passRate;
  if (m < 20)       passRate = 0.99;
  else if (m < 30)  passRate = 0.97;
  else if (m < 50)  passRate = 0.94;
  else if (m < 60)  passRate = 0.96;
  else              passRate = 0.98;

  for (let i = 0; i < 20; i++) {
    const sTime = new Date(minuteTime.getTime() + i * 3000);
    const dur   = randInt(80, 160);
    const eTime = new Date(sTime.getTime() + dur);
    const pass  = Math.random() < passRate;
    const item  = pass ? 'PASS' : errorTypes[randInt(0, errorTypes.length - 1)];

    // XOffset/YOffset: 30~50분 구간에 드리프트 시뮬레이션
    const drift = (m >= 30 && m < 50) ? rand(0.03, 0.08) : 0;
    const xOff  = rand(-0.01, 0.01) + drift;
    const yOff  = rand(-0.01, 0.01) + drift * 0.5;

    insertInsp.run(
      lotId, recipe, dur, fmt(sTime), fmt(eTime), item,
      randInt(1, 10), randInt(1, 8), xOff, yOff, rand(-0.5, 0.5),
      12.0, 12.0, 1, 3 // InspectionType=3: Qfn
    );
    insertCount++;
  }
}

// LOT-002: 90분~ 180분
for (let m = 90; m < 180; m++) {
  const minuteTime = addMinutes(start, m);
  const lotId      = lot2Id;
  const recipe     = 'BGA-256';
  const passRate   = m < 120 ? 0.995 : m < 150 ? 0.97 : 0.99;

  for (let i = 0; i < 20; i++) {
    const sTime = new Date(minuteTime.getTime() + i * 3000);
    const dur   = randInt(100, 200);
    const eTime = new Date(sTime.getTime() + dur);
    const pass  = Math.random() < passRate;
    const item  = pass ? 'PASS' : errorTypes[randInt(0, errorTypes.length - 1)];
    const xOff  = rand(-0.015, 0.015);
    const yOff  = rand(-0.015, 0.015);

    insertInsp.run(
      lotId, recipe, dur, fmt(sTime), fmt(eTime), item,
      randInt(1, 16), randInt(1, 16), xOff, yOff, rand(-0.5, 0.5),
      35.0, 35.0, 1, 2 // InspectionType=2: Bga
    );
    insertCount++;
  }
}

console.log(`inspection_results 삽입: ${insertCount}건`);

// ──────────────────────────────────────────
// 3. histories 삽입 (LOT 시작/종료, Recipe 변경, 시스템 이벤트)
// ──────────────────────────────────────────
const insertHist = db.prepare(`
  INSERT INTO histories (Time, Package, LotId, Camera, LogType, Description, Inspection)
  VALUES (?, ?, ?, ?, ?, ?, ?)
`);

const histEvents = [
  // LogType: 1=System, 2=Inspection, 4=LOT, 5=Recipe
  { offset:  0, lotId: null,   cam: null, type: 1, desc: 'GVISION START',                                    insp: null },
  { offset:  1, lotId: null,   cam: null, type: 5, desc: 'Recipe 변경: QFN-48',                              insp: null },
  { offset:  2, lotId: lot1Id, cam: null, type: 4, desc: 'LOT 시작: DUMMY-LOT-001',                          insp: null },

  // 카메라 오류
  { offset: 15, lotId: lot1Id, cam: 1,   type: 1, desc: 'Exception: CameraTimeOut on Camera1',               insp: null },
  { offset: 22, lotId: lot1Id, cam: 1,   type: 1, desc: 'Exception: PrsImageDequeue failed — 재시도 중',     insp: null },
  { offset: 27, lotId: lot1Id, cam: 1,   type: 1, desc: 'CameraTrigger signal lost on Camera1',              insp: null },

  { offset: 28, lotId: lot1Id, cam: 1,   type: 1, desc: '카메라 노출값 조정',                               insp: null },
  { offset: 31, lotId: lot1Id, cam: null, type: 1, desc: '조명 이상 감지 — 수율 하락 시작',                  insp: null },

  // 비전 오류
  { offset: 35, lotId: lot1Id, cam: null, type: 1, desc: 'VisionNotFound — 비전 라이브러리 응답 없음',        insp: null },
  { offset: 40, lotId: lot1Id, cam: null, type: 1, desc: 'VisionIf 초기화 실패 — 재연결 시도',               insp: null },

  // 통신 오류
  { offset: 45, lotId: lot1Id, cam: null, type: 1, desc: 'Exception: UdpSend timeout — 재전송',              insp: null },
  { offset: 48, lotId: lot1Id, cam: null, type: 1, desc: 'UdpBinding error — 소켓 초기화 실패',              insp: null },

  // 예외
  { offset: 50, lotId: lot1Id, cam: null, type: 1, desc: 'Exception: 알 수 없는 검사 오류 발생',             insp: null },

  { offset: 52, lotId: lot1Id, cam: null, type: 1, desc: '조명 재조정 완료',                                 insp: null },
  { offset: 81, lotId: lot1Id, cam: null, type: 4, desc: 'LOT 종료: DUMMY-LOT-001',                          insp: null },
  { offset: 89, lotId: null,   cam: null, type: 5, desc: 'Recipe 변경: BGA-256',                             insp: null },
  { offset: 90, lotId: lot2Id, cam: null, type: 4, desc: 'LOT 시작: DUMMY-LOT-002',                          insp: null },

  // 카메라 오류 (LOT-002)
  { offset: 95, lotId: lot2Id, cam: 2,   type: 1, desc: 'Exception: NotInitializedCamera on Camera2',        insp: null },
  { offset: 98, lotId: lot2Id, cam: 2,   type: 1, desc: 'CameraTrigger 응답 지연 — 재초기화',               insp: null },

  { offset:120, lotId: lot2Id, cam: 2,   type: 1, desc: 'Z축 높이 보정 실행',                               insp: null },

  // 비전 / 라이선스 오류 (LOT-002)
  { offset:130, lotId: lot2Id, cam: null, type: 1, desc: 'Exception: HalconLicense check failed',             insp: null },
  { offset:145, lotId: lot2Id, cam: null, type: 1, desc: 'VisionIf 연결 끊김 — 재연결 성공',                 insp: null },

  // 통신 오류 (LOT-002)
  { offset:155, lotId: lot2Id, cam: null, type: 1, desc: 'UdpSocket 바인딩 실패 — 포트 충돌 가능성',          insp: null },
  { offset:160, lotId: lot2Id, cam: null, type: 1, desc: 'Exception: UdpSend 반복 실패 (3회)',               insp: null },

  { offset:181, lotId: lot2Id, cam: null, type: 4, desc: 'LOT 종료: DUMMY-LOT-002',                          insp: null },
];

histEvents.forEach(e => {
  const t = fmt(addMinutes(start, e.offset));
  insertHist.run(t, e.lotId ? (e.lotId === lot1Id ? 'QFN-48' : 'BGA-256') : null,
    e.lotId, e.cam, e.type, e.desc, e.insp);
});

console.log(`histories 삽입: ${histEvents.length}건`);
console.log('\n완료! Grafana 대시보드를 새로고침하세요.');
console.log('삭제하려면: node server/seed-dummy.js --clean');
