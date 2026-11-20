const mongoose = require('mongoose');

const analyticsLogSchema = new mongoose.Schema(
  {
    station: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Station',
      required: true,
      index: true,
    },
    logDate: {
      type: String, // 'YYYY-MM-DD'
      required: true,
      index: true,
    },
    totalBookings: {
      type: Number,
      default: 0,
    },
    energyUsed: {
      type: Number, // kWh
      default: 0.0,
    },
    utilizationPercentage: {
      type: Number,
      default: 0.0,
    },
    revenue: {
      type: Number,
      default: 0.0,
    },
  },
  {
    timestamps: true,
  }
);

analyticsLogSchema.index({ station: 1, logDate: 1 }, { unique: true });

module.exports = mongoose.model('AnalyticsLog', analyticsLogSchema);
