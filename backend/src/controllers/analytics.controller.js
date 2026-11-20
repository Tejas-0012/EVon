const Station = require('../models/Station');
const Booking = require('../models/Booking');
const User = require('../models/User');
const Payment = require('../models/Payment');

// @desc    Get system-wide analytics overview
// @route   GET /api/analytics/overview
// @access  Private (super_admin)
const getSuperAdminOverview = async (req, res, next) => {
  try {
    const totalStations = await Station.countDocuments({ status: 'Active' });
    const totalUsers = await User.countDocuments({ role: 'user' });
    const totalBookings = await Booking.countDocuments();
    const paidBookings = await Booking.countDocuments({ paymentStatus: 'Paid' });

    // Aggregate total revenue
    const revenueAgg = await Payment.aggregate([
      { $match: { paymentStatus: 'Success' } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]);
    const totalRevenue = revenueAgg.length > 0 ? revenueAgg[0].total : 0;

    // Aggregate total energy dispensed
    const energyAgg = await Booking.aggregate([
      { $match: { bookingStatus: { $in: ['Confirmed', 'Paid', 'Completed'] } } },
      { $group: { _id: null, totalEnergy: { $sum: '$energyRequired' } } },
    ]);
    const totalEnergyDispensed = energyAgg.length > 0 ? parseFloat(energyAgg[0].totalEnergy.toFixed(2)) : 0;

    // Station utilization calculations
    const stations = await Station.find({ status: 'Active' });
    let totalCapacity = 0;
    let totalOccupied = 0;
    stations.forEach((st) => {
      totalCapacity += st.totalSlots || 4;
      totalOccupied += st.occupiedSlots || 0;
    });
    const networkUtilization = totalCapacity > 0 ? Math.round((totalOccupied / totalCapacity) * 100) : 0;

    // Recent 5 bookings
    const recentBookings = await Booking.find()
      .populate('user', 'name email')
      .populate('station', 'stationName city')
      .sort({ createdAt: -1 })
      .limit(5);

    res.json({
      success: true,
      metrics: {
        totalStations,
        totalUsers,
        totalBookings,
        paidBookings,
        totalRevenue: parseFloat(totalRevenue.toFixed(2)),
        totalEnergyDispensed,
        networkUtilization,
      },
      recentBookings,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get station-specific analytics
// @route   GET /api/analytics/station/:stationId
// @access  Private (station_admin / super_admin)
const getStationAnalytics = async (req, res, next) => {
  try {
    const { stationId } = req.params;
    const station = await Station.findById(stationId);
    if (!station) {
      return res.status(404).json({ success: false, message: 'Station not found' });
    }

    const bookings = await Booking.find({ station: stationId }).sort({ createdAt: -1 });
    const totalBookings = bookings.length;
    const totalEnergy = bookings.reduce((sum, b) => sum + (b.energyRequired || 0), 0);
    const totalRevenue = bookings
      .filter((b) => b.paymentStatus === 'Paid')
      .reduce((sum, b) => sum + (b.estimatedCost || 0), 0);

    const utilization =
      station.totalSlots > 0 ? Math.round((station.occupiedSlots / station.totalSlots) * 100) : 0;

    res.json({
      success: true,
      station: {
        id: station._id,
        name: station.stationName,
        availableSlots: station.availableSlots,
        totalSlots: station.totalSlots,
        occupiedSlots: station.occupiedSlots,
        utilization,
      },
      metrics: {
        totalBookings,
        totalEnergyDispensed: parseFloat(totalEnergy.toFixed(2)),
        totalRevenue: parseFloat(totalRevenue.toFixed(2)),
      },
      recentBookings: bookings.slice(0, 5),
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getSuperAdminOverview,
  getStationAnalytics,
};
