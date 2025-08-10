const { Room, RoomImage, User } = require('../models');
const { uploadFileBuffer } = require('../config/cloudinary');
const { Op } = require('sequelize');

/**
 * Create new room listing (verified landlords only)
 */
const createRoom = async (req, res) => {
  try {
    const {
      monthlyRent, roomType, maxOccupants,
      genderPreference, address, city, latitude, longitude,
      amenities, contactPhone, contactEmail
    } = req.body;

    // Create room record
    const room = await Room.create({
      landlordId: req.user.id,
      monthlyRent: parseFloat(monthlyRent),
      roomType,
      maxOccupants: parseInt(maxOccupants),
      genderPreference,
      address,
      city,
      latitude: latitude ? parseFloat(latitude) : null,
      longitude: longitude ? parseFloat(longitude) : null,
      amenities: amenities ? JSON.parse(amenities) : [],
      contactPhone: contactPhone || req.user.phone,
      contactEmail: contactEmail || req.user.email
    });

    // Upload images to Cloudinary if provided
    const imageUrls = [];
    if (req.files && req.files.length > 0) {
      for (let i = 0; i < req.files.length; i++) {
        const file = req.files[i];
        const uploadResult = await uploadFileBuffer(
          file.buffer,
          `rental-platform/rooms`,
          `room-image-${room.id}-${Date.now()}-${i}`
        );
        
        if (!uploadResult.success) {
          return res.status(400).json({
            success: false,
            message: 'Failed to upload room image',
            error: uploadResult.error
          });
        }
        
        // Create room image record
        await RoomImage.create({
          roomId: room.id,
          imageUrl: uploadResult.url,
          isPrimary: i === 0, // First image is primary
          displayOrder: i
        });

        imageUrls.push(uploadResult.url);
      }
    }

    // Get room with images
    const roomWithImages = await Room.findByPk(room.id, {
      include: [
        {
          model: RoomImage,
          as: 'roomImages',
          attributes: ['id', 'imageUrl', 'isPrimary', 'caption', 'displayOrder']
        }
      ]
    });

    res.status(201).json({
      success: true,
      message: 'Room listing created successfully. Pending admin approval.',
      data: {
        room: roomWithImages,
        uploadedImages: imageUrls
      }
    });
  } catch (error) {
    console.error('Create room error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create room listing',
      error: error.message
    });
  }
};

/**
 * Get all available rooms with filters
 */
const getAllRooms = async (req, res) => {
  try {
    const {
      city, minRent, maxRent, roomType, genderPreference,
      verifiedOnly, page = 1, limit = 10, sortBy = 'createdAt', sortOrder = 'DESC'
    } = req.query;

    // Build where clause
    const whereClause = {
      isAvailable: true,
    };
    // Only show approved by default; allow including pending for development/testing via query
    if (req.query.includePending !== 'true') {
      whereClause.isApproved = true;
    }

    if (city) whereClause.city = { [Op.iLike]: `%${city}%` };
    if (roomType) whereClause.roomType = roomType;
    if (genderPreference) whereClause.genderPreference = genderPreference;

    // Price range filter
    if (minRent || maxRent) {
      whereClause.monthlyRent = {};
      if (minRent) whereClause.monthlyRent[Op.gte] = parseFloat(minRent);
      if (maxRent) whereClause.monthlyRent[Op.lte] = parseFloat(maxRent);
    }

    // Landlord verification filter
    const landlordWhere = {};
    if (verifiedOnly === 'true') {
      landlordWhere.isLandlordVerified = true;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows: rooms } = await Room.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: User,
          as: 'landlord',
          attributes: ['id', 'firstName', 'lastName', 'email', 'phone', 'isLandlordVerified'],
          where: Object.keys(landlordWhere).length > 0 ? landlordWhere : undefined
        },
        {
          model: RoomImage,
          as: 'roomImages',
          attributes: ['id', 'imageUrl', 'isPrimary', 'caption', 'displayOrder'],
          order: [['displayOrder', 'ASC']]
        }
      ],
      order: [[sortBy, sortOrder.toUpperCase()]],
      limit: parseInt(limit),
      offset: offset
    });

    res.json({
      success: true,
      data: {
        rooms,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(count / parseInt(limit)),
          totalItems: count,
          itemsPerPage: parseInt(limit)
        }
      }
    });
  } catch (error) {
    console.error('Get rooms error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get rooms',
      error: error.message
    });
  }
};

