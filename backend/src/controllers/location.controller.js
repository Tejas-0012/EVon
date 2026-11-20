const {
  geocodeAddress,
  reverseGeocode,
  searchLocations,
} = require('../services/googleMaps.service');

// @desc    Geocode a text address to coordinates using Google Maps
// @route   GET /api/locations/geocode
// @access  Public
const geocode = async (req, res, next) => {
  try {
    const { address } = req.query;
    if (!address) {
      return res.status(400).json({ success: false, message: 'Please provide address parameter' });
    }

    const result = await geocodeAddress(address);
    res.json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Reverse geocode coordinates to street address
// @route   GET /api/locations/reverse
// @access  Public
const reverse = async (req, res, next) => {
  try {
    const { lat, lng } = req.query;
    if (lat === undefined || lng === undefined) {
      return res.status(400).json({ success: false, message: 'Please provide lat and lng parameters' });
    }

    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);

    if (isNaN(latitude) || isNaN(longitude)) {
      return res.status(400).json({ success: false, message: 'Invalid lat/lng numbers' });
    }

    const result = await reverseGeocode(latitude, longitude);
    res.json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Search locations and places matching query
// @route   GET /api/locations/search
// @access  Public
const search = async (req, res, next) => {
  try {
    const { query } = req.query;
    if (!query) {
      return res.status(400).json({ success: false, message: 'Please provide query parameter' });
    }

    const results = await searchLocations(query);
    res.json({
      success: true,
      count: results.length,
      locations: results,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  geocode,
  reverse,
  search,
};
