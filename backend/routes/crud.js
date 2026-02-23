const express = require('express');
const router = express.Router();
const { getPool } = require('../config/database');

function sanitizeTable(table) {
  return table.replace(/[^a-z0-9_]/gi, '');
}

router.get('/:table', async (req, res) => {
  try {
    const pool = await getPool();
    const table = sanitizeTable(req.params.table);
    if (!table) return res.status(400).json({ message: 'Table invalide' });
    const [rows] = await pool.query(`SELECT * FROM \`${table}\``);
    res.json({ data: rows });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.get('/:table/:id', async (req, res) => {
  try {
    const pool = await getPool();
    const table = sanitizeTable(req.params.table);
    if (!table) return res.status(400).json({ message: 'Table invalide' });
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
    const pool = await getPool();
    const table = req.params.table.replace(/[^a-z0-9_]/gi, '');
    if (!table) return res.status(400).json({ message: 'Table invalide' });
    const data = { ...req.body, created_at: new Date(), updated_at: new Date() };
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
    const pool = await getPool();
    const table = sanitizeTable(req.params.table);
    if (!table) return res.status(400).json({ message: 'Table invalide' });
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
    const pool = await getPool();
    const table = sanitizeTable(req.params.table);
    if (!table) return res.status(400).json({ message: 'Table invalide' });
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
