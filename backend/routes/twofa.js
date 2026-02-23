const express = require('express');
const router = express.Router();
const { getPool } = require('../config/database');
const speakeasy = require('speakeasy');
const QRCode = require('qrcode');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'abrazouver-2fa-secret-change-in-production';

router.post('/setup/:userId', async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (isNaN(userId)) return res.status(400).json({ message: 'ID invalide' });

    const pool = await getPool();
    const [rows] = await pool.query(
      'SELECT id, email FROM users WHERE id = ?',
      [userId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }

    const secret = speakeasy.generateSecret({
      name: `Abrazouver (${rows[0].email})`,
      issuer: 'Abrazouver',
      length: 32,
    });

    await pool.query(
      'UPDATE users SET two_factor_secret = ?, two_factor_enabled = 0 WHERE id = ?',
      [secret.base32, userId]
    );

    const otpauthUrl = speakeasy.otpauthURL({
      secret: secret.base32,
      label: rows[0].email,
      issuer: 'Abrazouver',
      encoding: 'base32',
    });

    const qrCodeDataUrl = await QRCode.toDataURL(otpauthUrl, {
      width: 256,
      margin: 2,
      color: { dark: '#000000', light: '#ffffff' },
    });

    res.json({
      secret: secret.base32,
      qrCodeDataUrl,
      manualEntryKey: secret.base32,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post('/confirm/:userId', async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    const { code } = req.body;
    if (isNaN(userId) || !code || code.length !== 6) {
      return res.status(400).json({ message: 'Code à 6 chiffres requis' });
    }

    const pool = await getPool();
    const [rows] = await pool.query(
      'SELECT two_factor_secret FROM users WHERE id = ?',
      [userId]
    );
    if (rows.length === 0 || !rows[0].two_factor_secret) {
      return res.status(400).json({ message: 'Configurez d\'abord la 2FA' });
    }

    const valid = speakeasy.totp.verify({
      secret: rows[0].two_factor_secret,
      encoding: 'base32',
      token: code.trim(),
      window: 1,
    });

    if (!valid) {
      return res.status(401).json({ message: 'Code invalide ou expiré' });
    }

    await pool.query(
      'UPDATE users SET two_factor_enabled = 1 WHERE id = ?',
      [userId]
    );

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post('/disable/:userId', async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    const { code } = req.body;
    if (isNaN(userId) || !code || code.length !== 6) {
      return res.status(400).json({ message: 'Code à 6 chiffres requis' });
    }

    const pool = await getPool();
    const [rows] = await pool.query(
      'SELECT two_factor_secret FROM users WHERE id = ?',
      [userId]
    );
    if (rows.length === 0 || !rows[0].two_factor_secret) {
      return res.status(400).json({ message: '2FA non configurée' });
    }

    const valid = speakeasy.totp.verify({
      secret: rows[0].two_factor_secret,
      encoding: 'base32',
      token: code.trim(),
      window: 1,
    });

    if (!valid) {
      return res.status(401).json({ message: 'Code invalide' });
    }

    await pool.query(
      'UPDATE users SET two_factor_secret = NULL, two_factor_enabled = 0 WHERE id = ?',
      [userId]
    );

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post('/verify', async (req, res) => {
  try {
    const { tempToken, code } = req.body;
    if (!tempToken || !code || code.length !== 6) {
      return res.status(400).json({ message: 'Token et code requis' });
    }

    let payload;
    try {
      payload = jwt.verify(tempToken, JWT_SECRET);
    } catch {
      return res.status(401).json({ message: 'Session expirée, reconnectez-vous' });
    }

    if (payload.type !== '2fa_pending') {
      return res.status(400).json({ message: 'Token invalide' });
    }

    const pool = await getPool();
    const [rows] = await pool.query(
      'SELECT id, email, nom, prenom, telephone, two_factor_enabled, is_admin, two_factor_secret FROM users WHERE id = ?',
      [payload.userId]
    );
    if (rows.length === 0 || !rows[0].two_factor_secret) {
      return res.status(401).json({ message: 'Utilisateur non trouvé' });
    }

    const valid = speakeasy.totp.verify({
      secret: rows[0].two_factor_secret,
      encoding: 'base32',
      token: code.trim(),
      window: 1,
    });

    if (!valid) {
      return res.status(401).json({ message: 'Code invalide ou expiré' });
    }

    const u = rows[0];
    res.json({
      id: u.id,
      email: u.email,
      nom: u.nom,
      prenom: u.prenom,
      telephone: u.telephone || null,
      twoFactorEnabled: !!u.two_factor_enabled,
      isAdmin: !!u.is_admin,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = { router, JWT_SECRET };
