/**
 * Crée les tables si elles n'existent pas (migration automatique au démarrage).
 * Utilisé par database.js au premier accès à la base.
 */
const fs = require("fs");
const path = require("path");

const SCHEMA_SQL = path.join(__dirname, "..", "scripts", "schema.sql");

async function ensureSchema(pool) {
  const sql = fs.readFileSync(SCHEMA_SQL, "utf8");
  const conn = await pool.getConnection();
  try {
    await conn.query(sql);
    console.log("✅ Schéma de la base vérifié (tables créées ou à jour)");
  } catch (err) {
    console.error("❌ Erreur init schéma:", err.message);
    if (err.code) console.error("   Code:", err.code);
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { ensureSchema };
