variable "region" {
  type        = string
  description = "Região da AWS onde a infraestrutura é criada."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Prefixo usado nos nomes e tags dos recursos."
  default     = "pm04-todo"
}

variable "environment" {
  type        = string
  description = "Ambiente de destino (parâmetro da pipeline)."
  default     = "dev"

  validation {
    condition     = contains(["dev", "homolog", "prod"], var.environment)
    error_message = "environment deve ser dev, homolog ou prod."
  }
}

# ---------- Rede ----------

variable "vpc_cidr" {
  type        = string
  description = "Faixa de IPs da VPC."
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Sub-rede pública (VM da aplicação)."
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "Sub-rede privada (VM do MongoDB, sem IP público)."
  default     = "10.20.2.0/24"
}

variable "enable_nat_gateway" {
  type        = bool
  description = "NAT Gateway para a VM do banco baixar pacotes e imagens. É o item mais caro; pode ser desligado depois da configuração (os backups seguem pelo endpoint S3)."
  default     = true
}

variable "admin_cidrs" {
  type        = list(string)
  description = "IPs (CIDR) com acesso SSH à VM da aplicação. A pipeline libera o IP do runner temporariamente, fora do Terraform."
  default     = []
}

# ---------- Máquinas ----------

variable "instance_name" {
  type        = string
  description = "Nome base das VMs (parâmetro da pipeline): gera <nome>-app e <nome>-db. Vazio = <project>-<environment>."
  default     = ""
}

variable "app_instance_type" {
  type        = string
  description = "Tipo da VM da aplicação (Nginx + React + API + Caddy)."
  default     = "t3.micro"
}

variable "db_instance_type" {
  type        = string
  description = "Tipo da VM exclusiva do MongoDB."
  default     = "t3.micro"
}

variable "root_volume_size" {
  type        = number
  description = "Disco do sistema de cada VM (GB)."
  default     = 16
}

variable "db_volume_size" {
  type        = number
  description = "Volume persistente dos dados do MongoDB (GB), separado do disco do sistema."
  default     = 10
}

variable "ssh_public_key" {
  type        = string
  description = "Chave pública SSH usada pela pipeline (Secret SSH_PUBLIC_KEY)."
}

variable "instance_profile_name" {
  type        = string
  description = "Instance profile já existente para as VMs (AWS Academy: LabInstanceProfile). Vazio = o Terraform cria um com acesso ao bucket de backup."
  default     = ""
}

# ---------- Publicação e backup ----------

variable "app_domain" {
  type        = string
  description = "Domínio público da aplicação. Vazio = <ip-elastico>.sslip.io (HTTPS sem comprar domínio)."
  default     = ""
}

variable "backup_bucket" {
  type        = string
  description = "Bucket S3 dos backups (criado por scripts/bootstrap-state.sh, fica fora deste state para sobreviver ao destroy)."
}
