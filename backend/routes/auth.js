const express = require('express');
const router = express.Router();
const { getPool } = require('../config/database');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'abrazouver-2fa-secret-change-in-production';

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email et mot de passe requis' });
    }

    const pool = await getPool();
    const [rows] = await pool.query(
      'SELECT id, email, nom, prenom, telephone, two_factor_enabled, is_admin, password_hash FROM users WHERE email = ?',
      [email.trim().toLowerCase()]
    );

    if (rows.length === 0) {
      return res.status(401).json({ message: 'Email ou mot de passe incorrect' });
    }

    const user = rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ message: 'Email ou mot de passe incorrect' });
    }

    if (user.two_factor_enabled) {
      const tempToken = jwt.sign(
        { userId: user.id, type: '2fa_pending' },
        JWT_SECRET,
        { expiresIn: '5m' }
      );
      return res.json({
        requires2FA: true,
        tempToken,
      });
    }

    res.json({
      id: user.id,
      email: user.email,
      nom: user.nom,
      prenom: user.prenom,
      telephone: user.telephone || null,
      twoFactorEnabled: !!user.two_factor_enabled,
      isAdmin: !!user.is_admin,
    });
  } catch (err) {
    console.error('Login error:', err.message);
    let msg = err.message;
    if (err.code === 'ENOTFOUND') {
      msg = 'Serveur MySQL introuvable (vérifiez DB_HOST dans .env). Pour OVH : l\'adresse doit être celle indiquée dans le manager OVH. La connexion distante peut être désactivée sur certains hébergements.';
    } else if (err.code === 'ECONNREFUSED') {
      msg = 'Base de données indisponible. Vérifiez que MySQL tourne et que .env est correct.';
    } else if (err.code === 'ER_ACCESS_DENIED_ERROR') {
      msg = 'Accès refusé à la base. Vérifiez DB_USER et DB_PASSWORD dans .env';
    } else if (err.code === 'ER_BAD_DB_ERROR') {
      msg = 'Base inexistante. Exécutez init_db.sql ou créez la base.';
    } else if (err.code === 'ER_NO_SUCH_TABLE') {
      msg = 'Table users manquante. Exécutez init_db.sql ou npm run init-db';
    } else if (err.message && err.message.includes('Unknown column')) {
      msg = `Colonne manquante. Exécutez add-profile-fields.sql pour mettre à jour le schéma. Détail: ${err.message}`;
    }
    res.status(500).json({ message: msg });
  }
});

router.get('/profile/:id', async (req, res) => {
  try {
    const pool = await getPool();
    const [rows] = await pool.query(
      'SELECT id, email, nom, prenom, telephone, two_factor_enabled, is_admin FROM users WHERE id = ?',
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
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

router.put('/profile/:id', async (req, res) => {
  try {
    const { nom, prenom, email, telephone, twoFactorEnabled } = req.body;
    const userId = parseInt(req.params.id, 10);
    if (isNaN(userId)) {
      return res.status(400).json({ message: 'ID invalide' });
    }

    const pool = await getPool();
    const updates = [];
    const values = [];

    if (nom !== undefined) {
      updates.push('nom = ?');
      values.push(nom.trim());
    }
    if (prenom !== undefined) {
      updates.push('prenom = ?');
      values.push(prenom.trim());
    }
    if (email !== undefined) {
      const newEmail = email.trim().toLowerCase();
      const [existing] = await pool.query(
        'SELECT id FROM users WHERE email = ? AND id != ?',
        [newEmail, userId]
      );
      if (existing.length > 0) {
        return res.status(409).json({ message: 'Cet email est déjà utilisé' });
      }
      updates.push('email = ?');
      values.push(newEmail);
    }
    if (telephone !== undefined) {
      updates.push('telephone = ?');
      values.push(telephone?.trim() || null);
    }

    if (updates.length === 0) {
      return res.status(400).json({ message: 'Aucune donnée à mettre à jour' });
    }

    values.push(userId);
    await pool.query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    const [rows] = await pool.query(
      'SELECT id, email, nom, prenom, telephone, two_factor_enabled, is_admin FROM users WHERE id = ?',
      [userId]
    );
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

router.post('/register', async (req, res) => {
  try {
    const { email, password, nom, prenom } = req.body;
    if (!email || !password || !nom || !prenom) {
      return res.status(400).json({
        message: 'Email, mot de passe, nom et prénom requis',
      });
    }
    if (password.length < 6) {
      return res.status(400).json({
        message: 'Le mot de passe doit contenir au moins 6 caractères',
      });
    }

    const pool = await getPool();
    const [existing] = await pool.query(
      'SELECT id FROM users WHERE email = ?',
      [email.trim().toLowerCase()]
    );
    if (existing.length > 0) {
      return res.status(409).json({ message: 'Cet email est déjà utilisé' });
    }

    const hash = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO users (email, password_hash, nom, prenom) VALUES (?, ?, ?, ?)',
      [email.trim().toLowerCase(), hash, nom.trim(), prenom.trim()]
    );

    res.status(201).json({
      id: result.insertId,
      email: email.trim().toLowerCase(),
      nom: nom.trim(),
      prenom: prenom.trim(),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
