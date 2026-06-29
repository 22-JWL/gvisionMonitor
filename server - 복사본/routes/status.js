/**
 * routes/status.js
 *
 * GET /api/status          → JSON (full)
 * GET /api/status/mode     → CSV  (runningMode as number: Run=1 SetUp=2 OFFLINE=0)
 * GET /api/status/recipe   → CSV  (recipeName string)
 * GET /api/status/lot      → CSV  (lotNo string)
 *
 * Grafana Infinity datasource + stat panel 은 string-type JSON 컬럼을 NoData로
 * 반환하는 버그가 있어서, CSV 형식으로 우회한다.
 */

const express = require('express');
const router = express.Router();
const wsManager = require('../websocket');
const { getLastStatus } = require('../poller');

const MODE_CODE = { Run: 1, SetUp: 2, OFFLINE: 0 };

function getCurrentValues() {
  const status = getLastStatus();
  if (status) {
    return {
      modeCode:   MODE_CODE[status.runningMode] ?? 0,
      recipeName: status.recipeName ?? '',
      lotNo:      status.lotNo      ?? '',
      connectedClients: wsManager.getClientCount(),
    };
  }
  return { modeCode: 0, recipeName: '(GvisionWpf 미실행)', lotNo: '-', connectedClients: 0 };
}

// ── full JSON (connectedClients panel 용) ──────────────────────────────
router.get('/', (req, res) => {
  const v = getCurrentValues();
  res.json({ rows: [{ connectedClients: v.connectedClients }] });
});

// ── 장비 모드 (숫자로 인코딩 → Infinity stat panel이 number는 OK) ───────
router.get('/mode', (req, res) => {
  const { modeCode } = getCurrentValues();
  res.type('text/csv').send(`value\n${modeCode}\n`);
});

// ── 현재 Recipe (CSV string) ─────────────────────────────────────────
router.get('/recipe', (req, res) => {
  const { recipeName } = getCurrentValues();
  res.type('text/csv').send(`value\n${recipeName}\n`);
});

// ── 현재 Lot 번호 (CSV string) ───────────────────────────────────────
router.get('/lot', (req, res) => {
  const { lotNo } = getCurrentValues();
  res.type('text/csv').send(`value\n${lotNo}\n`);
});

module.exports = router;
