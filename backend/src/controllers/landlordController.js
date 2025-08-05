const User = require('../models/User');
const LandlordRequest = require('../models/LandlordRequest');
const { uploadFileBuffer } = require('../config/cloudinary');

/**
 * Request landlord verification
 */
const requestLandlordVerification = async (req, res) => {
  try {
    const userId = req.user.id;

    // Check if files are uploaded
    if (!req.files || !req.files.nationalId || !req.files.propertyDocument) {
      return res.status(400).json({
        success: false,
        message: 'Both National ID and Property Document files are required'
      });
    }

    // Check if user already has a pending request
    const existingRequest = await LandlordRequest.findOne({
      where: { 
        userId,
        status: 'pending'
      }
    });

    if (existingRequest) {
      return res.status(400).json({
        success: false,
        message: 'You already have a pending landlord verification request'
      });
    }

    // Check if user is already a verified landlord
    if (req.user.role === 'landlord' && req.user.isLandlordVerified) {
      return res.status(400).json({
        success: false,
        message: 'You are already a verified landlord'
      });
    }

    // Upload National ID to Cloudinary
    const nationalIdUpload = await uploadFileBuffer(
      req.files.nationalId[0].buffer,
      'rental-platform/national-ids',
      `national-id-${userId}-${Date.now()}`
    );

    if (!nationalIdUpload.success) {
      return res.status(400).json({
        success: false,
        message: 'Failed to upload National ID',
        error: nationalIdUpload.error
      });
    }

    // Upload Property Document to Cloudinary
    const propertyDocUpload = await uploadFileBuffer(
      req.files.propertyDocument[0].buffer,
      'rental-platform/property-docs',
      `property-doc-${userId}-${Date.now()}`
    );

    if (!propertyDocUpload.success) {
      return res.status(400).json({
        success: false,
        message: 'Failed to upload Property Document',
        error: propertyDocUpload.error
      });
    }

    // Create landlord request
    const landlordRequest = await LandlordRequest.create({
      userId,
      nationalIdUrl: nationalIdUpload.url,
      propertyDocumentUrl: propertyDocUpload.url,
      status: 'pending'
    });

    res.status(201).json({
      success: true,
      message: 'Landlord verification request submitted successfully',
      data: {
        request: landlordRequest,
        uploadedUrls: {
          nationalIdUrl: nationalIdUpload.url,
          propertyDocumentUrl: propertyDocUpload.url
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to submit landlord verification request',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Get user's landlord request status
 */
const getMyLandlordRequest = async (req, res) => {
  try {
    const userId = req.user.id;

    const request = await LandlordRequest.findOne({
      where: { userId },
      order: [['createdAt', 'DESC']]
    });

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'No landlord verification request found'
      });
    }

    res.json({
      success: true,
      data: {
        request
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to get landlord request',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

module.exports = {
  requestLandlordVerification,
  getMyLandlordRequest
};
