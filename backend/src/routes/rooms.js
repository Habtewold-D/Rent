const express = require('express');
const router = express.Router();

const {
  createRoom,
  getAllRooms,
  getRoomById,
  getMyListings,
  updateRoom,
  deleteRoom,
  searchRooms,
  getRoomBookings
} = require('../controllers/roomController');

const { authenticate, requireVerifiedLandlord } = require('../middleware/auth');
const { uploadRoomImages } = require('../middleware/roomUpload');

// Public routes
router.get('/', getAllRooms);
router.get('/search', searchRooms);
router.get('/:id', getRoomById);

// Protected routes - Verified Landlord only
router.post('/', authenticate, requireVerifiedLandlord, uploadRoomImages, createRoom);
router.get('/my/listings', authenticate, requireVerifiedLandlord, getMyListings);
router.put('/:id', authenticate, requireVerifiedLandlord, uploadRoomImages, updateRoom);
router.delete('/:id', authenticate, requireVerifiedLandlord, deleteRoom);
router.get('/:id/bookings', authenticate, requireVerifiedLandlord, getRoomBookings);

module.exports = router;
