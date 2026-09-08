# Phase 4 — Azure Container Registry
#
# Private registry for the three service images. admin_enabled stays false —
# pulls are authorized via RBAC (AcrPull granted to AKS's kubelet identity in
# the aks module, since that identity doesn't exist until Phase 5), not a
# shared admin username/password.

resource "azurerm_container_registry" "main" {
  name                = "acr${var.project_name}${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}
