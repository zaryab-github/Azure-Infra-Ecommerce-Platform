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

# --- Phase 5 — AKS ------------------------------------------------------

variable "aks_node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "aks_node_count" {
  type    = number
  default = 1
}

# --- Phase 11 — Monitoring -------------------------------------------------

variable "enable_monitoring" {
  description = "Gates the monitoring module. Kept true by default (Phase 11 is built), but exists so the AKS module's optional log_analytics_workspace_id reference never hard-fails."
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address Azure Monitor alerts fire to. No default — set it deliberately in terraform.tfvars."
  type        = string
}

# --- Phase 12 — Security ----------------------------------------------------

variable "defender_tier" {
  description = "\"Free\" or \"Standard\" for Microsoft Defender for Cloud. Free by default — see docs/cost-management.md before switching."
  type        = string
  default     = "Free"
}

variable "deploy_appgateway" {
  description = "Set true only once AKS + its ingress controller are running and you have a real appgw_backend_address — see docs/deployment_phases/phase-12-security.md."
  type        = bool
  default     = false
}

variable "appgw_backend_address" {
  description = "Public IP of the AKS ingress controller's LoadBalancer Service. Get it with: kubectl get svc -n app-routing-system nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
  type        = string
  default     = "0.0.0.0"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    project    = "azure-ecommerce-platform"
    managed_by = "terraform"
  }
}
