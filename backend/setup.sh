#!/usr/bin/env bash
# Premier déploiement Abrazouver
# Usage: ./setup.sh  (à exécuter depuis le dossier backend)
#
# Ce script : copie .env.example → .env si absent, puis lance deploy.sh
# Après copie, éditez .env avec vos identifiants DB et JWT_SECRET avant de relancer.
set -e
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "📋 Configuration initiale..."
  cp .env.example .env
  echo ""
  echo "⚠️  Fichier .env créé à partir de .env.example"
  echo "   Éditez .env avec vos identifiants (DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, JWT_SECRET, CORS_ORIGINS)."
  echo ""
  echo "   Exemple : nano .env"
  echo ""
  echo "   Puis relancez : ./setup.sh"
  exit 0
fi

echo "🚀 Lancement du déploiement..."
./deploy.sh
