terraform {
  # use_lockfile (trava do state no próprio S3) exige Terraform 1.10+
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Credenciais NÃO ficam aqui: na pipeline vêm dos Secrets do GitHub (variáveis de ambiente AWS_*).
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Projeto       = var.project
      Ambiente      = var.environment
      GerenciadoPor = "terraform"
      Repositorio   = "pm04-todo-app"
    }
  }
}
