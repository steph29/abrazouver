# Architecture DNS - Abrazouver (multi-tenant)

## URLs propres (recommandé)

Utiliser **app.[client]** sans www : plus court et professionnel.

- ✅ https://app.enest-fest.steph-verardo.fr
- ✅ https://app.abrazouver-apel.steph-verardo.fr
- ✅ https://app.admin.steph-verardo.fr
- ❌ Éviter www.app.xxx (optionnel si besoin de rétrocompatibilité)

---

## Votre setup actuel

| Composant | Hébergement | IP |
|-----------|-------------|-----|
| **App Flutter** (build/web/) | OVH mutualisé | 51.91.236.193 |
| **Backend API** (Node.js) | VPS | 91.134.243.11 |
| **Cloud DB** (MySQL) | OVH Cloud | (accessible depuis le VPS) |

---

## Architecture correcte des DNS

```
                    ┌─────────────────────────────────────┐
                    │  OVH mutualisé (51.91.236.193)      │
                    │  → App Flutter (fichiers statiques)  │
  app.xxx            │  → HTTPS via SSL OVH / Let's Encrypt │
  (sans www)   ────►│     (panneau OVH)                   │
                    └─────────────────────────────────────┘
                                      │
                                      │ Appels API (fetch)
                                      ▼
                    ┌─────────────────────────────────────┐
                    │  VPS (91.134.243.11)                 │
  api.xxx       ────►│  → API Node.js (port 3000)           │
                    │  → Nginx (proxy + SSL certbot)        │
                    └─────────────────────────────────────┘
                                      │
                                      │ Requêtes SQL
                                      ▼
                    ┌─────────────────────────────────────┐
                    │  OVH Cloud DB                       │
                    │  → Une base par client (tenant)       │
                    └─────────────────────────────────────┘
```

---

## Tableau des domaines et cibles

| Domaine | Doit pointer vers | Rôle |
|---------|-------------------|------|
| **app.steph-verardo.fr** | 51.91.236.193 (mutualisé) | App client principal |
| **app.admin.steph-verardo.fr** | 51.91.236.193 (mutualisé) | Page config clients (admin) |
| **app.enest-fest.steph-verardo.fr** | 51.91.236.193 (mutualisé) | App client enest-fest |
| **app.abrazouver-apel.steph-verardo.fr** | 51.91.236.193 (mutualisé) | App client abrazouver-apel |
| **api.steph-verardo.fr** | 91.134.243.11 (VPS) | API client principal |
| **api.admin.steph-verardo.fr** | 91.134.243.11 (VPS) | API admin |
| **api.enest-fest.steph-verardo.fr** | 91.134.243.11 (VPS) | API client enest-fest |
| **api.abrazouver-apel.steph-verardo.fr** | 91.134.243.11 (VPS) | API client abrazouver-apel |

**www.app.*** : optionnel. Si vous en créez, pointer vers le mutualisé ; vous pouvez aussi rediriger www.app vers app.

---

## Pourquoi la redirection vers /api/health ?

Vous avez récemment pointé **app.enest-fest** vers le **VPS** au lieu du **mutualisé**.

Résultat :
- Une requête vers `https://www.app.enest-fest.steph-verardo.fr/` arrive sur le VPS
- Le VPS sert l’API (nginx → Node), pas l’app Flutter
- Node redirige `GET /` vers `/api/health` → vous tombez sur la page de health de l’API

**Correction** : remettre les domaines **app.*** et **www.app.*** vers le **mutualisé** (51.91.236.193).

---

## Action à faire (URLs propres app.[client])

Dans votre gestionnaire DNS, configurez uniquement les domaines **app** (sans www) :

| Enregistrement | Type | Valeur (cible) |
|----------------|------|----------------|
| app.steph-verardo.fr | A | 51.91.236.193 |
| app.admin.steph-verardo.fr | A | 51.91.236.193 |
| app.enest-fest.steph-verardo.fr | A | 51.91.236.193 |
| app.abrazouver-apel.steph-verardo.fr | A | 51.91.236.193 |
| api.steph-verardo.fr | A | 91.134.243.11 |
| api.admin.steph-verardo.fr | A | 91.134.243.11 |
| api.enest-fest.steph-verardo.fr | A | 91.134.243.11 |
| api.abrazouver-apel.steph-verardo.fr | A | 91.134.243.11 |

**Sous-domaines OVH** : sur le mutualisé, ajoutez les sous-domaines `app.enest-fest`, `app.abrazouver-apel`, etc. pointant vers le dossier de l’app (souvent via l’interface OVH « Multisite » ou « Sous-domaines »).

---

## HTTPS sur l’app (mutualisé)

Comme l’app est sur le mutualisé, le SSL doit être géré côté OVH :

1. **Espace client OVH** → Hébergement web → SSL / certificat
2. Activer Let's Encrypt (généralement gratuit)
3. Activer la redirection HTTP → HTTPS si disponible

Pas besoin de certbot sur le VPS pour les domaines app.
