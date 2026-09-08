variable "resource_group_id" {
  type = string
}

variable "allowed_location" {
  description = "The one Azure region resources are allowed to be created in, enforced by the Allowed Locations policy."
  type        = string
}

variable "defender_tier" {
  description = "\"Free\" costs nothing; \"Standard\" is the paid trial tier with real threat detection. Kept Free by default for cost — see docs/cost-management.md before switching this."
  type        = string
  default     = "Free"
}
