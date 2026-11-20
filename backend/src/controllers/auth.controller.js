const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Station = require('../models/Station');

const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET || 'evon_secret_key', {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
};

// @desc    Register a new user
// @route   POST /api/auth/register
// @access  Public
const registerUser = async (req, res, next) => {
  try {
    const { name, email, password, phone, vehicleType, batteryCapacity, role } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide name, email, and password' });
    }

    const userExists = await User.findOne({ email });
    if (userExists) {
      return res.status(400).json({ success: false, message: 'User already exists with this email' });
    }

    // Public registration creates regular EV drivers ('user').
    // Station Admins can ONLY be created by Super Admin with an assigned station.
    const userRole = 'user';

    const user = await User.create({
      name,
      email,
      password,
      phone: phone || '',
      vehicleType: vehicleType || 'Electric Car',
      batteryCapacity: batteryCapacity || 60.0,
      role: userRole,
    });

    const token = generateToken(user._id);

    res.status(201).json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.phone,
        vehicleType: user.vehicleType,
        batteryCapacity: user.batteryCapacity,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Authenticate user & get token
// @route   POST /api/auth/login
// @access  Public
const loginUser = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide email and password' });
    }

    // Check for user (must select password explicitly since select: false in schema)
    const user = await User.findOne({ email }).select('+password').populate('assignedStation');

    if (!user || !(await user.matchPassword(password))) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    const token = generateToken(user._id);

    res.json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.phone,
        vehicleType: user.vehicleType,
        batteryCapacity: user.batteryCapacity,
        assignedStation: user.assignedStation,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get current user profile
// @route   GET /api/auth/me
// @access  Private
const getMe = async (req, res) => {
  res.json({
    success: true,
    user: req.user,
  });
};

// @desc    Update current user profile
// @route   PUT /api/auth/profile
// @access  Private
const updateProfile = async (req, res, next) => {
  try {
    const { name, phone, vehicleType, batteryCapacity } = req.body;
    const user = await User.findById(req.user._id);

    if (name) user.name = name;
    if (phone !== undefined) user.phone = phone;
    if (vehicleType) user.vehicleType = vehicleType;
    if (batteryCapacity) user.batteryCapacity = parseFloat(batteryCapacity);

    await user.save();

    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.phone,
        vehicleType: user.vehicleType,
        batteryCapacity: user.batteryCapacity,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get all station admins (super_admin only)
// @route   GET /api/auth/station-admins
// @access  Private (super_admin)
const getStationAdmins = async (req, res, next) => {
  try {
    const admins = await User.find({ role: 'station_admin' })
      .populate('assignedStation')
      .select('-password');
    res.json({ success: true, count: admins.length, admins });
  } catch (error) {
    next(error);
  }
};

// @desc    Create a new station admin assigned to a specific station (super_admin only)
// @route   POST /api/auth/station-admins
// @access  Private (super_admin)
const createStationAdmin = async (req, res, next) => {
  try {
    const { name, email, password, phone, assignedStation } = req.body;

    if (!name || !email || !password || !assignedStation) {
      return res.status(400).json({
        success: false,
        message: 'Please provide name, email, password, and assigned station',
      });
    }

    const station = await Station.findById(assignedStation);
    if (!station) {
      return res.status(404).json({
        success: false,
        message: 'Assigned station not found',
      });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'A user account with this email already exists',
      });
    }

    const admin = await User.create({
      name,
      email,
      password,
      phone: phone || '',
      role: 'station_admin',
      assignedStation: station._id,
    });

    const populated = await User.findById(admin._id)
      .select('-password')
      .populate('assignedStation');

    res.status(201).json({
      success: true,
      message: `Station admin "${name}" created and assigned to ${station.stationName}`,
      admin: populated,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Delete a station admin (super_admin only)
// @route   DELETE /api/auth/station-admins/:id
// @access  Private (super_admin)
const deleteStationAdmin = async (req, res, next) => {
  try {
    const admin = await User.findOne({ _id: req.params.id, role: 'station_admin' });
    if (!admin) {
      return res.status(404).json({ success: false, message: 'Station admin not found' });
    }

    await User.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Station admin deleted successfully' });
  } catch (error) {
    next(error);
  }
};

// @desc    Get all registered users (drivers) with booking stats (super_admin only)
// @route   GET /api/auth/users
// @access  Private (super_admin)
const getAllUsers = async (req, res, next) => {
  try {
    const Booking = require('../models/Booking');
    const users = await User.find({ role: 'user' }).sort({ createdAt: -1 });

    const enriched = await Promise.all(
      users.map(async (u) => {
        const bookingsCount = await Booking.countDocuments({ user: u._id });
        return {
          id: u._id,
          _id: u._id,
          name: u.name,
          email: u.email,
          phone: u.phone || '+91 9123456789',
          vehicleType: u.vehicleType || 'Electric Car',
          batteryCapacity: u.batteryCapacity || 60.0,
          role: u.role,
          bookingsCount,
          createdAt: u.createdAt,
        };
      })
    );

    res.json({
      success: true,
      users: enriched,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Ensure 1 super_admin and 3 station_admins are seeded and linked
// @route   GET /api/auth/seed-admins
// @access  Public
const seedAdminsEndpoint = async (req, res, next) => {
  try {
    const ensureAdmins = require('../seed/ensureAdmins');
    const result = await ensureAdmins();
    res.json({ success: true, message: 'Admins ensured successfully', data: result });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  registerUser,
  loginUser,
  getMe,
  updateProfile,
  getStationAdmins,
  createStationAdmin,
  deleteStationAdmin,
  getAllUsers,
  seedAdminsEndpoint,
};
