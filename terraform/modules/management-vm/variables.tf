variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "resource_group_name" {
  description = "Resource group to create the VM in (from the identity module)."
  type        = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  description = "The snet-mgmt subnet ID (from the network module)."
  type        = string
}

variable "admin_username" {
  description = "Linux admin username for SSH login."
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "Your SSH public key contents (e.g. the contents of ~/.ssh/id_ed25519.pub). Password auth is disabled — key-only."
  type        = string
}

variable "vm_size" {
  description = "VM size. Standard_B2s is a low-cost burstable size, enough to run az/terraform/kubectl/docker builds."
  type        = string
  default     = "Standard_B2s"
}

variable "os_disk_size_gb" {
  description = "OS disk size — sized up from the default to comfortably hold Docker images pulled/built during testing."
  type        = number
  default     = 64
}

variable "tags" {
  type    = map(string)
  default = {}
}
