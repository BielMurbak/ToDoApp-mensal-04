# Regras em recursos separados (não inline): a regra temporária de SSH que a pipeline cria
# para o IP do runner não é apagada nem aparece como alteração no plan.

# ---------- VM da aplicação: entrada pública só por HTTP/HTTPS ----------

resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "VM da aplicacao: HTTP/HTTPS publico, SSH restrito"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP (redireciona para HTTPS e validacao do certificado)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS publico"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_admin" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.app.id
  description       = "SSH administrativo"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Saida liberada (pacotes, imagens, banco)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- VM do banco: só a VM da aplicação entra ----------

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "VM do MongoDB: acesso apenas pela VM da aplicacao"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_mongo_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MongoDB somente a partir da API"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
}

resource "aws_vpc_security_group_ingress_rule" "db_ssh_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "SSH via VM da aplicacao (bastion) para o Ansible"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id
  description       = "Saida via NAT/endpoint S3 (pacotes, imagens, backups)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
