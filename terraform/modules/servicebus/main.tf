# Phase 7 — Messaging
#
# order-service publishes to the "orders" queue on order creation;
# product-service runs a background receiver that consumes it and decrements
# stock — see docs/services.md for the full flow. Basic tier is enough for
# one queue (Basic doesn't support topics, which this project doesn't need).
#
# Auth is a namespace-scoped Shared Access Policy with Send+Listen only (not
# Manage) — narrower than the namespace's default RootManageSharedAccessKey.
# The connection string is a manual Kubernetes Secret until Phase 9 (Key
# Vault) supersedes it — same pattern as the SQL admin password in Phase 6.

resource "azurerm_servicebus_namespace" "main" {
  name                = "sb-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "orders" {
  name         = var.queue_name
  namespace_id = azurerm_servicebus_namespace.main.id

  max_delivery_count = 10
}

resource "azurerm_servicebus_namespace_authorization_rule" "app" {
  name         = "app-send-listen"
  namespace_id = azurerm_servicebus_namespace.main.id

  listen = true
  send   = true
  manage = false
}
