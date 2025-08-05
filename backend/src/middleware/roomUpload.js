const multer = require('multer');

// Configure multer for room image uploads
const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  // Check if file is an image
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Only image files are allowed!'), false);
  }
};

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit per file
    files: 10 // Maximum 10 images per room
  },
  fileFilter: fileFilter
});

// Middleware for room image uploads (multiple files)
const uploadRoomImages = upload.array('images', 10);

module.exports = {
  uploadRoomImages
};
