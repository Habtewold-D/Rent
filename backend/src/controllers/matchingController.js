const { Op } = require('sequelize');
const User = require('../models/User');
const Room = require('../models/Room');
const MatchGroup = require('../models/MatchGroup');
const GroupMember = require('../models/GroupMember');
const Notification = require('../models/Notification');
const sequelize = require('../config/database');

const matchingController = {};

// Join room - get filtered groups and create if needed
matchingController.joinRoom = async (req, res) => {
  try {
    const { roomId } = req.params;
    const { userAge, desiredGroupSize, religionPreference, genderPreference } = req.body;
    const userId = req.user.id;

    // Get room details
    const room = await Room.findByPk(roomId);
    if (!room) {
      return res.status(404).json({
        success: false,
        message: 'Room not found'
      });
    }

    // Get user details
    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Check room gender compatibility
    if (room.genderPreference !== 'mixed' && user.gender !== room.genderPreference) {
      return res.status(400).json({
        success: false,
        message: `This room is for ${room.genderPreference} only`
      });
    }

    // Update user age if provided and not in profile
    const finalAge = user.age || userAge;
    if (!user.age && userAge) {
      await user.update({ age: userAge });
    }

    if (!finalAge) {
      return res.status(400).json({
        success: false,
        message: 'Age is required for roommate matching'
      });
    }

    // Calculate age range
    const ageRangeMin = finalAge - 5;
    const ageRangeMax = finalAge + 5;

    // Get all active groups for this room
    const allGroups = await MatchGroup.findAll({
      where: {
        roomId,
        status: 'forming',
        isActive: true,
        currentSize: { [Op.lt]: sequelize.col('targetSize') }
      },
      include: [
        {
          model: GroupMember,
          as: 'members',
          include: [
            {
              model: User,
              as: 'user',
              attributes: ['id', 'firstName', 'age', 'religion', 'gender']
            }
          ]
        },
        {
          model: Room,
          as: 'room',
          attributes: ['monthlyRent', 'genderPreference']
        }
      ]
    });

    // Filter compatible groups (exact size match)
    const compatibleGroups = allGroups.filter(group => {
      // Check if user already in this group
      const isAlreadyMember = group.members.some(member => member.userId === userId);
      if (isAlreadyMember) return false;

      // Check group size compatibility (exact matches only here)
      if (group.targetSize !== desiredGroupSize) return false;

      // Check age compatibility with group creator's range
      if (finalAge < group.ageRangeMin || finalAge > group.ageRangeMax) return false;

      // Check religion compatibility
      if (group.religionPreference !== 'any' && religionPreference !== 'any') {
        if (group.religionPreference !== religionPreference) return false;
      }

      // Optional gender preference: if provided by requester, only show groups in rooms that are compatible
      // Room genderPreference: 'male' | 'female' | 'mixed'
      if (genderPreference && genderPreference !== 'any' && genderPreference !== 'mixed') {
        if (group.room && group.room.genderPreference) {
          const roomPref = group.room.genderPreference;
          if (!(roomPref === 'mixed' || roomPref === genderPreference)) return false;
        }
      }

      return true;
    });

    // Also find near-size groups (difference of 1) that otherwise match
    const nearSizeGroups = allGroups.filter(group => {
      const isAlreadyMember = group.members.some(member => member.userId === userId);
      if (isAlreadyMember) return false;
      if (Math.abs(group.targetSize - desiredGroupSize) !== 1) return false;
      if (finalAge < group.ageRangeMin || finalAge > group.ageRangeMax) return false;
      if (group.religionPreference !== 'any' && religionPreference !== 'any') {
        if (group.religionPreference !== religionPreference) return false;
      }
      if (genderPreference && genderPreference !== 'any' && genderPreference !== 'mixed') {
        if (group.room && group.room.genderPreference) {
          const roomPref = group.room.genderPreference;
          if (!(roomPref === 'mixed' || roomPref === genderPreference)) return false;
        }
      }
      return true;
    });

    // Separate recommended vs other groups
    let recommendedGroups = compatibleGroups.filter(group => {
      // Prioritize groups matching religion preference
      if (religionPreference !== 'any' && group.religionPreference === religionPreference) {
        return true;
      }
      return false;
    });

    // If none matched strictly by religion, use all compatible groups as recommended
    if (recommendedGroups.length === 0) {
      if (compatibleGroups.length > 0) {
        recommendedGroups = [...compatibleGroups];
      } else if (nearSizeGroups.length > 0) {
        // Promote near-size groups to recommended when no exact-size compatible groups exist
        recommendedGroups = [...nearSizeGroups];
      }
    }

    const otherGroups = [
      // any compatible not already recommended
      ...compatibleGroups.filter(group => !recommendedGroups.includes(group)),
      // any near-size not already recommended
      ...nearSizeGroups.filter(group => !recommendedGroups.includes(group))
    ];

    // Format response
    const formatGroup = (group) => ({
      id: group.id,
      currentSize: group.currentSize,
      targetSize: group.targetSize,
      costPerPerson: group.costPerPerson,
      ageRange: `${group.ageRangeMin}-${group.ageRangeMax}`,
      religionPreference: group.religionPreference,
      members: group.members.map(member => ({
        firstName: member.user.firstName,
        age: member.user.age,
        religion: member.user.religion,
        isCreator: member.isCreator
      })),
      spotsLeft: group.targetSize - group.currentSize
    });

    res.json({
      success: true,
      data: {
        room: {
          id: room.id,
          title: room.title,
          monthlyRent: room.monthlyRent,
          genderPreference: room.genderPreference
        },
        userCriteria: {
          age: finalAge,
          ageRange: `${ageRangeMin}-${ageRangeMax}`,
          religion: religionPreference,
          desiredGroupSize
        },
        recommendedGroups: recommendedGroups.map(formatGroup),
        otherGroups: otherGroups.map(formatGroup),
        canCreateNew: true,
        costPerPersonIfNewGroup: Math.round(room.monthlyRent / desiredGroupSize)
      }
    });

  } catch (error) {
    console.error('Error in joinRoom:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
};

// Create new group
matchingController.createGroup = async (req, res) => {
  try {
    const { roomId } = req.params;
    const { userAge, desiredGroupSize, religionPreference } = req.body;
    const userId = req.user.id;

    // Get room and user
    const room = await Room.findByPk(roomId);
    const user = await User.findByPk(userId);

    if (!room || !user) {
      return res.status(404).json({
        success: false,
        message: 'Room or user not found'
      });
    }

    // Update user age if provided
    const finalAge = user.age || userAge;
    if (!user.age && userAge) {
      await user.update({ age: userAge });
    }

    // Calculate cost per person
    const costPerPerson = Math.round(room.monthlyRent / desiredGroupSize);

    // Create new group
    const newGroup = await MatchGroup.create({
      roomId,
      creatorId: userId,
      targetSize: desiredGroupSize,
      currentSize: 1,
      costPerPerson,
      creatorAge: finalAge,
      ageRangeMin: finalAge - 5,
      ageRangeMax: finalAge + 5,
      religionPreference: religionPreference || 'any'
    });

    // Add creator as first member
    await GroupMember.create({
      groupId: newGroup.id,
      userId,
      isCreator: true
    });

    // Find and notify compatible users
    await notifyCompatibleUsers(newGroup.id, roomId);

    res.json({
      success: true,
      message: 'Group created successfully! We\'ll notify compatible users.',
      data: {
        groupId: newGroup.id,
        costPerPerson,
        spotsLeft: desiredGroupSize - 1
      }
    });

  } catch (error) {
    console.error('Error creating group:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create group',
      error: error.message
    });
  }
};

// Join existing group
matchingController.joinGroup = async (req, res) => {
  try {
    const { groupId } = req.params;
    const userId = req.user.id;
    const { userAge, religionPreference } = req.body || {};

    // Get group with members
    const group = await MatchGroup.findByPk(groupId, {
      include: [
        {
          model: GroupMember,
          as: 'members',
          include: [
            {
              model: User,
              as: 'user',
              attributes: ['firstName', 'age', 'religion']
            }
          ]
        },
        {
          model: Room,
          as: 'room',
          attributes: ['id', 'monthlyRent', 'genderPreference', 'address', 'city']
        }
      ]
    });

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Group not found'
      });
    }

    // Check if group is full
    if (group.currentSize >= group.targetSize) {
      return res.status(400).json({
        success: false,
        message: 'Group is already full'
      });
    }

    // Check if user already in group
    const isAlreadyMember = (group.members || []).some(member => member.userId === userId);
    if (isAlreadyMember) {
      return res.status(400).json({
        success: false,
        message: 'You are already in this group'
      });
    }

    // Get user details for compatibility check
    const user = await User.findByPk(userId);
    const finalAge = user.age || userAge;
    if (!finalAge) {
      return res.status(400).json({ success: false, message: 'Age is required to join a group' });
    }

    // Check compatibility
    if (finalAge < group.ageRangeMin || finalAge > group.ageRangeMax) {
      return res.status(400).json({
        success: false,
        message: 'Age not compatible with group requirements'
      });
    }

    const userReligion = user.religion || religionPreference || 'any';
    if (
      group.religionPreference !== 'any' &&
      userReligion !== 'any' &&
      userReligion !== group.religionPreference
    ) {
      return res.status(400).json({
        success: false,
        message: 'Religion preference not compatible with group'
      });
    }

    // Add user to group
    await GroupMember.create({
      groupId,
      userId
    });

    // Update group size
    const newSize = group.currentSize + 1;
    await group.update({ 
      currentSize: newSize,
      status: newSize >= group.targetSize ? 'complete' : 'forming'
    });

    // Notify all group members
    await notifyGroupMembers(groupId, 'member_joined', {
      newMemberName: user.firstName,
      currentSize: newSize,
      targetSize: group.targetSize
    });

    // If group is now complete, send completion notifications with payment info
    if (newSize >= group.targetSize) {
      await notifyGroupMembers(groupId, 'group_complete', {
        costPerPerson: group.costPerPerson,
        payRequired: true,
        payLabel: 'Pay now',
        // Frontend can construct a deep link or route; include placeholders
        payUrl: `/payments/rooms/${group.roomId}/groups/${group.id}`
      });
    }

    res.json({
      success: true,
      message: 'Successfully joined group!',
      data: {
        groupId,
        currentSize: newSize,
        targetSize: group.targetSize,
        costPerPerson: group.costPerPerson,
        isComplete: newSize >= group.targetSize
      }
    });

  } catch (error) {
    console.error('Error joining group:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to join group',
      error: error.message
    });
  }
};

