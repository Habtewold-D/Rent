const express = require('express');
const router = express.Router();

const {
  register,
  login,
  getProfile,
  updateProfile,
  changePassword,
  upgradeLandlord
} = require('../controllers/authController');

const {
  validateRegister,
  validateLogin,
  validatePasswordUpdate
} = require('../middleware/validation');

const { authenticate } = require('../middleware/auth');

// Public routes
router.post('/register', validateRegister, register);
router.post('/login', validateLogin, login);

// Protected routes
router.get('/profile', authenticate, getProfile);
router.put('/profile', authenticate, updateProfile);
router.put('/change-password', authenticate, validatePasswordUpdate, changePassword);
router.post('/upgrade-landlord', authenticate, upgradeLandlord);

module.exports = router;
