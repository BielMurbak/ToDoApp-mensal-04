# Permissão das VMs para gravar e ler backups no S3 (sem chaves de acesso nas máquinas).
# Na AWS Academy não é possível criar roles: informe instance_profile_name = "LabInstanceProfile".

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "backup" {
  statement {
    sid       = "ListarBackups"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.backup_bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["backups/${var.environment}/*"]
    }
  }

  statement {
    sid       = "GravarLerBackups"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["arn:aws:s3:::${var.backup_bucket}/backups/${var.environment}/*"]
  }
}

resource "aws_iam_role" "vm" {
  count              = var.instance_profile_name == "" ? 1 : 0
  name               = "${local.name}-vm"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_role_policy" "backup" {
  count  = var.instance_profile_name == "" ? 1 : 0
  name   = "backup-s3"
  role   = aws_iam_role.vm[0].id
  policy = data.aws_iam_policy_document.backup.json
}

resource "aws_iam_instance_profile" "vm" {
  count = var.instance_profile_name == "" ? 1 : 0
  name  = "${local.name}-vm"
  role  = aws_iam_role.vm[0].name
}
