/**
 * Gestion des clients (tenants) - accessible uniquement via api.admin.xxx
 */
const express = require("express");
const { exec } = require("child_process");
const path = require("path");
const router = express.Router();
const registry = require("../config/registry");
const { requireAdminTenant } = require("../middleware/tenant");
const { initSchemaForTenantConfig } = require("../config/database");

const SUPER_ADMIN_SECRET = process.env.SUPER_ADMIN_SECRET || "change-me-in-production";
const PROVISION_DOMAIN = process.env.PROVISION_DOMAIN || "steph-verardo.fr";
const PROVISION_SCRIPT = process.env.PROVISION_SCRIPT_PATH || path.join(__dirname, "..", "scripts", "provision-ssl.sh");
const PROVISION_ENABLED = process.env.PROVISION_ENABLED === "true" || process.env.PROVISION_ENABLED === "1";

function requireSuperAdmin(req, res, next) {
  const secret = req.headers["x-super-admin-secret"] || req.body?.superAdminSecret;
  if (secret !== SUPER_ADMIN_SECRET) {
    return res.status(401).json({ message: "Authentification super-admin requise" });
  }
  next();
}

function buildApiDomains() {
  const tenants = registry.listTenants();
  const base = PROVISION_DOMAIN.toLowerCase();
  const basePart = base.split(".")[0] || base; // ex: steph-verardo
  const domains = [];
  // API
  for (const t of tenants) {
    const sub = (t.subdomain || "").toLowerCase().trim();
    if (!sub) continue;
    const d = sub === basePart ? `api.${base}` : `api.${sub}.${base}`;
    if (!domains.includes(d)) domains.push(d);
  }
  if (!domains.includes(`api.admin.${base}`)) domains.push(`api.admin.${base}`);
  // App (app.xxx et www.app.xxx)
  for (const t of tenants) {
    const sub = (t.subdomain || "").toLowerCase().trim();
    if (!sub) continue;
    const d = sub === basePart ? `app.${base}` : `app.${sub}.${base}`;
    if (!domains.includes(d)) domains.push(d);
    const w = sub === basePart ? `www.app.${base}` : `www.app.${sub}.${base}`;
    if (!domains.includes(w)) domains.push(w);
  }
  if (!domains.includes(`app.admin.${base}`)) domains.push(`app.admin.${base}`);
  if (!domains.includes(`www.app.admin.${base}`)) domains.push(`www.app.admin.${base}`);
  return domains;
}

/** GET /api/superadmin/tenants - Liste des clients */
router.get("/", requireAdminTenant, requireSuperAdmin, (req, res) => {
  try {
    const tenants = registry.listTenants();
    res.json({ tenants });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** POST /api/superadmin/tenants - Ajouter un client */
router.post("/", requireAdminTenant, requireSuperAdmin, async (req, res) => {
  try {
    const { subdomain, clientName, dbHost, dbPort, dbUser, dbPassword, dbName } = req.body || {};
    const data = {
      subdomain: subdomain || clientName,
      clientName: clientName || subdomain,
      dbHost,
      dbPort,
      dbUser,
      dbPassword: dbPassword ?? "",
      dbName,
    };
    if (!data.dbHost || !data.dbUser || !data.dbName) {
      return res.status(400).json({
        message: "subdomain, clientName, dbHost, dbUser, dbName requis",
      });
    }
    registry.addTenant(data);
    if (process.env.AUTO_INIT_SCHEMA !== "false") {
      try {
        await initSchemaForTenantConfig(data);
      } catch (schemaErr) {
        const added = registry.listTenants().find((t) => t.subdomain === (data.subdomain || "").toLowerCase());
        if (added) registry.deleteTenant(added.id);
        return res.status(400).json({
          message: "Client ajouté au registry mais échec de l'initialisation du schéma sur la DB",
          details: schemaErr.message,
        });
      }
    }
    const tenants = registry.listTenants();
    const added = tenants.find((t) => t.subdomain === (data.subdomain || "").toLowerCase());
    res.status(201).json(added || { subdomain: data.subdomain });
  } catch (err) {
    if (err.message?.includes("UNIQUE constraint")) {
      return res.status(400).json({ message: "Ce sous-domaine existe déjà" });
    }
    res.status(500).json({ message: err.message });
  }
});

/** POST /api/superadmin/tenants/:id/init-schema - Appliquer le schéma sur la DB du client (création des tables manquantes) */
router.post("/:id/init-schema", requireAdminTenant, requireSuperAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ message: "ID invalide" });
    const tenant = registry.getTenantById(id);
    if (!tenant) return res.status(404).json({ message: "Client non trouvé" });
    const config = {
      dbHost: tenant.dbHost,
      dbPort: tenant.dbPort || 3306,
      dbUser: tenant.dbUser,
      dbPassword: tenant.dbPassword ?? "",
      dbName: tenant.dbName,
    };
    await initSchemaForTenantConfig(config);
    res.json({ success: true, message: "Schéma appliqué" });
  } catch (err) {
    res.status(400).json({
      message: "Échec de l'initialisation du schéma",
      details: err.message,
    });
  }
});

