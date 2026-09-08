output "server_fqdn" {
  value = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "database_name" {
  value = azurerm_mssql_database.main.name
}

output "database_id" {
  value = azurerm_mssql_database.main.id
}

output "admin_username" {
  value = var.sql_admin_username
}

output "admin_password" {
  value     = random_password.sql_admin.result
  sensitive = true
}
