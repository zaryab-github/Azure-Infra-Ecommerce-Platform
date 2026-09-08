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

variable "queue_name" {
  type    = string
  default = "orders"
}

variable "tags" {
  type    = map(string)
  default = {}
}