/**
 * Get single room details
 */
const getRoomById = async (req, res) => {
  try {
    const { id } = req.params;

    const room = await Room.findOne({
      where: { 
        id,
        isAvailable: true,
        isApproved: true
      },
      include: [
        {
          model: User,
          as: 'landlord',
          attributes: ['id', 'firstName', 'lastName', 'email', 'phone', 'isLandlordVerified']
        },
        {
          model: RoomImage,
          as: 'roomImages',
          attributes: ['id', 'imageUrl', 'isPrimary', 'caption', 'displayOrder'],
          order: [['displayOrder', 'ASC']]
        }
      ]
    });

    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found or not available'
      });
    }

    // Increment view count
    await room.increment('viewCount');

    res.json({
      success: true,
      data: { room }
    });
  } catch (error) {
    console.error('Get room by ID error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get room details',
      error: error.message
    });
  }
};

/**
 * Get landlord's own listings
 */
const getMyListings = async (req, res) => {
  try {
    const { page = 1, limit = 10, status = 'all' } = req.query;

    const whereClause = { landlordId: req.user.id };
    
    if (status === 'available') whereClause.isAvailable = true;
    if (status === 'unavailable') whereClause.isAvailable = false;
    if (status === 'approved') whereClause.isApproved = true;
    if (status === 'pending') whereClause.isApproved = false;

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows: rooms } = await Room.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: RoomImage,
          as: 'roomImages',
          attributes: ['id', 'imageUrl', 'isPrimary', 'caption', 'displayOrder'],
          order: [['displayOrder', 'ASC']]
        }
      ],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset: offset
    });

    res.json({
      success: true,
      data: {
        rooms,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(count / parseInt(limit)),
          totalItems: count,
          itemsPerPage: parseInt(limit)
        }
      }
    });
  } catch (error) {
    console.error('Get my listings error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get your listings',
      error: error.message
    });
  }
};

/**
 * Update room listing
 */
const updateRoom = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    // Find room and verify ownership
    const room = await Room.findOne({
      where: { id, landlordId: req.user.id }
    });

    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found or you do not have permission to update it'
      });
    }

    // Parse numeric fields
    if (updateData.monthlyRent) updateData.monthlyRent = parseFloat(updateData.monthlyRent);
    if (updateData.maxOccupants) updateData.maxOccupants = parseInt(updateData.maxOccupants);
    if (updateData.latitude) updateData.latitude = parseFloat(updateData.latitude);
    if (updateData.longitude) updateData.longitude = parseFloat(updateData.longitude);
    if (updateData.amenities) updateData.amenities = JSON.parse(updateData.amenities);

    // Parse boolean fields
    if (updateData.isAvailable !== undefined) {
      updateData.isAvailable = updateData.isAvailable === 'true';
    }

    // Update room
    await room.update(updateData);

    // Handle new images if provided
    if (req.files && req.files.length > 0) {
      for (let i = 0; i < req.files.length; i++) {
        const file = req.files[i];
        const uploadResult = await uploadFileBuffer(
          file.buffer,
          `rental-platform/rooms`,
          `room-image-${room.id}-${Date.now()}-${i}`
        );
        
        if (!uploadResult.success) {
          return res.status(400).json({
            success: false,
            message: 'Failed to upload room image',
            error: uploadResult.error
          });
        }
        
        await RoomImage.create({
          roomId: room.id,
          imageUrl: uploadResult.url,
          displayOrder: i + 100 // Add to end
        });
      }
    }

    // Get updated room with images
    const updatedRoom = await Room.findByPk(room.id, {
      include: [
        {
          model: RoomImage,
          as: 'roomImages',
          attributes: ['id', 'imageUrl', 'isPrimary', 'caption', 'displayOrder'],
          order: [['displayOrder', 'ASC']]
        }
      ]
    });

    res.json({
      success: true,
      message: 'Room updated successfully',
      data: { room: updatedRoom }
    });
  } catch (error) {
    console.error('Update room error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update room',
      error: error.message
    });
  }
};

