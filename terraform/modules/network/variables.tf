variable "resource_group_name" {
  description = "Resource group to create networking resources in (from the identity module)."
  type        = string
}

variable "location" {
  description = "Azure region, should match the resource group's region."
  type        = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vnet_cidr" {
  description = "Address space for the VNet."
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "Subnet for AKS nodes/pods — sized largest since pod IPs are allocated from it (Azure CNI)."
  type        = string
  default     = "10.0.0.0/20"
}

variable "appgw_subnet_cidr" {
  description = "Dedicated subnet for Application Gateway — Azure requires App Gateway to have its own subnet with no other resources."
  type        = string
  default     = "10.0.16.0/24"
}

variable "data_subnet_cidr" {
  description = "Subnet reserved for private endpoints to SQL/Redis/Key Vault (added in later phases)."
  type        = string
  default     = "10.0.17.0/24"
}

variable "mgmt_subnet_cidr" {
  description = "Subnet for the management/admin VM — isolated from the workload subnets, same VNet."
  type        = string
  default     = "10.0.18.0/24"
}

variable "admin_source_cidr" {
  description = <<-EOT
    CIDR allowed to SSH into the management subnet, e.g. "203.0.113.5/32" (your
    public IP). Required — there is no default, so you must set this deliberately
    rather than accidentally leaving SSH open to the internet.
  EOT
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
