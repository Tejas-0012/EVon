const fs = require('fs');
const path = require('path');
const readline = require('readline');
const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();
dotenv.config({ path: path.join(__dirname, '../../.env') });

const Station = require('../models/Station');

const CSV_FILE = path.resolve(__dirname, '../../../EVon_Major_project/dataset/real_stations.csv');

function parseCSVLine(line) {
  const result = [];
  let cur = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      if (inQuotes && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === ',' && !inQuotes) {
      result.push(cur.trim());
      cur = '';
    } else {
      cur += char;
    }
  }
  result.push(cur.trim());
  return result;
}

// Clean town / city string
function cleanCity(rawTown, rawAddress) {
  if (!rawTown) return 'Karnataka';
  let t = rawTown.replace(/^["'\s]+|["'\s]+$/g, '').trim();
  if (t.toLowerCase().includes('bangalore') || t.toLowerCase().includes('bengaluru')) return 'Bengaluru';
  if (t.toLowerCase().includes('mysore') || t.toLowerCase().includes('mysuru')) return 'Mysuru';
  if (t.toLowerCase().includes('mangalore') || t.toLowerCase().includes('mangaluru')) return 'Mangaluru';
  if (t.toLowerCase().includes('hubli') || t.toLowerCase().includes('hubballi')) return 'Hubballi';
  if (t.toLowerCase().includes('belgaum') || t.toLowerCase().includes('belagavi')) return 'Belagavi';
  if (t.toLowerCase().includes('udupi')) return 'Udupi';
  if (t.toLowerCase().includes('davangere') || t.toLowerCase().includes('davanagere')) return 'Davanagere';
  if (t.toLowerCase().includes('shimoga') || t.toLowerCase().includes('shivamogga')) return 'Shivamogga';
  if (t.toLowerCase().includes('madikeri') || t.toLowerCase().includes('coorg')) return 'Madikeri';
  if (t.toLowerCase().includes('hassan')) return 'Hassan';
  if (t.toLowerCase().includes('tumkur') || t.toLowerCase().includes('tumakuru')) return 'Tumakuru';
  if (t.toLowerCase().includes('ballari') || t.toLowerCase().includes('bellary')) return 'Ballari';
  if (t.toLowerCase().includes('chitradurga')) return 'Chitradurga';
  if (t.toLowerCase().includes('channapatna')) return 'Channapatna';
  if (t.toLowerCase().includes('kunigal')) return 'Kunigal';
  if (t.toLowerCase().includes('honnavar')) return 'Honnavar';
  if (t.toLowerCase().includes('puttur')) return 'Puttur';
  if (t.toLowerCase().includes('vijayapura')) return 'Vijayapura';
  if (t.length > 25 || t.match(/^\d/) || t.toLowerCase().includes('road') || t.toLowerCase().includes('floor')) {
    // If town looks like an address line, try checking address
    if (rawAddress && rawAddress.toLowerCase().includes('mysuru')) return 'Mysuru';
    if (rawAddress && rawAddress.toLowerCase().includes('mangaluru')) return 'Mangaluru';
    if (rawAddress && rawAddress.toLowerCase().includes('hubballi')) return 'Hubballi';
    if (rawAddress && rawAddress.toLowerCase().includes('bengaluru')) return 'Bengaluru';
    return 'Karnataka';
  }
  return t;
}

async function importRealStations() {
  try {
    const uri = process.env.MONGODB_URI;
    if (!uri) throw new Error('MONGODB_URI is missing in .env!');

    console.log(`[Import] Connecting to MongoDB Atlas...`);
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 20000 });
    console.log('[Import] MongoDB Connected!');

    if (!fs.existsSync(CSV_FILE)) {
      throw new Error(`Real stations CSV file not found at: ${CSV_FILE}`);
    }

    console.log(`[Import] Reading real OpenChargeMap stations from: ${CSV_FILE}...`);
    const fileStream = fs.createReadStream(CSV_FILE);
    const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });

    const karnatakaStations = new Map();
    let isHeader = true;

    for await (const line of rl) {
      if (!line || !line.trim()) continue;
      if (isHeader) {
        isHeader = false;
        continue;
      }

      const cols = parseCSVLine(line);
      const stationId = cols[0];
      const name = cols[1];
      const lat = parseFloat(cols[3]);
      const lng = parseFloat(cols[4]);
      const address = cols[5] || '';
      const rawTown = cols[6] || '';
      const state = (cols[7] || '').toLowerCase();
      const slots = parseInt(cols[15], 10) || 4;
      const power = parseFloat(cols[18]) || 22.0;

      // Filter: Valid coords and in Karnataka boundary (or state says karnataka)
      const isKarnatakaState = state.includes('karnataka');
      const inKarnatakaCoords = lat >= 11.5 && lat <= 18.6 && lng >= 74.0 && lng <= 78.6;

      if (stationId && name && !isNaN(lat) && !isNaN(lng) && (isKarnatakaState || inKarnatakaCoords)) {
        if (!karnatakaStations.has(stationId)) {
          const isFast = power >= 50.0;
          const chargerType = isFast ? 'DC Fast' : (power >= 22.0 ? 'AC Fast' : 'AC Slow');
          const city = cleanCity(rawTown, address);

          karnatakaStations.set(stationId, {
            stationName: name.replace(/^["']|["']$/g, '').trim(),
            address: address.replace(/^["']|["']$/g, '').trim() || `${city}, Karnataka`,
            city,
            location: {
              type: 'Point',
              coordinates: [lng, lat],
            },
            chargerType,
            chargerPower: power >= 3.0 ? power : 22.0,
            totalSlots: Math.max(slots, 4),
            availableSlots: Math.max(slots, 4),
            occupiedSlots: 0,
            status: 'Active',
            pricePerKwh: isFast ? 16.0 : 12.0,
          });
        }
      }
    }

    console.log(`[Import] Found ${karnatakaStations.size} verified real OpenChargeMap stations across Karnataka!`);

    const bulkOps = Array.from(karnatakaStations.values()).map((st) => ({
      updateOne: {
        filter: {
          stationName: st.stationName,
          'location.coordinates': st.location.coordinates,
        },
        update: { $set: st },
        upsert: true,
      },
    }));

    console.log(`[Import] Upserting ${bulkOps.length} stations into MongoDB...`);
    const res = await Station.bulkWrite(bulkOps, { ordered: false });

    console.log(`[Import Success] ✅ Successfully updated/upserted Karnataka stations in MongoDB!`);
    console.log(`   - Matched: ${res.matchedCount}`);
    console.log(`   - Modified: ${res.modifiedCount}`);
    console.log(`   - Upserted: ${res.upsertedCount}`);

    const finalTotal = await Station.countDocuments({ status: 'Active' });
    console.log(`[Import Success] Total active stations in MongoDB: ${finalTotal}`);

    process.exit(0);
  } catch (err) {
    console.error(`[Import Error] ${err.message}`);
    process.exit(1);
  }
}

importRealStations();
