# Abrazouver

Application Flutter avec backend REST CRUD connecté à une base SQL (OVH).

## Structure du projet

```
abrazouver/
├── lib/                    # Frontend Flutter (structure type terreenvie)
│   ├── api/                # Services API REST
│   │   └── api_service.dart
│   ├── controller/         # Pages et écrans
│   │   └── home_page.dart
│   ├── model/              # Modèles de données
│   │   └── base_model.dart
│   └── main.dart
│
└── backend/                # API Node.js + Express
    ├── config/             # Configuration BDD
    │   └── database.js
    ├── routes/             # Routes CRUD
    │   └── crud.js
    ├── scripts/            # Scripts SQL
    │   └── init_db.sql
    ├── server.js
    ├── .env.example
    └── package.json
```

## Démarrage

### Frontend Flutter

```bash
flutter pub get
flutter run
```

### Backend API

```bash
cd backend
cp .env.example .env
# Éditer .env avec vos paramètres OVH (host, user, password, database)
npm install
npm run dev
```

L'API est disponible sur `http://localhost:3000`.

### Déploiement web

1. **Modifier `web/config.json`** avant le build :
   ```json
   { "apiBaseUrl": "https://votre-serveur-api.com/api" }
   ```

2. **Builder** : `flutter build web`

3. **Déployer** le contenu de `build/web/` sur votre hébergement.

4. **Backend** : déployer aussi le backend et configurer CORS dans `.env` :
   ```
   CORS_ORIGINS=https://votresite.com
   ```

### Base de données SQL (OVH)

1. Copiez `backend/.env.example` vers `backend/.env`.
2. Modifiez `backend/.env` avec vos paramètres OVH :
   - `DB_HOST` : adresse du serveur (ex. `stephvxwpdb.mysql.db`)
   - `DB_USER` : nom d'utilisateur
   - `DB_PASSWORD` : mot de passe OVH
   - `DB_NAME` : nom de la base
3. Créez les tables : exécutez `backend/scripts/init_db_ovh.sql` dans phpMyAdmin OVH, ou `npm run init-db` si la base est déjà configurée.

### Test local (en attendant OVH)

**Prérequis : Docker Desktop doit être lancé** (Applications ou barre des tâches).

```bash
# 1. Démarrer MySQL avec Docker
docker compose up -d

# 2. Configurer le backend
cd backend
cp .env.example .env

# 3. Créer les tables et charger les données de test
npm run init-db
npm run seed
npm run dev
```

**Identifiants de test :**
- `admin@abrazouver.fr` / `admin123`
- `jean.dupont@test.fr` / `test123`
- `marie.martin@test.fr` / `test123`

**Si "Base de données indisponible" :** Vérifiez que Docker Desktop est ouvert, puis relancez `docker compose up -d`. Attendez quelques secondes que MySQL démarre avant `npm run init-db`.

## API CRUD

| Méthode | Endpoint        | Description      |
|---------|-----------------|------------------|
| GET     | /api/:table     | Liste tous les enregistrements |
| GET     | /api/:table/:id | Récupère un enregistrement      |
| POST    | /api/:table     | Crée un enregistrement         |
| PUT     | /api/:table/:id | Met à jour un enregistrement   |
| DELETE  | /api/:table/:id | Supprime un enregistrement     |

Exemple : `GET /api/items`, `POST /api/items` avec body JSON.
