const express = require("express");
const router = express.Router();
const { getPool } = require("../config/database");

/** Vérifie que l'utilisateur est admin via X-User-Id */
async function requireAdmin(req, res, next) {
  const userId = req.headers["x-user-id"];
  if (!userId) {
    return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
  }
  const id = parseInt(userId, 10);
  if (Number.isNaN(id)) {
    return res.status(401).json({ message: "X-User-Id invalide" });
  }
  try {
    const pool = await getPool();
    const [[row]] = await pool.query("SELECT is_admin FROM users WHERE id = ?", [id]);
    if (!row || !row.is_admin) {
      return res.status(403).json({ message: "Accès réservé aux administrateurs" });
    }
    req.adminUserId = id;
    next();
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

/** GET /api/admin/users - Liste de tous les utilisateurs inscrits (compte créé) + is_admin */
router.get("/", requireAdmin, async (req, res) => {
  try {
    const pool = await getPool();
    const [rows] = await pool.query(
      `SELECT id, nom, prenom, email, is_admin
       FROM users
       ORDER BY nom, prenom`
    );
    const users = rows.map((r) => ({
      id: r.id,
      nom: r.nom,
      prenom: r.prenom,
      email: r.email,
      isAdmin: !!r.is_admin,
    }));
    res.json({ users });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** PUT /api/admin/users/:id/role - Met à jour le rôle admin d'un bénévole */
router.put("/:id/role", requireAdmin, async (req, res) => {
  try {
    const targetId = parseInt(req.params.id, 10);
    if (Number.isNaN(targetId)) {
      return res.status(400).json({ message: "ID invalide" });
    }
    const { isAdmin } = req.body || {};
    if (typeof isAdmin !== "boolean") {
      return res.status(400).json({ message: "isAdmin (booléen) requis" });
    }

    // Ne pas se retirer soi-même les droits admin (au moins un admin doit rester)
    if (targetId === req.adminUserId && !isAdmin) {
      return res.status(400).json({ message: "Vous ne pouvez pas retirer vos propres droits admin" });
    }

    const pool = await getPool();
    const [result] = await pool.query(
      "UPDATE users SET is_admin = ? WHERE id = ?",
      [isAdmin ? 1 : 0, targetId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Utilisateur introuvable" });
    }

    res.json({ success: true, isAdmin });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
