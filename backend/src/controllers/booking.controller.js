const Booking = require('../models/Booking');
const Station = require('../models/Station');
const Slot = require('../models/Slot');
const { calculateCharging } = require('../services/charging.service');
const { estimateStationWaitTime } = require('../services/waitTime.service');
const { predictDemand } = require('../services/mlClient.service');

// @desc    Calculate booking quote without saving
// @route   POST /api/bookings/quote
// @access  Public / Private
const getBookingQuote = async (req, res, next) => {
  try {
    const { stationId, batteryCapacity, currentSoc, desiredSoc, slotDate, slotTime } = req.body;

    if (!stationId) {
      return res.status(400).json({ success: false, message: 'Please provide stationId' });
    }

    const station = await Station.findById(stationId);
    if (!station || station.status !== 'Active') {
      return res.status(400).json({ success: false, message: 'Station is not active or available' });
    }

    const battery = batteryCapacity || 60.0;
    const cur = currentSoc !== undefined ? currentSoc : 20.0;
    const des = desiredSoc !== undefined ? desiredSoc : 80.0;

    const calc = calculateCharging(battery, cur, des, station.chargerPower, station.pricePerKwh);
    if (calc.error) {
      return res.status(400).json({ success: false, message: calc.error });
    }

    const wait = estimateStationWaitTime(station, calc.chargingDuration);

    // Check ML demand
    const hour = slotTime ? parseInt(slotTime.split(':')[0]) : new Date().getHours();
    const mlDemand = await predictDemand({
      stationId: station._id,
      chargerPower: station.chargerPower,
      totalSlots: station.totalSlots,
      date: slotDate,
      hour,
    });

    res.json({
      success: true,
      quote: {
        station: {
          id: station._id,
          name: station.stationName,
          chargerType: station.chargerType,
          chargerPower: station.chargerPower,
          pricePerKwh: station.pricePerKwh,
        },
        energyRequired: calc.energyRequired,
        chargingDuration: calc.chargingDuration,
        estimatedCost: calc.estimatedCost,
        estimatedWaitTime: wait.estimatedWaitTimeHours,
        waitReport: wait,
        mlDemand: {
          predictedDemand: mlDemand.predicted_demand,
          congestionLevel: mlDemand.congestion_level,
          isPeakHour: mlDemand.congestion_level === 'High',
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Create and confirm a booking
// @route   POST /api/bookings
// @access  Private
const createBooking = async (req, res, next) => {
  try {
    const {
      stationId,
      slotId,
      slotDate,
      slotTime,
      vehicleType,
      batteryCapacity,
      currentSoc,
      desiredSoc,
      sourceLocation,
      destinationLocation,
    } = req.body;

    const station = await Station.findById(stationId);
    if (!station || station.status !== 'Active') {
      return res.status(400).json({ success: false, message: 'Station is not available for booking' });
    }

    const battery = batteryCapacity || req.user.batteryCapacity || 60.0;
    const cur = currentSoc !== undefined ? currentSoc : 20.0;
    const des = desiredSoc !== undefined ? desiredSoc : 80.0;

    const calc = calculateCharging(battery, cur, des, station.chargerPower, station.pricePerKwh);
    if (calc.error) {
      return res.status(400).json({ success: false, message: calc.error });
    }

    const wait = estimateStationWaitTime(station, calc.chargingDuration);

    // If slotId is provided, atomically reserve the slot
    let targetSlot = null;
    if (slotId) {
      targetSlot = await Slot.findOneAndUpdate(
        { _id: slotId, status: 'Available' },
        { status: 'Booked' },
        { new: true }
      );

      if (!targetSlot) {
        return res.status(409).json({ success: false, message: 'Selected time slot is no longer available' });
      }
    }

    // Decrement available slots on the physical station
    await Station.findByIdAndUpdate(stationId, {
      $inc: {
        availableSlots: station.availableSlots > 0 ? -1 : 0,
        occupiedSlots: 1,
      },
    });

    const booking = await Booking.create({
      user: req.user._id,
      station: station._id,
      slot: targetSlot ? targetSlot._id : null,
      slotDate: slotDate || targetSlot?.slotDate || new Date().toISOString().split('T')[0],
      slotTime: slotTime || targetSlot?.slotTime || 'Immediate',
      vehicleType: vehicleType || req.user.vehicleType || 'Electric Car',
      batteryCapacity: battery,
      currentSoc: cur,
      desiredSoc: des,
      energyRequired: calc.energyRequired,
      chargingDuration: calc.chargingDuration,
      estimatedWaitTime: wait.estimatedWaitTimeHours,
      estimatedCost: calc.estimatedCost,
      sourceLocation: sourceLocation || '',
      destinationLocation: destinationLocation || '',
      bookingStatus: 'Pending',
      paymentStatus: 'Unpaid',
    });

    const populated = await Booking.findById(booking._id).populate('station').populate('slot');

    res.status(201).json({
      success: true,
      message: 'Booking confirmed successfully',
      booking: populated,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Cancel a booking
// @route   PUT /api/bookings/:id/cancel
// @access  Private
const cancelBooking = async (req, res, next) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    // Check ownership or admin
    const isOwner = booking.user.toString() === req.user._id.toString();
    const isSuperAdmin = req.user.role === 'super_admin';
    const isAssignedStationAdmin =
      req.user.role === 'station_admin' &&
      booking.station &&
      req.user.assignedStation &&
      booking.station.toString() === req.user.assignedStation.toString();

    if (!isOwner && !isSuperAdmin && !isAssignedStationAdmin) {
      return res.status(403).json({ success: false, message: 'Unauthorized to cancel this booking' });
    }

    // Idempotent cancellation: if already cancelled, respond with success
    if (booking.bookingStatus === 'Cancelled') {
      return res.json({
        success: true,
        message: 'Booking is already cancelled',
        booking,
      });
    }

    if (booking.bookingStatus === 'Completed') {
      return res.status(400).json({ success: false, message: 'Cannot cancel a completed charging session' });
    }

    booking.bookingStatus = 'Cancelled';
    const wasPaid = booking.paymentStatus === 'Paid';
    if (wasPaid) {
      booking.paymentStatus = 'Refunded';
    }
    await booking.save();

    // Release slot if booked
    if (booking.slot) {
      await Slot.findByIdAndUpdate(booking.slot, { status: 'Available' });
    }

    // Restore station available slot count safely
    if (booking.station) {
      const station = await Station.findById(booking.station);
      if (station) {
        await Station.findByIdAndUpdate(booking.station, {
          $inc: {
            availableSlots: station.availableSlots < (station.totalSlots || 99) ? 1 : 0,
            occupiedSlots: station.occupiedSlots > 0 ? -1 : 0,
          },
        });
      }
    }

    res.json({
      success: true,
      message: wasPaid
        ? 'Booking cancelled successfully. Refund processed to your account.'
        : 'Booking cancelled successfully.',
      booking,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get bookings of current user
// @route   GET /api/bookings/my
// @access  Private
const getMyBookings = async (req, res, next) => {
  try {
    const bookings = await Booking.find({ user: req.user._id })
      .populate('station')
      .populate('slot')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: bookings.length,
      bookings,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get all bookings (super_admin or station_admin)
// @route   GET /api/bookings
// @access  Private (Admins)
const getAllBookings = async (req, res, next) => {
  try {
    const filter = {};
    if (req.user.role === 'station_admin' && req.user.assignedStation) {
      filter.station = req.user.assignedStation;
    } else if (req.query.stationId) {
      filter.station = req.query.stationId;
    }

    if (req.query.status) {
      filter.bookingStatus = req.query.status;
    }

    const bookings = await Booking.find(filter)
      .populate('user', 'name email phone vehicleType batteryCapacity')
      .populate('station', 'stationName city chargerType address pricePerKwh totalSlots availableSlots occupiedSlots')
      .populate('slot')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: bookings.length,
      bookings,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update booking status (station_admin or super_admin)
// @route   PUT /api/bookings/:id/status
// @access  Private (Admins)
const updateBookingStatus = async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!status || !['Pending', 'Confirmed', 'Accepted', 'Paid', 'Completed', 'Cancelled'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid booking status' });
    }

    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    // If station_admin, ensure booking is at their station
    if (
      req.user.role === 'station_admin' &&
      booking.station.toString() !== req.user.assignedStation?.toString()
    ) {
      return res.status(403).json({ success: false, message: 'Unauthorized for this station booking' });
    }

    const oldStatus = booking.bookingStatus;
    booking.bookingStatus = status;
    if (status === 'Cancelled' && booking.paymentStatus === 'Paid') {
      booking.paymentStatus = 'Refunded';
    }

    if (status === 'Completed' || status === 'Cancelled') {
      // Release slot back to Available
      if (booking.slot) {
        await Slot.findByIdAndUpdate(booking.slot, { status: 'Available' });
      }
      // Release physical occupied slot
      if (booking.station && ['Confirmed', 'Paid'].includes(oldStatus)) {
        const station = await Station.findById(booking.station);
        if (station) {
          await Station.findByIdAndUpdate(booking.station, {
            $inc: {
              availableSlots: station.availableSlots < (station.totalSlots || 99) ? 1 : 0,
              occupiedSlots: station.occupiedSlots > 0 ? -1 : 0,
            },
          });
        }
      }
    }

    await booking.save();

    res.json({
      success: true,
      message: `Booking updated to ${status}`,
      booking,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get booking by ID
// @route   GET /api/bookings/:id
// @access  Private
const getBookingById = async (req, res, next) => {
  try {
    const booking = await Booking.findById(req.params.id)
      .populate('user', 'name email phone')
      .populate('station')
      .populate('slot');

    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    res.json({
      success: true,
      booking,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getBookingQuote,
  createBooking,
  cancelBooking,
  getMyBookings,
  getAllBookings,
  getBookingById,
  updateBookingStatus,
};
