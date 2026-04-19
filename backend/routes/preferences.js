const express = require("express");
const router = express.Router();
const { getPool } = require("../config/database");
const { getCurrentEvenementId } = require("../utils/evenementContext");

const DEFAULTS = {
  primaryColor: "#4CAF50",
  secondaryColor: "#2b5a72",
  contactEmail: "",
  accueilTitre: "",
  accueilDescription: "",
};

const MAX_LOGO_BYTES = 2 * 1024 * 1024; // 2 Mo

/** Convertit une map en objet préférences */
function prefsToObject(rows) {
  const obj = {};
  for (const r of rows) {
    obj[r.pref_key] = r.pref_value ?? DEFAULTS[r.pref_key];
  }
  return {
    primaryColor: obj.primaryColor ?? DEFAULTS.primaryColor,
    secondaryColor: obj.secondaryColor ?? DEFAULTS.secondaryColor,
    logo: obj.logo || null,
    contactEmail: obj.contactEmail ?? "",
    accueilTitre: obj.accueilTitre ?? "",
    accueilDescription: obj.accueilDescription ?? "",
  };
}

/** Valide un code couleur hex (#RRGGBB ou RRGGBB) */
function isValidHex(s) {
  return /^#?[0-9A-Fa-f]{6}$/.test(s);
}

/** Normalise en #RRGGBB */
function normalizeHex(s) {
  if (!s || typeof s !== "string") return null;
  const m = s.trim().match(/^#?([0-9A-Fa-f]{6})$/);
  return m ? `#${m[1]}` : null;
}

async function loadPreferenceRows(pool) {
  const evId = await getCurrentEvenementId(pool);
  if (evId) {
    const [rowsEv] = await pool.query(
      "SELECT pref_key, pref_value FROM evenement_preferences WHERE evenement_id = ?",
      [evId]
    );
    if (rowsEv.length > 0) return rowsEv;
  }
  const [rows] = await pool.query(
    "SELECT pref_key, pref_value FROM app_preferences WHERE pref_key != 'currentEvenementId'"
  );
  return rows;
}

/** GET /api/preferences - Public, pour le thème de l'app (préférences de l'événement en cours) */
router.get("/", async (req, res) => {
  try {
    const pool = await getPool();
    const rows = await loadPreferenceRows(pool);
    const prefs = prefsToObject(rows);
    res.json(prefs);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

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

/** Valide et extrait le base64 du logo (data:image/xxx;base64,... ou base64 seul) */
function parseLogoDataUri(str) {
  if (!str || typeof str !== "string") return null;
  const s = str.trim();
  if (s.length < 20) return null;
  if (s.includes(";base64,")) {
    const parts = s.split(";base64,", 2);
    if (!/data:image\/(jpeg|jpg|png)/i.test(parts[0] || "")) return null;
    const part = parts[1];
    return part ? part.replace(/\s/g, "") : null;
  }
  if (/^[A-Za-z0-9+/=]+$/.test(s)) return s;
  return null;
}

/** Vérifie que le logo base64 fait max 2 Mo décodé */
function isLogoValid(base64) {
  if (!base64) return false;
  try {
    const bin = Buffer.from(base64, "base64");
    return bin.length > 0 && bin.length <= MAX_LOGO_BYTES;
  } catch {
    return false;
  }
}

async function upsertEvenementPref(pool, evId, key, value) {
  await pool.query(
    "INSERT INTO evenement_preferences (evenement_id, pref_key, pref_value) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE pref_value = VALUES(pref_value)",
    [evId, key, value]
  );
}

/** PUT /api/preferences - Admin only, met à jour les préférences de l'événement en cours */
router.put("/", requireAdmin, async (req, res) => {
  try {
    const { primaryColor, secondaryColor, logo, contactEmail, accueilTitre, accueilDescription } = req.body || {};
    let hasUpdate = false;
    const pool = await getPool();
    const evId = await getCurrentEvenementId(pool);
    if (!evId) {
      return res.status(400).json({ message: "Aucun événement actif — créez un événement d'abord" });
    }

    if (primaryColor !== undefined) {
      const hex = normalizeHex(primaryColor);
      if (!hex || !isValidHex(primaryColor)) {
        return res.status(400).json({ message: "primaryColor invalide (format: #RRGGBB)" });
      }
      await upsertEvenementPref(pool, evId, "primaryColor", hex);
      hasUpdate = true;
    }
    if (secondaryColor !== undefined) {
      const hex = normalizeHex(secondaryColor);
      if (!hex || !isValidHex(secondaryColor)) {
        return res.status(400).json({ message: "secondaryColor invalide (format: #RRGGBB)" });
      }
      await upsertEvenementPref(pool, evId, "secondaryColor", hex);
      hasUpdate = true;
    }
    if (logo !== undefined) {
      if (logo === null || logo === "") {
        await pool.query("DELETE FROM evenement_preferences WHERE evenement_id = ? AND pref_key = 'logo'", [evId]);
      } else {
        const base64 = parseLogoDataUri(logo);
        if (!base64 || !isLogoValid(base64)) {
          return res.status(400).json({
            message: "Logo invalide. Format : JPG ou PNG uniquement. Taille max : 2 Mo.",
          });
        }
        const toStore = logo.includes(";base64,") ? logo : `data:image/png;base64,${base64}`;
        await upsertEvenementPref(pool, evId, "logo", toStore);
      }
      hasUpdate = true;
    }
    if (contactEmail !== undefined) {
      const val = typeof contactEmail === "string" ? contactEmail.trim() : "";
      await upsertEvenementPref(pool, evId, "contactEmail", val);
      hasUpdate = true;
    }
    if (accueilTitre !== undefined) {
      const val = typeof accueilTitre === "string" ? accueilTitre.trim() : "";
      await upsertEvenementPref(pool, evId, "accueilTitre", val);
      hasUpdate = true;
    }
    if (accueilDescription !== undefined) {
      const val = typeof accueilDescription === "string" ? String(accueilDescription) : "";
      await upsertEvenementPref(pool, evId, "accueilDescription", val);
      hasUpdate = true;
    }

    if (!hasUpdate) {
      return res.status(400).json({ message: "Aucune préférence à modifier" });
    }

    const rows = await loadPreferenceRows(pool);
    res.json(prefsToObject(rows));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
