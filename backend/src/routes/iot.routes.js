const express = require('express');
const router = express.Router();
const {
  getIotStatus,
  updateBayStatus,
  sendHeartbeat,
  resetBays,
  disconnectHub,
} = require('../controllers/iot.controller');

router.get('/status', getIotStatus);
router.post('/bay-status', updateBayStatus);
router.post('/status', updateBayStatus);
router.post('/heartbeat', sendHeartbeat);
router.post('/reset', resetBays);
router.post('/disconnect', disconnectHub);

module.exports = router;
