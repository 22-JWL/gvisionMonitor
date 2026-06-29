/**
 * routes/events.js
 *
 * GET /api/events
 *   쿼리 파라미터:
 *     limit   - 가져올 개수 (기본 50)
 *     logType - 필터 (숫자: 1=System, 2=Inspection, 3=Database, 4=LOT, 5=Recipe)
 *
 * GET /api/events/:id/context
 *   특정 이벤트 발생 전후 맥락 (대시보드 Context Card용)
 *   쿼리 파라미터:
 *     before - 이전 몇 분 (기본 5)
 *     after  - 이후 몇 분 (기본 5)
 */

const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/events
router.get('/', (req, res) => {
  const limit   = parseInt(req.query.limit)   || 50;
  const logType = req.query.logType ? parseInt(req.query.logType) : null;

  const events = db.getRecentEvents(limit, logType);
  res.json({ count: events.length, events });
});

// GET /api/events/:id/context
router.get('/:id/context', (req, res) => {
  const id     = parseInt(req.params.id);
  const before = parseInt(req.query.before) || 5;
  const after  = parseInt(req.query.after)  || 5;

  // 기준 이벤트 조회
  const events = db.getRecentEvents(1000); // 전체에서 찾기
  const target = events.find(e => e.Id === id);

  if (!target) {
    return res.status(404).json({ error: `이벤트 Id ${id}를 찾을 수 없습니다.` });
  }

  // 전후 맥락 이벤트
  const contextEvents = db.getEventContext(target.Time, before, after);

  res.json({
    target,             // 기준 이벤트
    context: contextEvents,  // 전후 이벤트 목록
    window: { before, after },
  });
});

module.exports = router;
