const express = require("express");
const router = express.Router();
const bcrypt = require("bcrypt");
const { getPool } = require("../config/database");
const { deleteUserInscriptions } = require("../utils/deleteUserInscriptions");

function getUserId(req) {
  const id = req.headers["x-user-id"];
  if (!id) return null;
  const n = parseInt(id, 10);
  return Number.isNaN(n) ? null : n;
}

/** GET /family — membres du foyer (connecté : titulaire ou membre) */
router.get("/family", async (req, res) => {
  try {
    const userId = getUserId(req);
    if (!userId) {
      return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
    }
    const pool = await getPool();
    const [[u]] = await pool.query("SELECT id, user_with FROM users WHERE id = ?", [userId]);
    if (!u) return res.status(404).json({ message: "Utilisateur introuvable" });
    const headId = u.user_with ? u.user_with : u.id;
    const [members] = await pool.query(
      `SELECT id, email, nom, prenom, telephone, user_with
       FROM users WHERE id = ? OR user_with = ?
       ORDER BY CASE WHEN id = ? THEN 0 ELSE 1 END, id ASC`,
      [headId, headId, headId]
    );
    const data = members.map((m) => ({
      id: m.id,
      email: m.email || null,
      nom: m.nom,
      prenom: m.prenom,
      telephone: m.telephone || null,
      isHead: m.id === headId,
      canLogin: !!(m.email && m.email.trim()),
    }));
    res.json({ members: data });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** POST /family/member — ajouter un bénévole famille (titulaire uniquement) */
router.post("/family/member", async (req, res) => {
  try {
    const userId = getUserId(req);
    if (!userId) {
      return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
    }
    const { email, password, nom, prenom } = req.body || {};
    if (!nom || !prenom || !String(nom).trim() || !String(prenom).trim()) {
      return res.status(400).json({ message: "Nom et prénom requis" });
    }

    const pool = await getPool();
    const [[me]] = await pool.query("SELECT id, user_with FROM users WHERE id = ?", [userId]);
    if (!me || me.user_with != null) {
      return res.status(403).json({ message: "Seul le responsable du compte peut ajouter des membres." });
    }

    const emRaw = email != null ? String(email).trim().toLowerCase() : "";
    const hasEmail = emRaw.length > 0;
    const pwd = password != null ? String(password) : "";

    if (hasEmail) {
      if (pwd.length < 6) {
        return res.status(400).json({
          message: "Si un email est renseigné, un mot de passe d’au moins 6 caractères est requis.",
        });
      }
      const [existing] = await pool.query("SELECT id FROM users WHERE email = ?", [emRaw]);
      if (existing.length > 0) {
        return res.status(409).json({ message: "Cet email est déjà utilisé" });
      }
      const hash = await bcrypt.hash(pwd, 10);
      const [result] = await pool.query(
        "INSERT INTO users (email, password_hash, nom, prenom, user_with) VALUES (?, ?, ?, ?, ?)",
        [emRaw, hash, nom.trim(), prenom.trim(), userId]
      );
      return res.status(201).json({
        id: result.insertId,
        email: emRaw,
        nom: nom.trim(),
        prenom: prenom.trim(),
        userWith: userId,
        isHead: false,
        canLogin: true,
      });
    }

    const [result] = await pool.query(
      "INSERT INTO users (email, password_hash, nom, prenom, user_with) VALUES (NULL, NULL, ?, ?, ?)",
      [nom.trim(), prenom.trim(), userId]
    );

    res.status(201).json({
      id: result.insertId,
      email: null,
      nom: nom.trim(),
      prenom: prenom.trim(),
      userWith: userId,
      isHead: false,
      canLogin: false,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** DELETE /family/member/:id — retirer un membre (titulaire uniquement, pas soi-même) */
router.delete("/family/member/:targetId", async (req, res) => {
  try {
    const userId = getUserId(req);
    if (!userId) {
      return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
    }
    const targetId = parseInt(req.params.targetId, 10);
    if (Number.isNaN(targetId)) {
      return res.status(400).json({ message: "ID invalide" });
    }
    if (targetId === userId) {
      return res.status(400).json({ message: "Utilisez un autre moyen pour supprimer votre compte." });
    }

    const pool = await getPool();
    const [[me]] = await pool.query("SELECT id, user_with FROM users WHERE id = ?", [userId]);
    if (!me || me.user_with != null) {
      return res.status(403).json({ message: "Seul le responsable peut retirer un membre." });
    }

    const [[target]] = await pool.query("SELECT id, user_with FROM users WHERE id = ?", [targetId]);
    if (!target || target.user_with !== userId) {
      return res.status(404).json({ message: "Membre introuvable" });
    }

    await deleteUserInscriptions(pool, targetId);
    await pool.query("DELETE FROM users WHERE id = ?", [targetId]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
