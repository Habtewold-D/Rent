const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
require('dotenv').config();

const sequelize = require('./config/database');
const authRoutes = require('./routes/auth');
const landlordRoutes = require('./routes/landlord');
const adminRoutes = require('./routes/admin');
const roomRoutes = require('./routes/rooms');
const matchingRoutes = require('./routes/matching');
const paymentsRoutes = require('./routes/payments');
const createAdminUser = require('./utils/createAdmin');

// Import models to establish associations
require('./models/index');

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors());

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/landlord', landlordRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/rooms', roomRoutes);
app.use('/api/matching', matchingRoutes);
app.use('/api/payments', paymentsRoutes);

// Public return page for Chapa (non-API path)
app.get('/payments/chapa/return', (req, res) => {
  const tx = req.query.tx_ref || '';
  res.set('Content-Type', 'text/html');
  res.send(`<!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Payment Completed</title>
    <style>body{font-family:system-ui,Segoe UI,Roboto,Helvetica,Arial,sans-serif;padding:24px;line-height:1.5} .ok{color:#0a7}</style>
  </head>
  <body>
    <h2 class="ok">Payment Completed</h2>
    <p>Transaction: ${tx}</p>
    <p>You can now return to the app.</p>
  </body>
  </html>`);
});

// Health check route
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    message: 'Rental Platform API is running',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found'
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Something went wrong!',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// Database connection and server start
const startServer = async () => {
  try {
    // Test database connection
    await sequelize.authenticate();
    console.log('✅ Database connection established successfully.');
    
    // Sync database models in correct order (User first, then dependent models)
    const { User, LandlordRequest, Room, RoomImage, MatchGroup, GroupMember, Notification } = require('./models');

    // Use non-destructive sync. `alter: true` updates schema without dropping tables.
    const syncOptions = { alter: true };
    await User.sync(syncOptions);
    await LandlordRequest.sync(syncOptions);
    await Room.sync(syncOptions);
    await RoomImage.sync(syncOptions);
    await MatchGroup.sync(syncOptions);
    await GroupMember.sync(syncOptions);
    await Notification.sync(syncOptions);
    
    console.log('✅ Database models synchronized.');
    
    // Create admin user if not exists
    await createAdminUser();
    
    // Start server
    app.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      });
  } catch (error) {
    console.error('❌ Unable to start server:', error);
    process.exit(1);
  }
};

startServer();

module.exports = app;
