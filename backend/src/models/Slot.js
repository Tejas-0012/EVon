const mongoose = require('mongoose');

const slotSchema = new mongoose.Schema(
  {
    station: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Station',
      required: true,
    },
    slotDate: {
      type: String, // 'YYYY-MM-DD'
      required: true,
      index: true,
    },
    slotTime: {
      type: String, // 'HH:MM'
      required: true,
    },
    status: {
      type: String,
      enum: ['Available', 'Booked', 'Occupied', 'Maintenance'],
      default: 'Available',
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Unique compound index so a station cannot have duplicate slots for the same date & time
slotSchema.index({ station: 1, slotDate: 1, slotTime: 1 }, { unique: true });

module.exports = mongoose.model('Slot', slotSchema);
