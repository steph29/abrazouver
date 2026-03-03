#!/usr/bin/env bash
# Provisionnement SSL (certbot) + rechargement nginx
# Usage: provision-ssl.sh "api.steph-verardo.fr api.admin.steph-verardo.fr"

DOMAINS="${1:-}"
if [ -z "$DOMAINS" ]; then
  echo '{"success":false,"message":"Aucun domaine fourni"}'
  exit 1
fi

LOG=$(mktemp)
CERT_OK=0

# Certbot : essayer --expand d'abord, sinon créer nouveau cert
# --cert-name pour un chemin prévisible dans nginx : /etc/letsencrypt/live/steph-verardo.fr/
CERT_NAME="${2:-steph-verardo.fr}"
CERTBOT_EXPAND="certbot certonly --nginx --non-interactive --agree-tos --expand"
CERTBOT_NEW="certbot certonly --nginx --non-interactive --agree-tos --cert-name $CERT_NAME"
for d in $DOMAINS; do
  CERTBOT_EXPAND="$CERTBOT_EXPAND -d $d"
  CERTBOT_NEW="$CERTBOT_NEW -d $d"
done

$CERTBOT_EXPAND >> "$LOG" 2>&1 && CERT_OK=1
if [ $CERT_OK -eq 0 ]; then
  $CERTBOT_NEW >> "$LOG" 2>&1 && CERT_OK=1
fi

if [ $CERT_OK -eq 0 ]; then
  DETAILS=$(tail -15 "$LOG" | tr '\n' ' ' | sed 's/"/\\"/g')
  echo "{\"success\":false,\"message\":\"Certbot a échoué. Vérifiez le DNS (api.xxx doit pointer vers le VPS).\",\"details\":\"$DETAILS\"}"
  rm -f "$LOG"
  exit 1
fi
rm -f "$LOG"

# Recharger nginx
if nginx -t >> /dev/null 2>&1; then
  systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
  echo '{"success":true,"message":"Certificat SSL et nginx mis à jour"}'
else
  echo '{"success":false,"message":"Nginx config invalide. Certificat OK mais pas de reload nginx."}'
  exit 1
fi
