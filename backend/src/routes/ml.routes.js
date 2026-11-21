const express = require('express');
const router = express.Router();
const {
  getMlStatus,
  getStationDemand,
  getStationDemandCurve,
  getLoadForecasts,
} = require('../controllers/ml.controller');

router.get('/status', getMlStatus);
router.get('/demand/curve', getStationDemandCurve);
router.get('/demand/station/:stationId', getStationDemand);
router.get('/load/forecast', getLoadForecasts);

module.exports = router;
