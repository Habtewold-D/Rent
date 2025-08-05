const cloudinary = require('cloudinary').v2;
require('dotenv').config();

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

/**
 * Upload file buffer to Cloudinary
 * @param {Buffer} fileBuffer - File buffer from multer
 * @param {String} folder - Cloudinary folder name
 * @param {String} publicId - Optional public ID
 * @returns {Object} Upload result
 */
const uploadFileBuffer = async (fileBuffer, folder = 'rental-platform', publicId = null) => {
  try {
    return new Promise((resolve, reject) => {
      const uploadOptions = {
        folder: folder,
        resource_type: 'auto',
        quality: 'auto:good',
        format: 'jpg'
      };

      if (publicId) {
        uploadOptions.public_id = publicId;
      }

      cloudinary.uploader.upload_stream(
        uploadOptions,
        (error, result) => {
          if (error) {
            resolve({
              success: false,
              error: error.message
            });
          } else {
            resolve({
              success: true,
              url: result.secure_url,
              publicId: result.public_id
            });
          }
        }
      ).end(fileBuffer);
    });
  } catch (error) {
    return {
      success: false,
      error: error.message
    };
  }
};

/**
 * Delete image from Cloudinary
 * @param {String} publicId - Cloudinary public ID
 * @returns {Object} Delete result
 */
const deleteImage = async (publicId) => {
  try {
    const result = await cloudinary.uploader.destroy(publicId);
    return {
      success: true,
      result
    };
  } catch (error) {
    return {
      success: false,
      error: error.message
    };
  }
};

module.exports = {
  cloudinary,
  uploadFileBuffer,
  deleteImage
};
