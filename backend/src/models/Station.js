const mongoose = require('mongoose');

const stationSchema = new mongoose.Schema(
  {
    stationName: {
      type: String,
      required: [true, 'Please provide station name'],
      trim: true,
    },
    address: {
      type: String,
      required: [true, 'Please provide address'],
    },
    city: {
      type: String,
      required: [true, 'Please provide city'],
      default: 'Bangalore',
    },
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        required: true,
      },
    },
    chargerType: {
      type: String,
      enum: ['AC Slow', 'AC Fast', 'DC Fast', 'Ultra Fast'],
      required: true,
    },
    chargerPower: {
      type: Number,
      required: true, // in kW
    },
    totalSlots: {
      type: Number,
      default: 4,
    },
    availableSlots: {
      type: Number,
      default: 4,
    },
    occupiedSlots: {
      type: Number,
      default: 0,
    },
    status: {
      type: String,
      enum: ['Active', 'Inactive', 'Maintenance'],
      default: 'Active',
    },
    pricePerKwh: {
      type: Number,
      default: 12.0,
    },
    isIotHub: {
      type: Boolean,
      default: false,
    },
    hubId: {
      type: String,
      default: null,
      unique: true,
      sparse: true,
    },
    iotLastPing: {
      type: Date,
      default: null,
    },
    isIotActive: {
      type: Boolean,
      default: false,
    },
    bays: [
      {
        bayNumber: {
          type: Number,
          default: 1,
        },
        status: {
          type: String,
          enum: ['Available', 'Parked', 'Charging'],
          default: 'Available',
        },
        lastUpdated: {
          type: Date,
          default: Date.now,
        },
      },
    ],
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Geospatial index for nearby station search
stationSchema.index({ location: '2dsphere' });
stationSchema.index({ status: 1 });
stationSchema.index({ city: 1 });

// Helper virtuals
stationSchema.virtual('latitude').get(function () {
  return this.location && this.location.coordinates ? this.location.coordinates[1] : null;
});

stationSchema.virtual('longitude').get(function () {
  return this.location && this.location.coordinates ? this.location.coordinates[0] : null;
});

module.exports = mongoose.model('Station', stationSchema);
