# Phase 1 — Identity
#
# Creates the project's resource group, an optional Entra ID App Registration +
# Service Principal for Terraform/CI authentication, and a User-Assigned Managed
# Identity that AKS workloads will use from Phase 5 onward (so pods never carry
# long-lived credentials — see docs/phase-01-identity.md).

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# --- Terraform/CI service principal (optional) ------------------------------

resource "azuread_application" "terraform" {
  count        = var.create_terraform_service_principal ? 1 : 0
  display_name = "sp-${var.project_name}-terraform-${var.environment}"
}

resource "azuread_service_principal" "terraform" {
  count     = var.create_terraform_service_principal ? 1 : 0
  client_id = azuread_application.terraform[0].client_id
}

# Password credential for local/CI use. For anything longer-lived than a
# portfolio lab, prefer OIDC workload identity federation for Azure DevOps
# instead of a stored secret — see the note in docs/phase-01-identity.md.
resource "azuread_service_principal_password" "terraform" {
  count                = var.create_terraform_service_principal ? 1 : 0
  service_principal_id = azuread_service_principal.terraform[0].id
  end_date_relative    = "8760h" # 1 year
}

# Scoped to the resource group only, not the subscription — least privilege
# for a service principal whose job is to manage this project's resources.
resource "azurerm_role_assignment" "terraform_contributor" {
  count                = var.create_terraform_service_principal ? 1 : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.terraform[0].object_id
}

# --- AKS workload managed identity -------------------------------------------

resource "azurerm_user_assigned_identity" "aks_workload" {
  name                = "id-${var.project_name}-aks-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}
