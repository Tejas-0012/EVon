/**
 * Open Charge Map (OCM) Service
 * Connects to the Open Charge Map Global EV Charging API
 * https://openchargemap.org/site/develop/api
 */

const https = require('https');

/**
 * Fetch real charging stations from Open Charge Map API
 * @param {number} latitude
 * @param {number} longitude
 * @param {number} distanceKm
 * @returns {Promise<Array>}
 */
const fetchStationsFromOCM = ({ latitude = 12.9716, longitude = 77.5946, distanceKm = 25, maxResults = 50 }) => {
  return new Promise((resolve) => {
    const apiKey = process.env.OPEN_CHARGE_MAP_API_KEY || '';
    const keyParam = apiKey ? `&key=${apiKey}` : '';
    const url = `https://api.openchargemap.io/v3/poi/?output=json&countrycode=IN&latitude=${latitude}&longitude=${longitude}&distance=${distanceKm}&distanceunit=KM&maxresults=${maxResults}${keyParam}`;

    https.get(
      url,
      {
        headers: {
          'User-Agent': 'EVon-Charging-Platform/1.0 (https://evon.com)',
          'Accept': 'application/json',
        },
      },
      (res) => {
        let rawData = '';
        res.on('data', (chunk) => (rawData += chunk));
        res.on('end', () => {
          try {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              const data = JSON.parse(rawData);
              const mapped = (Array.isArray(data) ? data : []).map((poi) => {
                const addr = poi.AddressInfo || {};
                const conn = (poi.Connections && poi.Connections[0]) || {};
                const power = conn.PowerKW || 22.0;

                return {
                  stationName: addr.Title || 'EV Charging Point',
                  address: addr.AddressLine1 || addr.Town || 'Bangalore',
                  city: addr.Town || 'Bangalore',
                  location: {
                    type: 'Point',
                    coordinates: [addr.Longitude || longitude, addr.Latitude || latitude],
                  },
                  chargerType: power >= 50 ? 'DC Fast' : (power >= 22 ? 'AC Fast' : 'AC Slow'),
                  chargerPower: power,
                  totalSlots: poi.NumberOfPoints || 4,
                  availableSlots: poi.NumberOfPoints || 4,
                  occupiedSlots: 0,
                  pricePerKwh: power >= 50 ? 16.0 : 12.0,
                  status: 'Active',
                  ocmId: poi.ID,
                  operator: (poi.OperatorInfo && poi.OperatorInfo.Title) || 'Open Charge Map Network',
                };
              });
              resolve(mapped);
            } else {
              console.warn(`[OCM API Warning] Status ${res.statusCode}: ${rawData}`);
              resolve([]);
            }
          } catch (err) {
            console.warn('[OCM API Parse Error]', err.message);
            resolve([]);
          }
        });
      }
    ).on('error', (err) => {
      console.warn('[OCM API Connection Error]', err.message);
      resolve([]);
    });
  });
};

module.exports = {
  fetchStationsFromOCM,
};
