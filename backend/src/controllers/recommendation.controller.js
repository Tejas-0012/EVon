const Station = require('../models/Station');
const {
  rankStationsForRoute,
  getHybridDrivingRoute,
  resolveCoordinates,
} = require('../services/recommendation.service');

// @desc    Get smart station recommendations along a trip route
// @route   GET /api/recommendations/route
// @access  Public
const getRouteRecommendations = async (req, res, next) => {
  try {
    const { origin, destination, currentSoc, batteryCapacity } = req.query;

    if (!origin || !destination) {
      return res.status(400).json({
        success: false,
        message:
          'Please provide both origin and destination query parameters (e.g. ?origin=koramangala&destination=whitefield)',
      });
    }

    const originCoords = await resolveCoordinates(origin);
    const destCoords = await resolveCoordinates(destination);

    // Call Hybrid Routing Engine (Google Maps Directions with OSRM fallback)
    const drivingRoute = await getHybridDrivingRoute(originCoords, destCoords);

    const stations = await Station.find({ status: 'Active' });
    const ranked = rankStationsForRoute(stations, originCoords, destCoords);

    // Battery & Range Analysis for EV journey
    const cap = parseFloat(batteryCapacity) || 40.5; // kWh (e.g. Tata Nexon EV default)
    const soc = currentSoc !== undefined ? parseFloat(currentSoc) : 40.0; // %
    const kmPerKwh = 6.5; // standard real-world EV efficiency (approx 15.3 kWh/100km)
    const remainingKwh = parseFloat(((soc / 100) * cap).toFixed(2));
    const estimatedRangeKm = parseFloat((remainingKwh * kmPerKwh).toFixed(1));

    const distKm =
      drivingRoute?.distanceKm ||
      parseFloat(
        (drivingRoute?.distanceText ? parseFloat(drivingRoute.distanceText) : 20.0).toString()
      ) ||
      20.0;

    let signal = 'GREEN';
    let statusTitle = 'Easily Continue';
    let message = `Battery sufficient! You have ~${estimatedRangeKm} km range for this ${distKm} km trip. You can reach without stopping.`;
    let needsCharging = false;

    if (estimatedRangeKm < distKm) {
      signal = 'RED';
      statusTitle = 'Recharge Stop Required!';
      const deficit = (distKm - estimatedRangeKm).toFixed(1);
      message = `Warning: Battery insufficient! Range is ~${estimatedRangeKm} km for a ${distKm} km trip (deficit of ${deficit} km). Recommend charging on the way.`;
      needsCharging = true;
    } else if (estimatedRangeKm < distKm * 1.3) {
      signal = 'YELLOW';
      statusTitle = 'Low Buffer - Caution';
      message = `Caution: Tight battery margin (~${estimatedRangeKm} km range vs ${distKm} km route). Traffic or AC may require a top-up on the way.`;
      needsCharging = true;
    }

    const batteryAnalysis = {
      batteryCapacity: cap,
      currentSoc: soc,
      remainingKwh,
      estimatedRangeKm,
      distanceKm: distKm,
      bufferKm: parseFloat((estimatedRangeKm - distKm).toFixed(1)),
      signal, // 'GREEN' | 'YELLOW' | 'RED'
      statusTitle,
      message,
      needsCharging,
    };

    res.json({
      success: true,
      origin: { label: origin, ...originCoords },
      destination: { label: destination, ...destCoords },
      route: drivingRoute,
      routePoints: drivingRoute?.routePoints || [
        [originCoords.lat, originCoords.lng],
        [destCoords.lat, destCoords.lng],
      ],
      distanceText: drivingRoute?.distanceText || `${distKm} km`,
      distanceKm: distKm,
      durationText: drivingRoute?.durationText || '',
      routingEngine: drivingRoute?.source || 'Direct Corridor',
      batteryAnalysis,
      count: ranked.length,
      stations: ranked.slice(0, 10),
      recommendations: ranked.slice(0, 10),
      enRouteChargers: ranked.slice(0, 5),
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getRouteRecommendations,
};
