variable "project_name" {
  description = "Short project name used in resource naming, e.g. \"ecommerce\"."
  type        = string
}

variable "environment" {
  description = "Environment name, e.g. \"prod\"."
  type        = string
}

variable "location" {
  description = "Azure region for the resource group."
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Common tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}

variable "create_terraform_service_principal" {
  description = <<-EOT
    Whether to create an Entra ID App Registration + Service Principal for Terraform/CI to
    authenticate with. Set to false if you'd rather run Terraform under your own `az login`
    identity (fine for solo/portfolio use) and only want the AKS managed identity created.
  EOT
  type        = bool
  default     = true
}
