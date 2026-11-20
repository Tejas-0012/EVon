const mongoose = require('mongoose');

const demandPredictionSchema = new mongoose.Schema(
  {
    station: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Station',
      required: true,
      index: true,
    },
    predictionDate: {
      type: String, // 'YYYY-MM-DD'
      required: true,
      index: true,
    },
    predictionHour: {
      type: Number, // 0-23
      required: true,
    },
    predictedDemand: {
      type: Number,
      required: true,
    },
    congestionLevel: {
      type: String,
      enum: ['Low', 'Medium', 'High'],
      default: 'Low',
    },
  },
  {
    timestamps: true,
  }
);

demandPredictionSchema.index({ station: 1, predictionDate: 1, predictionHour: 1 }, { unique: true });

module.exports = mongoose.model('DemandPrediction', demandPredictionSchema);
