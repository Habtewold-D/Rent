const multer = require('multer');

// Configure multer for memory storage (no disk storage)
const storage = multer.memoryStorage();

// File filter: images for nationalId; images or PDFs for propertyDocument
const fileFilter = (req, file, cb) => {
  const field = file.fieldname;
  const isImage = file.mimetype && file.mimetype.startsWith('image/');
  const isPdf = file.mimetype === 'application/pdf';

  if (field === 'nationalId') {
    // National ID must be an image
    if (isImage) return cb(null, true);
    return cb(new Error('National ID must be an image file'), false);
  }

  if (field === 'propertyDocument') {
    // Property document can be image or PDF
    if (isImage || isPdf) return cb(null, true);
    return cb(new Error('Property document must be an image or PDF'), false);
  }

  // Default: allow images only for any other fields
  if (isImage) return cb(null, true);
  return cb(new Error('Unsupported file type'), false);
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
