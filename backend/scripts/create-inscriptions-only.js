/**
 * Crée UNIQUEMENT la table inscriptions.
 * Usage : node scripts/create-inscriptions-only.js
 * Utile si npm run migrate a réussi mais inscriptions manque encore.
 */
require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const mysql = require("mysql2/promise");
const fs = require("fs");
const path = require("path");

const dbConfig = {
  host: process.env.DB_HOST || "localhost",
  port: parseInt(process.env.DB_PORT || "3306", 10),
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "abrazouver_apel",
};

async function main() {
  const sqlPath = path.join(__dirname, "create-inscriptions.sql");
  const sql = fs.readFileSync(sqlPath, "utf8");

  console.log(`Connexion à ${dbConfig.host}:${dbConfig.port} / ${dbConfig.database}...`);
  const conn = await mysql.createConnection(dbConfig);
  try {
    await conn.query(sql);
    const [[r]] = await conn.query("SHOW TABLES LIKE 'inscriptions'");
    if (r) {
      console.log("✅ Table inscriptions créée ou déjà existante.");
    } else {
      console.log("⚠️  Requête exécutée mais table introuvable (vérifiez les FK users/creneaux).");
    }
  } catch (err) {
    console.error("❌ Erreur:", err.message);
    process.exit(1);
  } finally {
    await conn.end();
  }
}

main();
