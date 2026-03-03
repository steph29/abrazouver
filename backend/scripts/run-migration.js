/**
 * Module de migration partagé.
 * Lit schema.sql et exécute toutes les instructions.
 * Utilisé par init-db.js, deploy et au démarrage du serveur.
 *
 * Pour ajouter de nouvelles tables : éditez schema.sql uniquement.
 */
require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const mysql = require("mysql2/promise");
const fs = require("fs");
const path = require("path");

/** Erreurs MySQL qu'on peut ignorer (objet déjà existant) */
function isIgnorableError(err) {
  if (!err || !err.code) return false;
  const code = err.code;
  const msg = (err.message || "").toLowerCase();
  return (
    code === "ER_DUP_KEYNAME" ||
    code === "ER_DUP_INDEX" ||
    code === "ER_DUP_FIELDNAME" ||
    code === "ER_TABLE_EXISTS" ||
    code === "ER_DUP_ENTRY" ||
    /duplicate key name/i.test(msg) ||
    /duplicate column name/i.test(msg) ||
    /already exists/i.test(msg)
  );
}

async function runMigration(options = {}) {
  const verbose = options.verbose !== false;
  const schemaPath = path.join(__dirname, "schema.sql");
  if (!fs.existsSync(schemaPath)) {
    throw new Error(`schema.sql introuvable : ${schemaPath}`);
  }
  const sql = fs.readFileSync(schemaPath, "utf8");
  const statements = sql
    .split(";")
    .map((s) =>
      s
        .split("\n")
        .filter((line) => !line.trim().startsWith("--"))
        .join("\n")
        .trim()
    )
    .filter((s) => s.length > 0);

  const dbConfig = {
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT || "3306", 10),
    user: process.env.DB_USER || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_NAME || "abrazouver_apel",
  };

  let conn;
  if (options.pool) {
    conn = await options.pool.getConnection();
  } else {
    if (verbose) {
      console.log(`   Connexion à ${dbConfig.host}:${dbConfig.port} / ${dbConfig.database}...`);
    }
    conn = await mysql.createConnection(dbConfig);
  }
  try {
    // Créer app_preferences en premier (résilient si schema.sql incomplet via FTP)
    await conn.query(`
      CREATE TABLE IF NOT EXISTS app_preferences (
        pref_key VARCHAR(100) PRIMARY KEY,
        pref_value MEDIUMTEXT
      )
    `);
    await conn.query("ALTER TABLE app_preferences MODIFY pref_value MEDIUMTEXT").catch(() => {});
    await conn.query(`
      INSERT IGNORE INTO app_preferences (pref_key, pref_value) VALUES
        ('primaryColor', '#4CAF50'),
        ('secondaryColor', '#2b5a72'),
        ('contactEmail', ''),
        ('accueilTitre', ''),
        ('accueilDescription', '')
    `);

    // Créer contact_messages ici (résilient si schema.sql non mis à jour via FTP)
    await conn.query(`
      CREATE TABLE IF NOT EXISTS contact_messages (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        email VARCHAR(255) NOT NULL,
        subject VARCHAR(500) NOT NULL,
        body TEXT NOT NULL,
        attachment_name VARCHAR(255) DEFAULT NULL,
        attachment_data MEDIUMBLOB DEFAULT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        KEY idx_contact_user (user_id),
        KEY idx_contact_created (created_at)
      )
    `);

    for (const stmt of statements) {
      if (!stmt) continue;
      try {
        await conn.query(stmt);
      } catch (err) {
        if (isIgnorableError(err)) {
          if (verbose) console.log("   (déjà existant, ignoré)");
          continue;
        }
        if (verbose) {
          console.error("   Erreur sur:", stmt.substring(0, 60) + "...");
          console.error("   ", err.message);
        }
        throw err;
      }
    }
    if (verbose) console.log("   ✅ Schéma BDD appliqué.");
    return true;
  } finally {
    if (options.pool) {
      conn.release();
    } else {
      await conn.end();
    }
  }
}

module.exports = { runMigration, isIgnorableError };
