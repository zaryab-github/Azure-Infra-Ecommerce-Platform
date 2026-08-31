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
