const express = require('express');
const router = express.Router();
const { getSuperAdminOverview, getStationAnalytics } = require('../controllers/analytics.controller');
const { protect } = require('../middleware/auth.middleware');
const { restrictTo } = require('../middleware/role.middleware');

router.get('/overview', protect, getSuperAdminOverview);
router.get('/station/:stationId', protect, restrictTo('super_admin', 'station_admin'), getStationAnalytics);

module.exports = router;
