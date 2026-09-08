# Phase 8 — Storage
#
# One Storage Account, three containers. "product-images" is public-read at
# the container level — product photos are meant to be public anyway, and it
# lets product-service link to images by plain URL with no SDK/RBAC code
# needed (see Application_services/product-service). "invoices" and "logs"
# stay private — no service reads/writes them yet in this minimal pass;
# they exist to demonstrate the storage layer per the architecture diagram.

resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "main" {
  name                     = "st${var.project_name}${var.environment}${random_string.storage_suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "product_images" {
  name                  = "product-images"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "container"
}

resource "azurerm_storage_container" "invoices" {
  name                  = "invoices"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}
