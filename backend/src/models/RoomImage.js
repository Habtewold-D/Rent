const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const RoomImage = sequelize.define('RoomImage', {
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
  imageUrl: {
    type: DataTypes.STRING,
    allowNull: false
  },
  isPrimary: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  caption: {
    type: DataTypes.STRING,
    allowNull: true
  },
  displayOrder: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  }
}, {
  tableName: 'room_images',
  timestamps: true,
  indexes: [
    {
      fields: ['roomId']
    },
    {
      fields: ['isPrimary']
    }
  ]
});

module.exports = RoomImage;
