const multer = require('multer');

// Configure multer for memory storage (no disk storage)
const storage = multer.memoryStorage();

// File filter for images only
const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Only image files are allowed'), false);
  }
};

// Configure multer
const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit
  }
});

// Middleware for landlord verification documents
const uploadLandlordDocs = upload.fields([
  { name: 'nationalId', maxCount: 1 },
  { name: 'propertyDocument', maxCount: 1 }
]);

module.exports = {
  upload,
  uploadLandlordDocs
};
