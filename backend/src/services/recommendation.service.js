/**
 * EVon Route Recommendation Service
 * Hybrid Driving Route Engine:
 * 1. Tries Google Maps Directions API using GOOGLE_MAPS_API_KEY
 * 2. Seamlessly falls back to OpenStreetMap OSRM (100% free, real driving turn-by-turn roads)
 */

const https = require('https');

const BANGALORE_LANDMARKS = {
  koramangala: { lat: 12.9352, lng: 77.6245 },
  whitefield: { lat: 12.9698, lng: 77.75 },
  'mg road': { lat: 12.975, lng: 77.6063 },
  indiranagar: { lat: 12.9784, lng: 77.6408 },
  hsr: { lat: 12.9116, lng: 77.6473 },
  'hsr layout': { lat: 12.9116, lng: 77.6473 },
  jayanagar: { lat: 12.9308, lng: 77.5838 },
  'electronic city': { lat: 12.8456, lng: 77.6603 },
  marathahalli: { lat: 12.9591, lng: 77.6974 },
  bangalore: { lat: 12.9716, lng: 77.5946 },
  bengaluru: { lat: 12.9716, lng: 77.5946 },
  itpl: { lat: 12.9698, lng: 77.75 },
  airport: { lat: 13.1986, lng: 77.7066 },
};

/**
 * Great-circle distance between two coords in km
 */
const haversineKm = (lat1, lon1, lat2, lon2) => {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return parseFloat((R * c).toFixed(2));
};

/**
 * Decode Google Maps encoded polyline algorithm
 */
const decodePolyline = (encoded) => {
  const points = [];
  let index = 0;
  const len = encoded.length;
  let lat = 0;
  let lng = 0;

  while (index < len) {
    let b;
    let shift = 0;
    let result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlat = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlng = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
    lng += dlng;

    points.push([lat / 1e5, lng / 1e5]);
  }

  return points;
};

const { geocodeAddress } = require('./googleMaps.service');

/**
 * Geocode text input into { lat, lng } asynchronously using Google Maps Geocoding
 */
const resolveCoordinates = async (text) => {
  if (!text) return { lat: 12.9716, lng: 77.5946, formattedAddress: 'Bengaluru, Karnataka, India' };
  try {
    const geo = await geocodeAddress(text);
    return {
      lat: geo.lat,
      lng: geo.lng,
      formattedAddress: geo.formattedAddress,
    };
  } catch (err) {
    const clean = text.trim().toLowerCase();
    if (BANGALORE_LANDMARKS[clean]) {
      return { ...BANGALORE_LANDMARKS[clean], formattedAddress: clean };
    }
    return { lat: 12.9716, lng: 77.5946, formattedAddress: 'Bengaluru, Karnataka, India' };
  }
};

/**
 * 1. Fetch real driving route from Google Maps Directions API
 */
const fetchGoogleRoute = (origin, dest) => {
  return new Promise((resolve) => {
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) {
      return resolve(null);
    }

    const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${origin.lat},${origin.lng}&destination=${dest.lat},${dest.lng}&key=${apiKey}`;

    https.get(url, (res) => {
      let raw = '';
      res.on('data', (c) => (raw += c));
      res.on('end', () => {
        try {
          const data = JSON.parse(raw);
          if (data.status === 'OK' && data.routes && data.routes.length > 0) {
            console.log('[Routing] ✅ Successfully retrieved driving route from Google Maps Directions API');
            const route = data.routes[0];
            const poly = route.overview_polyline ? route.overview_polyline.points : '';
            const points = poly ? decodePolyline(poly) : [];
            const leg = route.legs[0] || {};

            resolve({
              source: 'Google Maps Directions API',
              distanceText: leg.distance?.text || '',
              durationText: leg.duration?.text || '',
              distanceKm: leg.distance?.value ? leg.distance.value / 1000 : 0,
              routePoints: points,
            });
          } else {
            console.warn(`[Routing Warning] Google Maps Directions: ${data.status} - ${data.error_message || 'Fallback to OSRM'}`);
            resolve(null);
          }
        } catch (e) {
          resolve(null);
        }
      });
    }).on('error', () => resolve(null));
  });
};

/**
 * 2. Fetch real driving route from OSRM (OpenStreetMap Routing Engine)
 * 100% Free, no API key required, real turn-by-turn road geometry!
 */
const fetchOSRMRoute = (origin, dest) => {
  return new Promise((resolve) => {
    const url = `https://router.project-osrm.org/route/v1/driving/${origin.lng},${origin.lat};${dest.lng},${dest.lat}?overview=full&geometries=geojson`;

    https.get(
      url,
      {
        headers: {
          'User-Agent': 'EVon-Charging-Platform/1.0',
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => (raw += c));
        res.on('end', () => {
          try {
            const data = JSON.parse(raw);
            if (data.code === 'Ok' && data.routes && data.routes.length > 0) {
              console.log('[Routing] ✅ Successfully retrieved driving route from OSRM (OpenStreetMap Engine)');
              const r = data.routes[0];
              const distKm = (r.distance / 1000).toFixed(1);
              const durMin = Math.round(r.duration / 60);
              // GeoJSON coordinates are [lng, lat], convert to [lat, lng]
              const points = r.geometry.coordinates.map((c) => [c[1], c[0]]);

              resolve({
                source: 'OSRM OpenStreetMap Driving Engine',
                distanceText: `${distKm} km`,
                durationText: `${durMin} mins`,
                distanceKm: parseFloat(distKm),
                routePoints: points,
              });
            } else {
              resolve(null);
            }
          } catch (e) {
            resolve(null);
          }
        });
      }
    ).on('error', () => resolve(null));
  });
};

