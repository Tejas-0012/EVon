const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();
dotenv.config({ path: path.join(__dirname, '../../.env') });

const User = require('../models/User');
const Station = require('../models/Station');
const Slot = require('../models/Slot');

// Resolve path to real_stations.csv from various possible working directories
const getCsvPath = () => {
  const candidates = [
    path.resolve(__dirname, '../../..', 'EVon_Major_project/dataset/real_stations.csv'),
    path.resolve(__dirname, '../../../EVon_Major_project/dataset/real_stations.csv'),
    path.resolve(process.cwd(), 'EVon_Major_project/dataset/real_stations.csv'),
    path.resolve(process.cwd(), '../EVon_Major_project/dataset/real_stations.csv'),
    path.resolve('B:/MPEVon/EVon_Major_project/dataset/real_stations.csv'),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return null;
};

// Robust CSV Line Parser
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

// Special IoT Hardware Hub (+5km from central Bangalore)
const IOT_STATION = {
  stationName: 'EVon Charging Hub',
  address: 'IoT Smart Testbed Hub, +5km from City Center',
  city: 'Bangalore',
  location: { type: 'Point', coordinates: [77.6350, 12.9850] },
  chargerType: 'DC Fast',
  chargerPower: 50.0,
  totalSlots: 2,
  availableSlots: 2,
  occupiedSlots: 0,
  status: 'Active',
  pricePerKwh: 12.0,
  isIotHub: true,
  hubId: 'evon-charging-hub',
  iotLastPing: null,
  isIotActive: false,
  bays: [
    { bayNumber: 1, status: 'Available', lastUpdated: new Date() },
    { bayNumber: 2, status: 'Available', lastUpdated: new Date() },
  ],
};

const STANDARD_TIMES = [
  '08:00', '09:00', '10:00', '11:00', '12:00',
  '13:00', '14:00', '15:00', '16:00', '17:00',
  '18:00', '19:00', '20:00', '21:00'
];

const loadRealStationsFromCsv = () => {
  const csvFile = getCsvPath();
  if (!csvFile) {
    console.warn('[Seed Warning] real_stations.csv not found in candidate paths. Falling back to default list.');
    return [];
  }

  console.log(`[Seed] Reading real charging stations from: ${csvFile}...`);
  const content = fs.readFileSync(csvFile, 'utf8');
  const lines = content.split(/\r?\n/);

  const unique = new Map();

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i];
    if (!line || !line.trim()) continue;

    const cols = parseCSVLine(line);
    const stationId = cols[0];
    const name = cols[1];
    const lat = parseFloat(cols[3]);
    const lng = parseFloat(cols[4]);
    const address = cols[5] || '';
    const town = cols[6] || 'Bangalore';
    const slots = parseInt(cols[15], 10) || 4;
    const power = parseFloat(cols[18]) || 22.0;

    // Filter Bangalore bounding box: lat ~12.7 to 13.3, lng ~77.4 to 77.8
    if (
      stationId &&
      name &&
      !isNaN(lat) &&
      !isNaN(lng) &&
      lat >= 12.7 &&
      lat <= 13.3 &&
      lng >= 77.4 &&
      lng <= 77.8 &&
      !unique.has(stationId)
    ) {
      const isFast = power >= 50.0;
      unique.set(stationId, {
        stationName: name.replace(/^"(.*)"$/, '$1'),
        address: address ? address.replace(/^"(.*)"$/, '$1') : (town || 'Bangalore'),
        city: town || 'Bangalore',
        location: {
          type: 'Point',
          coordinates: [lng, lat],
        },
        chargerType: isFast ? 'DC Fast' : (power >= 22.0 ? 'AC Fast' : 'AC Slow'),
        chargerPower: power || 22.0,
        totalSlots: Math.max(slots, 4),
        availableSlots: Math.max(slots, 4),
        occupiedSlots: 0,
        status: 'Active',
        pricePerKwh: isFast ? 16.0 : 12.0,
      });
    }
  }

  console.log(`[Seed] Extracted ${unique.size} real Bangalore stations from dataset!`);
  return Array.from(unique.values());
};

