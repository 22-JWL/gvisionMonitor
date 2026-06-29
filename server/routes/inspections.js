/**
 * routes/inspections.js — 시계열 검사 데이터 API
 *
 * GET /api/inspections/series
 *   원시 검사 결과 목록 (모든 필드)
 *   쿼리: from, to (ISO string), lotId
 *
 * GET /api/inspections/yield
 *   수율 시계열 — 1분 단위 집계
 *   그래프 X축: minute, Y축: yield(%)
 *   쿼리: from, to, lotId
 *
 * GET /api/inspections/duration
 *   처리시간 시계열 — 1분 단위 평균
 *   쿼리: from, to, lotId
 *
 * GET /api/inspections/errors
 *   불량 유형별 건수 (파이/바 차트용)
 *   쿼리: lotId (필수)
 *
 * GET /api/inspections/heatmap
 *   XY 위치별 불량 분포 (히트맵용)
 *   쿼리: lotId (필수)
 */

const express = require('express');
const router = express.Router();
const db = require('../db');

// DB 저장 형식(KST, 'YYYY-MM-DD HH:MM:SS')에 맞는 문자열 반환
function kstStr(d) {
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  return kst.toISOString().replace('T', ' ').substring(0, 19);
}

// 기본 시간 범위: 오늘 00:00 KST ~ 현재 (당일 전체)
function defaultRange() {
  const now  = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const todayKst = new Date(kstNow.toISOString().substring(0, 10) + 'T00:00:00Z');
  return {
    from: kstStr(new Date(todayKst.getTime() - 9 * 60 * 60 * 1000)), // KST 00:00
    to:   kstStr(now),
  };
}

// GET /api/inspections/series
router.get('/series', (req, res) => {
  const { from, to } = req.query.from ? req.query : defaultRange();
  const lotId = req.query.lotId ? parseInt(req.query.lotId) : null;

  const data = db.getInspectionSeries(from, to, lotId);
  res.json({ count: data.length, from, to, data });
});

// GET /api/inspections/yield
router.get('/yield', (req, res) => {
  const { from, to } = req.query.from ? req.query : defaultRange();
  const lotId = req.query.lotId ? parseInt(req.query.lotId) : null;

  const data = db.getYieldSeries(from, to, lotId);
  res.json({ from, to, data });
});

// GET /api/inspections/duration
router.get('/duration', (req, res) => {
  const { from, to } = req.query.from ? req.query : defaultRange();
  const lotId = req.query.lotId ? parseInt(req.query.lotId) : null;

  const data = db.getDurationSeries(from, to, lotId);
  res.json({ from, to, data });
});

// GET /api/inspections/errors
// lotId 없으면 전체 또는 오늘 기준 불량 유형별 집계 반환
router.get('/errors', (req, res) => {
  const lotId = req.query.lotId ? parseInt(req.query.lotId) : null;
  const today = req.query.today === '1';

  if (lotId) {
    const data = db.getErrorBreakdown(lotId);
    return res.json({ lotId, data });
  }

  const data = db.getErrorBreakdownGlobal(today);
  res.json({ today, data });
});

// GET /api/inspections/heatmap
router.get('/heatmap', (req, res) => {
  const lotId = parseInt(req.query.lotId);
  if (!lotId) return res.status(400).json({ error: 'lotId 파라미터가 필요합니다.' });

  const data = db.getFailHeatmap(lotId);
  res.json({ lotId, data });
});

module.exports = router;
