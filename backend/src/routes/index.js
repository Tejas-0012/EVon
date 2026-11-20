const express = require('express');
const router = express.Router();

const authRoutes = require('./auth.routes');
const stationRoutes = require('./station.routes');
const slotRoutes = require('./slot.routes');
const bookingRoutes = require('./booking.routes');
const paymentRoutes = require('./payment.routes');
const recommendationRoutes = require('./recommendation.routes');
const mlRoutes = require('./ml.routes');
const analyticsRoutes = require('./analytics.routes');
const iotRoutes = require('./iot.routes');
const locationRoutes = require('./location.routes');

router.use('/auth', authRoutes);
router.use('/stations', stationRoutes);
router.use('/slots', slotRoutes);
router.use('/bookings', bookingRoutes);
router.use('/payments', paymentRoutes);
router.use('/recommendations', recommendationRoutes);
router.use('/ml', mlRoutes);
router.use('/analytics', analyticsRoutes);
router.use('/iot', iotRoutes);
router.use('/locations', locationRoutes);

module.exports = router;
