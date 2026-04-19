const { getPool } = require("../config/database");

/**
 * Authentifie X-User-Id et autorise administrateurs + référents ayant au moins un poste.
 * Renseigne req.posteAccess = { userId, isAdmin, referentPosteIds }
 */
async function requirePosteManagementAuth(req, res, next) {
  const userIdHeader = req.headers["x-user-id"];
  if (!userIdHeader) {
    return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
  }
  const userId = parseInt(userIdHeader, 10);
  if (Number.isNaN(userId)) {
    return res.status(401).json({ message: "X-User-Id invalide" });
  }
  try {
    const pool = await getPool();
    const [[u]] = await pool.query("SELECT id, is_admin FROM users WHERE id = ?", [userId]);
    if (!u) {
      return res.status(401).json({ message: "Utilisateur introuvable" });
    }
    const [rps] = await pool.query("SELECT poste_id FROM referent_postes WHERE user_id = ?", [userId]);
    const referentPosteIds = rps.map((r) => Number(r.poste_id));
    const isAdmin = !!u.is_admin;
    if (!isAdmin && referentPosteIds.length === 0) {
      return res.status(403).json({ message: "Accès réservé aux administrateurs et aux référents de poste" });
    }
    req.posteAccess = { userId, isAdmin, referentPosteIds };
    next();
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

function canManagePoste(access, posteId) {
  if (!access) return false;
  if (access.isAdmin) return true;
  const pid = Number(posteId);
  return access.referentPosteIds.includes(pid);
}

module.exports = { requirePosteManagementAuth, canManagePoste };
