# Déploiement Abrazouver

## Premier déploiement (nouveau VPS / nouvelle DB)

```bash
cd backend
chmod +x setup.sh deploy.sh
./setup.sh
```

1. Si `.env` n'existe pas : il est créé depuis `.env.example`. **Éditez-le** (DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, JWT_SECRET, CORS_ORIGINS), puis relancez `./setup.sh`
2. Sinon : le script lance `deploy.sh` (migrations + PM2)

---

## Déploiement habituel (une seule commande)

```bash
cd backend
./deploy.sh
```

Le script exécute :
1. `npm install` (dépendances)
2. `npm run migrate` (création/mise à jour de **toutes** les tables de `schema.sql`)
3. `pm2 restart abrazouver-api` (ou démarrage si première fois)

---

## Déploiement via Git

```bash
cd backend
git pull
./deploy.sh
```

---

## Migrations automatiques

- **Au déploiement** : `deploy.sh` lance `npm run migrate`
- **Au démarrage** : le serveur applique `schema.sql` si des tables manquent

Pour ajouter des tables : éditez `backend/scripts/schema.sql`, déployez, c’est tout.

---

## Fichiers nécessaires

| Fichier | Rôle |
|---------|------|
| `backend/.env` | Config (DB, JWT, CORS) |
| `backend/scripts/schema.sql` | Schéma BDD (toutes les tables) |
| `backend/deploy.sh` | Script de déploiement |
| `backend/setup.sh` | Premier déploiement (crée .env) |
| `backend/ecosystem.config.cjs` | Config PM2 |

---

## Dépannage

| Problème | Solution |
|----------|----------|
| `deploy.sh: Permission denied` | `chmod +x deploy.sh setup.sh` |
| Base vide | Vérifiez .env (DB_HOST, DB_USER, DB_PASSWORD, DB_NAME) puis `./deploy.sh` |
| PM2 inconnu | `npm install -g pm2` |
