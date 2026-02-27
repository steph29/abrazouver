/**
 * Configuration PM2 pour Abrazouver API
 * Usage: pm2 start ecosystem.config.cjs
 * Déploiement: pm2 start ecosystem.config.cjs --env production
 */
module.exports = {
  apps: [
    {
      name: "abrazouver-api",
      script: "server.js",
      cwd: __dirname,
      instances: 1,
      exec_mode: "fork",
      env: { NODE_ENV: "development" },
      env_production: { NODE_ENV: "production" },
      // Migration BDD exécutée automatiquement via npm prestart
      // si vous utilisez "npm start" au lieu de "node server.js"
    },
  ],
};
