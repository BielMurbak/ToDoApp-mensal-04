# Lidos pela pipeline (scripts/gen-inventory.sh) para montar o inventário do Ansible.

output "environment" {
  value = var.environment
}

output "app_url" {
  description = "Endereço público HTTPS da aplicação."
  value       = "https://${local.app_domain}"
}

output "app_domain" {
  value = local.app_domain
}

output "app_public_ip" {
  value = aws_eip.app.public_ip
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}

output "app_instance_id" {
  value = aws_instance.app.id
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}

output "db_instance_id" {
  value = aws_instance.db.id
}

output "db_data_volume_id" {
  description = "Volume EBS com os dados do MongoDB."
  value       = aws_ebs_volume.db_data.id
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "backup_bucket" {
  value = var.backup_bucket
}

output "backup_prefix" {
  value = "backups/${var.environment}/"
}

output "nat_gateway_enabled" {
  value = var.enable_nat_gateway
}

output "inventory" {
  description = "Resumo das VMs para o inventário de recursos."
  value = {
    app = { name = local.app_name, type = var.app_instance_type, public_ip = aws_eip.app.public_ip, private_ip = aws_instance.app.private_ip }
    db  = { name = local.db_name, type = var.db_instance_type, private_ip = aws_instance.db.private_ip, data_volume = aws_ebs_volume.db_data.id }
  }
}
