# State remoto no S3, um arquivo por ambiente, com versionamento e trava (use_lockfile).
# Os valores são informados no "terraform init" pela pipeline (scripts/bootstrap-state.sh cria o bucket):
#   terraform init \
#     -backend-config="bucket=pm04-todo-tfstate-<conta>" \
#     -backend-config="key=todo-app/<ambiente>.tfstate" \
#     -backend-config="region=us-east-1"
terraform {
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}
