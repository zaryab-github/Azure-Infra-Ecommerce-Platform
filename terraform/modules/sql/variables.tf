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
  description = "snet-data subnet ID (from the network module) — the private endpoint lands here."
  type        = string
}

variable "vnet_id" {
  description = "VNet ID (from the network module) — the private DNS zone is linked to it."
  type        = string
}

variable "sql_admin_username" {
  type    = string
  default = "sqladmin"
}

variable "sku_name" {
  description = "Serverless Gen5 tier — auto-pauses on idle (near-zero cost when not in use), per docs/cost-management.md."
  type        = string
  default     = "GP_S_Gen5_1"
}

variable "auto_pause_delay_in_minutes" {
  type    = number
  default = 60
}

variable "min_capacity" {
  type    = number
  default = 0.5
}

variable "tags" {
  type    = map(string)
  default = {}
}
