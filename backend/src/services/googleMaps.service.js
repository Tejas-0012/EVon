const https = require('https');

const GOOGLE_GEOCODE_URL = 'https://maps.googleapis.com/maps/api/geocode/json';

// In-memory cache to minimize redundant external calls and speed up response times
const geocodeCache = new Map();

/**
 * Fallback landmarks for Bangalore city center and key hubs
 */
const FALLBACK_LANDMARKS = {
  hebbal: { lat: 13.0358, lng: 77.5970, address: 'Hebbal, Bengaluru, Karnataka, India' },
  'hebbal flyover': { lat: 13.0382, lng: 77.5925, address: 'Hebbal Flyover, Bellary Rd, Bengaluru, Karnataka' },
  'hebbal lake': { lat: 13.0422, lng: 77.5902, address: 'Hebbal Lake, Outer Ring Rd, Bengaluru, Karnataka' },
  hennur: { lat: 13.0256, lng: 77.6322, address: 'Hennur, Bengaluru, Karnataka, India' },
  koramangala: { lat: 12.9352, lng: 77.6245, address: 'Koramangala, Bengaluru, Karnataka, India' },
  whitefield: { lat: 12.9698, lng: 77.7500, address: 'Whitefield, Bengaluru, Karnataka, India' },
  'mg road': { lat: 12.9750, lng: 77.6063, address: 'MG Road, Bengaluru, Karnataka, India' },
  indiranagar: { lat: 12.9784, lng: 77.6408, address: 'Indiranagar, Bengaluru, Karnataka, India' },
  hsr: { lat: 12.9116, lng: 77.6473, address: 'HSR Layout, Bengaluru, Karnataka, India' },
  'hsr layout': { lat: 12.9116, lng: 77.6473, address: 'HSR Layout, Bengaluru, Karnataka, India' },
  jayanagar: { lat: 12.9308, lng: 77.5838, address: 'Jayanagar, Bengaluru, Karnataka, India' },
  'electronic city': { lat: 12.8456, lng: 77.6603, address: 'Electronic City, Bengaluru, Karnataka, India' },
  marathahalli: { lat: 12.9591, lng: 77.6974, address: 'Marathahalli, Bengaluru, Karnataka, India' },
  bellandur: { lat: 12.9304, lng: 77.6784, address: 'Bellandur, Bengaluru, Karnataka, India' },
  'sarjapur road': { lat: 12.9166, lng: 77.6833, address: 'Sarjapur Road, Bengaluru, Karnataka, India' },
  sarjapur: { lat: 12.8597, lng: 77.7864, address: 'Sarjapur, Bengaluru, Karnataka, India' },
  yelahanka: { lat: 13.1007, lng: 77.5963, address: 'Yelahanka, Bengaluru, Karnataka, India' },
  malleshwaram: { lat: 13.0031, lng: 77.5643, address: 'Malleshwaram, Bengaluru, Karnataka, India' },
  banashankari: { lat: 12.9255, lng: 77.5468, address: 'Banashankari, Bengaluru, Karnataka, India' },
  domlur: { lat: 12.9609, lng: 77.6387, address: 'Domlur, Bengaluru, Karnataka, India' },
  rajajinagar: { lat: 12.9982, lng: 77.5530, address: 'Rajajinagar, Bengaluru, Karnataka, India' },
  'btm layout': { lat: 12.9166, lng: 77.6101, address: 'BTM Layout, Bengaluru, Karnataka, India' },
  yeshwanthpur: { lat: 13.0238, lng: 77.5529, address: 'Yeshwanthpur, Bengaluru, Karnataka, India' },
  'kr puram': { lat: 13.0075, lng: 77.6959, address: 'KR Puram, Bengaluru, Karnataka, India' },
  'silk board': { lat: 12.9177, lng: 77.6238, address: 'Central Silk Board, Bengaluru, Karnataka, India' },
  'outer ring road': { lat: 12.9345, lng: 77.6912, address: 'Outer Ring Road, Bengaluru, Karnataka, India' },
  itpl: { lat: 12.9863, lng: 77.7381, address: 'ITPL, Whitefield, Bengaluru, Karnataka, India' },
  airport: { lat: 13.1986, lng: 77.7066, address: 'Kempegowda International Airport Bengaluru, Karnataka, India' },
  bangalore: { lat: 12.9716, lng: 77.5946, address: 'Bengaluru, Karnataka, India' },
  bengaluru: { lat: 12.9716, lng: 77.5946, address: 'Bengaluru, Karnataka, India' },
};

