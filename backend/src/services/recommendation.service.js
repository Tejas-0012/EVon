/**
 * EVon Route Recommendation Service
 * Hybrid Driving Route Engine:
 * 1. Tries Google Maps Directions API using GOOGLE_MAPS_API_KEY
 * 2. Seamlessly falls back to OpenStreetMap OSRM (100% free, real driving turn-by-turn roads)
 */

const https = require('https');

const KARNATAKA_LANDMARKS = {
  // Karnataka Districts & Key Cities
  'dakshina kannada': { lat: 12.8703, lng: 75.1400 },
  'mangaluru': { lat: 12.9141, lng: 74.8560 },
  'mangalore': { lat: 12.9141, lng: 74.8560 },
  'udupi': { lat: 13.3409, lng: 74.7421 },
  'mysuru': { lat: 12.2958, lng: 76.6394 },
  'mysore': { lat: 12.2958, lng: 76.6394 },
  'hubballi': { lat: 15.3647, lng: 75.1240 },
  'hubli': { lat: 15.3647, lng: 75.1240 },
  'belagavi': { lat: 15.8497, lng: 74.4977 },
  'belgaum': { lat: 15.8497, lng: 74.4977 },
  'hassan': { lat: 13.0033, lng: 76.1004 },
  'shivamogga': { lat: 13.9299, lng: 75.5681 },
  'shimoga': { lat: 13.9299, lng: 75.5681 },
  'davanagere': { lat: 14.4644, lng: 75.9218 },
  'davangere': { lat: 14.4644, lng: 75.9218 },
  'tumakuru': { lat: 13.3379, lng: 77.1010 },
  'tumkur': { lat: 13.3379, lng: 77.1010 },
  'ballari': { lat: 15.1394, lng: 76.9214 },
  'bellary': { lat: 15.1394, lng: 76.9214 },
  'kalaburagi': { lat: 17.3297, lng: 76.8343 },
  'gulbarga': { lat: 17.3297, lng: 76.8343 },
  'bidar': { lat: 17.9104, lng: 77.5199 },
  'raichur': { lat: 16.2076, lng: 77.3463 },
  'mandya': { lat: 12.5218, lng: 76.8951 },
  'kolar': { lat: 13.1367, lng: 78.1291 },
  'chikkamagaluru': { lat: 13.3161, lng: 75.7720 },
  'chikmagalur': { lat: 13.3161, lng: 75.7720 },
  'kodagu': { lat: 12.4244, lng: 75.7382 },
  'coorg': { lat: 12.4244, lng: 75.7382 },
  'madikeri': { lat: 12.4244, lng: 75.7382 },
  'uttara kannada': { lat: 14.8185, lng: 74.1300 },
  'karwar': { lat: 14.8185, lng: 74.1300 },
  'chitradurga': { lat: 14.2251, lng: 76.3980 },
  'vijayapura': { lat: 16.8302, lng: 75.7100 },
  'bijapur': { lat: 16.8302, lng: 75.7100 },
  'bagalkote': { lat: 16.1691, lng: 75.6615 },
  'bagalkot': { lat: 16.1691, lng: 75.6615 },
  'haveri': { lat: 14.7970, lng: 75.4022 },
  'gadag': { lat: 15.4298, lng: 75.6268 },
  'koppal': { lat: 15.3524, lng: 76.1557 },
  'yadgir': { lat: 16.7645, lng: 77.1378 },
  'chamarajanagar': { lat: 11.9261, lng: 76.9437 },
  'ramanagara': { lat: 12.7209, lng: 77.2799 },
  'chikkaballapur': { lat: 13.4355, lng: 77.7275 },
  'sakleshpur': { lat: 12.9436, lng: 75.7865 },
  'bantwal': { lat: 12.8931, lng: 75.0353 },
  'puttur': { lat: 12.7667, lng: 75.2000 },

  // Bengaluru Major Localities
  'koramangala': { lat: 12.9352, lng: 77.6245 },
  'whitefield': { lat: 12.9698, lng: 77.75 },
  'mg road': { lat: 12.975, lng: 77.6063 },
  'indiranagar': { lat: 12.9784, lng: 77.6408 },
  'hsr': { lat: 12.9116, lng: 77.6473 },
  'hsr layout': { lat: 12.9116, lng: 77.6473 },
  'jayanagar': { lat: 12.9308, lng: 77.5838 },
  'electronic city': { lat: 12.8456, lng: 77.6603 },
  'marathahalli': { lat: 12.9591, lng: 77.6974 },
  'bangalore': { lat: 12.9716, lng: 77.5946 },
  'bengaluru': { lat: 12.9716, lng: 77.5946 },
  'itpl': { lat: 12.9698, lng: 77.75 },
  'airport': { lat: 13.1986, lng: 77.7066 },
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
    if (KARNATAKA_LANDMARKS[clean]) {
      return { ...KARNATAKA_LANDMARKS[clean], formattedAddress: clean };
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
 * Rank stations for a route based on corridor proximity, charger power, and slot availability
 */
const rankStationsForRoute = (stations, originCoords, destCoords) => {
  const origin = (originCoords && typeof originCoords === 'object' && originCoords.lat)
    ? originCoords
    : { lat: 12.9716, lng: 77.5946 };
  const dest = (destCoords && typeof destCoords === 'object' && destCoords.lat)
    ? destCoords
    : { lat: 12.9716, lng: 77.5946 };

  const directDist = haversineKm(origin.lat, origin.lng, dest.lat, dest.lng);

  return stations
    .map((station) => {
      const lat = station.latitude || (station.location?.coordinates ? station.location.coordinates[1] : 0);
      const lng = station.longitude || (station.location?.coordinates ? station.location.coordinates[0] : 0);

      const distOrigin = haversineKm(origin.lat, origin.lng, lat, lng);
      const distDest = haversineKm(dest.lat, dest.lng, lat, lng);
      const totalDetour = parseFloat((distOrigin + distDest).toFixed(2));
      // True extra detour beyond direct straight line
      const extraDetourKm = Math.max(0, parseFloat((totalDetour - directDist).toFixed(2)));

      const slotScore = Math.min(10, (station.availableSlots / Math.max(1, station.totalSlots)) * 10);
      const powerScore = Math.min(10, (station.chargerPower / 120.0) * 10);
      // Detour penalty: within 10 km extra detour is barely penalized; >30 km heavily penalized
      const detourPenalty = Math.min(10, extraDetourKm / 4.0);

      const totalScore = parseFloat((slotScore * 0.35 + powerScore * 0.35 - detourPenalty * 0.3 + 5.0).toFixed(1));

      return {
        ...(station.toObject ? station.toObject() : station),
        distFromOriginKm: distOrigin,
        distFromDestKm: distDest,
        totalDetourKm: extraDetourKm,
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
