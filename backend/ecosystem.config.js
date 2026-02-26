/**
 * Configuration PM2 - Lancement permanent du serveur
 * Usage sur le VPS : pm2 start ecosystem.config.js
 */
module.exports = {
  apps: [
    {
      name: 'abrazouver-api',
      script: 'server.js',
      cwd: __dirname,
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '200M',
      env: {
        NODE_ENV: 'production',
      },
    },
  ],
};
