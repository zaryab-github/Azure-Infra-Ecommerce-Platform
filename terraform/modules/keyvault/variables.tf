variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "aks_key_vault_csi_identity_object_id" {
  description = "The AKS-managed CSI Key Vault provider's own identity (aks module output) — granted Secrets User so pods can mount secrets via SecretProviderClass."
  type        = string
}

variable "mgmt_vm_identity_principal_id" {
  description = "Management VM's identity (management-vm module output) — granted Secrets User for az keyvault CLI debugging from the VM."
  type        = string
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
}

variable "sql_server_fqdn" {
  type = string
}

variable "sql_database_name" {
  type = string
}

variable "sql_admin_username" {
  type = string
}

variable "servicebus_connection_string" {
  type      = string
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
