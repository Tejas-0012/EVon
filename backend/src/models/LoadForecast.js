const mongoose = require('mongoose');

const loadForecastSchema = new mongoose.Schema(
  {
    station: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Station',
      default: null, // null = system-wide
      index: true,
    },
    forecastTime: {
      type: Date,
      required: true,
      index: true,
    },
    predictedLoadKwh: {
      type: Number,
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('LoadForecast', loadForecastSchema);
