const express = require('express');
const router = express.Router();
const { getPool } = require('../config/database');

const RESERVED_TABLES = [
  'auth', 'admin', 'benevoles', 'health', '2fa',
  'postes', 'creneaux', 'inscriptions', 'users', 'app_preferences', 'contact_messages',
];

function sanitizeTable(table) {
  return table.replace(/[^a-z0-9_]/gi, '');
}

function isReserved(table) {
  return RESERVED_TABLES.includes(table?.toLowerCase());
}

router.get('/:table', async (req, res) => {
  try {
    const table = sanitizeTable(req.params.table);
    if (!table) return res.status(400).json({ message: 'Table invalide' });
    if (isReserved(table)) {
      return res.status(400).json({ message: `"${table}" n'est pas une table CRUD. Utilisez /api/auth/* pour l'authentification.` });
    }
    const pool = await getPool();
    const [rows] = await pool.query(`SELECT * FROM \`${table}\``);
    res.json({ data: rows });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.get('/:table/:id', async (req, res) => {
  try {
    const table = sanitizeTable(req.params.table);
    if (!table) return res.status(400).json({ message: 'Table invalide' });
    if (isReserved(table)) {
      return res.status(400).json({ message: `"${table}" n'est pas une table CRUD.` });
    }
    const pool = await getPool();
    const [rows] = await pool.query(
      `SELECT * FROM \`${table}\` WHERE id = ?`,
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: 'Non trouvé' });
    }
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post('/:table', async (req, res) => {
  try {
    const table = req.params.table.replace(/[^a-z0-9_]/gi, '');
    if (isReserved(table)) {
      return res.status(400).json({
        message: table === 'postes'
          ? "Utilisez POST /api/admin/postes pour créer un poste avec créneaux."
          : `"${table}" n'est pas une table CRUD.`,
      });
    }
    if (!table) return res.status(400).json({ message: 'Table invalide' });
    const pool = await getPool();
    const body = { ...req.body };
    Object.keys(body).forEach((k) => {
      if (typeof body[k] === 'object' && body[k] !== null) delete body[k];
    });
    const data = { ...body, created_at: new Date(), updated_at: new Date() };
    const fields = Object.keys(data);
    const placeholders = fields.map(() => '?').join(', ');
    const [result] = await pool.query(
      `INSERT INTO \`${table}\` (${fields.map((f) => `\`${f}\``).join(', ')}) VALUES (${placeholders})`,
      Object.values(data)
    );
    res.status(201).json({ id: result.insertId, ...data });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put('/:table/:id', async (req, res) => {
  try {
    const table = sanitizeTable(req.params.table);
    if (!table) return res.status(400).json({ message: 'Table invalide' });
    if (isReserved(table)) {
      return res.status(400).json({ message: `"${table}" n'est pas une table CRUD.` });
    }
    const pool = await getPool();
    const data = { ...req.body, updated_at: new Date() };
    const fields = Object.keys(data);
    const setClause = fields.map((f) => `\`${f}\` = ?`).join(', ');
    const values = [...Object.values(data), req.params.id];
    const [result] = await pool.query(
      `UPDATE \`${table}\` SET ${setClause} WHERE id = ?`,
      values
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Non trouvé' });
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.delete('/:table/:id', async (req, res) => {
  try {
    const table = sanitizeTable(req.params.table);
    if (!table) return res.status(400).json({ message: 'Table invalide' });
    if (isReserved(table)) {
      return res.status(400).json({ message: `"${table}" n'est pas une table CRUD.` });
    }
    const pool = await getPool();
    const [result] = await pool.query(
      `DELETE FROM \`${table}\` WHERE id = ?`,
      [req.params.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Non trouvé' });
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
