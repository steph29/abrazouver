/**
 * Exécute schema.sql sur la base configurée dans .env
 * Usage : node scripts/init-db.js   ou   npm run migrate
 */
const { runMigration } = require("./run-migration");

async function main() {
  console.log("Migration base de données...");
  await runMigration({ verbose: true });
  console.log("✅ Tables créées ou mises à jour.");
}

main().catch((err) => {
  console.error("❌ Erreur migration:", err.message);
  process.exit(1);
});
