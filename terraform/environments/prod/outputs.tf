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
