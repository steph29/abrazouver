require("dotenv").config();
const { AsyncLocalStorage } = require("async_hooks");
const mysql = require("mysql2/promise");
const { ensureSchema } = require("./ensureSchema");
const { getTenantBySubdomain } = require("./registry");

/** Contexte de requête (tenantId) accessible partout */
const requestContext = new AsyncLocalStorage();

/** Pools MySQL par tenant (cache) */
const poolByTenant = new Map();

/**
 * Extrait l'identifiant tenant du Host.
 * Ex: api.client1.abrazouver.fr -> client1
 *     api.admin.steph-verardo.fr -> admin
 *     www.app.enest-fest.steph-verardo.fr -> enest-fest
 *     app.admin.xxx -> admin (quand le proxy envoie l'origine au lieu de la cible)
 */
function getTenantFromHost(host) {
  if (!host || typeof host !== "string") return null;
  const parts = host.toLowerCase().split(".").map((p) => p.split(":")[0]); // ignore port
  // www.app.xxx.domain -> xxx
  if (parts.length >= 5 && parts[0] === "www" && parts[1] === "app") return parts[2];
  if (parts.length >= 4 && (parts[0] === "api" || parts[0] === "app")) return parts[1];
  if (parts.length === 3 && parts[0] === "api") return parts[1];
  return null;
}

/**
 * Retourne le pool MySQL pour le tenant. Utilise le cache.
 */
async function getPoolForTenant(tenantId) {
  if (!tenantId) return null;
  const cached = poolByTenant.get(tenantId);
  if (cached) return cached;

  const tenant = getTenantBySubdomain(tenantId);
  if (!tenant) {
    throw new Error(`Client "${tenantId}" inconnu. Ajoutez-le dans la configuration.`);
  }

  const config = {
    host: tenant.dbHost,
    port: tenant.dbPort || 3306,
    user: tenant.dbUser,
    password: tenant.dbPassword,
    database: tenant.dbName,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    multipleStatements: true,
  };

  const pool = mysql.createPool(config);
  try {
    const conn = await pool.getConnection();
    let db = config.database;
    let tables = [];
    try {
      const [[row]] = await conn.query("SELECT DATABASE() as d");
      db = row?.d || db;
      [tables] = await conn.query("SHOW TABLES");
    } catch (_) {}
    conn.release();
    if (process.env.NODE_ENV !== "test") {
      console.log(`✅ Connexion [${tenantId}] → ${config.host}:${config.port}/${db}`);
    }
    if (process.env.AUTO_INIT_SCHEMA !== "false") {
      await ensureSchema(pool);
    }
    poolByTenant.set(tenantId, pool);
    return pool;
  } catch (err) {
    pool.end();
    throw err;
  }
}

/**
 * Retourne le pool pour la requête courante.
 * Utilise le tenantId du contexte (middleware tenant).
 */
async function getPool() {
  const ctx = requestContext.getStore();
  const tenantId = ctx?.tenantId;
  if (!tenantId) {
    throw new Error("Tenant non identifié. Utilisez api.client.xxx pour accéder à l'application.");
  }
  return getPoolForTenant(tenantId);
}

/** Expose le stockage de contexte (pour le middleware) */
function runWithTenant(tenantId, fn) {
  return requestContext.run({ tenantId }, fn);
}

/**
 * Applique le schéma sur une DB à partir de sa config (utilisé à la création d'un tenant).
 * Crée un pool temporaire, applique schema.sql, puis ferme le pool.
 */
async function initSchemaForTenantConfig(config) {
  const pool = mysql.createPool({
    host: config.dbHost,
    port: config.dbPort || 3306,
    user: config.dbUser,
    password: config.dbPassword ?? "",
    database: config.dbName,
    waitForConnections: true,
    connectionLimit: 2,
    multipleStatements: true,
  });
  try {
    await ensureSchema(pool);
  } finally {
    await pool.end();
  }
}

/** Ancienne config pour compatibilité (utilisée par migrate, seed) */
const dbConfig = {
  host: process.env.DB_HOST || "localhost",
  port: parseInt(process.env.DB_PORT, 10) || 3306,
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "abrazouver_apel",
};

module.exports = {
  getPool,
  getPoolForTenant,
  getTenantFromHost,
  runWithTenant,
  initSchemaForTenantConfig,
  dbConfig,
};
