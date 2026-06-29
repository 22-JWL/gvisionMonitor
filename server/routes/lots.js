/**
 * routes/lots.js
 *
 * GET /api/lots
 *   쿼리 파라미터:
 *     limit - 가져올 개수 (기본 20)
 *
 * GET /api/lots/:id/stats
 *   특정 Lot의 수율 통계 (검사 타입별 pass/fail/yield)
 */

const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/lots
router.get('/', (req, res) => {
  const limit = parseInt(req.query.limit) || 20;
  const lots = db.getLots(limit);
  res.json({ count: lots.length, lots });
});

// GET /api/lots/:id/stats
router.get('/:id/stats', (req, res) => {
  const lotId = parseInt(req.params.id);
  const stats = db.getLotStats(lotId);

  if (!stats) {
    return res.status(404).json({ error: `Lot Id ${lotId}를 찾을 수 없습니다.` });
  }

  res.json(stats);
});

module.exports = router;