const seedDatabase = async () => {
  try {
    const uri = process.env.MONGODB_URI;
    if (!uri) {
      throw new Error('MONGODB_URI is not defined in .env file!');
    }
    console.log(`[Seed] Connecting to MongoDB: ${uri.replace(/:([^@]+)@/, ':****@')}`);
    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 15000,
    });
    console.log('[Seed] Connected to MongoDB...');

    // Clear existing data
    await User.deleteMany({});
    await Station.deleteMany({});
    await Slot.deleteMany({});
    console.log('[Seed] Cleared existing Users, Stations, and Slots.');

    // 1. Gather all stations: IoT Hub first, then real stations from real_stations.csv
    const realStations = loadRealStationsFromCsv();
    const allStationsToSeed = [IOT_STATION, ...realStations];

    const createdStations = await Station.insertMany(allStationsToSeed);
    console.log(`[Seed] Successfully inserted ${createdStations.length} Charging Stations into MongoDB Atlas!`);
    console.log(`[Seed] ⚡ Station #1 is the IoT Hardware Testbed: "EVon Charging Hub" (+5km)`);

    // 2. Create Users (1 Super Admin, 3 Fake Station Admins mapped to 3 stations, 1 Driver)
    const superAdmin = await User.create({
      name: 'Super Administrator',
      email: 'superadmin@evon.com',
      password: 'admin123',
      phone: '+91 9876543210',
      role: 'super_admin',
    });

    const stationAdmin1 = await User.create({
      name: `Station Admin (${createdStations[0]?.stationName || 'EVon Hub'})`,
      email: 'station1@evon.com',
      password: 'station123',
      phone: '+91 9876543211',
      role: 'station_admin',
      assignedStation: createdStations[0]._id,
    });

    const stationAdmin2 = await User.create({
      name: `Station Admin (${createdStations[1]?.stationName || 'Aloft Outer Ring Road'})`,
      email: 'station2@evon.com',
      password: 'station123',
      phone: '+91 9876543212',
      role: 'station_admin',
      assignedStation: createdStations[1]._id,
    });

    const stationAdmin3 = await User.create({
      name: `Station Admin (${createdStations[2]?.stationName || 'Akshaya Motors'})`,
      email: 'station3@evon.com',
      password: 'station123',
      phone: '+91 9876543213',
      role: 'station_admin',
      assignedStation: createdStations[2]._id,
    });

    const demoUser = await User.create({
      name: 'Demo EV Driver',
      email: 'user@evon.com',
      password: 'user123',
      phone: '+91 9876543214',
      role: 'user',
      vehicleType: 'Electric Car (Nexon EV)',
      batteryCapacity: 40.5,
    });

    console.log('[Seed] Seeded default accounts: superadmin, 3 station admins (station1, station2, station3), user.');

    // 3. Generate slots for the week for top stations
    const today = new Date();
    const dates = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(today);
      d.setDate(today.getDate() + i);
      dates.push(d.toISOString().split('T')[0]);
    }

    const slotsToInsert = [];
    // Generate slots for up to 30 stations so database seed runs quickly
    const stationsForSlots = createdStations.slice(0, 30);

    for (const station of stationsForSlots) {
      for (const dateStr of dates) {
        for (const timeStr of STANDARD_TIMES) {
          slotsToInsert.push({
            station: station._id,
            slotDate: dateStr,
            slotTime: timeStr,
            status: 'Available',
          });
        }
      }
    }

    if (slotsToInsert.length > 0) {
      await Slot.insertMany(slotsToInsert);
      console.log(`[Seed] Generated ${slotsToInsert.length} bookable time slots across stations for the week.`);
    }

    console.log('\n====================================================');
    console.log('  🎉 Database Seeding Completed Successfully!');
    console.log(`  🔌 Total Real Stations: ${createdStations.length}`);
    console.log('  ⚡ IoT Hub: "EVon Charging Hub" (2 Bays, ESP32 Bridge)');
    console.log('  🔑 Demo Accounts:');
    console.log('     • Driver: user@evon.com / user123');
    console.log('     • Station Admin: station1@evon.com / station123');
    console.log('     • Super Admin: superadmin@evon.com / admin123');
    console.log('====================================================\n');

    process.exit(0);
  } catch (error) {
    console.error(`❌ [Seed Failed]: ${error}`);
    process.exit(1);
  }
};

seedDatabase();
