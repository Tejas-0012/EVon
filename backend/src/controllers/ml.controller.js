const Station = require('../models/Station');
const { predictDemand, forecastLoad, predictBestSlotAndBay } = require('../services/mlClient.service');

// @desc    Get ML service status
// @route   GET /api/ml/status
// @access  Public
const getMlStatus = async (req, res) => {
  res.json({
    success: true,
    engine: 'EVon Scikit-Learn & Keras LSTM Microservice Bridge',
    mlServiceUrl: process.env.ML_SERVICE_URL || 'http://localhost:8000',
    models: {
      demandPredictor: 'RandomForestRegressor & LinearRegression',
      loadForecaster: 'TensorFlow/Keras LSTM Recurrent Neural Network',
    },
  });
};

// @desc    Get predicted demand for a specific station
// @route   GET /api/ml/demand/station/:stationId
// @access  Public
const getStationDemand = async (req, res, next) => {
  try {
    const { stationId } = req.params;
    const { date, hour } = req.query;

    const station = await Station.findById(stationId);
    if (!station) {
      return res.status(404).json({ success: false, message: 'Station not found' });
    }

    const prediction = await predictDemand({
      stationId: station._id,
      chargerPower: station.chargerPower,
      totalSlots: station.totalSlots,
      date,
      hour: hour !== undefined ? parseInt(hour) : new Date().getHours(),
    });

    res.json({
      success: true,
      station: {
        id: station._id,
        name: station.stationName,
        chargerPower: station.chargerPower,
      },
      ...prediction,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get 24-hour system load forecast (LSTM)
// @route   GET /api/ml/load/forecast
// @access  Public
const getLoadForecasts = async (req, res, next) => {
  try {
    const { stationId, horizonHours } = req.query;

    const forecast = await forecastLoad({
      stationId: stationId || null,
      horizonHours: horizonHours ? parseInt(horizonHours) : 24,
    });

    res.json({
      success: true,
      ...forecast,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Predict Best Slot & Best Bay (Fast Time & Low Traffic Optimization)
// @route   GET /api/ml/predict/best-slot-bay
// @access  Public
const getBestSlotBayPrediction = async (req, res, next) => {
  try {
    const { stationId, date, hour } = req.query;

    let station = null;
    if (stationId) {
      station = await Station.findById(stationId);
    } else {
      station = await Station.findOne({ status: 'Active' });
    }

    const prediction = await predictBestSlotAndBay({
      station,
      date,
      hour: hour !== undefined ? parseInt(hour) : new Date().getHours(),
    });

    res.json({
      success: true,
      station: station
        ? {
            id: station._id,
            stationName: station.stationName,
            chargerPower: station.chargerPower,
            chargerType: station.chargerType,
            totalSlots: station.totalSlots,
          }
        : null,
      ...prediction,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getMlStatus,
  getStationDemand,
  getLoadForecasts,
  getBestSlotBayPrediction,
};
