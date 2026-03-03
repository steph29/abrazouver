/**
 * Registry des tenants (clients) - SQLite
 * Stocke la correspondance sous-domaine <-> config Cloud DB
 */
const Database = require("better-sqlite3");
const path = require("path");
const fs = require("fs");

const REGISTRY_PATH = process.env.REGISTRY_PATH || path.join(__dirname, "..", "data", "tenants.db");

function ensureDataDir() {
  const dir = path.dirname(REGISTRY_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function getDb() {
  ensureDataDir();
  const db = new Database(REGISTRY_PATH);
  db.exec(`
    CREATE TABLE IF NOT EXISTS tenants (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subdomain TEXT NOT NULL UNIQUE,
      client_name TEXT NOT NULL,
      db_host TEXT NOT NULL,
      db_port INTEGER NOT NULL DEFAULT 3306,
      db_user TEXT NOT NULL,
      db_password TEXT NOT NULL,
      db_name TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    )
  `);
  return db;
}

function listTenants() {
  const db = getDb();
  try {
    const rows = db.prepare("SELECT * FROM tenants ORDER BY client_name").all();
    return rows.map((r) => ({
      id: r.id,
      subdomain: r.subdomain,
      clientName: r.client_name,
      dbHost: r.db_host,
      dbPort: r.db_port,
      dbUser: r.db_user,
      dbName: r.db_name,
      createdAt: r.created_at,
    }));
  } finally {
    db.close();
  }
}

function getTenantBySubdomain(subdomain) {
  const db = getDb();
  try {
    const row = db.prepare("SELECT * FROM tenants WHERE subdomain = ?").get(subdomain.toLowerCase());
    return row
      ? {
          id: row.id,
          subdomain: row.subdomain,
          clientName: row.client_name,
          dbHost: row.db_host,
          dbPort: row.db_port,
          dbUser: row.db_user,
          dbPassword: row.db_password,
          dbName: row.db_name,
        }
      : null;
  } finally {
    db.close();
  }
}

function addTenant(data) {
  const db = getDb();
  try {
    const sub = (data.subdomain || "").toLowerCase().trim();
    if (!sub) throw new Error("subdomain requis");
    const stmt = db.prepare(`
      INSERT INTO tenants (subdomain, client_name, db_host, db_port, db_user, db_password, db_name)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);
    stmt.run(
      sub,
      (data.clientName || "").trim() || sub,
      (data.dbHost || "").trim(),
      parseInt(data.dbPort, 10) || 3306,
      (data.dbUser || "").trim(),
      data.dbPassword ?? "",
      (data.dbName || "").trim()
    );
    return { subdomain: sub };
  } finally {
    db.close();
  }
}

function updateTenant(id, data) {
  const db = getDb();
  try {
    const existing = db.prepare("SELECT * FROM tenants WHERE id = ?").get(id);
    if (!existing) return null;
    const sub = (data.subdomain ?? existing.subdomain).toString().toLowerCase().trim();
    if (!sub) throw new Error("subdomain requis");
    const stmt = db.prepare(`
      UPDATE tenants SET
        subdomain = ?, client_name = ?, db_host = ?, db_port = ?, db_user = ?, db_password = ?, db_name = ?
      WHERE id = ?
    `);
    stmt.run(
      sub,
      (data.clientName != null ? data.clientName : (existing.client_name || sub)).toString().trim(),
      (data.dbHost ?? existing.db_host).toString().trim(),
      parseInt(data.dbPort ?? existing.db_port, 10) || 3306,
      (data.dbUser ?? existing.db_user).toString().trim(),
      data.dbPassword !== undefined ? data.dbPassword : existing.db_password,
      (data.dbName ?? existing.db_name).toString().trim(),
      id
    );
    const updated = db.prepare("SELECT * FROM tenants WHERE id = ?").get(id);
    return updated
      ? {
          id: updated.id,
          subdomain: updated.subdomain,
          clientName: updated.client_name,
          dbHost: updated.db_host,
          dbPort: updated.db_port,
          dbUser: updated.db_user,
          dbName: updated.db_name,
          createdAt: updated.created_at,
        }
      : null;
  } finally {
    db.close();
  }
}

function getTenantById(id) {
  const db = getDb();
  try {
    const row = db.prepare("SELECT * FROM tenants WHERE id = ?").get(id);
    return row
      ? {
          id: row.id,
          subdomain: row.subdomain,
          clientName: row.client_name,
          dbHost: row.db_host,
          dbPort: row.db_port,
          dbUser: row.db_user,
          dbPassword: row.db_password,
          dbName: row.db_name,
          createdAt: row.created_at,
        }
      : null;
  } finally {
    db.close();
  }
}

function deleteTenant(id) {
  const db = getDb();
  try {
    const result = db.prepare("DELETE FROM tenants WHERE id = ?").run(id);
    return result.changes > 0;
  } finally {
    db.close();
  }
}

function testConnection(config) {
  const mysql = require("mysql2/promise");
  return mysql
    .createConnection({
      host: config.dbHost,
      port: config.dbPort || 3306,
      user: config.dbUser,
      password: config.dbPassword,
      database: config.dbName,
      connectTimeout: 5000,
    })
    .then((conn) => {
      conn.end();
      return true;
    });
}

module.exports = {
  listTenants,
  getTenantBySubdomain,
  getTenantById,
  addTenant,
  updateTenant,
  deleteTenant,
  testConnection,
};
