# Provisionnement automatique SSL (certificats + nginx)

Quand vous ajoutez un client dans la page admin, le système peut automatiquement :
1. Créer/étendre le certificat SSL Let's Encrypt pour `api.[sous-domaine].votredomaine.fr`
2. Recharger nginx

## Activation

### 1. Variables dans `.env`

```env
PROVISION_ENABLED=true
PROVISION_DOMAIN=steph-verardo.fr
```

### 2. Configurer sudo sur le VPS

Le script doit s'exécuter avec les droits root (certbot, nginx). Sur le VPS :

```bash
sudo visudo
```

Ajoutez (remplacez `ubuntu` par votre utilisateur si différent) :

```
ubuntu ALL=(ALL) NOPASSWD: /chemin/vers/abrazouver/backend/scripts/provision-ssl.sh
```

Exemple si le backend est dans `/home/ubuntu/abrazouver/backend` :

```
ubuntu ALL=(ALL) NOPASSWD: /home/ubuntu/abrazouver/backend/scripts/provision-ssl.sh
```

### 3. Rendre le script exécutable

```bash
chmod +x backend/scripts/provision-ssl.sh
```

(Le `deploy.sh` le fait automatiquement.)

## Utilisation

1. **À l'ajout d'un client** : le provisionnement se lance automatiquement.
2. **Bouton "Mise à jour SSL"** : pour relancer en cas d'erreur (ex. DNS pas encore propagé).

## Prérequis

- **DNS** : `api.[sous-domaine].steph-verardo.fr` doit pointer vers l'IP du VPS **avant** le provisionnement.
- **Nginx** : la config API doit accepter le motif `api.*.steph-verardo.fr` (voir `nginx-api.conf.example`).

## En cas d'erreur

Le dialogue affiche le message et les détails (sortie certbot). Causes courantes :
- DNS non propagé → attendre puis cliquer sur « Mise à jour SSL »
- Certificat ou nginx invalide → vérifier les chemins dans la config nginx
