const express = require("express");
const router = express.Router();
const { getPool } = require("../config/database");
const { getCurrentEvenementId } = require("../utils/evenementContext");

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

/** GET /api/admin/users - Liste de tous les utilisateurs inscrits + is_admin + referentPosteIds */
router.get("/", requireAdmin, async (req, res) => {
  try {
    const pool = await getPool();
    const [rows] = await pool.query(
      `SELECT id, nom, prenom, email, is_admin
       FROM users
       ORDER BY nom, prenom`
    );
    const [rps] = await pool.query("SELECT user_id, poste_id FROM referent_postes");
    const byUser = new Map();
    for (const rp of rps) {
      const uid = rp.user_id;
      if (!byUser.has(uid)) byUser.set(uid, []);
      byUser.get(uid).push(Number(rp.poste_id));
    }
    const users = rows.map((r) => ({
      id: r.id,
      nom: r.nom,
      prenom: r.prenom,
      email: r.email,
      isAdmin: !!r.is_admin,
      referentPosteIds: byUser.get(r.id) || [],
    }));
    res.json({ users });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** PUT /api/admin/users/:id/referent-postes - Postes dont ce bénévole est référent (événement en cours) */
router.put("/:id/referent-postes", requireAdmin, async (req, res) => {
  try {
    const targetId = parseInt(req.params.id, 10);
    if (Number.isNaN(targetId)) {
      return res.status(400).json({ message: "ID invalide" });
    }
    const { posteIds } = req.body || {};
    if (!Array.isArray(posteIds)) {
      return res.status(400).json({ message: "posteIds (tableau) requis" });
    }
    const pool = await getPool();
    const [[u]] = await pool.query("SELECT id FROM users WHERE id = ?", [targetId]);
    if (!u) {
      return res.status(404).json({ message: "Utilisateur introuvable" });
    }
    const evId = await getCurrentEvenementId(pool);
    if (!evId) {
      return res.status(400).json({ message: "Aucun événement actif" });
    }
    const ids = [...new Set(posteIds.map((x) => parseInt(x, 10)).filter((n) => !Number.isNaN(n)))];
    if (ids.length > 0) {
      const [valid] = await pool.query(
        `SELECT id FROM postes WHERE evenement_id = ? AND id IN (${ids.map(() => "?").join(",")})`,
        [evId, ...ids]
      );
      if (valid.length !== ids.length) {
        return res.status(400).json({ message: "Certains postes sont invalides pour l'événement en cours" });
      }
    }
    await pool.query("DELETE FROM referent_postes WHERE user_id = ?", [targetId]);
    for (const pid of ids) {
      await pool.query("INSERT INTO referent_postes (user_id, poste_id) VALUES (?, ?)", [targetId, pid]);
    }
    res.json({ success: true, referentPosteIds: ids });
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
