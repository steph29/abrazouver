const express = require("express");
const { getPool } = require("../config/database");

/**
 * Vérifie si des créneaux se chevauchent.
 * Deux créneaux [a1,b1] et [a2,b2] se chevauchent si a1 < b2 ET b1 > a2.
 */
function creneauxSeChevauchent(creneaux) {
  const arr = creneaux.map((c) => ({
    deb: new Date(c.dateDebut || c.date_debut),
    fin: new Date(c.dateFin || c.date_fin),
  }));
  for (let i = 0; i < arr.length; i++) {
    if (arr[i].fin <= arr[i].deb) return true; // date_fin <= date_debut
    for (let j = i + 1; j < arr.length; j++) {
      if (arr[i].deb < arr[j].fin && arr[i].fin > arr[j].deb) return true;
    }
  }
  return false;
}

/** Routeur lecture seule - GET /api/postes (public, Places libres) */
const postesReadRouter = express.Router();

postesReadRouter.get("/", async (req, res) => {
  try {
    const pool = await getPool();
    const [postes] = await pool.query(
      "SELECT id, titre, description, created_at, updated_at FROM postes ORDER BY titre"
    );
    const [creneaux] = await pool.query(
      "SELECT id, poste_id, date_debut, date_fin, nb_benevoles_requis FROM creneaux ORDER BY poste_id, date_debut"
    );
    const byPoste = creneaux.reduce((acc, c) => {
      const pid = c.poste_id;
      if (!acc[pid]) acc[pid] = [];
      acc[pid].push({
        id: c.id,
        dateDebut: c.date_debut,
        dateFin: c.date_fin,
        nbBenevolesRequis: c.nb_benevoles_requis,
      });
      return acc;
    }, {});
    const result = postes.map((p) => ({
      ...p,
      creneaux: byPoste[p.id] || [],
    }));
    res.json({ data: result });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

postesReadRouter.get("/:id", async (req, res) => {
  try {
    const pool = await getPool();
    const [[poste]] = await pool.query(
      "SELECT id, titre, description, created_at, updated_at FROM postes WHERE id = ?",
      [req.params.id]
    );
    if (!poste) return res.status(404).json({ message: "Poste non trouvé" });
    const [creneaux] = await pool.query(
      "SELECT id, date_debut, date_fin, nb_benevoles_requis FROM creneaux WHERE poste_id = ? ORDER BY date_debut",
      [req.params.id]
    );
    res.json({
      ...poste,
      creneaux: creneaux.map((c) => ({
        id: c.id,
        dateDebut: c.date_debut,
        dateFin: c.date_fin,
        nbBenevolesRequis: c.nb_benevoles_requis,
      })),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** Routeur admin - POST, PUT, DELETE /api/admin/postes */
const postesAdminRouter = express.Router();

async function createPosteHandler(req, res) {
  try {
    const { titre, description, creneaux } = req.body;
    if (!titre || typeof titre !== "string" || titre.trim().length === 0) {
      return res.status(400).json({ message: "Titre requis" });
    }
    const creneauxArr = Array.isArray(creneaux) ? creneaux : [];
    for (const c of creneauxArr) {
      if (!c.dateDebut || !c.dateFin) {
        return res.status(400).json({
          message: "Chaque créneau doit avoir dateDebut et dateFin",
        });
      }
      const deb = new Date(c.dateDebut);
      const fin = new Date(c.dateFin);
      if (fin <= deb) {
        return res.status(400).json({
          message: "Créneau invalide : la fin doit être après le début",
        });
      }
      if (!(c.nbBenevolesRequis > 0)) {
        return res.status(400).json({
          message: "Le nombre de bénévoles par créneau doit être > 0",
        });
      }
    }
    if (creneauxSeChevauchent(creneauxArr)) {
      return res.status(400).json({
        message: "Les créneaux ne doivent pas se chevaucher",
      });
    }
    const pool = await getPool();
    const [r] = await pool.query(
      "INSERT INTO postes (titre, description) VALUES (?, ?)",
      [titre.trim(), description?.trim() || null]
    );
    const posteId = r.insertId;
    for (const c of creneauxArr) {
      await pool.query(
        "INSERT INTO creneaux (poste_id, date_debut, date_fin, nb_benevoles_requis) VALUES (?, ?, ?, ?)",
        [
          posteId,
          c.dateDebut,
          c.dateFin,
          c.nbBenevolesRequis > 0 ? c.nbBenevolesRequis : 1,
        ]
      );
    }
    const [[nouveau]] = await pool.query(
      "SELECT id, titre, description, created_at, updated_at FROM postes WHERE id = ?",
      [posteId]
    );
    const [creneauxDb] = await pool.query(
      "SELECT id, date_debut, date_fin, nb_benevoles_requis FROM creneaux WHERE poste_id = ?",
      [posteId]
    );
    res.status(201).json({
      ...nouveau,
      creneaux: creneauxDb.map((c) => ({
        id: c.id,
        dateDebut: c.date_debut,
        dateFin: c.date_fin,
        nbBenevolesRequis: c.nb_benevoles_requis,
      })),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

postesAdminRouter.post(["/", ""], createPosteHandler);

postesAdminRouter.put("/:id", async (req, res) => {
  try {
    const posteId = parseInt(req.params.id, 10);
    if (isNaN(posteId)) return res.status(400).json({ message: "ID invalide" });
    const { titre, description, creneaux } = req.body;
    if (!titre || typeof titre !== "string" || titre.trim().length === 0) {
      return res.status(400).json({ message: "Titre requis" });
    }
    const creneauxArr = Array.isArray(creneaux) ? creneaux : [];
    for (const c of creneauxArr) {
      if (!c.dateDebut || !c.dateFin) {
        return res.status(400).json({
          message: "Chaque créneau doit avoir dateDebut et dateFin",
        });
      }
      const deb = new Date(c.dateDebut);
      const fin = new Date(c.dateFin);
      if (fin <= deb) {
        return res.status(400).json({
          message: "Un créneau a une fin antérieure au début",
        });
      }
      if (!(c.nbBenevolesRequis > 0)) {
        return res.status(400).json({
          message: "Le nombre de bénévoles par créneau doit être > 0",
        });
      }
    }
    if (creneauxSeChevauchent(creneauxArr)) {
      return res.status(400).json({
        message: "Les créneaux ne doivent pas se chevaucher",
      });
    }
    const pool = await getPool();
    const [r] = await pool.query(
      "UPDATE postes SET titre = ?, description = ? WHERE id = ?",
      [titre.trim(), description?.trim() || null, posteId]
    );
    if (r.affectedRows === 0) {
      return res.status(404).json({ message: "Poste non trouvé" });
    }
    await pool.query("DELETE FROM creneaux WHERE poste_id = ?", [posteId]);
    for (const c of creneauxArr) {
      await pool.query(
        "INSERT INTO creneaux (poste_id, date_debut, date_fin, nb_benevoles_requis) VALUES (?, ?, ?, ?)",
        [
          posteId,
          c.dateDebut,
          c.dateFin,
          c.nbBenevolesRequis > 0 ? c.nbBenevolesRequis : 1,
        ]
      );
    }
    const [[poste]] = await pool.query(
      "SELECT id, titre, description, created_at, updated_at FROM postes WHERE id = ?",
      [posteId]
    );
    const [creneauxDb] = await pool.query(
      "SELECT id, date_debut, date_fin, nb_benevoles_requis FROM creneaux WHERE poste_id = ?",
      [posteId]
    );
    res.json({
      ...poste,
      creneaux: creneauxDb.map((c) => ({
        id: c.id,
        dateDebut: c.date_debut,
        dateFin: c.date_fin,
        nbBenevolesRequis: c.nb_benevoles_requis,
      })),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

postesAdminRouter.delete("/:id", async (req, res) => {
  try {
    const pool = await getPool();
    const [r] = await pool.query("DELETE FROM postes WHERE id = ?", [
      req.params.id,
    ]);
    if (r.affectedRows === 0) {
      return res.status(404).json({ message: "Poste non trouvé" });
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = {
  postesReadRouter,
  postesAdminRouter,
};
