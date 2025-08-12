const express = require('express');
const router = express.Router();

const { 
  getLandlordRequests, 
  reviewLandlordRequest, 
  getLandlordRequestStats,
  getUsers,
  getAdminSummary,
} = require('../controllers/adminController');

const { authenticate, authorize } = require('../middleware/auth');

// Admin only routes
router.get('/landlord-requests', authenticate, authorize('admin'), getLandlordRequests);
router.put('/landlord-requests/:id/review', authenticate, authorize('admin'), reviewLandlordRequest);
router.get('/landlord-requests/stats', authenticate, authorize('admin'), getLandlordRequestStats);
router.get('/users', authenticate, authorize('admin'), getUsers);
router.get('/summary', authenticate, authorize('admin'), getAdminSummary);

module.exports = router;
