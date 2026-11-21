const express = require('express');
const router = express.Router();
const {
  getMlStatus,
  getStationDemand,
  getLoadForecasts,
  getBestSlotBayPrediction,
} = require('../controllers/ml.controller');

router.get('/status', getMlStatus);
router.get('/demand/station/:stationId', getStationDemand);
router.get('/load/forecast', getLoadForecasts);
router.get('/predict/best-slot-bay', getBestSlotBayPrediction);

module.exports = router;
