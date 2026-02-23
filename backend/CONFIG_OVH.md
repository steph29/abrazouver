# Configuration OVH MySQL – Dépannage

## Erreur ENOTFOUND (serveur introuvable)

L’erreur `getaddrinfo ENOTFOUND stephvxwpdb.mysql.db` indique que le nom de serveur ne peut pas être résolu par le DNS.

### À vérifier dans le Manager OVH

1. **Manager OVH** → **Hébergement Web** → votre offre → **Bases de données**
2. Repérez la section **« Informations de connexion »** ou **« Paramètres de la base »**
3. Relevez **exactement** :
   - **Serveur MySQL** (peut être différent de `stephvxwpdb.mysql.db`)
   - **Utilisateur**
   - **Nom de la base**

### Formats possibles côté OVH

- `stephvxwpdb.mysql.db`
- `stephvxwpdb.mysql.db.ovh.net`
- `sqlXX.mysql.db` (XX = numéro de serveur)
- Ou une adresse du type `mysql.clusterXXX.hosting.ovh.net`

Utilisez uniquement ce qui est indiqué dans le Manager OVH.

### Connexion à distance

Sur les hébergements **mutualisés**, la connexion MySQL depuis l’extérieur (par exemple votre Mac) peut être limitée ou bloquée.

Si vous ne parvenez pas à vous connecter :

1. **Autoriser votre IP** dans le Manager OVH  
   (si l’option existe pour votre offre)

2. **Déployer le backend sur OVH**  
   Le serveur Node.js et MySQL sur le même hébergement contourne les restrictions d’accès à distance.

3. **Vérifier votre offre**  
   Certaines offres OVH autorisent la connexion distante, d’autres non.
