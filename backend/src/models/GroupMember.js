const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const GroupMember = sequelize.define('GroupMember', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  groupId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: 'match_groups',
      key: 'id'
    }
  },
  userId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: 'users',
      key: 'id'
    }
  },
  status: {
    type: DataTypes.ENUM('active', 'left', 'kicked'),
    defaultValue: 'active'
  },
  joinedAt: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  isCreator: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  isReplacementMember: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  }
}, {
  tableName: 'group_members',
  timestamps: true,
  indexes: [
    {
      fields: ['groupId']
    },
    {
      fields: ['userId']
    },
    {
      fields: ['status']
    }
  ]
});

module.exports = GroupMember;
