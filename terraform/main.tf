locals {
  name     = "${var.project}-${var.environment}"
  az       = data.aws_availability_zones.available.names[0]
  vm_base  = var.instance_name != "" ? var.instance_name : local.name
  app_name = "${local.vm_base}-app"
  db_name  = "${local.vm_base}-db"

  # IP privado fixo do banco: a API continua apontando para o mesmo endereço se a VM for recriada
  db_private_ip = cidrhost(var.private_subnet_cidr, 10)

  app_domain = var.app_domain != "" ? var.app_domain : "${replace(aws_eip.app.public_ip, ".", "-")}.sslip.io"

  instance_profile = var.instance_profile_name != "" ? var.instance_profile_name : aws_iam_instance_profile.vm[0].name
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Ubuntu 24.04 LTS oficial da Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------- Rede ----------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = local.az

  tags = { Name = "${local.name}-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = local.az

  tags = { Name = "${local.name}-private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name}-rt-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = { Name = "${local.name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id

  tags = { Name = "${local.name}-nat" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name}-rt-private" }
}

# Saída para a internet da sub-rede privada (só quando o NAT está ligado)
resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Endpoint gratuito: backups chegam ao S3 pela rede da AWS, mesmo sem NAT
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]

  tags = { Name = "${local.name}-s3-endpoint" }
}

# ---------- Máquinas ----------

resource "aws_key_pair" "pipeline" {
  key_name   = "${local.name}-pipeline"
  public_key = var.ssh_public_key
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.pipeline.key_name
  iam_instance_profile   = local.instance_profile

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = { Name = local.app_name, Funcao = "app" }

  lifecycle {
    # Nova versão da AMI não recria a VM; atualizações do SO são feitas pelo Ansible
    ignore_changes = [ami]
  }
}

# IP fixo da aplicação: não muda quando a VM é parada para trocar de tipo
resource "aws_eip" "app" {
  domain = "vpc"

  tags = { Name = "${local.name}-app-eip" }
}

resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private.id
  private_ip             = local.db_private_ip
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = aws_key_pair.pipeline.key_name
  iam_instance_profile   = local.instance_profile

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = { Name = local.db_name, Funcao = "db" }

  lifecycle {
    ignore_changes = [ami]
  }

  # Sem NAT a VM não consegue instalar pacotes na primeira configuração
  depends_on = [aws_route.private_nat]
}

# Dados do MongoDB em volume próprio: sobrevivem à recriação da VM do banco
resource "aws_ebs_volume" "db_data" {
  availability_zone = local.az
  size              = var.db_volume_size
  type              = "gp3"
  encrypted         = true

  tags = { Name = "${local.name}-mongo-data" }
}

resource "aws_volume_attachment" "db_data" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.db_data.id
  instance_id                    = aws_instance.db.id
  stop_instance_before_detaching = true
}
