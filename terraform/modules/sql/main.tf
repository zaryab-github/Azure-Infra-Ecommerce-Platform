# Phase 6 — Databases
#
# One logical server + one Serverless database (auto-pauses when idle) for
# all three services' tables (Users/Products/Orders — schema created by each
# service on startup, see Application_services/*/src/db.js). Reached only via
# a private endpoint in snet-data — public_network_access_enabled is false,
# so nothing outside the VNet can reach it directly.
#
# The admin password is Terraform-generated and surfaced as a sensitive
# output. Until Phase 9 (Key Vault) lands, it's copied into a plain
# Kubernetes Secret by hand — see docs/deployment_phases/phase-06-databases.md.
# Phase 9 supersedes that manual step with a Key Vault-sourced secret.

resource "random_password" "sql_admin" {
  length      = 24
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

resource "azurerm_mssql_server" "main" {
  name                          = "sql-${var.project_name}-${var.environment}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_username
  administrator_login_password  = random_password.sql_admin.result
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_mssql_database" "main" {
  name                        = "sqldb-${var.project_name}-${var.environment}"
  server_id                   = azurerm_mssql_server.main.id
  sku_name                    = var.sku_name
  auto_pause_delay_in_minutes = var.auto_pause_delay_in_minutes
  min_capacity                = var.min_capacity
  zone_redundant              = false
  tags                        = var.tags
}

# --- Private endpoint --------------------------------------------------

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "link-${var.project_name}-sql-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = var.vnet_id
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-${var.project_name}-sql-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}
