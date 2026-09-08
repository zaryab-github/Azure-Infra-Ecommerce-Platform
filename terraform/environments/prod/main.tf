module "identity" {
  source = "../../modules/identity"

  project_name                       = var.project_name
  environment                        = var.environment
  location                           = var.location
  tags                               = var.tags
  create_terraform_service_principal = var.create_terraform_service_principal
}

module "network" {
  source = "../../modules/network"

  resource_group_name = module.identity.resource_group_name
  location            = module.identity.location
  project_name        = var.project_name
  environment         = var.environment
  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
  appgw_subnet_cidr   = var.appgw_subnet_cidr
  data_subnet_cidr    = var.data_subnet_cidr
  mgmt_subnet_cidr    = var.mgmt_subnet_cidr
  admin_source_cidr   = var.admin_source_cidr
  tags                = var.tags
}

module "management_vm" {
  source = "../../modules/management-vm"

  project_name        = var.project_name
  environment         = var.environment
  resource_group_name = module.identity.resource_group_name
  location            = module.identity.location
  subnet_id           = module.network.mgmt_subnet_id
  admin_username      = var.mgmt_admin_username
  ssh_public_key      = var.mgmt_ssh_public_key
  vm_size             = var.mgmt_vm_size
  tags                = var.tags
}

# --- Phase 4 — Azure Container Registry -------------------------------

module "acr" {
  source = "../../modules/acr"

  project_name        = var.project_name
  environment         = var.environment
  resource_group_name = module.identity.resource_group_name
  location            = module.identity.location
  tags                = var.tags
}

# --- Phase 5 — AKS ------------------------------------------------------

module "aks" {
  source = "../../modules/aks"

  project_name                   = var.project_name
  environment                    = var.environment
  resource_group_name            = module.identity.resource_group_name
  location                       = module.identity.location
  subnet_id                      = module.network.aks_subnet_id
  acr_id                         = module.acr.id
  workload_identity_id           = module.identity.aks_workload_identity_id
  workload_identity_client_id    = module.identity.aks_workload_identity_client_id
  workload_identity_principal_id = module.identity.aks_workload_identity_principal_id
  node_vm_size                   = var.aks_node_vm_size
  node_count                     = var.aks_node_count
  log_analytics_workspace_id     = var.enable_monitoring ? module.monitoring[0].log_analytics_workspace_id : null
  tags                           = var.tags
}

# --- Phase 6 — Databases -------------------------------------------------

module "sql" {
  source = "../../modules/sql"

  project_name        = var.project_name
  environment         = var.environment
  resource_group_name = module.identity.resource_group_name
  location            = module.identity.location
  subnet_id           = module.network.data_subnet_id
  vnet_id             = module.network.vnet_id
  tags                = var.tags
}

# --- Phase 7 — Messaging -------------------------------------------------

module "servicebus" {
  source = "../../modules/servicebus"

  project_name        = var.project_name
  environment         = var.environment
  resource_group_name = module.identity.resource_group_name
  location            = module.identity.location
  tags                = var.tags
}

# --- Phase 8 — Storage ----------------------------------------------------

module "storage" {
  source = "../../modules/storage"

  project_name        = var.project_name
  environment         = var.environment
  resource_group_name = module.identity.resource_group_name
  location            = module.identity.location
  tags                = var.tags
}

# --- Phase 9 — Secrets -----------------------------------------------------

module "keyvault" {
  source = "../../modules/keyvault"

  project_name                         = var.project_name
  environment                          = var.environment
  resource_group_name                  = module.identity.resource_group_name
  location                             = module.identity.location
  tenant_id                            = var.tenant_id
  aks_key_vault_csi_identity_object_id = module.aks.key_vault_secrets_provider_identity_object_id
  mgmt_vm_identity_principal_id        = module.management_vm.identity_principal_id
  sql_admin_password                   = module.sql.admin_password
  sql_server_fqdn                      = module.sql.server_fqdn
  sql_database_name                    = module.sql.database_name
  sql_admin_username                   = module.sql.admin_username
  servicebus_connection_string         = module.servicebus.connection_string
  tags                                 = var.tags
}

# --- Phase 11 — Monitoring -------------------------------------------------
# Gated behind enable_monitoring (default true) only so the aks module above
# can reference module.monitoring[0].log_analytics_workspace_id without a
# hard failure the very first time this config is planned, before Phase 11
# is actually reached — see docs/deployment_phases/phase-11-monitoring.md.

module "monitoring" {
  source = "../../modules/monitoring"
  count  = var.enable_monitoring ? 1 : 0

  project_name        = var.project_name
  environment         = var.environment
  resource_group_name = module.identity.resource_group_name
  location            = module.identity.location
  aks_id              = module.aks.cluster_id
  key_vault_id        = module.keyvault.id
  sql_database_id     = module.sql.database_id
  alert_email         = var.alert_email
  tags                = var.tags
}

# --- Phase 12 — Security ----------------------------------------------------

module "security" {
  source = "../../modules/security"

  resource_group_id = module.identity.resource_group_id
  allowed_location  = var.location
  defender_tier     = var.defender_tier
}

# Gated behind deploy_appgateway (default false) — the backend pool needs the
# AKS ingress controller's real public IP, only known after Phase 5 is
# applied and `kubectl get svc` has been run. See variables.tf and
# docs/deployment_phases/phase-12-security.md.
module "appgateway" {
  source = "../../modules/appgateway"
  count  = var.deploy_appgateway ? 1 : 0

  project_name        = var.project_name
  environment         = var.environment
  resource_group_name = module.identity.resource_group_name
  location            = module.identity.location
  subnet_id           = module.network.appgw_subnet_id
  backend_address     = var.appgw_backend_address
  tags                = var.tags
}
