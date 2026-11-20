const User = require('../models/User');
const Station = require('../models/Station');

/**
 * Ensure 1 Super Admin and 3 Station Admins are always populated and mapped to 3 distinct stations.
 */
const ensureAdmins = async () => {
  try {
    // 1. Ensure Super Administrator
    let superAdmin = await User.findOne({ email: 'superadmin@evon.com' });
    if (!superAdmin) {
      superAdmin = await User.create({
        name: 'Super Administrator',
        email: 'superadmin@evon.com',
        password: 'admin123',
        phone: '+91 9876543210',
        role: 'super_admin',
      });
      console.log('[Admins] ✅ Created Super Admin: superadmin@evon.com / admin123');
    }

    // 2. Fetch the first 3 active stations (IoT Hub first, then others)
    const stations = await Station.find({ status: 'Active' })
      .sort({ isIotHub: -1, createdAt: 1 })
      .limit(3);

    if (stations.length === 0) {
      console.warn('[Admins Notice] No active stations found yet to map station admins.');
      return;
    }

    const adminConfigs = [
      {
        email: 'station1@evon.com',
        name: `Station Admin (${stations[0]?.stationName || 'EVon Hub'})`,
        station: stations[0],
        phone: '+91 9876543211',
      },
      {
        email: 'station2@evon.com',
        name: `Station Admin (${stations[1]?.stationName || 'Station 2'})`,
        station: stations[1] || stations[0],
        phone: '+91 9876543212',
      },
      {
        email: 'station3@evon.com',
        name: `Station Admin (${stations[2]?.stationName || 'Station 3'})`,
        station: stations[2] || stations[0],
        phone: '+91 9876543213',
      },
    ];

    const results = [];
    for (const cfg of adminConfigs) {
      let admin = await User.findOne({ email: cfg.email });
      if (!admin) {
        admin = await User.create({
          name: cfg.name,
          email: cfg.email,
          password: 'station123',
          phone: cfg.phone,
          role: 'station_admin',
          assignedStation: cfg.station._id,
        });
        console.log(`[Admins] ✅ Created Station Admin: ${cfg.email} -> assigned to ${cfg.station.stationName}`);
      } else {
        // Update station mapping and role if changed
        admin.role = 'station_admin';
        admin.assignedStation = cfg.station._id;
        admin.name = cfg.name;
        await admin.save();
        console.log(`[Admins] 🔄 Updated Station Admin: ${cfg.email} -> mapped to ${cfg.station.stationName}`);
      }
      results.push({
        email: admin.email,
        name: admin.name,
        stationId: cfg.station._id,
        stationName: cfg.station.stationName,
      });
    }

    return {
      superAdmin: { email: superAdmin.email, role: superAdmin.role },
      stationAdmins: results,
    };
  } catch (error) {
    console.error(`[Admins Error] Failed ensuring admins: ${error.message}`);
    return null;
  }
};

module.exports = ensureAdmins;
