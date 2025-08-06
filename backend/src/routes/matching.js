const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { authenticate } = require('../middleware/auth');
const matchingController = require('../controllers/matchingController');

// Validation middleware
const validateJoinRoom = [
  body('userAge')
    .optional()
    .isInt({ min: 18, max: 65 })
    .withMessage('Age must be between 18 and 65'),
  body('desiredGroupSize')
    .isInt({ min: 2, max: 3 })
    .withMessage('Group size must be 2 or 3'),
  body('religionPreference')
    .isIn(['any', 'orthodox', 'muslim', 'protestant', 'catholic', 'other_christian', 'other'])
    .withMessage('Invalid religion preference')
];

// Check validation errors
const checkValidation = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }
  next();
};

// Core matching routes
router.post('/join-room/:roomId', authenticate, validateJoinRoom, checkValidation, matchingController.joinRoom);
router.post('/create-group/:roomId', authenticate, validateJoinRoom, checkValidation, matchingController.createGroup);
router.post('/groups/:groupId/join', authenticate, matchingController.joinGroup);
router.delete('/groups/:groupId/leave', authenticate, matchingController.leaveGroup);

// User dashboard routes
router.get('/my-groups', authenticate, matchingController.getMyGroups);

// Notification routes
router.get('/notifications', authenticate, matchingController.getNotifications);
router.put('/notifications/:notificationId/read', authenticate, matchingController.markNotificationRead);

module.exports = router;
