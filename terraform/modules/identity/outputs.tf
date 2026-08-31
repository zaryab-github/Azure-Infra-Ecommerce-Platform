output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "resource_group_id" {
  value = azurerm_resource_group.main.id
}

output "location" {
  value = azurerm_resource_group.main.location
}

output "terraform_sp_client_id" {
  description = "Application (client) ID of the Terraform/CI service principal, if created."
  value       = var.create_terraform_service_principal ? azuread_application.terraform[0].client_id : null
}

output "terraform_sp_password" {
  description = "Client secret for the Terraform/CI service principal, if created. Sensitive."
  value       = var.create_terraform_service_principal ? azuread_service_principal_password.terraform[0].value : null
  sensitive   = true
}

output "aks_workload_identity_id" {
  value = azurerm_user_assigned_identity.aks_workload.id
}

output "aks_workload_identity_principal_id" {
  value = azurerm_user_assigned_identity.aks_workload.principal_id
}

output "aks_workload_identity_client_id" {
  value = azurerm_user_assigned_identity.aks_workload.client_id
}
