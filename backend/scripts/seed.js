/**
 * Script de seed - Données de test pour Abrazouver
 * Usage : node scripts/seed.js
 * Prérequis : Base créée (init_db.sql), .env configuré
 */
// require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
require("dotenv").config();
const mysql = require("mysql2/promise");
const bcrypt = require("bcrypt");

const dbConfig = {
  host: process.env.DB_HOST || "localhost",
  port: parseInt(process.env.DB_PORT || "3306", 10),
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "abrazouver_apel",
};

const testUsers = [
  {
    email: "admin@abrazouver.fr",
    password: "admin123",
    nom: "Admin",
    prenom: "Abrazouver",
  },
  {
    email: "jean.dupont@test.fr",
    password: "test123",
    nom: "Dupont",
    prenom: "Jean",
  },
  {
    email: "marie.martin@test.fr",
    password: "test123",
    nom: "Martin",
    prenom: "Marie",
  },
];

const testItems = [
  { name: "Élément test 1", description: "Premier élément de démonstration" },
  { name: "Élément test 2", description: "Deuxième élément de démonstration" },
];

async function seed() {
  console.log("🌱 Chargement des données de test...\n");
  const conn = await mysql.createConnection(dbConfig);

  try {
    const [existingUsers] = await conn.query("SELECT COUNT(*) as n FROM users");
    if (existingUsers[0].n > 0) {
      console.log(
        "⚠️  La table users contient déjà des données. Passage des utilisateurs.",
      );
    } else {
      for (const u of testUsers) {
        const hash = await bcrypt.hash(u.password, 10);
        const isAdmin = u.email === "admin@abrazouver.fr" ? 1 : 0;
        await conn.query(
          "INSERT INTO users (email, password_hash, nom, prenom, is_admin) VALUES (?, ?, ?, ?, ?)",
          [u.email, hash, u.nom, u.prenom, isAdmin],
        );
        console.log(
          `   ✓ Utilisateur créé : ${u.email} (mot de passe: ${u.password})${isAdmin ? " [ADMIN]" : ""}`,
        );
      }
      console.log(`   → ${testUsers.length} utilisateur(s) inséré(s)\n`);
    }

    const [existingItems] = await conn.query("SELECT COUNT(*) as n FROM items");
    if (existingItems[0].n > 0) {
      console.log(
        "⚠️  La table items contient déjà des données. Passage des items.",
      );
    } else {
      for (const item of testItems) {
        await conn.query(
          "INSERT INTO items (name, description) VALUES (?, ?)",
          [item.name, item.description],
        );
      }
      console.log(`   ✓ ${testItems.length} item(s) inséré(s)\n`);
    }

    console.log("✅ Jeu de test chargé avec succès !");
    console.log("\nIdentifiants de connexion :");
    console.log("   - admin@abrazouver.fr / admin123");
    console.log("   - jean.dupont@test.fr / test123");
    console.log("   - marie.martin@test.fr / test123");
  } catch (err) {
    console.error("❌ Erreur :", err.message);
    if (err.code === "ER_BAD_DB_ERROR") {
      console.log(
        "\n→ Assurez-vous d'avoir exécuté init_db.sql et configuré DB_NAME dans .env",
      );
    }
    process.exit(1);
  } finally {
    await conn.end();
  }
}

seed();
