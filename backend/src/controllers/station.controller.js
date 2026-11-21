const Station = require('../models/Station');
const { estimateStationWaitTime } = require('../services/waitTime.service');
const { geocodeAddress } = require('../services/googleMaps.service');
const { haversineKm } = require('../services/recommendation.service');

const IOT_TIMEOUT_MS = 5 * 60 * 1000;

/**
 * Augment station with live wait time, dynamic IoT active/offline health, and full bay list
 */
const augmentStation = (st) => {
  const obj = st.toObject ? st.toObject() : { ...st };
  obj.waitTime = estimateStationWaitTime(st);

  if (obj.isIotHub) {
    const lastPing = obj.iotLastPing ? new Date(obj.iotLastPing).getTime() : 0;
    const isOnline = lastPing > 0 && Date.now() - lastPing < IOT_TIMEOUT_MS;
    obj.isIotActive = isOnline;
    obj.iotStatusMessage = isOnline ? 'Active (Live Synced)' : 'Not Available (ESP32 Offline)';
    if (!isOnline) {
      obj.availableSlots = 0;
    }
  }

  // Ensure dynamic bays array matches totalSlots (e.g. 4 slots -> 4 bays in 2x2 grid)
  const totalSlots = obj.totalSlots || 4;
  const existingBays = obj.bays || [];
  const fullBays = [];
  for (let i = 1; i <= totalSlots; i++) {
    const match = existingBays.find((b) => b.bayNumber === i);
    if (match) {
      fullBays.push(match);
    } else {
      fullBays.push({
        bayNumber: i,
        status: i <= (obj.occupiedSlots || 0) ? 'Charging' : 'Available',
        lastUpdated: new Date(),
      });
    }
  }
  obj.bays = fullBays;

  return obj;
};

