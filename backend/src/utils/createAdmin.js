const User = require('../models/User');
require('dotenv').config();

const createAdminUser = async () => {
  try {
    // Check if admin already exists
    const existingAdmin = await User.findOne({ 
      where: { email: 'admin@rental.com' } 
    });

    if (existingAdmin) {
      console.log('Admin user already exists');
      return;
    }

    // Create admin user
    const admin = await User.create({
      email: 'admin@rental.com',
      password: 'Admin123',
      firstName: 'Admin',
      lastName: 'User',
      phone: '+251911111111',
      gender: 'male',
      role: 'admin',
      isVerified: true,
      isActive: true
    });

    console.log('✅ Admin user created successfully');
    console.log('Email: admin@rental.com');
    console.log('Password: Admin123');
  } catch (error) {
    console.error('❌ Error creating admin user:', error.message);
  }
};

module.exports = createAdminUser;
