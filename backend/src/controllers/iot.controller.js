const Station = require('../models/Station');

const IOT_HUB_COORDINATES = [77.635, 12.985]; // [longitude, latitude] (~5km northeast from central Bangalore)
const IOT_HUB_NAME = 'EVon Charging Hub';
const IOT_TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes inactivity timeout

/**
 * Normalizes input status from ESP32 or sensors
 */
const normalizeStatus = (val) => {
  if (!val) return 'Available';
  const clean = val.toString().trim().toLowerCase();
  if (clean === 'charging' || clean === 'charge' || clean === 'active') {
    return 'Charging';
  }
  if (clean === 'parked' || clean === 'detected' || clean === 'occupied' || clean === 'present') {
    return 'Parked';
  }
  return 'Available';
};

/**
 * Helper to ensure the IoT Station document exists in MongoDB
 */
const getOrCreateIotHub = async () => {
  let hub = await Station.findOne({
    $or: [{ hubId: 'evon-charging-hub' }, { isIotHub: true }, { stationName: IOT_HUB_NAME }],
  });

  if (!hub) {
    try {
      hub = await Station.create({
        stationName: IOT_HUB_NAME,
        address: 'IoT Smart Testbed Hub, +5km from City Center',
        city: 'Bangalore',
        location: {
          type: 'Point',
          coordinates: IOT_HUB_COORDINATES,
        },
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
      });
      console.log(`[IoT Hub] ⚡ Initialized "${IOT_HUB_NAME}" station in MongoDB Atlas (+5km location)`);
    } catch (err) {
      hub = await Station.findOne({
        $or: [{ hubId: 'evon-charging-hub' }, { isIotHub: true }, { stationName: IOT_HUB_NAME }],
      });
    }
  } else if (!hub.bays || hub.bays.length === 0) {
    hub.isIotHub = true;
    hub.hubId = 'evon-charging-hub';
    hub.totalSlots = 2;
    hub.bays = [
      { bayNumber: 1, status: 'Available', lastUpdated: new Date() },
      { bayNumber: 2, status: 'Available', lastUpdated: new Date() },
    ];
    await hub.save();
  }

  return hub;
};

