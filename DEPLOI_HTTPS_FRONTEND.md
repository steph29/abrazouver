# Site « non sécurisé » : activer HTTPS pour le frontend

Si le navigateur affiche **« Site non sécurisé »**, c’est que le site web (Flutter) est servi en **HTTP** au lieu de **HTTPS**.

## OVH mutualisé

1. Connectez-vous au [Manager OVH](https://www.ovh.com/manager/)
2. Allez dans **Hébergements** → votre hébergement
3. Onglet **Multisite** ou **Domaines associés**
4. Cliquez sur votre domaine (ex. `www.steph-verardo.fr`)
5. Recherchez l’option **SSL** ou **Certificat SSL**
6. Activez le **SSL Let's Encrypt** (gratuit)

Après quelques minutes, le site sera accessible en `https://`.

## Vérifier

- L’URL doit commencer par `https://` et non `http://`
- Une fois en HTTPS, l’alerte « non sécurisé » disparaît
