output "vm_name" {
  value = azurerm_linux_virtual_machine.mgmt.name
}

output "public_ip" {
  value = azurerm_public_ip.mgmt.ip_address
}

output "private_ip" {
  value = azurerm_network_interface.mgmt.private_ip_address
}

output "identity_principal_id" {
  description = "Principal ID of the VM's system-assigned managed identity — used for `az login --identity` on the box."
  value       = azurerm_linux_virtual_machine.mgmt.identity[0].principal_id
}
