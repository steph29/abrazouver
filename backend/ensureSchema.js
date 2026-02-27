/**
 * Crée les tables si elles n'existent pas (migration automatique au démarrage).
 * Utilisé par database.js au premier accès à la base.
 */
const fs = require("fs");
const path = require("path");

const SCHEMA_SQL = path.join(__dirname, "..", "scripts", "schema.sql");

async function ensureSchema(pool) {
  try {
    const sql = fs.readFileSync(SCHEMA_SQL, "utf8");
    const statements = sql
      .split(";")
      .map((s) => s.trim())
      .filter((s) => s.length > 0 && !s.startsWith("--"));
    const conn = await pool.getConnection();
    try {
      for (const stmt of statements) {
        if (stmt) await conn.query(stmt);
      }
      console.log("✅ Schéma de la base vérifié (tables créées ou à jour)");
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error("⚠️  Init schéma:", err.message);
  }
}

module.exports = { ensureSchema };
