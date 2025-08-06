const User = require('./User');
const LandlordRequest = require('./LandlordRequest');
const Room = require('./Room');
const RoomImage = require('./RoomImage');
const MatchGroup = require('./MatchGroup');
const GroupMember = require('./GroupMember');
const Notification = require('./Notification');

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

// Room <-> MatchGroup associations
Room.hasMany(MatchGroup, {
  foreignKey: 'roomId',
  as: 'matchGroups'
});

MatchGroup.belongsTo(Room, {
  foreignKey: 'roomId',
  as: 'room'
});

// User <-> MatchGroup associations
User.hasMany(MatchGroup, {
  foreignKey: 'creatorId',
  as: 'createdGroups'
});

MatchGroup.belongsTo(User, {
  foreignKey: 'creatorId',
  as: 'creator'
});

// MatchGroup <-> GroupMember associations
MatchGroup.hasMany(GroupMember, {
  foreignKey: 'groupId',
  as: 'members'
});

GroupMember.belongsTo(MatchGroup, {
  foreignKey: 'groupId',
  as: 'matchGroup'
});

// User <-> GroupMember associations
User.hasMany(GroupMember, {
  foreignKey: 'userId',
  as: 'groupMemberships'
});

GroupMember.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user'
});

// User <-> Notification associations
User.hasMany(Notification, {
  foreignKey: 'userId',
  as: 'notifications'
});

Notification.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user'
});

// Room <-> Notification associations
Room.hasMany(Notification, {
  foreignKey: 'relatedRoomId',
  as: 'notifications'
});

Notification.belongsTo(Room, {
  foreignKey: 'relatedRoomId',
  as: 'relatedRoom'
});

// MatchGroup <-> Notification associations
MatchGroup.hasMany(Notification, {
  foreignKey: 'relatedGroupId',
  as: 'notifications'
});

Notification.belongsTo(MatchGroup, {
  foreignKey: 'relatedGroupId',
  as: 'relatedGroup'
});

module.exports = {
  User,
  LandlordRequest,
  Room,
  RoomImage,
  MatchGroup,
  GroupMember,
  Notification
};
