# Activer HTTPS pour l'app Flutter (Option A)

Guide pas à pas pour servir l'app en HTTPS.

## Prérequis

- **DNS** : Les domaines `app.xxx.steph-verardo.fr` et `www.app.xxx.steph-verardo.fr` doivent pointer vers l'IP du VPS (91.134.243.11 ou la vôtre).
- L'app et l'API sont sur le même VPS.

---

## Étape 1 : Vérifier le DNS

Sur votre machine :

```bash
# Remplacer par vos domaines
dig +short www.app.enest-fest.steph-verardo.fr
dig +short www.app.abrazouver-apel.steph-verardo.fr
```

Les réponses doivent être l'IP du VPS. Si ce n'est pas le cas, créez des enregistrements A (ou CNAME) chez votre registrar DNS.

---

## Étape 2 : Créer le certificat SSL pour l'app

Sur le VPS, créez un certificat incluant tous les domaines app et www.app :

```bash
sudo certbot certonly --nginx --cert-name app.steph-verardo.fr \
  -d app.steph-verardo.fr \
  -d app.admin.steph-verardo.fr \
  -d app.enest-fest.steph-verardo.fr \
  -d app.abrazouver-apel.steph-verardo.fr \
  -d www.app.steph-verardo.fr \
  -d www.app.admin.steph-verardo.fr \
  -d www.app.enest-fest.steph-verardo.fr \
  -d www.app.abrazouver-apel.steph-verardo.fr
```

**Pour un nouveau client plus tard** : ajoutez les domaines puis :

```bash
sudo certbot certonly --nginx --expand --cert-name app.steph-verardo.fr \
  -d app.steph-verardo.fr \
  -d app.admin.steph-verardo.fr \
  ... (tous les domaines existants) \
  -d app.nouveau-client.steph-verardo.fr \
  -d www.app.nouveau-client.steph-verardo.fr
```

Vérifiez le chemin du certificat :

```bash
sudo certbot certificates
```

Le certificat app sera dans `/etc/letsencrypt/live/app.steph-verardo.fr/`.

---

## Étape 3 : Mettre à jour la config nginx de l'app

Sur le VPS, éditez `/etc/nginx/sites-available/abrazouver-app` :

```bash
sudo nano /etc/nginx/sites-available/abrazouver-app
```

Vérifiez que les lignes certificat sont correctes (adapter si certbot a mis un autre nom) :

```nginx
ssl_certificate /etc/letsencrypt/live/app.steph-verardo.fr/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/app.steph-verardo.fr/privkey.pem;
```

Si le fichier utilisait `steph-verardo.fr`, remplacez par la commande :

```bash
sudo sed -i 's|/etc/letsencrypt/live/steph-verardo\.fr/|/etc/letsencrypt/live/app.steph-verardo.fr/|g' /etc/nginx/sites-available/abrazouver-app
```

---

## Étape 4 : Activer et tester nginx

```bash
sudo ln -sf /etc/nginx/sites-available/abrazouver-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## Étape 5 : Déployer l'app Flutter

Sur votre machine locale :

```bash
cd /chemin/vers/abrazouver
flutter build web
rsync -avz --delete build/web/ user@VPS_IP:/var/www/abrazouver/app/
```

(Remplacer `user` et `VPS_IP` par vos identifiants.)

---

## Étape 6 : Vérifier

- https://www.app.abrazouver-apel.steph-verardo.fr/
- https://www.app.enest-fest.steph-verardo.fr/
- https://app.admin.steph-verardo.fr/

Les requêtes `http://` doivent être redirigées vers `https://`.

---

## Si l'app est sur OVH mutualisé (pas le VPS)

Dans ce cas, nginx du VPS ne sert pas l'app. Deux options :

1. **Migrer l'app vers le VPS** : changer le DNS de `app.xxx` pour pointer vers le VPS, puis suivre ce guide.
2. **Utiliser le SSL OVH** : dans l’espace client OVH (hébergement web), activer SSL / Let's Encrypt pour le domaine. La redirection HTTP → HTTPS se configure dans le panneau ou via `.htaccess`.
