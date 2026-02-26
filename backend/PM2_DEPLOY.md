# Lancer le serveur en permanence sur le VPS (PM2)

## 1. Installer PM2 sur le VPS

```bash
sudo npm install -g pm2
```

## 2. Démarrer le serveur avec PM2

Depuis le dossier backend sur le VPS :

```bash
cd /home/ubuntu/backend
pm2 start ecosystem.config.js
```

Ou directement :

```bash
pm2 start server.js --name abrazouver-api
```

## 3. Commandes utiles

| Commande | Description |
|----------|-------------|
| `pm2 list` | Voir les processus |
| `pm2 logs abrazouver-api` | Voir les logs |
| `pm2 restart abrazouver-api` | Redémarrer |
| `pm2 stop abrazouver-api` | Arrêter |
| `pm2 delete abrazouver-api` | Supprimer du suivi PM2 |

## 4. Démarrer au redémarrage du VPS

```bash
pm2 save
pm2 startup
```

Exécutez la commande que `pm2 startup` affiche (généralement un `sudo env ...`).

## 5. Après une mise à jour du code

```bash
cd /home/ubuntu/backend
git pull   # ou déployer vos fichiers
pm2 restart abrazouver-api
```