/** POST /api/superadmin/tenants/test - Tester la connexion à une DB */
router.post("/test", requireAdminTenant, requireSuperAdmin, async (req, res) => {
  try {
    const { dbHost, dbPort, dbUser, dbPassword, dbName } = req.body || {};
    if (!dbHost || !dbUser || !dbName) {
      return res.status(400).json({ message: "dbHost, dbUser, dbName requis" });
    }
    await registry.testConnection({
      dbHost,
      dbPort: dbPort || 3306,
      dbUser,
      dbPassword: dbPassword ?? "",
      dbName,
    });
    res.json({ ok: true, message: "Connexion réussie" });
  } catch (err) {
    res.status(400).json({ message: "Connexion échouée: " + err.message });
  }
});

/** POST /api/superadmin/tenants/provision - Certificats SSL + nginx pour tous les clients */
router.post("/provision", requireAdminTenant, requireSuperAdmin, (req, res) => {
  if (!PROVISION_ENABLED) {
    return res.json({
      success: false,
      message: "Provision désactivé. Ajoutez PROVISION_ENABLED=true et PROVISION_DOMAIN dans .env, et configurez sudo pour le script.",
      details: `Script: ${PROVISION_SCRIPT}`,
    });
  }
  const domains = buildApiDomains();
  if (domains.length === 0) {
    return res.json({ success: false, message: "Aucun domaine à configurer. Ajoutez au moins un client." });
  }
  const domainList = domains.join(" ");
  const scriptPath = PROVISION_SCRIPT;
  const certName = PROVISION_DOMAIN;
  const cmd = `sudo "${scriptPath}" "${domainList}" "${certName}" 2>&1`;
  exec(cmd, { timeout: 120000 }, (err, stdout, stderr) => {
    const output = (stdout || "") + (stderr || "");
    try {
      const lastLine = output.trim().split("\n").filter(Boolean).pop() || "";
      const parsed = JSON.parse(lastLine);
      return res.json(parsed);
    } catch (_) {
      if (err) {
        return res.json({
          success: false,
          message: "Erreur lors du provisionnement",
          details: output.slice(-500) || err.message,
        });
      }
      return res.json({ success: true, message: "Provisionnement terminé" });
    }
  });
});

/** PUT /api/superadmin/tenants/:id - Modifier un client */
router.put("/:id", requireAdminTenant, requireSuperAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ message: "ID invalide" });
    const { subdomain, clientName, dbHost, dbPort, dbUser, dbPassword, dbName } = req.body || {};
    const data = {};
    if (subdomain !== undefined) data.subdomain = subdomain;
    if (clientName !== undefined) data.clientName = clientName;
    if (dbHost !== undefined) data.dbHost = dbHost;
    if (dbPort !== undefined) data.dbPort = dbPort;
    if (dbUser !== undefined) data.dbUser = dbUser;
    if (dbPassword !== undefined) data.dbPassword = dbPassword;
    if (dbName !== undefined) data.dbName = dbName;
    const updated = registry.updateTenant(id, data);
    if (!updated) return res.status(404).json({ message: "Client non trouvé" });
    if (process.env.AUTO_INIT_SCHEMA !== "false") {
      try {
        const tenant = registry.getTenantById(id);
        if (tenant) {
          await initSchemaForTenantConfig({
            dbHost: tenant.dbHost,
            dbPort: tenant.dbPort || 3306,
            dbUser: tenant.dbUser,
            dbPassword: tenant.dbPassword ?? "",
            dbName: tenant.dbName,
          });
        }
      } catch (schemaErr) {
        return res.status(200).json({
          ...updated,
          schemaApplied: false,
          schemaError: schemaErr.message,
        });
      }
    }
    res.json({ ...updated, schemaApplied: true });
  } catch (err) {
    if (err.message?.includes("UNIQUE constraint")) {
      return res.status(400).json({ message: "Ce sous-domaine existe déjà" });
    }
    res.status(500).json({ message: err.message });
  }
});

/** DELETE /api/superadmin/tenants/:id - Supprimer un client */
router.delete("/:id", requireAdminTenant, requireSuperAdmin, (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ message: "ID invalide" });
    const ok = registry.deleteTenant(id);
    if (!ok) return res.status(404).json({ message: "Client non trouvé" });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
