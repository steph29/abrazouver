# Configuration email (Mot de passe perdu + Contact)

Le flux « Mot de passe perdu » envoie un email avec un lien de réinitialisation.

## Quelle option choisir ?

| Option | Avantage | Inconvénient |
|--------|----------|--------------|
| **SMTP OVH** | Très bonne délivrabilité (Gmail, etc.) | Nécessite identifiants OVH |
| **Sendmail** | Simple, pas de mot de passe | Gmail bloque souvent les emails (VPS sans SPF) |

**Recommandation** : Si les emails n'arrivent pas chez Gmail → utiliser **SMTP OVH**.

---

## Option A : SMTP OVH (recommandé pour Gmail)

Dans `backend/.env` :

```env
# Désactiver Sendmail
EMAIL_SENDMAIL=false

# SMTP OVH - port 587 (STARTTLS) souvent plus fiable que 465
SMTP_HOST=smtp.ovh.net
SMTP_PORT=587
SMTP_USER=contact@steph-verardo.fr
SMTP_PASS=votre_mot_de_passe_ovh
SMTP_SECURE=false
EMAIL_FROM=contact@steph-verardo.fr
```

**Si timeout sur smtp.ovh.net:587** (pare-feu VPS) : utiliser `ssl0.ovh.net:465` :
```env
SMTP_HOST=ssl0.ovh.net
SMTP_PORT=465
SMTP_SECURE=true
```

Puis `pm2 restart abrazouver-api` et tester avec `node scripts/test-email.js s.verardo29@gmail.com`.

---

## Option B : Sendmail (si SMTP indisponible)

Dans `backend/.env` :

```env
EMAIL_SENDMAIL=true
EMAIL_FROM=contact@steph-verardo.fr
```

- `EMAIL_SENDMAIL=true` : utilise la commande Sendmail du serveur
- `EMAIL_FROM` : adresse affichée comme expéditeur (doit être un domaine que vous contrôlez)

## 2. Installer Sendmail sur le VPS

```bash
# Debian / Ubuntu
sudo apt update
sudo apt install sendmail

# Vérifier l'installation
which sendmail
# → /usr/sbin/sendmail
```

## 3. Tester l'envoi d'email

Depuis le dossier `backend` :

```bash
npm run test-email votre@email.com
```

Si l’email arrive (vérifier aussi les spams), la configuration est correcte.

## 4. Redémarrer l'API

Après modification du `.env` :

```bash
pm2 restart abrazouver-api
```

## Alternative : msmtp (plus léger)

Si Sendmail pose problème, vous pouvez utiliser msmtp :

```bash
sudo apt install msmtp msmtp-mta
```

Puis configurer `/etc/msmtprc` et mettre `EMAIL_SENDMAIL=true` (Nodemailer utilisera la commande par défaut, souvent msmtp si msmtp-mta est installé).

## Dépannage

| Problème | Solution |
|----------|----------|
| `sendmail: command not found` | Installer Sendmail ou msmtp (voir ci-dessus) |
| Emails en spam (Gmail, etc.) | Configurer SPF/DKIM pour votre domaine (voir ci-dessous) |
| Erreur 503 « Envoi d'email non configuré » | Vérifier EMAIL_SENDMAIL=true et EMAIL_FROM dans .env |
| Mot de passe perdu : pas d'email reçu | Vérifier les logs : `pm2 logs abrazouver-api` — si "email envoyé vers x@..." apparaît, l'envoi a réussi (vérifier spams). Sinon, erreur côté Sendmail. |

## Emails vers Gmail : améliorer la délivrabilité

Gmail peut placer les emails en spam si le domaine n’est pas configuré. À faire dans le gestionnaire DNS (OVH, etc.) :

1. **SPF** : enregistrement TXT sur `steph-verardo.fr` :
   ```
   v=spf1 ip4:IP_DU_VPS include:_spf.google.com ~all
   ```
   (remplacer `IP_DU_VPS` par l’IP du serveur qui envoie les emails)

2. **DKIM** (optionnel) : rend les emails plus fiables

3. Tester l’envoi vers une adresse Gmail : si l’email arrive en spam, c’est souvent un problème de réputation ou de configuration SPF/DKIM.
