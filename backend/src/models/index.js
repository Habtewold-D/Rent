const User = require('./User');
const LandlordRequest = require('./LandlordRequest');
const Room = require('./Room');
const RoomImage = require('./RoomImage');

// User <-> LandlordRequest associations
User.hasMany(LandlordRequest, { 
  foreignKey: 'userId', 
  as: 'landlordRequests' 
});

User.hasMany(LandlordRequest, { 
  foreignKey: 'reviewedBy', 
  as: 'reviewedRequests' 
});

LandlordRequest.belongsTo(User, { 
  foreignKey: 'userId', 
  as: 'user' 
});

LandlordRequest.belongsTo(User, { 
  foreignKey: 'reviewedBy', 
  as: 'reviewer' 
});

// User <-> Room associations
User.hasMany(Room, { 
  foreignKey: 'landlordId', 
  as: 'rooms' 
});

User.hasMany(Room, { 
  foreignKey: 'approvedBy', 
  as: 'approvedRooms' 
});

Room.belongsTo(User, { 
  foreignKey: 'landlordId', 
  as: 'landlord' 
});

Room.belongsTo(User, { 
  foreignKey: 'approvedBy', 
  as: 'approver' 
});

// Room <-> RoomImage associations
Room.hasMany(RoomImage, { 
  foreignKey: 'roomId', 
  as: 'roomImages' 
});

RoomImage.belongsTo(Room, { 
  foreignKey: 'roomId', 
  as: 'room' 
});

module.exports = {
  User,
  LandlordRequest,
  Room,
  RoomImage
};