// Get user's active groups
matchingController.getMyGroups = async (req, res) => {
  try {
    const userId = req.user.id;

    const userGroups = await GroupMember.findAll({
      where: {
        userId,
        status: 'active'
      },
      include: [
        {
          model: MatchGroup,
          as: 'matchGroup',
          include: [
            {
              model: Room,
              as: 'room',
              attributes: ['id', 'address', 'city', 'monthlyRent']
            },
            {
              model: GroupMember,
              as: 'members',
              include: [
                {
                  model: User,
                  as: 'user',
                  attributes: ['id', 'firstName', 'age', 'religion']
                }
              ]
            }
          ]
        }
      ]
    });

    const formattedGroups = userGroups
      .map(membership => {
        const group = membership.matchGroup; // correct alias per models/index.js
        if (!group) return null;
        return {
          groupId: group.id,
          room: group.room || null,
          currentSize: group.currentSize,
          targetSize: group.targetSize,
          costPerPerson: group.costPerPerson,
          status: group.status,
          isCreator: membership.isCreator,
          religionPreference: group.religionPreference,
          ageRange: `${group.ageRangeMin}-${group.ageRangeMax}`,
          members: (group.members || []).map(member => ({
            firstName: member.user?.firstName,
            age: member.user?.age,
            religion: member.user?.religion,
            isCreator: member.isCreator
          })),
          spotsLeft: group.targetSize - group.currentSize
        };
      })
      .filter(Boolean);

    res.json({
      success: true,
      data: formattedGroups
    });

  } catch (error) {
    console.error('Error getting user groups:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get groups',
      error: error.message
    });
  }
};

