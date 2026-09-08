# Phase 12 — Security (governance half)
#
# Two baseline Azure Policy guardrails scoped to the project's resource
# group, and Microsoft Defender for Cloud pricing tiers (subscription-wide —
# Defender doesn't have a resource-group scope, unlike everything else in
# this project). Kept at the Free tier by default; switch defender_tier to
# "Standard" only if you want the paid trial and understand the cost.

data "azurerm_policy_definition_built_in" "require_tag" {
  display_name = "Require a tag on resources"
}

data "azurerm_policy_definition_built_in" "allowed_locations" {
  display_name = "Allowed locations"
}

resource "azurerm_resource_group_policy_assignment" "require_project_tag" {
  name                 = "require-project-tag"
  resource_group_id    = var.resource_group_id
  policy_definition_id = data.azurerm_policy_definition_built_in.require_tag.id
  parameters = jsonencode({
    tagName = { value = "project" }
  })
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  resource_group_id    = var.resource_group_id
  policy_definition_id = data.azurerm_policy_definition_built_in.allowed_locations.id
  parameters = jsonencode({
    listOfAllowedLocations = { value = [var.allowed_location] }
  })
}

resource "azurerm_security_center_subscription_pricing" "vms" {
  tier          = var.defender_tier
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "sql" {
  tier          = var.defender_tier
  resource_type = "SqlServers"
}

resource "azurerm_security_center_subscription_pricing" "keyvaults" {
  tier          = var.defender_tier
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = var.defender_tier
  resource_type = "Containers"
}
