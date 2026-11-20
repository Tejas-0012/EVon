const express = require('express');
const router = express.Router();
const {
  getBookingQuote,
  createBooking,
  cancelBooking,
  getMyBookings,
  getAllBookings,
  getBookingById,
  updateBookingStatus,
} = require('../controllers/booking.controller');
const { protect } = require('../middleware/auth.middleware');
const { restrictTo } = require('../middleware/role.middleware');

router.post('/quote', getBookingQuote);
router.post('/', protect, createBooking);
router.get('/my', protect, getMyBookings);
router.get('/', protect, restrictTo('super_admin', 'station_admin'), getAllBookings);
router.get('/:id', protect, getBookingById);
router.put('/:id/cancel', protect, cancelBooking);
router.put('/:id/status', protect, restrictTo('super_admin', 'station_admin'), updateBookingStatus);

module.exports = router;