// Leave group
matchingController.leaveGroup = async (req, res) => {
  try {
    const { groupId } = req.params;
    const userId = req.user.id;

    // Find group membership
    const membership = await GroupMember.findOne({
      where: {
        groupId,
        userId,
        status: 'active'
      },
      include: [
        {
          model: MatchGroup,
          as: 'matchGroup'
        }
      ]
    });

    if (!membership) {
      return res.status(404).json({
        success: false,
        message: 'Group membership not found'
      });
    }

    const group = membership.matchGroup;
    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Group not found'
      });
    }

    // Update membership status
    await membership.update({ status: 'left' });

    // Update group size
    const newSize = group.currentSize - 1;
    await group.update({ 
      currentSize: newSize,
      status: newSize === 0 ? 'expired' : 'forming'
    });

    // If group becomes empty, deactivate it
    if (newSize === 0) {
      await group.update({ isActive: false });
    } else {
      // Notify remaining members
      await notifyGroupMembers(groupId, 'member_left', {
        leftMemberName: req.user.firstName,
        currentSize: newSize,
        targetSize: group.targetSize
      });
    }

    res.json({
      success: true,
      message: 'Successfully left group'
    });

  } catch (error) {
    console.error('Error leaving group:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to leave group',
      error: error.message
    });
  }
};

