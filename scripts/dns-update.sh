#!/usr/bin/env bash
# Aponta o domínio da aplicação para o Elastic IP criado pelo Terraform.
# Cloudflare (CF_API_TOKEN) ou DuckDNS (DUCKDNS_TOKEN); sem token, nada a fazer (ex.: sslip.io).
# Uso: scripts/dns-update.sh <arquivo-terraform-output.json>
set -euo pipefail

OUT="$1"
DOMAIN=$(jq -r .app_domain.value "$OUT")
IP=$(jq -r .app_public_ip.value "$OUT")

if [ -n "${CF_API_TOKEN:-}" ]; then
  api() { curl -fsS -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" "$@"; }
  CF=https://api.cloudflare.com/client/v4

  # Zona = maior sufixo do domínio que existe na conta (funciona para .com e .com.br)
  ZONE_ID=""
  CANDIDATE="$DOMAIN"
  while [[ "$CANDIDATE" == *.* ]]; do
    ZONE_ID=$(api "$CF/zones?name=${CANDIDATE}" | jq -r '.result[0].id // empty')
    [ -n "$ZONE_ID" ] && break
    CANDIDATE="${CANDIDATE#*.}"
  done
  if [ -z "$ZONE_ID" ]; then
    echo "::error::Zona de ${DOMAIN} não encontrada na Cloudflare (o token tem permissão de DNS nessa zona?)"
    exit 1
  fi

  # Um CNAME com o mesmo nome impediria o registro A: avisar em vez de apagar algo existente
  if [ "$(api "$CF/zones/${ZONE_ID}/dns_records?type=CNAME&name=${DOMAIN}" | jq '.result | length')" != "0" ]; then
    echo "::error::${DOMAIN} já é um CNAME em uso na Cloudflare. Escolha outro APP_DOMAIN."
    exit 1
  fi

  # DNS direto (sem proxy laranja): o Caddy da VM emite e serve o certificado HTTPS
  BODY=$(jq -nc --arg n "$DOMAIN" --arg ip "$IP" \
    '{type: "A", name: $n, content: $ip, ttl: 60, proxied: false, comment: "pm04-todo (pipeline)"}')
  RECORD_ID=$(api "$CF/zones/${ZONE_ID}/dns_records?type=A&name=${DOMAIN}" | jq -r '.result[0].id // empty')
  if [ -n "$RECORD_ID" ]; then
    api -X PUT "$CF/zones/${ZONE_ID}/dns_records/${RECORD_ID}" --data "$BODY" | jq -e .success >/dev/null
  else
    api -X POST "$CF/zones/${ZONE_ID}/dns_records" --data "$BODY" | jq -e .success >/dev/null
  fi
  echo "Cloudflare: ${DOMAIN} -> ${IP}"

elif [ -n "${DUCKDNS_TOKEN:-}" ] && [[ "$DOMAIN" == *.duckdns.org ]]; then
  curl -fsS "https://www.duckdns.org/update?domains=${DOMAIN%.duckdns.org}&token=${DUCKDNS_TOKEN}&ip=${IP}" | grep -qx OK
  echo "DuckDNS: ${DOMAIN} -> ${IP}"

else
  echo "Sem DNS gerenciado - usando ${DOMAIN}"
fi
