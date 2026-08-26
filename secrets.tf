// App env vars are injected as machine environment variables at boot.
// Secrets (from `var.secrets` and capabilities) are stored in AWS Secrets Manager
// and loaded by the user-data init script; they are never embedded in user data.
resource "aws_secretsmanager_secret" "app_secret" {
  for_each = local.secret_keys

  name_prefix = "${local.block_name}/${each.value}/"
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "app_secret" {
  for_each = local.secret_keys

  secret_id     = aws_secretsmanager_secret.app_secret[each.value].id
  secret_string = local.all_secrets[each.value]

  lifecycle {
    create_before_destroy = true
  }
}

// Gateway registration secrets follow the same pattern
resource "aws_secretsmanager_secret" "client_secret" {
  count = local.auto_register ? 1 : 0

  name_prefix = "${local.block_name}/registration-client-secret/"
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "client_secret" {
  count = local.auto_register ? 1 : 0

  secret_id     = aws_secretsmanager_secret.client_secret[0].id
  secret_string = var.client_secret

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret" "recovery_key" {
  count = local.auto_register ? 1 : 0

  name_prefix = "${local.block_name}/registration-recovery-key/"
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "recovery_key" {
  count = local.auto_register ? 1 : 0

  secret_id     = aws_secretsmanager_secret.recovery_key[0].id
  secret_string = var.recovery_key

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  secret_arns = concat(
    [for secret in aws_secretsmanager_secret.app_secret : secret.arn],
    aws_secretsmanager_secret.client_secret[*].arn,
    aws_secretsmanager_secret.recovery_key[*].arn,
  )
}

resource "aws_iam_role_policy" "secrets" {
  count = length(local.secret_keys) > 0 || local.auto_register ? 1 : 0

  name   = "read-secrets"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.secrets[0].json
}

data "aws_iam_policy_document" "secrets" {
  count = length(local.secret_keys) > 0 || local.auto_register ? 1 : 0

  statement {
    sid       = "AllowReadSecrets"
    effect    = "Allow"
    resources = local.secret_arns

    actions = [
      "secretsmanager:GetSecretValue",
      "kms:Decrypt",
    ]
  }
}