/**
 * Delete room listing
 */
const deleteRoom = async (req, res) => {
  try {
    const { id } = req.params;

    // Find room and verify ownership
    const room = await Room.findOne({
      where: { id, landlordId: req.user.id }
    });

    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found or you do not have permission to delete it'
      });
    }

    // Delete associated images first
    await RoomImage.destroy({ where: { roomId: id } });

    // Delete room
    await room.destroy();

    res.json({
      success: true,
      message: 'Room listing deleted successfully'
    });
  } catch (error) {
    console.error('Delete room error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete room',
      error: error.message
    });
  }
};

/**
 * Advanced search with location/filters
 */
const searchRooms = async (req, res) => {
  try {
    const {
      q, city, minRent, maxRent, roomType, genderPreference,
      amenities, verifiedOnly, page = 1, limit = 10
    } = req.query;

    const whereClause = {
      isAvailable: true,
      isApproved: true
    };

    // Text search in address
    if (q) {
      whereClause[Op.or] = [
        { address: { [Op.iLike]: `%${q}%` } }
      ];
    }

    // Apply filters (same as getAllRooms)
    if (city) whereClause.city = { [Op.iLike]: `%${city}%` };
    if (roomType) whereClause.roomType = roomType;
    if (genderPreference) whereClause.genderPreference = genderPreference;

    // Price range
    if (minRent || maxRent) {
      whereClause.monthlyRent = {};
      if (minRent) whereClause.monthlyRent[Op.gte] = parseFloat(minRent);
      if (maxRent) whereClause.monthlyRent[Op.lte] = parseFloat(maxRent);
    }

    // Amenities search
    if (amenities) {
      const amenityList = amenities.split(',');
      whereClause[Op.and] = amenityList.map(amenity => ({
        amenities: { [Op.contains]: [amenity.trim()] }
      }));
    }

    const landlordWhere = {};
    if (verifiedOnly === 'true') {
      landlordWhere.isLandlordVerified = true;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows: rooms } = await Room.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: User,
          as: 'landlord',
          attributes: ['id', 'firstName', 'lastName', 'email', 'phone', 'isLandlordVerified'],
          where: Object.keys(landlordWhere).length > 0 ? landlordWhere : undefined
        },
        {
          model: RoomImage,
          as: 'roomImages',
          attributes: ['id', 'imageUrl', 'isPrimary', 'caption', 'displayOrder'],
          order: [['displayOrder', 'ASC']]
        }
      ],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset: offset
    });

    res.json({
      success: true,
      data: {
        rooms,
        searchQuery: q,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(count / parseInt(limit)),
          totalItems: count,
          itemsPerPage: parseInt(limit)
        }
      }
    });
  } catch (error) {
    console.error('Search rooms error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to search rooms',
      error: error.message
    });
  }
};

/**
 * Get bookings for specific room (landlord only)
 */
const getRoomBookings = async (req, res) => {
  try {
    const { id } = req.params;

    // Verify room ownership
    const room = await Room.findOne({
      where: { id, landlordId: req.user.id }
    });

    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found or you do not have permission to view its bookings'
      });
    }

    // TODO: Implement booking system first
    // For now, return placeholder
    res.json({
      success: true,
      message: 'Booking system not yet implemented',
      data: {
        room: { id: room.id, title: room.title },
        bookings: []
      }
    });
  } catch (error) {
    console.error('Get room bookings error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get room bookings',
      error: error.message
    });
  }
};

module.exports = {
  createRoom,
  getAllRooms,
  getRoomById,
  getMyListings,
  updateRoom,
  deleteRoom,
  searchRooms,
  getRoomBookings
};
