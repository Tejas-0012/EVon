const Payment = require('../models/Payment');
const Booking = require('../models/Booking');

// @desc    Process mock payment for a booking
// @route   POST /api/payments
// @access  Private
const processPayment = async (req, res, next) => {
  try {
    const { bookingId, amount, paymentMethod } = req.body;

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    if (booking.paymentStatus === 'Paid') {
      return res.status(400).json({ success: false, message: 'This booking has already been paid' });
    }

    // Generate unique transaction ID
    const transactionId = `EVON-TXN-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    const payment = await Payment.create({
      booking: booking._id,
      user: req.user._id,
      amount: amount || booking.estimatedCost,
      paymentStatus: 'Success',
      paymentMethod: paymentMethod || 'Demo Card / UPI',
      transactionId,
    });

    booking.paymentStatus = 'Paid';
    booking.bookingStatus = 'Paid';
    await booking.save();

    res.status(200).json({
      success: true,
      message: 'Payment completed successfully',
      payment,
      booking,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get payment details for a booking
// @route   GET /api/payments/booking/:bookingId
// @access  Private
const getPaymentByBooking = async (req, res, next) => {
  try {
    const payment = await Payment.findOne({ booking: req.params.bookingId });
    if (!payment) {
      return res.status(404).json({ success: false, message: 'No payment record found for this booking' });
    }

    res.json({
      success: true,
      payment,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  processPayment,
  getPaymentByBooking,
};
