const { body, validationResult } = require('express-validator');

/**
 * Handle validation errors
 */
const handleValidationErrors = (req, res, next) => {
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

/**
 * Validation rules for user registration
 */
const validateRegister = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email'),
  
  body('password')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters long')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Password must contain at least one uppercase letter, one lowercase letter, and one number'),
  
  body('firstName')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('First name must be between 2 and 50 characters'),
  
  body('lastName')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Last name must be between 2 and 50 characters'),
  
  body('phone')
    .matches(/^(\+251|0)[79]\d{8}$/)
    .withMessage('Please provide a valid Ethiopian phone number'),
  
  body('gender')
    .isIn(['male', 'female'])
    .withMessage('Gender must be either male or female'),
  
  body('age')
    .optional()
    .isInt({ min: 18, max: 65 })
    .withMessage('Age must be between 18 and 65'),
  
  body('profession')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Profession must not exceed 100 characters'),
  
  body('religion')
    .optional()
    .isIn(['orthodox', 'muslim', 'protestant', 'catholic', 'other', 'prefer_not_to_say'])
    .withMessage('Invalid religion option'),
  
  handleValidationErrors
];

/**
 * Validation rules for user login
 */
const validateLogin = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email'),
  
  body('password')
    .notEmpty()
    .withMessage('Password is required'),
  
  handleValidationErrors
];

/**
 * Validation rules for password update
 */
const validatePasswordUpdate = [
  body('currentPassword')
    .notEmpty()
    .withMessage('Current password is required'),
  
  body('newPassword')
    .isLength({ min: 6 })
    .withMessage('New password must be at least 6 characters long')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('New password must contain at least one uppercase letter, one lowercase letter, and one number'),
  
  handleValidationErrors
];

module.exports = {
  validateRegister,
  validateLogin,
  validatePasswordUpdate,
  handleValidationErrors
};