/**
 * Master Hybrid Route Fetcher
 */
const getHybridDrivingRoute = async (originStr, destStr) => {
  const origin = (originStr && typeof originStr === 'object' && originStr.lat)
    ? originStr
    : await resolveCoordinates(originStr);
  const dest = (destStr && typeof destStr === 'object' && destStr.lat)
    ? destStr
    : await resolveCoordinates(destStr);

  // Attempt Google Maps Directions API first
  let route = await fetchGoogleRoute(origin, dest);

  // If Google Maps key is unavailable or denied, fall back to OSRM
  if (!route || !route.routePoints || route.routePoints.length === 0) {
    route = await fetchOSRMRoute(origin, dest);
  }

  // If both external APIs fail, generate interpolated road curve points
  if (!route || !route.routePoints || route.routePoints.length === 0) {
    const dist = haversineKm(origin.lat, origin.lng, dest.lat, dest.lng);
    const estMin = Math.round(dist * 2.2); // ~25-30 km/h city driving speed
    route = {
      source: 'Direct Corridor Navigation',
      distanceText: `${dist} km`,
      durationText: `${estMin} mins`,
      distanceKm: dist,
      routePoints: [
        [origin.lat, origin.lng],
        [(origin.lat + dest.lat) / 2 + 0.005, (origin.lng + dest.lng) / 2],
        [dest.lat, dest.lng],
      ],
    };
  }

  return route;
};

/**
 * Rank stations for a route
 */
const rankStationsForRoute = (stations, originCoords, destCoords) => {
  const origin = (originCoords && typeof originCoords === 'object' && originCoords.lat)
    ? originCoords
    : { lat: 12.9716, lng: 77.5946 };
  const dest = (destCoords && typeof destCoords === 'object' && destCoords.lat)
    ? destCoords
    : { lat: 12.9716, lng: 77.5946 };

  return stations
    .map((station) => {
      const lat = station.latitude || (station.location?.coordinates ? station.location.coordinates[1] : 0);
      const lng = station.longitude || (station.location?.coordinates ? station.location.coordinates[0] : 0);

      const distOrigin = haversineKm(origin.lat, origin.lng, lat, lng);
      const distDest = haversineKm(dest.lat, dest.lng, lat, lng);
      const detourKm = parseFloat((distOrigin + distDest).toFixed(2));

      const slotScore = Math.min(10, (station.availableSlots / Math.max(1, station.totalSlots)) * 10);
      const powerScore = Math.min(10, (station.chargerPower / 120.0) * 10);
      const detourPenalty = Math.min(10, detourKm / 5.0);

      const totalScore = parseFloat((slotScore * 0.4 + powerScore * 0.4 - detourPenalty * 0.2 + 5.0).toFixed(1));

      return {
        ...(station.toObject ? station.toObject() : station),
        distFromOriginKm: distOrigin,
        distFromDestKm: distDest,
        totalDetourKm: detourKm,
        recommendationScore: Math.max(1.0, Math.min(10.0, totalScore)),
      };
    })
    .sort((a, b) => b.recommendationScore - a.recommendationScore);
};

module.exports = {
  haversineKm,
  resolveCoordinates,
  decodePolyline,
  fetchGoogleRoute,
  fetchOSRMRoute,
  getHybridDrivingRoute,
  rankStationsForRoute,
};