/**
 * Perform HTTPS GET returning parsed JSON
 */
function httpsGetJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let raw = '';
      res.on('data', (c) => (raw += c));
      res.on('end', () => {
        try {
          resolve(JSON.parse(raw));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', (err) => reject(err));
  });
}

/**
 * Geocode text address using Google Maps Geocoding API
 * @param {string} address
 * @returns {Promise<{ lat: number, lng: number, formattedAddress: string, placeId: string, bounds?: any }>}
 */
async function geocodeAddress(address) {
  if (!address || typeof address !== 'string') {
    return { lat: 12.9716, lng: 77.5946, formattedAddress: 'Bengaluru, Karnataka, India' };
  }

  const clean = address.trim();
  const cacheKey = clean.toLowerCase();

  if (geocodeCache.has(cacheKey)) {
    return geocodeCache.get(cacheKey);
  }

  // Check if already "lat,lng" coordinates
  const coordsMatch = clean.match(/^(-?\d+(\.\d+)?)[,\s]+(-?\d+(\.\d+)?)$/);
  if (coordsMatch) {
    const lat = parseFloat(coordsMatch[1]);
    const lng = parseFloat(coordsMatch[3]);
    if (!isNaN(lat) && !isNaN(lng)) {
      return { lat, lng, formattedAddress: `${lat.toFixed(4)}, ${lng.toFixed(4)}` };
    }
  }

  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (apiKey) {
    try {
      // Append Bengaluru/Karnataka if not specified to bias search to Bangalore area
      let query = clean;
      if (!query.toLowerCase().includes('bengaluru') && !query.toLowerCase().includes('bangalore') && !query.toLowerCase().includes('india')) {
        query = `${clean}, Bengaluru, Karnataka, India`;
      }

      const url = `${GOOGLE_GEOCODE_URL}?address=${encodeURIComponent(query)}&key=${apiKey}`;
      const data = await httpsGetJson(url);

      if (data.status === 'OK' && data.results && data.results.length > 0) {
        const top = data.results[0];
        const res = {
          lat: top.geometry.location.lat,
          lng: top.geometry.location.lng,
          formattedAddress: top.formatted_address,
          placeId: top.place_id,
          bounds: top.geometry.bounds || null,
          viewport: top.geometry.viewport || null,
          source: 'Google Maps Geocoding API',
        };
        geocodeCache.set(cacheKey, res);
        return res;
      } else {
        console.warn(`[Google Geocode Warning] Status: ${data.status} for query: "${clean}"`);
      }
    } catch (err) {
      console.error('[Google Geocode Error]', err.message);
    }
  }

  // Fallback to static landmarks
  if (FALLBACK_LANDMARKS[cacheKey]) {
    const fb = FALLBACK_LANDMARKS[cacheKey];
    return { ...fb, formattedAddress: fb.address, source: 'Local Landmark DB' };
  }

  return { lat: 12.9716, lng: 77.5946, formattedAddress: 'Bengaluru, Karnataka, India', source: 'Default Center' };
}

/**
 * Reverse Geocode coordinates to street address using Google Maps Geocoding API
 * @param {number} lat
 * @param {number} lng
 * @returns {Promise<{ formattedAddress: string, locality: string, area: string, city: string, postalCode: string, placeId: string }>}
 */
