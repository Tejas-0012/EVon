const Slot = require('../models/Slot');
const Station = require('../models/Station');

const STANDARD_TIMES = [
  '08:00', '09:00', '10:00', '11:00', '12:00',
  '13:00', '14:00', '15:00', '16:00', '17:00',
  '18:00', '19:00', '20:00', '21:00'
];

// @desc    Get slots for a station on a date (auto-creates if missing)
// @route   GET /api/stations/:stationId/slots
// @access  Public
const getStationSlots = async (req, res, next) => {
  try {
    const { stationId } = req.params;
    const date = req.query.date || new Date().toISOString().split('T')[0];

    const station = await Station.findById(stationId);
    if (!station) {
      return res.status(404).json({ success: false, message: 'Station not found' });
    }

    let slots = await Slot.find({ station: stationId, slotDate: date }).sort({ slotTime: 1 });

    // If slots not yet initialized for this date, auto-populate standard day slots
    if (slots.length === 0) {
      const initialSlots = STANDARD_TIMES.map((time) => ({
        station: stationId,
        slotDate: date,
        slotTime: time,
        status: 'Available',
      }));

      try {
        slots = await Slot.insertMany(initialSlots, { ordered: false });
      } catch (err) {
        // If race condition created them, fetch again
        slots = await Slot.find({ station: stationId, slotDate: date }).sort({ slotTime: 1 });
      }
    }

    res.json({
      success: true,
      stationId,
      date,
      count: slots.length,
      slots,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update slot status (station admin or super admin)
// @route   PUT /api/slots/:slotId
// @access  Private
const updateSlotStatus = async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!status || !['Available', 'Booked', 'Occupied', 'Maintenance'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid slot status' });
    }

    const slot = await Slot.findById(req.params.slotId);
    if (!slot) {
      return res.status(404).json({ success: false, message: 'Slot not found' });
    }

    slot.status = status;
    await slot.save();

    res.json({
      success: true,
      slot,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getStationSlots,
  updateSlotStatus,
};
