const express = require('express');
const router = express.Router();
const {
  registerUser,
  loginUser,
  getMe,
  updateProfile,
  getStationAdmins,
  createStationAdmin,
  deleteStationAdmin,
  getAllUsers,
  seedAdminsEndpoint,
} = require('../controllers/auth.controller');
const { protect } = require('../middleware/auth.middleware');
const { restrictTo } = require('../middleware/role.middleware');

router.post('/register', registerUser);
router.post('/login', loginUser);
router.get('/me', protect, getMe);
router.put('/profile', protect, updateProfile);
router.get('/users', protect, restrictTo('super_admin'), getAllUsers);
router.get('/station-admins', protect, restrictTo('super_admin'), getStationAdmins);
router.post('/station-admins', protect, restrictTo('super_admin'), createStationAdmin);
router.delete('/station-admins/:id', protect, restrictTo('super_admin'), deleteStationAdmin);
router.get('/seed-admins', seedAdminsEndpoint);
router.post('/seed-admins', seedAdminsEndpoint);

module.exports = router;
