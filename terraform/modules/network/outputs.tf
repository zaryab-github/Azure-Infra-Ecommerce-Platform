output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "data_subnet_id" {
  value = azurerm_subnet.data.id
}

output "mgmt_subnet_id" {
  value = azurerm_subnet.mgmt.id
}

output "mgmt_nsg_id" {
  value = azurerm_network_security_group.mgmt.id
}

output "aks_nsg_id" {
  value = azurerm_network_security_group.aks.id
}

output "appgw_nsg_id" {
  value = azurerm_network_security_group.appgw.id
}

output "data_nsg_id" {
  value = azurerm_network_security_group.data.id
}

output "nat_gateway_public_ip" {
  value = azurerm_public_ip.nat.ip_address
}
