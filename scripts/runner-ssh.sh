#!/usr/bin/env bash
# Libera (open) ou remove (close) o SSH do IP do runner do GitHub na VM da aplicação.
# A regra é criada fora do Terraform: não gera alteração no plan e existe só durante a execução.
# Uso: scripts/runner-ssh.sh open|close <security-group-id>
set -euo pipefail

ACTION="$1"
SG_ID="$2"
RUNNER_IP=$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')
CIDR="${RUNNER_IP}/32"

case "$ACTION" in
  open)
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
      --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${CIDR},Description=runner-github-temporario}]" \
      >/dev/null 2>&1 || echo "Regra já existia"
    echo "SSH liberado temporariamente para o runner (${CIDR})"
    ;;
  close)
    aws ec2 revoke-security-group-ingress --group-id "$SG_ID" \
      --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${CIDR}}]" \
      >/dev/null 2>&1 || true
    echo "SSH do runner removido (${CIDR})"
    ;;
  *)
    echo "Uso: $0 open|close <security-group-id>" >&2
    exit 1
    ;;
esac
