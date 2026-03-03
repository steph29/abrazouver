#!/usr/bin/env bash
# Déploiement Abrazouver - Backend
# Usage: ./deploy.sh  (à exécuter depuis le dossier backend)
# Ou: bash deploy.sh

set -e
cd "$(dirname "$0")"

echo "📦 Déploiement Abrazouver API..."
echo ""

# 1. Mise à jour des dépendances (si package.json a changé)
echo "1/3 - Installation des dépendances..."
npm ci --omit=dev 2>/dev/null || npm install --production 2>/dev/null || npm install
echo "   ✓ Dépendances à jour"
echo ""

# 2. Script provision exécutable
chmod +x scripts/provision-ssl.sh 2>/dev/null || true

# 3. Migration base de données (crée/met à jour toutes les tables de schema.sql)
echo "2/3 - Migration base de données..."
npm run migrate
echo ""

# 4. Redémarrage PM2
echo "3/3 - Redémarrage de l'API..."
if pm2 describe abrazouver-api &>/dev/null; then
  pm2 restart abrazouver-api
  echo "   ✓ API redémarrée"
else
  pm2 start ecosystem.config.cjs --env production
  echo "   ✓ API démarrée (nouvelle instance)"
fi

echo ""
echo "✅ Déploiement terminé."
pm2 list
