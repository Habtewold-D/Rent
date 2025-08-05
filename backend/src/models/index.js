const User = require('./User');
const LandlordRequest = require('./LandlordRequest');

// Define associations
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

module.exports = {
  User,
  LandlordRequest
};
