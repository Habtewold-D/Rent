const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const MatchGroup = sequelize.define('MatchGroup', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  roomId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: 'rooms',
      key: 'id'
    }
  },
  creatorId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: 'users',
      key: 'id'
    }
  },
  targetSize: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 2,
      max: 3
    }
  },
  currentSize: {
    type: DataTypes.INTEGER,
    defaultValue: 1
  },
  costPerPerson: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  // Group creator's criteria (inherited by all members)
  creatorAge: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  ageRangeMin: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  ageRangeMax: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  religionPreference: {
    type: DataTypes.ENUM('any', 'orthodox', 'muslim', 'protestant', 'catholic', 'other_christian', 'other'),
    allowNull: false,
    defaultValue: 'any'
  },
  status: {
    type: DataTypes.ENUM('forming', 'complete', 'expired'),
    defaultValue: 'forming'
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
}, {
  tableName: 'match_groups',
  timestamps: true,
  indexes: [
    {
      fields: ['roomId']
    },
    {
      fields: ['status', 'isActive']
    },
    {
      fields: ['creatorId']
    },
    {
      fields: ['religionPreference']
    }
  ]
});

module.exports = MatchGroup;
