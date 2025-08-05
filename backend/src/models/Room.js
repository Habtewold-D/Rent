const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Room = sequelize.define('Room', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  landlordId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: 'users',
      key: 'id'
    }
  },
  monthlyRent: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    validate: {
      min: 0
    }
  },
  roomType: {
    type: DataTypes.ENUM('single', 'shared', 'studio', 'apartment'),
    allowNull: false
  },
  maxOccupants: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1,
      max: 10
    }
  },
  genderPreference: {
    type: DataTypes.ENUM('male', 'female', 'mixed'),
    allowNull: false
  },
  // Location details
  address: {
    type: DataTypes.STRING,
    allowNull: false
  },
  city: {
    type: DataTypes.STRING,
    allowNull: false
  },
  latitude: {
    type: DataTypes.DECIMAL(10, 8),
    allowNull: true
  },
  longitude: {
    type: DataTypes.DECIMAL(11, 8),
    allowNull: true
  },
  // Amenities
  amenities: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: []
  },
  // Status and availability
  isAvailable: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  isApproved: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  approvedBy: {
    type: DataTypes.UUID,
    allowNull: true,
    references: {
      model: 'users',
      key: 'id'
    }
  },
  approvedAt: {
    type: DataTypes.DATE,
    allowNull: true
  },
  rejectionReason: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  // Images
  images: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: []
  },
  // Contact info
  contactPhone: {
    type: DataTypes.STRING,
    allowNull: true
  },
  contactEmail: {
    type: DataTypes.STRING,
    allowNull: true
  },
  // Statistics
  viewCount: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  averageRating: {
    type: DataTypes.DECIMAL(3, 2),
    defaultValue: 0.00
  },
  totalReviews: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  }
}, {
  tableName: 'rooms',
  timestamps: true,
  indexes: [
    {
      fields: ['landlordId']
    },
    {
      fields: ['city']
    },
    {
      fields: ['monthlyRent']
    },
    {
      fields: ['genderPreference']
    },
    {
      fields: ['isAvailable', 'isApproved']
    }
  ]
});

module.exports = Room;
