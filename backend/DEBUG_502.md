# Diagnostic 502 Bad Gateway

Le 502 indique que Nginx ne reçoit pas de réponse de l’API Node.js.

## Étapes de diagnostic (à exécuter sur le serveur)

### 1. Vérifier si l’API tourne
```bash
pm2 list
```
Si `abrazouver-api` est absent ou en statut `errored` / `stopped` → l’API ne tourne pas.

### 2. Voir les logs (erreurs de démarrage ou de requêtes)
```bash
cd /chemin/vers/abrazouver/backend
pm2 logs abrazouver-api --lines 100
```
Rechercher des messages comme :
- `❌ Erreur connexion base de données`
- `❌ uncaughtException`
- `❌ unhandledRejection`
- `EADDRINUSE` (port déjà utilisé)

### 3. Démarrer ou redémarrer l’API
```bash
cd /chemin/vers/abrazouver/backend
./deploy.sh
```
Ou manuellement :
```bash
cd backend
npm run migrate    # créer/mettre à jour les tables
pm2 start ecosystem.config.cjs --env production
# ou si déjà existant :
pm2 restart abrazouver-api
```

### 4. Tester l’API en local
```bash
curl -s http://127.0.0.1:3000/api/health
```
- Réponse JSON (p.ex. `{"status":"ok"}`) → l’API répond, le problème peut venir de Nginx.
- `Connection refused` → l’API n’est pas à l’écoute sur le port 3000 (mauvais port ou process arrêté).

### 5. Vérifier le port
Le fichier `.env` doit contenir :
```
PORT=3000
```
Nginx doit faire `proxy_pass http://127.0.0.1:3000;` (ou le port défini dans `.env`).

### 6. Vérifier la base de données
Le `.env` doit contenir :
```
DB_HOST=...
DB_PORT=3306
DB_USER=...
DB_PASSWORD=...
DB_NAME=abrazouver_apel
```
Une erreur de connexion MySQL provoque souvent un crash au démarrage.

## Action rapide

```bash
cd /chemin/vers/abrazouver/backend
./deploy.sh
pm2 logs abrazouver-api --lines 20
```

Si l’API ne démarre toujours pas, les logs indiqueront la cause (souvent MySQL).
