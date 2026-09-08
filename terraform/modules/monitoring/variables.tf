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

variable "aks_id" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "sql_database_id" {
  type = string
}

variable "alert_email" {
  description = "Email address for the action group alerts fire to. No default — set it deliberately."
  type        = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
