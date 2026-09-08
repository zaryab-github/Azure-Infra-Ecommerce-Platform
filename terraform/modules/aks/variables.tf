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

variable "subnet_id" {
  description = "snet-aks subnet ID (from the network module) — Azure CNI assigns pod IPs from here."
  type        = string
}

variable "acr_id" {
  description = "ACR resource ID (from the acr module) — granted AcrPull for the cluster's kubelet identity."
  type        = string
}

variable "workload_identity_id" {
  description = "id-<project>-aks-<env> resource ID (from the identity module) — federated with a Kubernetes ServiceAccount for pod-level Azure access (Key Vault, etc.)."
  type        = string
}

variable "workload_identity_client_id" {
  type = string
}

variable "workload_identity_principal_id" {
  type = string
}

variable "workload_identity_namespace" {
  description = "Kubernetes namespace the federated ServiceAccount lives in."
  type        = string
  default     = "ecommerce"
}

variable "workload_identity_service_account_name" {
  type    = string
  default = "ecommerce-workload-sa"
}

variable "node_vm_size" {
  description = "Node pool VM size. Standard_B2s is a low-cost burstable size — bump it if pods get evicted for resource pressure."
  type        = string
  default     = "Standard_B2s"
}

variable "node_count" {
  description = "Fixed node count. Kept small and non-autoscaling by default for predictable cost — override via node_min_count/node_max_count + enable_auto_scaling if you want elasticity."
  type        = number
  default     = 1
}

variable "enable_auto_scaling" {
  type    = bool
  default = false
}

variable "node_min_count" {
  type    = number
  default = 1
}

variable "node_max_count" {
  type    = number
  default = 2
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for the AKS monitoring add-on (Phase 11's monitoring module output). Left null until Phase 11 — the add-on is simply omitted while null."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Left null to track whatever AKS currently defaults new clusters to."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Control plane SLA tier. \"Free\" has no uptime SLA and costs nothing extra — appropriate for a portfolio lab; a real production cluster would use \"Standard\"."
  type        = string
  default     = "Free"
}

variable "tags" {
  type    = map(string)
  default = {}
}
