const express = require("express");
const router = express.Router();
const { getPool } = require("../config/database");

const DEFAULTS = {
  primaryColor: "#4CAF50",
  secondaryColor: "#2b5a72",
};

/** Convertit une map { primaryColor, secondaryColor } en objet lisible */
function prefsToObject(rows) {
  const obj = {};
  for (const r of rows) {
    obj[r.pref_key] = r.pref_value ?? DEFAULTS[r.pref_key];
  }
  return {
    primaryColor: obj.primaryColor ?? DEFAULTS.primaryColor,
    secondaryColor: obj.secondaryColor ?? DEFAULTS.secondaryColor,
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

/** GET /api/preferences - Public, pour le thème de l'app */
router.get("/", async (req, res) => {
  try {
    const pool = await getPool();
    const [rows] = await pool.query("SELECT pref_key, pref_value FROM app_preferences");
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

/** PUT /api/preferences - Admin only, met à jour les préférences */
router.put("/", requireAdmin, async (req, res) => {
  try {
    const { primaryColor, secondaryColor } = req.body || {};
    let hasUpdate = false;
    const pool = await getPool();

    if (primaryColor !== undefined) {
      const hex = normalizeHex(primaryColor);
      if (!hex || !isValidHex(primaryColor)) {
        return res.status(400).json({ message: "primaryColor invalide (format: #RRGGBB)" });
      }
      await pool.query(
        "INSERT INTO app_preferences (pref_key, pref_value) VALUES ('primaryColor', ?) ON DUPLICATE KEY UPDATE pref_value = VALUES(pref_value)",
        [hex]
      );
      hasUpdate = true;
    }
    if (secondaryColor !== undefined) {
      const hex = normalizeHex(secondaryColor);
      if (!hex || !isValidHex(secondaryColor)) {
        return res.status(400).json({ message: "secondaryColor invalide (format: #RRGGBB)" });
      }
      await pool.query(
        "INSERT INTO app_preferences (pref_key, pref_value) VALUES ('secondaryColor', ?) ON DUPLICATE KEY UPDATE pref_value = VALUES(pref_value)",
        [hex]
      );
      hasUpdate = true;
    }

    if (!hasUpdate) {
      return res.status(400).json({ message: "Aucune préférence à modifier" });
    }

    const [rows] = await pool.query("SELECT pref_key, pref_value FROM app_preferences");
    res.json(prefsToObject(rows));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
