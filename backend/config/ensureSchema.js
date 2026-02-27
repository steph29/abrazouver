/**
 * Applique schema.sql via le module partagé.
 * Exécuté automatiquement au premier accès à la base.
 */
const { runMigration } = require("../scripts/run-migration");

async function ensureSchema(pool) {
  await runMigration({ pool, verbose: true });
}

module.exports = { ensureSchema };
