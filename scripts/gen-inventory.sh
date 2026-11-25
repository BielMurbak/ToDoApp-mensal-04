#!/usr/bin/env bash
# Gera o inventário do Ansible e o ~/.ssh/config a partir do "terraform output".
# A VM do banco não tem IP público: o SSH passa pela VM da aplicação (ProxyJump).
# Uso: scripts/gen-inventory.sh <arquivo-terraform-output.json>
set -euo pipefail

OUT="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
val() { jq -r ".$1.value" "$OUT"; }

APP_PUBLIC_IP=$(val app_public_ip)
APP_PRIVATE_IP=$(val app_private_ip)
DB_PRIVATE_IP=$(val db_private_ip)
KEY="${SSH_KEY_FILE:-$HOME/.ssh/pm04}"

mkdir -p "$HOME/.ssh"
cat > "$HOME/.ssh/config" <<EOF
Host bastion
  HostName ${APP_PUBLIC_IP}
  User ubuntu
  IdentityFile ${KEY}
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new

Host ${APP_PRIVATE_IP}
  HostName ${APP_PUBLIC_IP}
  User ubuntu
  IdentityFile ${KEY}
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new

Host ${DB_PRIVATE_IP}
  User ubuntu
  IdentityFile ${KEY}
  IdentitiesOnly yes
  ProxyJump bastion
  StrictHostKeyChecking accept-new
EOF
chmod 600 "$HOME/.ssh/config"

cat > "$ROOT/ansible/inventory/hosts.yml" <<EOF
# Gerado por scripts/gen-inventory.sh - não editar
all:
  vars:
    ansible_user: ubuntu
    environment_name: $(val environment)
    aws_region: ${AWS_REGION:-us-east-1}
    app_domain: $(val app_domain)
    app_public_ip: ${APP_PUBLIC_IP}
    db_private_ip: ${DB_PRIVATE_IP}
    db_data_volume_id: $(val db_data_volume_id)
    backup_bucket: $(val backup_bucket)
    backup_prefix: $(val backup_prefix)
  children:
    app:
      hosts:
        ${APP_PRIVATE_IP}:
    db:
      hosts:
        ${DB_PRIVATE_IP}:
EOF

echo "Inventário gerado: app=${APP_PRIVATE_IP} (público ${APP_PUBLIC_IP}), db=${DB_PRIVATE_IP} (somente privado)"
