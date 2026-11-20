const fs = require('fs');
const path = require('path');
const readline = require('readline');
const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();
dotenv.config({ path: path.join(__dirname, '../../.env') });

const Station = require('../models/Station');
const Slot = require('../models/Slot');

const CSV_FILE = path.resolve(__dirname, '../../../EVon_Major_project/dataset/real_stations.csv');

// Robust CSV Line Parser that handles quoted values with commas
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

const STANDARD_TIMES = [
  '08:00', '09:00', '10:00', '11:00', '12:00',
  '13:00', '14:00', '15:00', '16:00', '17:00',
  '18:00', '19:00', '20:00', '21:00'
];

async function importRealStations() {
  try {
    const uri = process.env.MONGODB_URI;
    if (!uri) {
      throw new Error('MONGODB_URI is missing in .env!');
    }

    console.log(`[Import] Connecting to MongoDB: ${uri.replace(/:([^@]+)@/, ':****@')}...`);
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 15000 });
    console.log('[Import] MongoDB Connected!');

    if (!fs.existsSync(CSV_FILE)) {
      throw new Error(`Real stations CSV file not found at: ${CSV_FILE}`);
    }

    console.log(`[Import] Reading real charging stations from: ${CSV_FILE}...`);
    const fileStream = fs.createReadStream(CSV_FILE);
    const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });

    const uniqueStations = new Map();
    let isHeader = true;
    let headerCols = [];

    for await (const line of rl) {
      if (!line || !line.trim()) continue;

      if (isHeader) {
        headerCols = parseCSVLine(line);
        isHeader = false;
        continue;
      }

      const cols = parseCSVLine(line);
      const stationId = cols[0];
      const name = cols[1];
      const lat = parseFloat(cols[3]);
      const lng = parseFloat(cols[4]);
      const address = cols[5] || '';
      const town = cols[6] || 'Bangalore';
      const slots = parseInt(cols[15], 10) || 4;
      const power = parseFloat(cols[18]) || 22.0;

      // Filter: valid station, coordinates, and Bangalore / Karnataka region
      if (
        stationId &&
        name &&
        !isNaN(lat) &&
        !isNaN(lng) &&
        lat > 8.0 &&
        lat < 28.0 &&
        lng > 68.0 &&
        lng < 88.0 &&
        !uniqueStations.has(stationId)
      ) {
        const isFast = power >= 50.0;
        const chargerType = isFast
          ? 'DC Fast'
          : power >= 22.0
          ? 'AC Fast'
          : 'AC Slow';

        uniqueStations.set(stationId, {
          stationName: name,
          address: address || town || 'Bangalore, Karnataka',
          city: town || 'Bangalore',
          location: {
            type: 'Point',
            coordinates: [lng, lat],
          },
          chargerType,
          chargerPower: power,
          totalSlots: Math.max(slots, 4),
          availableSlots: Math.max(slots, 4),
          occupiedSlots: 0,
          status: 'Active',
          pricePerKwh: isFast ? 16.0 : 12.0,
        });
      }
    }

    console.log(`[Import] Parsed ${uniqueStations.size} unique real charging stations from dataset.`);

    // Choose top 50 real stations (or all Bangalore ones)
    const stationsToInsert = Array.from(uniqueStations.values()).slice(0, 50);

    let insertedCount = 0;
    let slotCount = 0;

    const today = new Date();
    const dates = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(today);
      d.setDate(today.getDate() + i);
      dates.push(d.toISOString().split('T')[0]);
    }

    for (const data of stationsToInsert) {
      // Upsert station by name & coordinates
      const station = await Station.findOneAndUpdate(
        {
          stationName: data.stationName,
          'location.coordinates': data.location.coordinates,
        },
        data,
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );

      insertedCount++;

      // Create slots for each station for the week
      for (const dateStr of dates) {
        for (const timeStr of STANDARD_TIMES) {
          try {
            await Slot.findOneAndUpdate(
              {
                station: station._id,
                slotDate: dateStr,
                slotTime: timeStr,
              },
              {
                station: station._id,
                slotDate: dateStr,
                slotTime: timeStr,
                status: 'Available',
              },
              { upsert: true }
            );
            slotCount++;
          } catch (e) {
            // Ignore duplicate slot error
          }
        }
      }
    }

    console.log(`[Import Success] Successfully imported ${insertedCount} real charging stations into MongoDB Atlas!`);
    console.log(`[Import Success] Generated ${slotCount} bookable time slots across the week.`);
    process.exit(0);
  } catch (err) {
    console.error(`[Import Error] ${err.message}`);
    process.exit(1);
  }
}

importRealStations();
