variable "subscription_id" {
  description = "Azure subscription ID to deploy into (from `az account show`)."
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant ID (from `az account show`)."
  type        = string
}

variable "project_name" {
  description = "Short project name used in resource naming."
  type        = string
  default     = "ecommerce"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "create_terraform_service_principal" {
  description = "Whether to create a dedicated Entra ID service principal for Terraform/CI (see identity module)."
  type        = bool
  default     = true
}

variable "vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.0.0.0/20"
}

variable "appgw_subnet_cidr" {
  type    = string
  default = "10.0.16.0/24"
}

variable "data_subnet_cidr" {
  type    = string
  default = "10.0.17.0/24"
}

variable "mgmt_subnet_cidr" {
  type    = string
  default = "10.0.18.0/24"
}

variable "admin_source_cidr" {
  description = "Your public IP in CIDR form, e.g. \"203.0.113.5/32\" — the only source allowed to SSH into the management VM. Find yours with: curl -s ifconfig.me"
  type        = string
}

variable "mgmt_admin_username" {
  description = "Linux admin username on the management VM."
  type        = string
  default     = "azureadmin"
}

variable "mgmt_ssh_public_key" {
  description = "Your SSH public key (contents of e.g. ~/.ssh/id_ed25519.pub) for logging into the management VM."
  type        = string
}

variable "mgmt_vm_size" {
  description = "Management VM size."
  type        = string
  default     = "Standard_B2s"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    project    = "azure-ecommerce-platform"
    managed_by = "terraform"
  }
}
