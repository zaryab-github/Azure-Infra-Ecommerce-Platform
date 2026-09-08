# Phase 9 — Secrets
#
# RBAC-authorized Key Vault (not the older access-policy model) holding the
# secrets Phase 6/7 had you paste into plain Kubernetes Secrets by hand:
# sql-admin-password, sql-connection-string, servicebus-connection-string —
# plus a reserved jwt-secret for when the services grow real auth. AKS reads
# these via the CSI Key Vault provider add-on (Phase 5) and a
# SecretProviderClass (kubernetes/), not via any SDK code in the services.
#
# CAVEAT: whichever identity runs `terraform apply` for THIS module needs
# "Key Vault Secrets Officer" on the vault to write the secret resources
# below. The role assignment granting that to the management VM's identity
# is in this same apply — Azure RBAC can take a minute or two to propagate,
# so the very first apply of this module may need to run from a session that
# already has rights (e.g. your own `az login`), or be re-run once if it
# fails on the secret resources. See docs/deployment_phases/phase-09-secrets.md.

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.project_name}-${var.environment}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = false # lab convenience — allows clean teardown; a real prod vault would enable this
  soft_delete_retention_days = 7
  tags                       = var.tags
}

resource "azurerm_role_assignment" "csi_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.aks_key_vault_csi_identity_object_id
}

resource "azurerm_role_assignment" "mgmt_vm_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.mgmt_vm_identity_principal_id
}

resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "sql-connection-string"
  value        = "Server=tcp:${var.sql_server_fqdn},1433;Database=${var.sql_database_name};User ID=${var.sql_admin_username};Password=${var.sql_admin_password};Encrypt=true;"
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "servicebus_connection_string" {
  name         = "servicebus-connection-string"
  value        = var.servicebus_connection_string
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = random_password.jwt_secret.result
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}
