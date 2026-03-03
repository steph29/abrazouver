# Configuration Nginx pour Abrazouver (steph-verardo.fr)

## Problème

Si vous voyez "Welcome to nginx!" au lieu de l'app, c'est que nginx n'est pas configuré pour vos sous-domaines.

## Étapes

### 1. Créer le certificat SSL (si pas encore fait)

**Important** : le certificat doit inclure TOUS les sous-domaines (app.xxx, www.app.xxx, api.xxx).

```bash
sudo certbot certonly --nginx -d steph-verardo.fr -d app.steph-verardo.fr -d app.admin.steph-verardo.fr -d app.enest-fest.steph-verardo.fr -d www.app.steph-verardo.fr -d www.app.admin.steph-verardo.fr -d www.app.enest-fest.steph-verardo.fr -d api.steph-verardo.fr -d api.admin.steph-verardo.fr -d api.enest-fest.steph-verardo.fr
```

Pour ajouter un nouveau client à un certificat existant, utilisez `--expand` et ajoutez les domaines.

Le certificat sera dans `/etc/letsencrypt/live/<nom>/` (nom = premier domaine ou --cert-name).

**Vérifier le chemin exact :**
```bash
sudo certbot certificates
```
Puis adapter `ssl_certificate` et `ssl_certificate_key` dans les configs nginx.

### 2. Préparer le répertoire de l'app Flutter

```bash
# Builder (sans --base-href : app à la racine)
flutter build web

# Créer le répertoire sur le serveur
ssh user@vps "mkdir -p /var/www/abrazouver/app"

# Déployer (app.xxx ou www.app.xxx selon la config DNS)
rsync -avz --delete build/web/ user@vps:/var/www/abrazouver/app/
```

### 3. Configurer Nginx

Copiez les fichiers d'exemple et adaptez si besoin :

```bash
# App Flutter
sudo cp backend/deploy/nginx-app.conf.example /etc/nginx/sites-available/abrazouver-app
# Vérifiez que root pointe vers /var/www/abrazouver/app

# API
sudo cp backend/deploy/nginx-api.conf.example /etc/nginx/sites-available/abrazouver-api
```

**Si le chemin du certificat est différent** (ex. certbot a créé `api.steph-verardo.fr`), éditez :
```bash
sudo nano /etc/nginx/sites-available/abrazouver-app
sudo nano /etc/nginx/sites-available/abrazouver-api
```
et corrigez les lignes `ssl_certificate` et `ssl_certificate_key`.

### 4. Activer et recharger Nginx

```bash
sudo ln -sf /etc/nginx/sites-available/abrazouver-app /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/abrazouver-api /etc/nginx/sites-enabled/
sudo nginx -t        # Vérifier la config
sudo systemctl reload nginx
```

### 5. Déployer l'app Flutter

Depuis votre machine (app à la racine, pas de `--base-href`) :
```bash
flutter build web
rsync -avz --delete build/web/ user@91.134.243.11:/var/www/abrazouver/app/
```

L'app sera accessible à https://app.xxx.steph-verardo.fr/ ou https://www.app.xxx.steph-verardo.fr/ selon la config DNS.

### 6. Erreur Content-Security-Policy (CSP) / favicon bloqué

Si vous voyez « default-src 'none' » ou « img-src » bloqué : la config nginx-app inclut une CSP adaptée. Vérifiez que le fichier sur le VPS est à jour.

Si l’erreur persiste, la CSP peut venir d’un proxy OVH (CDN, WAF). Dans l’espace client OVH, désactiver les options de sécurité strictes pour ce domaine si disponible.

### 7. Vérifier

- https://app.admin.steph-verardo.fr/ ou https://www.app.admin.steph-verardo.fr/ → page Configuration clients
- https://app.steph-verardo.fr/ → app (après avoir ajouté le tenant steph-verardo)
- https://www.app.enest-fest.steph-verardo.fr/ → app client enest-fest
- https://api.admin.steph-verardo.fr/api/health → `{"status":"ok"}`
- https://api.enest-fest.steph-verardo.fr/api/health → `{"status":"ok"}`

### 8. Dépannage : "Plus accès" à app.xxx ou api.xxx

1. **Certificat SSL** : si le sous-domaine n'est pas dans le certificat Let's Encrypt, le navigateur bloquera (erreur de certificat).
   ```bash
   sudo certbot certificates   # Voir les domaines actuels
   sudo certbot certonly --nginx --expand -d ... -d app.enest-fest.steph-verardo.fr -d api.enest-fest.steph-verardo.fr
   ```

2. **Nginx server_name** : les configs doivent inclure app.enest-fest et api.enest-fest (ou un motif regex). Vérifier les fichiers dans `/etc/nginx/sites-available/`.

3. **DNS** : `app.enest-fest.steph-verardo.fr` et `api.enest-fest.steph-verardo.fr` doivent pointer vers les bonnes IP (app → mutualisé ou VPS, api → VPS).

4. **URL de l'app** : app à la racine. Ne pas utiliser `--base-href /www/` lors du build (garder le base href par défaut `/`).

5. **CORS** : géré uniquement par Express (.env CORS_ORIGINS). Ne pas ajouter d'en-têtes CORS dans nginx (risque de doublons = erreur « plusieurs Access-Control-Allow-Origin »).

6. **HTTP vs HTTPS** : l'app force HTTPS pour l'API en prod. En HTTP, le Service Worker échoue (« The current context is NOT secure »). Soit activer HTTPS pour l'app, soit builder avec `flutter build web --pwa-strategy=none`.
