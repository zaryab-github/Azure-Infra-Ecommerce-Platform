# Management / admin VM — Phase 2b
#
# A single Linux VM in snet-mgmt (a dedicated subnet, isolated from the
# workload subnets) used to run Terraform, kubectl, docker, and az from
# inside Azure rather than from a local laptop. Auth is SSH-key-only, and the
# VM carries a system-assigned managed identity with Contributor on the
# resource group, so `az login --identity` on the box gives it everything it
# needs without ever copying the Terraform service-principal secret onto it.
# See docs/deployment_phases/phase-02b-management-vm.md for the full walkthrough and rationale.

resource "azurerm_public_ip" "mgmt" {
  name                = "pip-${var.project_name}-mgmt-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "mgmt" {
  name                = "nic-${var.project_name}-mgmt-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mgmt.id
  }
}

resource "azurerm_linux_virtual_machine" "mgmt" {
  name                = "vm-${var.project_name}-mgmt-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.mgmt.id,
  ]
  tags = var.tags

  # Key-only login — password authentication is explicitly disabled.
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    admin_username = var.admin_username
  }))

  identity {
    type = "SystemAssigned"
  }
}

# Lets the VM run Terraform/az/kubectl against this project's resource group
# via `az login --identity`, with no stored secret on disk.
resource "azurerm_role_assignment" "mgmt_contributor" {
  scope                = data.azurerm_resource_group.this.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_virtual_machine.mgmt.identity[0].principal_id
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}
