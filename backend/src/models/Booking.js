const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    station: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Station',
      required: true,
      index: true,
    },
    slot: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Slot',
      default: null,
    },
    slotDate: {
      type: String,
      default: null,
    },
    slotTime: {
      type: String,
      default: null,
    },
    vehicleType: {
      type: String,
      default: 'Electric Car',
    },
    batteryCapacity: {
      type: Number,
      required: true, // kWh
    },
    currentSoc: {
      type: Number,
      required: true, // %
    },
    desiredSoc: {
      type: Number,
      required: true, // %
    },
    energyRequired: {
      type: Number,
      required: true, // kWh
    },
    chargingDuration: {
      type: Number,
      required: true, // hours
    },
    estimatedWaitTime: {
      type: Number,
      default: 0.0, // hours
    },
    estimatedCost: {
      type: Number,
      required: true,
    },
    sourceLocation: {
      type: String,
      default: '',
    },
    destinationLocation: {
      type: String,
      default: '',
    },
    bookingStatus: {
      type: String,
      enum: ['Pending', 'Confirmed', 'Accepted', 'Paid', 'Completed', 'Cancelled'],
      default: 'Pending',
      index: true,
    },
    paymentStatus: {
      type: String,
      enum: ['Unpaid', 'Paid', 'Refunded'],
      default: 'Unpaid',
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Booking', bookingSchema);
