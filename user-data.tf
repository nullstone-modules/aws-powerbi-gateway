locals {
  user_data = templatefile("${path.module}/user-data.ps1.tpl", {
    env_vars   = data.ns_env_values.this.env_variables
    secret_ids = { for key, secret in aws_secretsmanager_secret.app_secret : key => secret.id }

    auto_register    = local.auto_register
    application_id   = var.application_id
    tenant_id        = var.tenant_id
    gateway_name     = local.gateway_name
    gateway_region   = var.gateway_region
    client_secret_id = local.auto_register ? aws_secretsmanager_secret.client_secret[0].id : ""
    recovery_key_id  = local.auto_register ? aws_secretsmanager_secret.recovery_key[0].id : ""
  })
}
