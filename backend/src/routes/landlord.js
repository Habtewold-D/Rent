const express = require('express');
const router = express.Router();

const {
  requestLandlordVerification,
  getMyLandlordRequest
} = require('../controllers/landlordController');

const { authenticate } = require('../middleware/auth');
const { uploadLandlordDocs } = require('../middleware/upload');

// Protected routes
router.post('/request-verification', authenticate, uploadLandlordDocs, requestLandlordVerification);
router.get('/my-request', authenticate, getMyLandlordRequest);

module.exports = router;
