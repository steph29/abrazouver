const express = require("express");
const router = express.Router();
const { getPool } = require("../config/database");

/** Extrait le user_id du header X-User-Id (utilisateur connecté) */
function getUserId(req) {
  const id = req.headers["x-user-id"];
  if (!id) return null;
  const n = parseInt(id, 10);
  return Number.isNaN(n) ? null : n;
}

/** GET /me - Mes inscriptions avec détails poste/créneau (header: X-User-Id) */
router.get("/me", async (req, res) => {
  try {
    const userId = getUserId(req);
    if (!userId) {
      return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
    }
    const pool = await getPool();
    const [rows] = await pool.query(
      `SELECT i.id as inscription_id, i.creneau_id, i.user_id,
              c.date_debut, c.date_fin, c.nb_benevoles_requis,
              p.id as poste_id, p.titre, p.description
       FROM inscriptions i
       JOIN creneaux c ON c.id = i.creneau_id
       JOIN postes p ON p.id = c.poste_id
       WHERE i.user_id = ?
       ORDER BY c.date_debut, p.titre`,
      [userId]
    );
    const data = rows.map((r) => ({
      inscriptionId: r.inscription_id,
      creneauId: r.creneau_id,
      poste: {
        id: r.poste_id,
        titre: r.titre,
        description: r.description,
      },
      creneau: {
        id: r.creneau_id,
        dateDebut: r.date_debut,
        dateFin: r.date_fin,
        nbBenevolesRequis: r.nb_benevoles_requis,
      },
    }));
    res.json({ data });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** GET - Info des endpoints */
router.get("/", (req, res) => {
  res.json({
    message: "Inscriptions bénévoles",
    endpoints: {
      "GET /me": "Mes inscriptions (header: X-User-Id)",
      "POST /": "S'inscrire à un créneau (body: { creneauId }, header: X-User-Id)",
      "DELETE /:creneauId": "Se désinscrire (header: X-User-Id)",
    },
  });
});

/** POST - S'inscrire à un créneau */
router.post("/", async (req, res) => {
  try {
    const userId = getUserId(req);
    if (!userId) {
      return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
    }
    const { creneauId } = req.body;
    if (!creneauId) {
      return res.status(400).json({ message: "creneauId requis" });
    }
    const creneauIdNum = parseInt(creneauId, 10);
    if (Number.isNaN(creneauIdNum)) {
      return res.status(400).json({ message: "creneauId invalide" });
    }

    const pool = await getPool();

    const [[creneau]] = await pool.query(
      `SELECT c.id, c.nb_benevoles_requis, 
              (SELECT COUNT(*) FROM inscriptions i WHERE i.creneau_id = c.id) as nb_inscrits
       FROM creneaux c WHERE c.id = ?`,
      [creneauIdNum]
    );
    if (!creneau) {
      return res.status(404).json({ message: "Créneau non trouvé" });
    }
    const placesRestantes = creneau.nb_benevoles_requis - Number(creneau.nb_inscrits);
    if (placesRestantes <= 0) {
      return res.status(400).json({ message: "Ce créneau est complet" });
    }

    const [[exists]] = await pool.query(
      "SELECT id FROM users WHERE id = ?",
      [userId]
    );
    if (!exists) {
      return res.status(404).json({ message: "Utilisateur non trouvé" });
    }

    await pool.query(
      "INSERT INTO inscriptions (user_id, creneau_id) VALUES (?, ?)",
      [userId, creneauIdNum]
    );
    res.status(201).json({ success: true, message: "Inscription enregistrée" });
  } catch (err) {
    if (err.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "Vous êtes déjà inscrit à ce créneau" });
    }
    res.status(500).json({ message: err.message });
  }
});

/** DELETE /api/inscriptions/:creneauId - Se désinscrire d'un créneau */
router.delete("/:creneauId", async (req, res) => {
  try {
    const userId = getUserId(req);
    if (!userId) {
      return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
    }
    const creneauId = parseInt(req.params.creneauId, 10);
    if (Number.isNaN(creneauId)) {
      return res.status(400).json({ message: "ID de créneau invalide" });
    }

    const pool = await getPool();
    const [r] = await pool.query(
      "DELETE FROM inscriptions WHERE user_id = ? AND creneau_id = ?",
      [userId, creneauId]
    );
    if (r.affectedRows === 0) {
      return res.status(404).json({ message: "Inscription non trouvée" });
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