// @desc    Get live IoT Hub bays status & connectivity health
// @route   GET /api/iot/status
// @access  Public
const getIotStatus = async (req, res, next) => {
  try {
    const hub = await getOrCreateIotHub();

    // Check if ESP32 has communicated within the last 5 minutes
    const now = Date.now();
    const lastPingTime = hub.iotLastPing ? new Date(hub.iotLastPing).getTime() : 0;
    const isOnline = lastPingTime > 0 && now - lastPingTime < IOT_TIMEOUT_MS;

    res.json({
      success: true,
      stationId: hub._id,
      stationName: hub.stationName,
      address: hub.address,
      latitude: hub.location.coordinates[1],
      longitude: hub.location.coordinates[0],
      chargerPower: hub.chargerPower,
      pricePerKwh: hub.pricePerKwh,
      totalSlots: hub.totalSlots,
      availableSlots: isOnline ? hub.availableSlots : 0,
      occupiedSlots: hub.occupiedSlots,
      isIotHub: true,
      isIotActive: isOnline,
      iotStatusMessage: isOnline ? 'Active (ESP32 Live)' : 'Not Available (ESP32 Offline)',
      iotLastPing: hub.iotLastPing,
      bays: isOnline
        ? hub.bays
        : hub.bays.map((b) => ({
            ...b.toObject ? b.toObject() : b,
            status: 'Offline',
          })),
      rawBays: hub.bays,
      lastUpdated: new Date().toISOString(),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update Bay Status from ESP32 Microcontroller
// @route   POST /api/iot/bay-status
// @access  Public (ESP32 Wi-Fi)
const updateBayStatus = async (req, res, next) => {
  try {
    const hub = await getOrCreateIotHub();
    const body = req.body || {};

    let updatedAny = false;

    if (body.bay !== undefined || body.bayNumber !== undefined) {
      const targetBay = parseInt(body.bay || body.bayNumber, 10);
      const newStatus = normalizeStatus(body.status || body.state);

      const bayObj = hub.bays.find((b) => b.bayNumber === targetBay);
      if (bayObj) {
        bayObj.status = newStatus;
        bayObj.lastUpdated = new Date();
        updatedAny = true;
      }
    }

    if (body.bay1 !== undefined) {
      const b1 = hub.bays.find((b) => b.bayNumber === 1);
      if (b1) {
        b1.status = normalizeStatus(body.bay1);
        b1.lastUpdated = new Date();
        updatedAny = true;
      }
    }

    if (body.bay2 !== undefined) {
      const b2 = hub.bays.find((b) => b.bayNumber === 2);
      if (b2) {
        b2.status = normalizeStatus(body.bay2);
        b2.lastUpdated = new Date();
        updatedAny = true;
      }
    }

    // Recalculate available and occupied slots
    const availableCount = hub.bays.filter((b) => b.status === 'Available').length;
    hub.availableSlots = availableCount;
    hub.occupiedSlots = hub.bays.length - availableCount;

    // Mark as Active & record timestamp
    hub.iotLastPing = new Date();
    hub.isIotActive = true;

    await hub.save();

    console.log(
      `[IoT Bridge] ⚡ ESP32 Signal Received -> Bay 1: ${hub.bays[0]?.status} | Bay 2: ${hub.bays[1]?.status} (Status: ACTIVE)`
    );

    const b1Short = hub.bays[0]?.status.substring(0, 3).toUpperCase();
    const b2Short = hub.bays[1]?.status.substring(0, 3).toUpperCase();

    res.json({
      success: true,
      message: 'IoT bay status updated successfully',
      isIotActive: true,
      bays: hub.bays,
      availableSlots: hub.availableSlots,
      totalSlots: hub.totalSlots,
      lcdHint: `B1:${b1Short} B2:${b2Short}`,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Heartbeat ping from ESP32 to keep IoT status active
// @route   POST /api/iot/heartbeat
// @access  Public
const sendHeartbeat = async (req, res, next) => {
  try {
    const hub = await getOrCreateIotHub();
    hub.iotLastPing = new Date();
    hub.isIotActive = true;
    await hub.save();

    res.json({
      success: true,
      message: 'Heartbeat acknowledged. IoT Hub is ACTIVE.',
      isIotActive: true,
      lastPing: hub.iotLastPing,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Reset both bays to Available
// @route   POST /api/iot/reset
// @access  Public
const resetBays = async (req, res, next) => {
  try {
    const hub = await getOrCreateIotHub();
    hub.bays.forEach((b) => {
      b.status = 'Available';
      b.lastUpdated = new Date();
    });
    hub.availableSlots = 2;
    hub.occupiedSlots = 0;
    hub.iotLastPing = new Date(); // resets also ping to activate
    hub.isIotActive = true;
    await hub.save();

    res.json({
      success: true,
      message: 'Both bays reset to Available & IoT marked Active',
      isIotActive: true,
      bays: hub.bays,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Simulate ESP32 Disconnect (marks IoT status as Not Available)
// @route   POST /api/iot/disconnect
// @access  Public
const disconnectHub = async (req, res, next) => {
  try {
    const hub = await getOrCreateIotHub();
    hub.iotLastPing = new Date(Date.now() - 10 * 60 * 1000); // 10 minutes ago
    hub.isIotActive = false;
    await hub.save();

    res.json({
      success: true,
      message: 'IoT Hub marked as Disconnected / Not Available',
      isIotActive: false,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getOrCreateIotHub,
  getIotStatus,
  updateBayStatus,
  sendHeartbeat,
  resetBays,
  disconnectHub,
};
