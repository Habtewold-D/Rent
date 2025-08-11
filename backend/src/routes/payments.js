const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const paymentsController = require('../controllers/paymentsController');

// Create Chapa checkout (authenticated)
router.post('/chapa/checkout', authenticate, paymentsController.createChapaCheckout);

// Mark paid (authenticated) — used when client detects success return immediately
router.post('/chapa/mark-paid', authenticate, paymentsController.markPaid);

// Return page (GET) — used by Chapa redirect; shows a minimal page
router.get('/chapa/return', (req, res) => {
  const tx = req.query.tx_ref || '';
  res.set('Content-Type', 'text/html');
  res.send(`<!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Payment Completed</title>
    <style>body{font-family:system-ui,Segoe UI,Roboto,Helvetica,Arial,sans-serif;padding:24px;line-height:1.5} .ok{color:#0a7}
    </style>
    <script>try{ if(window && window.history){ window.history.replaceState({}, '', '/payments/chapa/return'); } }catch(e){}</script>
  </head>
  <body>
    <h2 class="ok">Payment Completed</h2>
    <p>Transaction: ${tx}</p>
    <p>You can now close this page.</p>
  </body>
  </html>`);
});

// Webhook (no auth; Chapa calls this)
router.post('/chapa/webhook', express.json({ type: '*/*' }), paymentsController.chapaWebhook);

module.exports = router;
