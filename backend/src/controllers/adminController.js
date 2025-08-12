const User = require('../models/User');
const LandlordRequest = require('../models/LandlordRequest');
const { Op } = require('sequelize');
const sequelize = require('../config/database');

/**
 * Get all landlord requests with filtering
 */
const getLandlordRequests = async (req, res) => {
  try {
    const { status, page = 1, limit = 10, search } = req.query;
    
    const offset = (page - 1) * limit;
    const whereClause = {};
    
    // Filter by status if provided (compare against enum values by normalizing input)
    if (status && ['pending', 'approved', 'rejected'].includes(String(status).toLowerCase())) {
      whereClause.status = String(status).toLowerCase();
    }

    // Search by user email or name if provided
    let userWhereClause = {};
    if (search) {
      userWhereClause = {
        [Op.or]: [
          { email: { [Op.iLike]: `%${search}%` } },
          { firstName: { [Op.iLike]: `%${search}%` } },
          { lastName: { [Op.iLike]: `%${search}%` } }
        ]
      };
    }

    const { count, rows: requests } = await LandlordRequest.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'email', 'firstName', 'lastName', 'phone', 'role'],
          where: Object.keys(userWhereClause).length > 0 ? userWhereClause : undefined
        },
        {
          model: User,
          as: 'reviewer',
          attributes: ['id', 'email', 'firstName', 'lastName'],
          required: false
        }
      ],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset: parseInt(offset)
    });

    const totalPages = Math.ceil(count / limit);

    res.json({
      success: true,
      data: {
        requests,
        pagination: {
          currentPage: parseInt(page),
          totalPages,
          totalItems: count,
          itemsPerPage: parseInt(limit)
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to get landlord requests',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Get users (admin)
 */
const getUsers = async (req, res) => {
  try {
    const { page = 1, limit = 20, search, role } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const where = {};
    if (role && typeof role === 'string') {
      where.role = role.toLowerCase();
    } else {
      // By default, do not include admin accounts in the users list
      where.role = { [Op.ne]: 'admin' };
    }
    if (search && typeof search === 'string' && search.trim()) {
      const s = `%${search.trim()}%`;
      where[Op.or] = [
        { email: { [Op.iLike]: s } },
        { firstName: { [Op.iLike]: s } },
        { lastName: { [Op.iLike]: s } },
      ];
    }

    const { count, rows } = await User.findAndCountAll({
      where,
      attributes: ['id', 'email', 'firstName', 'lastName', 'role', 'createdAt'],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset,
    });

    res.json({
      success: true,
      data: {
        users: rows,
        pagination: {
          currentPage: parseInt(page),
          itemsPerPage: parseInt(limit),
          totalItems: count,
          totalPages: Math.ceil(count / parseInt(limit)),
        },
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to fetch users',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

/**
 * Review landlord request (approve/reject)
 */
const reviewLandlordRequest = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, adminNotes } = req.body;
    const reviewerId = req.user.id;

    // Validate status
    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Status must be either "approved" or "rejected"'
      });
    }

    // Find the request
    const request = await LandlordRequest.findByPk(id, {
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'email', 'firstName', 'lastName', 'role']
        }
      ]
    });

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Landlord request not found'
      });
    }

    // Check if already reviewed
    if (request.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: `Request has already been ${request.status}`
      });
    }

    // Update request status
    await request.update({
      status,
      adminNotes,
      reviewedBy: reviewerId,
      reviewedAt: new Date()
    });

    // If approved, update user role and verification status
    if (status === 'approved') {
      await User.update(
        { 
          role: 'landlord',
          isLandlordVerified: true,
          nationalIdUrl: request.nationalIdUrl,
          propertyDocumentUrl: request.propertyDocumentUrl
        },
        { where: { id: request.userId } }
      );
    }

    // Fetch updated request with associations
    const updatedRequest = await LandlordRequest.findByPk(id, {
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'email', 'firstName', 'lastName', 'role', 'isLandlordVerified']
        },
        {
          model: User,
          as: 'reviewer',
          attributes: ['id', 'email', 'firstName', 'lastName']
        }
      ]
    });

    res.json({
      success: true,
      message: `Landlord request ${status} successfully`,
      data: {
        request: updatedRequest
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to review landlord request',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Get landlord request statistics
 */
const getLandlordRequestStats = async (req, res) => {
  try {
    const { fn, col } = require('sequelize');
    const stats = await LandlordRequest.findAll({
      attributes: [
        'status',
        [fn('COUNT', col('status')), 'count']
      ],
      group: ['status']
    });

    const formattedStats = {
      pending: 0,
      approved: 0,
      rejected: 0,
      total: 0
    };

    stats.forEach(stat => {
      formattedStats[stat.status] = parseInt(stat.dataValues.count);
      formattedStats.total += parseInt(stat.dataValues.count);
    });

    res.json({
      success: true,
      data: {
        stats: formattedStats
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to get statistics',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

module.exports = {
  getLandlordRequests,
  reviewLandlordRequest,
  getLandlordRequestStats,
  getUsers,
};
