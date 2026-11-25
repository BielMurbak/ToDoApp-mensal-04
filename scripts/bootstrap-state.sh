#!/usr/bin/env bash
# Cria (se ainda não existirem) os buckets do Terraform State e dos backups. Idempotente.
# Ficam fora do state do Terraform para sobreviver ao "destroy" do ambiente.
# Saída: grava TF_STATE_BUCKET e BACKUP_BUCKET em $GITHUB_ENV (ou imprime, fora da pipeline).
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
PREFIX="${BUCKET_PREFIX:-pm04-todo}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

STATE_BUCKET="${PREFIX}-tfstate-${ACCOUNT_ID}"
BACKUP_BUCKET="${PREFIX}-backups-${ACCOUNT_ID}"

create_bucket() {
  local bucket="$1"
  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    echo "Bucket $bucket já existe"
    return
  fi
  echo "Criando bucket $bucket"
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$bucket" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$bucket" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" >/dev/null
  fi
  aws s3api put-public-access-block --bucket "$bucket" --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-encryption --bucket "$bucket" --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
}

create_bucket "$STATE_BUCKET"
create_bucket "$BACKUP_BUCKET"

# State versionado: permite recuperar uma versão anterior se o arquivo for corrompido
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled

# Backups expiram depois de 14 dias (custo previsível)
aws s3api put-bucket-lifecycle-configuration --bucket "$BACKUP_BUCKET" --lifecycle-configuration \
  '{"Rules":[{"ID":"expira-backups","Status":"Enabled","Filter":{"Prefix":"backups/"},"Expiration":{"Days":14}}]}'

if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "TF_STATE_BUCKET=$STATE_BUCKET"
    echo "BACKUP_BUCKET=$BACKUP_BUCKET"
    echo "TF_VAR_backup_bucket=$BACKUP_BUCKET"
  } >> "$GITHUB_ENV"
else
  echo "TF_STATE_BUCKET=$STATE_BUCKET"
  echo "BACKUP_BUCKET=$BACKUP_BUCKET"
fi