async function reverseGeocode(lat, lng) {
  const cacheKey = `rev_${Number(lat).toFixed(4)}_${Number(lng).toFixed(4)}`;
  if (geocodeCache.has(cacheKey)) {
    return geocodeCache.get(cacheKey);
  }

  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (apiKey) {
    try {
      const url = `${GOOGLE_GEOCODE_URL}?latlng=${lat},${lng}&key=${apiKey}`;
      const data = await httpsGetJson(url);

      if (data.status === 'OK' && data.results && data.results.length > 0) {
        const top = data.results[0];

        let locality = '';
        let area = '';
        let city = 'Bengaluru';
        let postalCode = '';

        for (const comp of top.address_components || []) {
          const types = comp.types || [];
          if (types.includes('sublocality_level_1') || types.includes('sublocality')) {
            area = comp.long_name;
          } else if (types.includes('locality')) {
            city = comp.long_name;
          } else if (types.includes('neighborhood') || types.includes('sublocality_level_2')) {
            locality = comp.long_name;
          } else if (types.includes('postal_code')) {
            postalCode = comp.long_name;
          }
        }

        const res = {
          lat: parseFloat(lat),
          lng: parseFloat(lng),
          formattedAddress: top.formatted_address,
          area: area || locality || 'Bengaluru',
          locality: locality || area,
          city: city || 'Bengaluru',
          postalCode,
          placeId: top.place_id,
          source: 'Google Maps Geocoding API',
        };
        geocodeCache.set(cacheKey, res);
        return res;
      }
    } catch (err) {
      console.error('[Google Reverse Geocode Error]', err.message);
    }
  }

  return {
    lat: parseFloat(lat),
    lng: parseFloat(lng),
    formattedAddress: `${Number(lat).toFixed(4)}, ${Number(lng).toFixed(4)}, Bengaluru, Karnataka`,
    area: 'Current Location',
    locality: 'Bengaluru',
    city: 'Bengaluru',
    postalCode: '',
    source: 'Coordinates Fallback',
  };
}

/**
 * Search locations & places matching query with coordinates
 * @param {string} query
 * @returns {Promise<Array<{ name: string, formattedAddress: string, lat: number, lng: number, placeId: string }>>}
 */
async function searchLocations(query) {
  if (!query || query.trim().length === 0) {
    return [];
  }

  const clean = query.trim();
  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  const results = [];

  if (apiKey) {
    try {
      const q = clean.toLowerCase().includes('india') ? clean : `${clean}, Bengaluru, Karnataka, India`;
      const url = `${GOOGLE_GEOCODE_URL}?address=${encodeURIComponent(q)}&key=${apiKey}`;
      const data = await httpsGetJson(url);

      if (data.status === 'OK' && data.results) {
        for (const r of data.results.slice(0, 5)) {
          results.push({
            name: r.address_components?.[0]?.long_name || r.formatted_address.split(',')[0],
            formattedAddress: r.formatted_address,
            lat: r.geometry.location.lat,
            lng: r.geometry.location.lng,
            placeId: r.place_id,
            source: 'Google Maps',
          });
        }
      }
    } catch (e) {
      console.warn('[Location Search Warning]', e.message);
    }
  }

  // Prioritize verified landmarks for instant, ultra-fast autocomplete matching
  const qLower = clean.toLowerCase();
  for (const [key, val] of Object.entries(FALLBACK_LANDMARKS)) {
    if (key.startsWith(qLower) || key.includes(qLower) || val.address.toLowerCase().includes(qLower)) {
      if (!results.some((r) => Math.abs(r.lat - val.lat) < 0.005 && Math.abs(r.lng - val.lng) < 0.005)) {
        results.unshift({
          name: key.charAt(0).toUpperCase() + key.slice(1),
          formattedAddress: val.address,
          lat: val.lat,
          lng: val.lng,
          placeId: `local_${key}`,
          source: 'Verified Hub',
        });
      }
    }
  }

  return results;
}

module.exports = {
  geocodeAddress,
  reverseGeocode,
  searchLocations,
};
