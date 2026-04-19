const express = require("express");
const { getPool } = require("../config/database");
const { getCurrentEvenementId } = require("../utils/evenementContext");

const publicRouter = express.Router();
const adminRouter = express.Router();

function toMysqlDateTime(str) {
  if (!str) return null;
  const d = new Date(str);
  if (Number.isNaN(d.getTime())) return null;
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const h = String(d.getHours()).padStart(2, "0");
  const min = String(d.getMinutes()).padStart(2, "0");
  const sec = String(d.getSeconds()).padStart(2, "0");
  return `${y}-${m}-${day} ${h}:${min}:${sec}`;
}

function parseNotes(raw) {
  if (!raw || typeof raw !== "string") return [];
  try {
    const j = JSON.parse(raw);
    return Array.isArray(j) ? j : [];
  } catch {
    return [];
  }
}

async function requireAdmin(req, res, next) {
  const userId = req.headers["x-user-id"];
  if (!userId) return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
  const id = parseInt(userId, 10);
  if (Number.isNaN(id)) return res.status(401).json({ message: "X-User-Id invalide" });
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

/** GET /api/evenements/current */
publicRouter.get("/current", async (req, res) => {
  try {
    const pool = await getPool();
    const evId = await getCurrentEvenementId(pool);
    if (!evId) {
      return res.json({ evenement: null, message: "Aucun événement configuré" });
    }
    const [[ev]] = await pool.query(
      "SELECT id, nom, description, date_debut, date_fin, annee, notes_json FROM evenements WHERE id = ?",
      [evId]
    );
    if (!ev) return res.json({ evenement: null, message: "Événement courant introuvable" });
    res.json({
      evenement: {
        id: ev.id,
        nom: ev.nom,
        description: ev.description || "",
        dateDebut: ev.date_debut,
        dateFin: ev.date_fin,
        annee: ev.annee,
        notes: parseNotes(ev.notes_json),
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** GET /api/admin/evenements */
adminRouter.get("/", requireAdmin, async (req, res) => {
  try {
    const pool = await getPool();
    const currentId = await getCurrentEvenementId(pool);
    const [rows] = await pool.query(
      "SELECT id, nom, description, date_debut, date_fin, annee, notes_json FROM evenements ORDER BY date_debut DESC, id DESC"
    );
    res.json({
      evenements: rows.map((ev) => ({
        id: ev.id,
        nom: ev.nom,
        description: ev.description || "",
        dateDebut: ev.date_debut,
        dateFin: ev.date_fin,
        annee: ev.annee,
        notes: parseNotes(ev.notes_json),
        isCurrent: ev.id === currentId,
      })),
      currentEvenementId: currentId,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** POST /api/admin/evenements */
adminRouter.post("/", requireAdmin, async (req, res) => {
  try {
    const { nom, description, dateDebut, dateFin, annee, notes } = req.body || {};
    if (!nom || typeof nom !== "string" || !nom.trim()) {
      return res.status(400).json({ message: "Le nom est requis" });
    }
    const deb = toMysqlDateTime(dateDebut || new Date());
    const fin = toMysqlDateTime(dateFin || new Date());
    if (!deb || !fin) return res.status(400).json({ message: "Dates invalides" });
    const yr = annee != null ? parseInt(annee, 10) : new Date(deb).getFullYear();
    const notesJson = JSON.stringify(Array.isArray(notes) ? notes : []);

    const pool = await getPool();
    const [r] = await pool.query(
      `INSERT INTO evenements (nom, description, date_debut, date_fin, annee, notes_json)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [nom.trim(), description?.trim() || null, deb, fin, Number.isNaN(yr) ? new Date().getFullYear() : yr, notesJson]
    );
    const newId = r.insertId;

    const [[anyEv]] = await pool.query("SELECT id FROM evenements WHERE id != ? ORDER BY id ASC LIMIT 1", [newId]);
    if (anyEv) {
      const [copyRows] = await pool.query("SELECT pref_key, pref_value FROM evenement_preferences WHERE evenement_id = ?", [
        anyEv.id,
      ]);
      for (const row of copyRows) {
        await pool.query(
          "INSERT INTO evenement_preferences (evenement_id, pref_key, pref_value) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE pref_value = VALUES(pref_value)",
          [newId, row.pref_key, row.pref_value]
        );
      }
    } else {
      await pool.query(
        `INSERT INTO evenement_preferences (evenement_id, pref_key, pref_value) VALUES
         (?, 'primaryColor', '#4CAF50'), (?, 'secondaryColor', '#2b5a72'),
         (?, 'contactEmail', ''), (?, 'accueilTitre', ''), (?, 'accueilDescription', '')`,
        [newId, newId, newId, newId, newId]
      );
    }

    const [[ev]] = await pool.query("SELECT * FROM evenements WHERE id = ?", [newId]);
    res.status(201).json({
      id: ev.id,
      nom: ev.nom,
      description: ev.description || "",
      dateDebut: ev.date_debut,
      dateFin: ev.date_fin,
      annee: ev.annee,
      notes: parseNotes(ev.notes_json),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** PUT /api/admin/evenements/:id */
adminRouter.put("/:id", requireAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ message: "ID invalide" });
    const { nom, description, dateDebut, dateFin, annee, notes } = req.body || {};
    const pool = await getPool();
    const [[ex]] = await pool.query("SELECT id FROM evenements WHERE id = ?", [id]);
    if (!ex) return res.status(404).json({ message: "Événement introuvable" });

    const updates = [];
    const vals = [];
    if (nom !== undefined) {
      updates.push("nom = ?");
      vals.push(String(nom).trim());
    }
    if (description !== undefined) {
      updates.push("description = ?");
      vals.push(description?.trim() || null);
    }
    if (dateDebut !== undefined) {
      const d = toMysqlDateTime(dateDebut);
      if (!d) return res.status(400).json({ message: "dateDebut invalide" });
      updates.push("date_debut = ?");
      vals.push(d);
    }
    if (dateFin !== undefined) {
      const d = toMysqlDateTime(dateFin);
      if (!d) return res.status(400).json({ message: "dateFin invalide" });
      updates.push("date_fin = ?");
      vals.push(d);
    }
    if (annee !== undefined) {
      updates.push("annee = ?");
      vals.push(parseInt(annee, 10));
    }
    if (notes !== undefined) {
      updates.push("notes_json = ?");
      vals.push(JSON.stringify(Array.isArray(notes) ? notes : []));
    }
    if (updates.length === 0) return res.status(400).json({ message: "Aucune modification" });
    vals.push(id);
    await pool.query(`UPDATE evenements SET ${updates.join(", ")} WHERE id = ?`, vals);

    const [[ev]] = await pool.query("SELECT * FROM evenements WHERE id = ?", [id]);
    res.json({
      id: ev.id,
      nom: ev.nom,
      description: ev.description || "",
      dateDebut: ev.date_debut,
      dateFin: ev.date_fin,
      annee: ev.annee,
      notes: parseNotes(ev.notes_json),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** POST /api/admin/evenements/:id/activate */
adminRouter.post("/:id/activate", requireAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ message: "ID invalide" });
    const pool = await getPool();
    const [[ex]] = await pool.query("SELECT id FROM evenements WHERE id = ?", [id]);
    if (!ex) return res.status(404).json({ message: "Événement introuvable" });

    await pool.query(
      "INSERT INTO app_preferences (pref_key, pref_value) VALUES ('currentEvenementId', ?) ON DUPLICATE KEY UPDATE pref_value = VALUES(pref_value)",
      [String(id)]
    );
    res.json({ success: true, currentEvenementId: id });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** DELETE /api/admin/evenements/:id */
adminRouter.delete("/:id", requireAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ message: "ID invalide" });
    const pool = await getPool();
    const [[cnt]] = await pool.query("SELECT COUNT(*) as n FROM evenements");
    if (Number(cnt.n) <= 1) {
      return res.status(400).json({ message: "Impossible de supprimer le dernier événement" });
    }
    const currentId = await getCurrentEvenementId(pool);
    if (currentId === id) {
      return res.status(400).json({ message: "Changez d’abord l’événement en cours avant suppression" });
    }
    const [[pc]] = await pool.query("SELECT COUNT(*) as n FROM postes WHERE evenement_id = ?", [id]);
    if (Number(pc.n) > 0) {
      return res.status(400).json({ message: "Supprimez d’abord les postes liés à cet événement" });
    }
    await pool.query("DELETE FROM evenements WHERE id = ?", [id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = { publicRouter: publicRouter, adminRouter: adminRouter };
