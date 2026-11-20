const express = require('express');
const router = express.Router();
const {
  getAllStations,
  getNearbyStations,
  getStationById,
  createStation,
  updateStation,
  deleteStation,
} = require('../controllers/station.controller');
const { getStationSlots } = require('../controllers/slot.controller');
const { protect } = require('../middleware/auth.middleware');
const { restrictTo } = require('../middleware/role.middleware');

router.get('/', getAllStations);
router.get('/nearby', getNearbyStations);
router.get('/:id', getStationById);
router.get('/:stationId/slots', getStationSlots);

// Admin operations
router.post('/', protect, restrictTo('super_admin'), createStation);
router.put('/:id', protect, restrictTo('super_admin', 'station_admin'), updateStation);
router.delete('/:id', protect, restrictTo('super_admin'), deleteStation);

module.exports = router;
