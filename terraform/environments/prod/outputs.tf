output "resource_group_name" {
  value = module.identity.resource_group_name
}

output "aks_workload_identity_client_id" {
  value = module.identity.aks_workload_identity_client_id
}

output "terraform_sp_client_id" {
  value = module.identity.terraform_sp_client_id
}

output "vnet_id" {
  value = module.network.vnet_id
}

output "aks_subnet_id" {
  value = module.network.aks_subnet_id
}

output "appgw_subnet_id" {
  value = module.network.appgw_subnet_id
}

output "data_subnet_id" {
  value = module.network.data_subnet_id
}

output "nat_gateway_public_ip" {
  value = module.network.nat_gateway_public_ip
}

output "mgmt_subnet_id" {
  value = module.network.mgmt_subnet_id
}

output "mgmt_vm_public_ip" {
  value = module.management_vm.public_ip
}

output "mgmt_vm_private_ip" {
  value = module.management_vm.private_ip
}

output "mgmt_vm_name" {
  value = module.management_vm.vm_name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "sql_server_fqdn" {
  value = module.sql.server_fqdn
}

output "sql_admin_password" {
  value     = module.sql.admin_password
  sensitive = true
}

output "servicebus_namespace_name" {
  value = module.servicebus.namespace_name
}

output "servicebus_connection_string" {
  value     = module.servicebus.connection_string
  sensitive = true
}

output "storage_account_name" {
  value = module.storage.account_name
}

output "storage_product_images_url" {
  value = "${module.storage.primary_blob_endpoint}${module.storage.product_images_container_name}"
}

output "keyvault_uri" {
  value = module.keyvault.vault_uri
}

output "app_insights_connection_string" {
  value     = var.enable_monitoring ? module.monitoring[0].app_insights_connection_string : null
  sensitive = true
}

output "appgateway_public_ip" {
  value = var.deploy_appgateway ? module.appgateway[0].public_ip_address : null
}
