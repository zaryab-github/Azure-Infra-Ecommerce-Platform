output "account_name" {
  value = azurerm_storage_account.main.name
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.main.primary_blob_endpoint
}

output "product_images_container_name" {
  value = azurerm_storage_container.product_images.name
}
