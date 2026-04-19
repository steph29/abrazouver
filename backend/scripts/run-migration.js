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
    await conn.query("ALTER TABLE users ADD COLUMN password_reset_token VARCHAR(64) DEFAULT NULL").catch(() => {});
    await conn.query("ALTER TABLE users ADD COLUMN password_reset_expires_at DATETIME DEFAULT NULL").catch(() => {});
    await conn.query(`
      INSERT IGNORE INTO app_preferences (pref_key, pref_value) VALUES
        ('primaryColor', '#4CAF50'),
        ('secondaryColor', '#2b5a72'),
        ('contactEmail', ''),
        ('accueilTitre', ''),
        ('accueilDescription', '')
    `);

    // Créer benevoles_manuels (inscrits à la main, sans compte)
    await conn.query(`
      CREATE TABLE IF NOT EXISTS benevoles_manuels (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nom VARCHAR(100) NOT NULL,
        prenom VARCHAR(100) NOT NULL,
        annee INT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        KEY idx_annee (annee)
      )
    `).catch(() => {});

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

    await conn.query("ALTER TABLE users ADD COLUMN user_with INT NULL DEFAULT NULL AFTER is_admin").catch(() => {});
    await conn.query("ALTER TABLE users ADD KEY idx_users_user_with (user_with)").catch(() => {});
    await conn
      .query(
        "ALTER TABLE users ADD CONSTRAINT fk_users_user_with FOREIGN KEY (user_with) REFERENCES users(id) ON DELETE CASCADE"
      )
      .catch(() => {});

    await conn.query("ALTER TABLE users MODIFY email VARCHAR(255) NULL").catch(() => {});
    await conn.query("ALTER TABLE users MODIFY password_hash VARCHAR(255) NULL").catch(() => {});

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

    // --- Événements (plusieurs par an, postes et préférences liés) ---
    await conn
      .query(
        `CREATE TABLE IF NOT EXISTS evenements (
          id INT AUTO_INCREMENT PRIMARY KEY,
          nom VARCHAR(255) NOT NULL,
          description TEXT,
          date_debut DATETIME NOT NULL,
          date_fin DATETIME NOT NULL,
          annee INT NOT NULL,
          notes_json MEDIUMTEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )`
      )
      .catch(() => {});
    await conn
      .query(
        `CREATE TABLE IF NOT EXISTS evenement_preferences (
          evenement_id INT NOT NULL,
          pref_key VARCHAR(100) NOT NULL,
          pref_value MEDIUMTEXT,
          PRIMARY KEY (evenement_id, pref_key),
          CONSTRAINT fk_evenement_preferences_evenement FOREIGN KEY (evenement_id) REFERENCES evenements(id) ON DELETE CASCADE
        )`
      )
      .catch(() => {});

    await conn.query("ALTER TABLE postes ADD COLUMN evenement_id INT NULL").catch(() => {});

    const [[evCountRow]] = await conn.query("SELECT COUNT(*) as n FROM evenements");
    if (Number(evCountRow?.n || 0) === 0) {
      const y = new Date().getFullYear();
      const deb = `${y}-01-01 00:00:00`;
      const fin = `${y}-12-31 23:59:59`;
      await conn.query(
        `INSERT INTO evenements (nom, description, date_debut, date_fin, annee, notes_json) VALUES (?, NULL, ?, ?, ?, '[]')`,
        ["Événement principal", deb, fin, y]
      );
    }

    const [[firstEv]] = await conn.query("SELECT id FROM evenements ORDER BY id ASC LIMIT 1");
    const defaultEvId = firstEv?.id;
    if (defaultEvId) {
      await conn.query("UPDATE postes SET evenement_id = ? WHERE evenement_id IS NULL", [defaultEvId]).catch(() => {});
      await conn.query("ALTER TABLE postes MODIFY COLUMN evenement_id INT NOT NULL").catch(() => {});
      await conn
        .query(
          "ALTER TABLE postes ADD CONSTRAINT fk_postes_evenement FOREIGN KEY (evenement_id) REFERENCES evenements(id) ON DELETE RESTRICT"
        )
        .catch(() => {});
      await conn.query("INSERT IGNORE INTO app_preferences (pref_key, pref_value) VALUES ('currentEvenementId', ?)", [
        String(defaultEvId),
      ]);

      const [[prefCountRow]] = await conn.query(
        "SELECT COUNT(*) as n FROM evenement_preferences WHERE evenement_id = ?",
        [defaultEvId]
      );
      if (Number(prefCountRow?.n || 0) === 0) {
        const [prefRows] = await conn.query(
          "SELECT pref_key, pref_value FROM app_preferences WHERE pref_key IN ('primaryColor','secondaryColor','logo','contactEmail','accueilTitre','accueilDescription')"
        );
        for (const pr of prefRows) {
          await conn.query(
            "INSERT INTO evenement_preferences (evenement_id, pref_key, pref_value) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE pref_value = VALUES(pref_value)",
            [defaultEvId, pr.pref_key, pr.pref_value]
          );
        }
      }
    }

    await conn
      .query(
        `CREATE TABLE IF NOT EXISTS referent_postes (
          user_id INT NOT NULL,
          poste_id INT NOT NULL,
          PRIMARY KEY (user_id, poste_id),
          CONSTRAINT fk_referent_postes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          CONSTRAINT fk_referent_postes_poste FOREIGN KEY (poste_id) REFERENCES postes(id) ON DELETE CASCADE
        )`
      )
      .catch(() => {});

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
