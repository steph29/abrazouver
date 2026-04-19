const express = require("express");
const router = express.Router();
const { getPool } = require("../config/database");

function getUserId(req) {
  const id = req.headers["x-user-id"];
  if (!id) return null;
  const n = parseInt(id, 10);
  return Number.isNaN(n) ? null : n;
}

async function getFamilyContext(pool, userId) {
  const [[u]] = await pool.query("SELECT id, user_with FROM users WHERE id = ?", [userId]);
  if (!u) return null;
  const headId = u.user_with ? u.user_with : u.id;
  return { headId, selfId: u.id };
}

async function getFamilyMemberIds(pool, headId) {
  const [rows] = await pool.query("SELECT id FROM users WHERE id = ? OR user_with = ?", [headId, headId]);
  return new Set(rows.map((r) => r.id));
}

function mapInscriptionRow(r) {
  return {
    inscriptionId: r.inscription_id,
    creneauId: r.creneau_id,
    userId: r.user_id,
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
  };
}

/** GET /me - Mes inscriptions seules (header: X-User-Id) */
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
    const data = rows.map(mapInscriptionRow);
    res.json({ data });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** GET /me/family — inscriptions groupées par membre du foyer */
router.get("/me/family", async (req, res) => {
  try {
    const userId = getUserId(req);
    if (!userId) {
      return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
    }
    const pool = await getPool();
    const ctx = await getFamilyContext(pool, userId);
    if (!ctx) return res.status(404).json({ message: "Utilisateur introuvable" });

    const [members] = await pool.query(
      `SELECT id, email, nom, prenom, telephone, user_with
       FROM users WHERE id = ? OR user_with = ?
       ORDER BY CASE WHEN id = ? THEN 0 ELSE 1 END, id ASC`,
      [ctx.headId, ctx.headId, ctx.headId]
    );

    const out = [];
    for (const m of members) {
      const [rows] = await pool.query(
        `SELECT i.id as inscription_id, i.creneau_id, i.user_id,
                c.date_debut, c.date_fin, c.nb_benevoles_requis,
                p.id as poste_id, p.titre, p.description
         FROM inscriptions i
         JOIN creneaux c ON c.id = i.creneau_id
         JOIN postes p ON p.id = c.poste_id
         WHERE i.user_id = ?
         ORDER BY c.date_debut, p.titre`,
        [m.id]
      );
      out.push({
        userId: m.id,
        email: m.email,
        nom: m.nom,
        prenom: m.prenom,
        telephone: m.telephone || null,
        isHead: m.id === ctx.headId,
        inscriptions: rows.map(mapInscriptionRow),
      });
    }
    res.json({ members: out });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.get("/", (req, res) => {
  res.json({
    message: "Inscriptions bénévoles",
    endpoints: {
      "GET /me": "Mes inscriptions (header: X-User-Id)",
      "GET /me/family": "Inscriptions par membre du foyer",
      "POST /": "S'inscrire (body: { creneauId, targetUserIds? })",
      "DELETE /:creneauId": "Se désinscrire (?targetUserId= pour le responsable)",
    },
  });
});

/** POST - Inscription (un ou plusieurs membres du foyer) */
router.post("/", async (req, res) => {
  try {
    const userId = getUserId(req);
    if (!userId) {
      return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
    }
    const { creneauId, targetUserIds } = req.body || {};
    if (!creneauId) {
      return res.status(400).json({ message: "creneauId requis" });
    }
    const creneauIdNum = parseInt(creneauId, 10);
    if (Number.isNaN(creneauIdNum)) {
      return res.status(400).json({ message: "creneauId invalide" });
    }

    const pool = await getPool();
    const ctx = await getFamilyContext(pool, userId);
    if (!ctx) return res.status(404).json({ message: "Utilisateur introuvable" });
    const [[requester]] = await pool.query("SELECT id, user_with FROM users WHERE id = ?", [userId]);
    if (!requester) return res.status(404).json({ message: "Utilisateur introuvable" });

    const allowed = await getFamilyMemberIds(pool, ctx.headId);

    let targets = Array.isArray(targetUserIds) && targetUserIds.length > 0
      ? targetUserIds.map((x) => parseInt(x, 10)).filter((n) => !Number.isNaN(n))
      : [userId];

    targets = [...new Set(targets)];

    if (requester.user_with != null) {
      if (targets.length !== 1 || targets[0] !== userId) {
        return res.status(403).json({ message: "Vous ne pouvez inscrire que votre propre compte" });
      }
    } else {
      for (const t of targets) {
        if (!allowed.has(t)) {
          return res.status(403).json({ message: "Membre non autorisé pour cette famille" });
        }
      }
    }

    const [[creneau]] = await pool.query(
      `SELECT c.id, c.nb_benevoles_requis,
              (SELECT COUNT(*) FROM inscriptions i WHERE i.creneau_id = c.id) as nb_inscrits
       FROM creneaux c WHERE c.id = ?`,
      [creneauIdNum]
    );
    if (!creneau) {
      return res.status(404).json({ message: "Créneau non trouvé" });
    }

    const [existingRows] = await pool.query(
      `SELECT user_id FROM inscriptions WHERE creneau_id = ? AND user_id IN (${targets.map(() => "?").join(",")})`,
      [creneauIdNum, ...targets]
    );
    const already = new Set(existingRows.map((r) => r.user_id));
    const toInsert = targets.filter((t) => !already.has(t));
    if (toInsert.length === 0) {
      return res.status(409).json({ message: "Déjà inscrit(s) pour ce créneau" });
    }

    const placesRestantes = creneau.nb_benevoles_requis - Number(creneau.nb_inscrits);
    if (placesRestantes < toInsert.length) {
      return res.status(400).json({ message: "Pas assez de places libres pour ce créneau" });
    }

    for (const uid of toInsert) {
      await pool.query("INSERT INTO inscriptions (user_id, creneau_id) VALUES (?, ?)", [uid, creneauIdNum]);
    }

    res.status(201).json({ success: true, message: "Inscription enregistrée", count: toInsert.length });
  } catch (err) {
    if (err.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "Déjà inscrit à ce créneau" });
    }
    res.status(500).json({ message: err.message });
  }
});

/** DELETE /:creneauId — ?targetUserId= pour désinscrire un membre (responsable) */
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

    let targetUserId = userId;
    const q = req.query.targetUserId;
    if (q !== undefined && q !== "") {
      const t = parseInt(q, 10);
      if (Number.isNaN(t)) {
        return res.status(400).json({ message: "targetUserId invalide" });
      }
      targetUserId = t;
    }

    const pool = await getPool();
    const ctx = await getFamilyContext(pool, userId);
    if (!ctx) return res.status(404).json({ message: "Utilisateur introuvable" });

    if (targetUserId !== userId) {
      const [[me]] = await pool.query("SELECT user_with FROM users WHERE id = ?", [userId]);
      if (!me || me.user_with != null) {
        return res.status(403).json({ message: "Seul le responsable peut annuler pour un autre membre" });
      }
      const allowed = await getFamilyMemberIds(pool, ctx.headId);
      if (!allowed.has(targetUserId)) {
        return res.status(403).json({ message: "Membre non autorisé" });
      }
    }

    const [r] = await pool.query(
      "DELETE FROM inscriptions WHERE user_id = ? AND creneau_id = ?",
      [targetUserId, creneauId]
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
