/**
 * Middleware multi-tenant : extrait le client du Host et le stocke dans le contexte.
 * Ex: api.client1.abrazouver.fr -> tenantId = client1
 */
const { getTenantFromHost, runWithTenant } = require("../config/database");

function tenantMiddleware(req, res, next) {
  // Host prioritaire ; si IP/localhost (requête via proxy), utiliser X-Forwarded-Host
  let host = req.get("host") || req.hostname;
  const forwarded = req.get("x-forwarded-host");
  if (host && /^\d+\.\d+\.\d+\.\d+(:\d+)?$|^localhost(:\d+)?$/i.test(host.split(",")[0].trim()) && forwarded) {
    host = forwarded.split(",")[0].trim();
  } else if (forwarded && !host) {
    host = forwarded.split(",")[0].trim();
  }
  const tenantId = getTenantFromHost(host);

  if (!tenantId) {
    return res.status(400).json({
      message:
        "Tenant manquant. Utilisez l'URL avec sous-domaine client (ex: api.client1.votredomaine.fr)",
      debug: { host: host || "vide", expectedFormat: "api.admin.steph-verardo.fr ou api.steph-verardo.fr" },
    });
  }

  req.tenantId = tenantId;
  runWithTenant(tenantId, () => next());
}

/** Vérifie que la requête vient du sous-domaine admin (gestion des clients) */
function requireAdminTenant(req, res, next) {
  if (req.tenantId === "admin") return next();
  return res.status(403).json({ message: "Accès réservé au sous-domaine admin." });
}

module.exports = { tenantMiddleware, requireAdminTenant };
