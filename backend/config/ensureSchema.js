/**
 * Crée les tables si elles n'existent pas (migration automatique au démarrage).
 * Utilisé par database.js au premier accès à la base.
 */
const fs = require("fs");
const path = require("path");

const SCHEMA_SQL = path.join(__dirname, "..", "scripts", "schema.sql");

function isDuplicateKeyError(err) {
  return err.code === "ER_DUP_KEYNAME" || /duplicate key name/i.test(err.message || "");
}

async function ensureSchema(pool) {
  const sql = fs.readFileSync(SCHEMA_SQL, "utf8");
  const statements = sql
    .split(";")
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && !s.startsWith("--"));
  const conn = await pool.getConnection();
  try {
    for (const stmt of statements) {
      if (!stmt) continue;
      try {
        await conn.query(stmt);
      } catch (err) {
        if (isDuplicateKeyError(err)) {
          // Index existe déjà, on ignore
          continue;
        }
        throw err;
      }
    }
    console.log("✅ Schéma de la base vérifié (tables créées ou à jour)");
  } finally {
    conn.release();
  }
}

module.exports = { ensureSchema };