// Helper function to notify compatible users about new group
const notifyCompatibleUsers = async (groupId, roomId) => {
  try {
    const group = await MatchGroup.findByPk(groupId, {
      include: [
        {
          model: Room,
          as: 'room',
          attributes: ['id', 'address', 'city', 'monthlyRent', 'genderPreference']
        }
      ]
    });

    // Find compatible users
    const compatibleUsers = await User.findAll({
      where: {
        age: {
          [Op.between]: [group.ageRangeMin, group.ageRangeMax]
        },
        gender: group.room.genderPreference === 'mixed' ? 
          { [Op.in]: ['male', 'female'] } : 
          group.room.genderPreference,
        religion: group.religionPreference === 'any' ? 
          { [Op.ne]: null } : 
          group.religionPreference,
        id: { [Op.ne]: group.creatorId } // Exclude group creator
      }
    });

    // Create notifications for compatible users
    const notifications = compatibleUsers.map(user => ({
      userId: user.id,
      type: 'group_found',
      title: 'Compatible Group Found!',
      message: `A roommate group near ${group.room.address || group.room.city} is looking for members. Join now!`,
      relatedGroupId: groupId,
      relatedRoomId: roomId,
      data: {
        costPerPerson: group.costPerPerson,
        spotsLeft: group.targetSize - group.currentSize
      }
    }));

    await Notification.bulkCreate(notifications);

  } catch (error) {
    console.error('Error notifying compatible users:', error);
  }
};

// Helper function to notify group members
const notifyGroupMembers = async (groupId, type, data) => {
  try {
    const groupMembers = await GroupMember.findAll({
      where: {
        groupId,
        status: 'active'
      }
    });

    let title, message;
    
    switch (type) {
      case 'member_joined':
        title = 'New Member Joined!';
        message = `${data.newMemberName} joined your group. ${data.currentSize}/${data.targetSize} members.`;
        break;
      case 'member_left':
        title = 'Member Left Group';
        message = `${data.leftMemberName} left the group. ${data.currentSize}/${data.targetSize} members.`;
        break;
      case 'group_complete':
        title = 'Group Complete!';
        message = 'Your group is now full and ready for booking!';
        break;
      default:
        return;
    }

    const notifications = groupMembers.map(member => ({
      userId: member.userId,
      type,
      title,
      message,
      relatedGroupId: groupId,
      data
    }));

    await Notification.bulkCreate(notifications);

  } catch (error) {
    console.error('Error notifying group members:', error);
  }
};

// Get notifications for user
matchingController.getNotifications = async (req, res) => {
  try {
    const userId = req.user.id;
    const { limit = 20, offset = 0 } = req.query;

    const notifications = await Notification.findAndCountAll({
      where: { userId },
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset: parseInt(offset),
      include: [
        {
          model: Room,
          as: 'relatedRoom',
          attributes: ['id', 'address', 'city'],
          required: false
        }
      ]
    });

    res.json({
      success: true,
      data: {
        notifications: notifications.rows,
        total: notifications.count,
        unreadCount: await Notification.count({
          where: {
            userId,
            isRead: false
          }
        })
      }
    });

  } catch (error) {
    console.error('Error getting notifications:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get notifications',
      error: error.message
    });
  }
};

// Mark notification as read
matchingController.markNotificationRead = async (req, res) => {
  try {
    const { notificationId } = req.params;
    const userId = req.user.id;

    const notification = await Notification.findOne({
      where: {
        id: notificationId,
        userId
      }
    });

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found'
      });
    }

    await notification.update({ isRead: true });

    res.json({
      success: true,
      message: 'Notification marked as read'
    });

  } catch (error) {
    console.error('Error marking notification read:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to mark notification as read',
      error: error.message
    });
  }
};

module.exports = matchingController;