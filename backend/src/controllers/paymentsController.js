const fetch = global.fetch;
const { Op } = require('sequelize');
const User = require('../models/User');
const MatchGroup = require('../models/MatchGroup');
const GroupMember = require('../models/GroupMember');

const CHAPA_SECRET_KEY = process.env.CHAPA_SECRET_KEY;
const BASE_URL = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;

if (!CHAPA_SECRET_KEY) {
  console.warn('[payments] CHAPA_SECRET_KEY is not set. Chapa checkout will fail until configured.');
}

const paymentsController = {};

// Create a Chapa checkout session and return checkout_url
paymentsController.createChapaCheckout = async (req, res) => {
  try {
    const { groupId, roomId } = req.body || {};
    const userId = req.user.id;
    console.log(`[payments] createChapaCheckout hit`, { userId, groupId, roomId });
    if (!groupId) return res.status(400).json({ success: false, message: 'groupId is required' });

    let group = await MatchGroup.findByPk(groupId);
    if (!group) {
      // Fallback for string/UUID PKs
      group = await MatchGroup.findOne({ where: { id: groupId } });
    }
    if (!group) return res.status(404).json({ success: false, message: 'Group not found' });

    let member = await GroupMember.findOne({ where: { groupId, userId, status: 'active' } });
    if (!member) {
      // Allow the group creator/owner to proceed; upsert an active membership for them
      const isOwner = (
        (group.userId && String(group.userId) === String(userId)) ||
        (group.createdBy && String(group.createdBy) === String(userId)) ||
        (group.ownerId && String(group.ownerId) === String(userId))
      );
      if (isOwner) {
        const existingAny = await GroupMember.findOne({ where: { groupId, userId } });
        if (existingAny) {
          await existingAny.update({ status: 'active', role: existingAny.role || 'owner' });
          member = existingAny;
        } else {
          member = await GroupMember.create({ groupId, userId, status: 'active', role: 'owner' });
        }
      } else {
        return res.status(403).json({ success: false, message: 'You are not a member of this group' });
      }
    }

    const user = await User.findByPk(userId);
    const amount = group.costPerPerson;
    if (!amount || amount <= 0) return res.status(400).json({ success: false, message: 'Invalid amount' });

    const rawFirst = (user.firstName || 'User').toString();
    const rawLast = (user.lastName || '').toString();
    const sanitizeName = (s) => s.replace(/[^a-zA-Z\s'-]/g, '').trim().slice(0, 30) || 'User';
    const firstName = sanitizeName(rawFirst);
    const lastName = sanitizeName(rawLast);
    // Sanitize email for Chapa
    const toShort = (v) => `${v}`.replace(/[^a-zA-Z0-9]/g, '').slice(0, 8);
    const isValidEmail = (e) => /^(?=.{3,128}$)[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e || '');
    let email = (user.email || '').toString().trim().toLowerCase();
    if (!isValidEmail(email)) {
      email = 'payer@rent.com';
    } else {
      // Enforce a common domain if the TLD is suspicious (e.g., too short/uncommon)
      const domain = email.split('@')[1] || '';
      const tld = (domain.split('.').pop() || '').toLowerCase();
      const allowedDomains = new Set(['gmail.com','yahoo.com','outlook.com','hotmail.com','icloud.com','proton.me','rent.com']);
      if (!allowedDomains.has(domain) || tld.length < 3) {
        email = 'payer@rent.com';
      }
    }

    // Build a short, Chapa-compliant tx_ref (alphanumeric and '-')
    const txRef = `grp${toShort(groupId)}-usr${toShort(userId)}-${Date.now()}`.slice(0, 64);
    console.log('[payments] tx_ref =>', txRef);

    const body = {
      amount: String(amount),
      currency: 'ETB',
      email,
      first_name: firstName,
      last_name: lastName,
      tx_ref: txRef,
      // After user finishes, Chapa redirects here
      return_url: `${BASE_URL}/payments/chapa/return?tx_ref=${encodeURIComponent(txRef)}`,
      // Server-side notification
      callback_url: `${BASE_URL}/api/payments/chapa/webhook`
    };
    console.log('[payments] initialize payload', {
      amount: body.amount,
      currency: body.currency,
      email: body.email,
      first_name: body.first_name,
      last_name: body.last_name,
      tx_ref: body.tx_ref,
      return_url: body.return_url,
      callback_url: body.callback_url,
    });

    const resp = await fetch('https://api.chapa.co/v1/transaction/initialize', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${CHAPA_SECRET_KEY}`
      },
      body: JSON.stringify(body)
    });

    const data = await resp.json();
    if (!resp.ok || !data || !data.status || data.status !== 'success') {
      const detail = data && data.message ? data.message : undefined;
      console.warn('[payments] Initialize failed', { status: resp.status, data, detail });
      return res.status(502).json({ success: false, message: 'Failed to initialize payment', status: resp.status, error: data });
    }

    const checkoutUrl = data.data && data.data.checkout_url ? data.data.checkout_url : null;
    if (!checkoutUrl) return res.status(502).json({ success: false, message: 'No checkout_url returned' });

    // Optionally store tx_ref on member (if you have a field). We'll keep only paymentStatus pending.
    await member.update({ paymentStatus: 'pending' });

    return res.json({ success: true, data: { checkout_url: checkoutUrl, tx_ref: txRef } });
  } catch (error) {
    console.error('[payments] Error creating Chapa checkout:', error);
    return res.status(500).json({ success: false, message: 'Failed to create checkout', error: error.message });
  }
};

// Webhook from Chapa
paymentsController.chapaWebhook = async (req, res) => {
  try {
    const payload = req.body || {};
    // Chapa usually sends tx_ref; verify with Chapa verify endpoint
    const txRef = payload.tx_ref || (payload.data && payload.data.tx_ref);
    if (!txRef) {
      return res.status(400).json({ success: false, message: 'tx_ref missing' });
    }

    // Verify with Chapa
    const verifyResp = await fetch(`https://api.chapa.co/v1/transaction/verify/${encodeURIComponent(txRef)}`, {
      headers: { 'Authorization': `Bearer ${CHAPA_SECRET_KEY}` }
    });
    const verifyData = await verifyResp.json();
    if (!verifyResp.ok || !verifyData || verifyData.status !== 'success') {
      console.warn('Chapa verify failed:', verifyData);
      return res.status(400).json({ success: false, message: 'Verification failed' });
    }

    const status = verifyData.data && verifyData.data.status; // should be 'success'
    if (status !== 'success') {
      return res.status(200).json({ success: true }); // acknowledge non-success without changes
    }

    // Parse tx_ref to get groupId and userId
    const match = txRef.match(/^grp(\d+)-usr(\d+)-/);
    if (!match) return res.status(200).json({ success: true });
    const groupId = parseInt(match[1], 10);
    const userId = parseInt(match[2], 10);

    const member = await GroupMember.findOne({ where: { groupId, userId } });
    if (!member) return res.status(200).json({ success: true });

    await member.update({ paymentStatus: 'paid', paymentDueAt: null });

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error handling Chapa webhook:', error);
    return res.status(500).json({ success: false });
  }
};

// Mark paid from client after a confirmed success return (defensive in case webhook is delayed)
paymentsController.markPaid = async (req, res) => {
  try {
    const userId = req.user.id;
    const { groupId } = req.body || {};
    if (!groupId) return res.status(400).json({ success: false, message: 'groupId is required' });
    const member = await GroupMember.findOne({ where: { groupId, userId } });
    if (!member) return res.status(404).json({ success: false, message: 'Membership not found' });
    await member.update({ paymentStatus: 'paid', paymentDueAt: null });
    return res.json({ success: true });
  } catch (error) {
    console.error('[payments] markPaid error:', error);
    return res.status(500).json({ success: false, message: 'Failed to mark paid' });
  }
};

module.exports = paymentsController;
