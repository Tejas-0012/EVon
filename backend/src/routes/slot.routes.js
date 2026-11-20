const express = require('express');
const router = express.Router();
const { updateSlotStatus } = require('../controllers/slot.controller');
const { protect } = require('../middleware/auth.middleware');
const { restrictTo } = require('../middleware/role.middleware');

router.put('/:slotId', protect, restrictTo('super_admin', 'station_admin'), updateSlotStatus);

module.exports = router;
