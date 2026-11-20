const express = require('express');
const router = express.Router();
const { processPayment, getPaymentByBooking } = require('../controllers/payment.controller');
const { protect } = require('../middleware/auth.middleware');

router.post('/', protect, processPayment);
router.get('/booking/:bookingId', protect, getPaymentByBooking);

module.exports = router;
