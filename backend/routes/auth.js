const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const { getPool } = require('../config/database');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { sendMail } = require('../config/email');

const JWT_SECRET = process.env.JWT_SECRET || 'abrazouver-2fa-secret-change-in-production';

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email et mot de passe requis' });
    }

    const pool = await getPool();
    const [rows] = await pool.query(
      'SELECT id, email, nom, prenom, telephone, two_factor_enabled, is_admin, user_with, password_hash FROM users WHERE email = ?',
      [email.trim().toLowerCase()]
    );

    if (rows.length === 0) {
      return res.status(401).json({ message: 'Email ou mot de passe incorrect' });
    }

    const user = rows[0];
    if (!user.password_hash) {
      return res.status(401).json({
        message:
          'Ce compte ne permet pas la connexion par mot de passe. Utilisez le compte du responsable du foyer.',
      });
    }
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
      userWith: user.user_with != null ? user.user_with : null,
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
      'SELECT id, email, nom, prenom, telephone, two_factor_enabled, is_admin, user_with FROM users WHERE id = ?',
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
      userWith: u.user_with != null ? u.user_with : null,
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
      'SELECT id, email, nom, prenom, telephone, two_factor_enabled, is_admin, user_with FROM users WHERE id = ?',
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
      userWith: u.user_with != null ? u.user_with : null,
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

/** Construit l'URL de l'app à partir du Host API (api.xxx.domaine → app.xxx.domaine) */
function getAppBaseUrlFromHost(req) {
  const host = req.get('host') || req.get('x-forwarded-host') || '';
  const domain = (process.env.PROVISION_DOMAIN || 'steph-verardo.fr').trim();
  if (!host) return null;
  const parts = host.toLowerCase().replace(/:\d+$/, '').split('.');
  if (parts[0] === 'api' && parts[1]) {
    return `https://app.${parts[1]}.${parts.slice(2).join('.') || domain}`;
  }
  return null;
}

/** POST /auth/forgot-password - Demande de réinitialisation (envoi email avec lien) */
router.post('/forgot-password', async (req, res) => {
  try {
    const { email, appBaseUrl } = req.body || {};
    if (!email || !email.trim()) {
      return res.status(400).json({ message: 'Email requis' });
    }

    const pool = await getPool();
    const [rows] = await pool.query('SELECT id FROM users WHERE email = ?', [email.trim().toLowerCase()]);
    if (rows.length === 0) {
      return res.json({ message: 'Si cet email existe, un lien de réinitialisation vous a été envoyé.' });
    }

    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);

    await pool.query(
      'UPDATE users SET password_reset_token = ?, password_reset_expires_at = ? WHERE id = ?',
      [token, expiresAt, rows[0].id]
    );

    const baseUrl = (appBaseUrl || req.get('origin') || getAppBaseUrlFromHost(req) || '').toString().trim().replace(/\/$/, '');
    const resetLink = baseUrl ? `${baseUrl}/reset-password?token=${token}` : null;

    if (!resetLink) {
      console.error('Forgot password: impossible de construire le lien (appBaseUrl manquant)');
      return res.status(503).json({
        message: 'Configuration manquante pour le lien de réinitialisation. Contactez l\'administrateur.',
      });
    }

    const to = email.trim().toLowerCase();
    const sent = await sendMail({
      to,
      subject: 'Abrazouver - Réinitialisation du mot de passe',
      text: `Pour réinitialiser votre mot de passe, cliquez sur ce lien (valide 1 heure) :\n\n${resetLink}\n\nSi vous n'avez pas demandé cette réinitialisation, ignorez cet email.`,
      html: `<p>Pour réinitialiser votre mot de passe, <a href="${resetLink}">cliquez ici</a> (lien valide 1 heure).</p><p>Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.</p>`,
    });

    if (!sent) {
      console.error('Forgot password: échec envoi email vers', to);
      return res.status(503).json({
        message: 'L\'envoi d\'email a échoué. Réessayez ou contactez l\'administrateur.',
      });
    }

    console.log('Forgot password: email envoyé vers', to);
    res.json({ message: 'Si cet email existe, un lien de réinitialisation vous a été envoyé.' });
  } catch (err) {
    console.error('Forgot password error:', err.message);
    res.status(500).json({ message: err.message });
  }
});

/** POST /auth/reset-password - Réinitialisation avec token du lien email */
router.post('/reset-password', async (req, res) => {
  try {
    const token = (req.body?.token || '').toString().trim();
    const newPassword = (req.body?.newPassword || '').toString();
    if (!token || !newPassword) {
      return res.status(400).json({ message: 'Token et nouveau mot de passe requis' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'Le mot de passe doit contenir au moins 6 caractères' });
    }

    const pool = await getPool();
    const now = new Date();
    const [rows] = await pool.query(
      'SELECT id FROM users WHERE password_reset_token = ? AND password_reset_expires_at > ?',
      [token, now]
    );
    if (rows.length === 0) {
      const [byToken] = await pool.query('SELECT id, password_reset_expires_at FROM users WHERE password_reset_token = ?', [token]);
      if (byToken.length > 0) {
        console.error('Reset password: token expiré pour user', byToken[0].id, 'expires_at=', byToken[0].password_reset_expires_at);
      } else {
        console.error('Reset password: token non trouvé, len=', token.length);
      }
      return res.status(400).json({ message: 'Lien invalide ou expiré. Demandez une nouvelle réinitialisation.' });
    }

    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query(
      'UPDATE users SET password_hash = ?, password_reset_token = NULL, password_reset_expires_at = NULL WHERE id = ?',
      [hash, rows[0].id]
    );

    res.json({ message: 'Mot de passe modifié. Vous pouvez vous connecter.' });
  } catch (err) {
    console.error('Reset password error:', err.message);
    res.status(500).json({ message: err.message });
  }
});

/** PUT /auth/password/:id - Modifier le mot de passe (utilisateur connecté, X-User-Id requis) */
router.put('/password/:id', async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = parseInt(req.params.id, 10);
    const headerUserId = req.headers['x-user-id'];

    if (isNaN(userId) || !headerUserId || parseInt(headerUserId, 10) !== userId) {
      return res.status(401).json({ message: 'Authentification requise' });
    }
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: 'Mot de passe actuel et nouveau mot de passe requis' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'Le nouveau mot de passe doit contenir au moins 6 caractères' });
    }

    const pool = await getPool();
    const [rows] = await pool.query('SELECT password_hash FROM users WHERE id = ?', [userId]);
    if (rows.length === 0) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }

    const valid = await bcrypt.compare(currentPassword, rows[0].password_hash);
    if (!valid) {
      return res.status(401).json({ message: 'Mot de passe actuel incorrect' });
    }

    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password_hash = ? WHERE id = ?', [hash, userId]);

    res.json({ message: 'Mot de passe modifié' });
  } catch (err) {
    console.error('Update password error:', err.message);
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