// @desc    Get all charging stations
// @route   GET /api/stations
// @access  Public
const getAllStations = async (req, res, next) => {
  try {
    const { city, status, chargerType, search } = req.query;
    const filter = {};

    if (city) filter.city = new RegExp(city, 'i');
    if (status) filter.status = status;
    if (chargerType) filter.chargerType = chargerType;
    if (search) {
      filter.$or = [
        { stationName: new RegExp(search, 'i') },
        { address: new RegExp(search, 'i') },
        { city: new RegExp(search, 'i') },
      ];
    }

    const stations = await Station.find(filter).sort({ isIotHub: -1, stationName: 1 });

    const augmented = stations.map(augmentStation);

    res.json({
      success: true,
      count: stations.length,
      stations: augmented,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get stations nearby user coordinates or searched location
// @route   GET /api/stations/nearby
// @access  Public
const getNearbyStations = async (req, res, next) => {
  try {
    let { lat, lng, location, address, maxDistanceKm = 50 } = req.query;
    let resolvedLocation = null;

    if ((!lat || !lng) && (location || address)) {
      const geo = await geocodeAddress(location || address);
      lat = geo.lat;
      lng = geo.lng;
      resolvedLocation = geo;
    }

    if (!lat || !lng) {
      return res.status(400).json({
        success: false,
        message: 'Please provide lat & lng coordinates or a location/address query parameter',
      });
    }

    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);
    const maxMeters = parseFloat(maxDistanceKm) * 1000;

    let stations;
    try {
      // Use MongoDB 2dsphere $near
      stations = await Station.find({
        status: 'Active',
        location: {
          $near: {
            $geometry: {
              type: 'Point',
              coordinates: [longitude, latitude],
            },
            $maxDistance: maxMeters,
          },
        },
      });
    } catch (geoErr) {
      // Fallback if 2dsphere index is still building
      stations = await Station.find({ status: 'Active' });
    }

    const augmented = stations.map((st) => {
      const base = augmentStation(st);
      const stLat = base.latitude || (base.location?.coordinates ? base.location.coordinates[1] : 0);
      const stLng = base.longitude || (base.location?.coordinates ? base.location.coordinates[0] : 0);
      const dist = haversineKm(latitude, longitude, stLat, stLng);
      return {
        ...base,
        distanceKm: dist,
        distanceText: `${dist.toFixed(1)} km`,
      };
    }).sort((a, b) => (a.distanceKm || 0) - (b.distanceKm || 0));

    res.json({
      success: true,
      count: augmented.length,
      userLocation: {
        latitude,
        longitude,
        ...(resolvedLocation ? { formattedAddress: resolvedLocation.formattedAddress } : {}),
      },
      stations: augmented,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get single station by ID
// @route   GET /api/stations/:id
// @access  Public
const getStationById = async (req, res, next) => {
  try {
    const station = await Station.findById(req.params.id);
    if (!station) {
      return res.status(404).json({ success: false, message: 'Charging station not found' });
    }

    res.json({
      success: true,
      station: augmentStation(station),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Create a new station
// @route   POST /api/stations
// @access  Private (super_admin)
const createStation = async (req, res, next) => {
  try {
    const { stationName, address, city, latitude, longitude, chargerType, chargerPower, totalSlots, pricePerKwh } =
      req.body;

    if (!stationName || !address || latitude === undefined || longitude === undefined || !chargerType || !chargerPower) {
      return res.status(400).json({ success: false, message: 'Please provide all required station fields' });
    }

    const station = await Station.create({
      stationName,
      address,
      city: city || 'Bangalore',
      location: {
        type: 'Point',
        coordinates: [parseFloat(longitude), parseFloat(latitude)],
      },
      chargerType,
      chargerPower: parseFloat(chargerPower),
      totalSlots: totalSlots ? parseInt(totalSlots) : 4,
      availableSlots: totalSlots ? parseInt(totalSlots) : 4,
      occupiedSlots: 0,
      pricePerKwh: pricePerKwh ? parseFloat(pricePerKwh) : 12.0,
      status: 'Active',
    });

    res.status(201).json({
      success: true,
      station,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update a station
// @route   PUT /api/stations/:id
// @access  Private (super_admin / station_admin)
const updateStation = async (req, res, next) => {
  try {
    const station = await Station.findById(req.params.id);
    if (!station) {
      return res.status(404).json({ success: false, message: 'Station not found' });
    }

    const {
      stationName,
      address,
      city,
      latitude,
      longitude,
      chargerType,
      chargerPower,
      totalSlots,
      availableSlots,
      occupiedSlots,
      status,
      pricePerKwh,
    } = req.body;

    if (stationName) station.stationName = stationName;
    if (address) station.address = address;
    if (city) station.city = city;
    if (latitude !== undefined && longitude !== undefined) {
      station.location = {
        type: 'Point',
        coordinates: [parseFloat(longitude), parseFloat(latitude)],
      };
    }
    if (chargerType) station.chargerType = chargerType;
    if (chargerPower !== undefined) station.chargerPower = parseFloat(chargerPower);
    if (totalSlots !== undefined) station.totalSlots = parseInt(totalSlots);
    if (availableSlots !== undefined) station.availableSlots = parseInt(availableSlots);
    if (occupiedSlots !== undefined) station.occupiedSlots = parseInt(occupiedSlots);
    if (status) station.status = status;
    if (pricePerKwh !== undefined) station.pricePerKwh = parseFloat(pricePerKwh);

    await station.save();

    res.json({
      success: true,
      station,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Delete a station
// @route   DELETE /api/stations/:id
// @access  Private (super_admin)
const deleteStation = async (req, res, next) => {
  try {
    const station = await Station.findByIdAndDelete(req.params.id);
    if (!station) {
      return res.status(404).json({ success: false, message: 'Station not found' });
    }

    res.json({
      success: true,
      message: 'Station deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getAllStations,
  getNearbyStations,
  getStationById,
  createStation,
  updateStation,
  deleteStation,
};
