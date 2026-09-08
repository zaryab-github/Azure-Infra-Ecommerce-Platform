output "namespace_name" {
  value = azurerm_servicebus_namespace.main.name
}

output "queue_name" {
  value = azurerm_servicebus_queue.orders.name
}

output "connection_string" {
  value     = azurerm_servicebus_namespace_authorization_rule.app.primary_connection_string
  sensitive = true
}
