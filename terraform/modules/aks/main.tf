# Phase 5 — AKS
#
# The cluster: system-assigned control-plane identity, Azure CNI into
# snet-aks (sized /20 for pod IPs — see Phase 2), the built-in Key Vault
# Secrets Provider add-on (Phase 9 grants it access, no manual CSI driver
# install needed), the built-in Web Application Routing add-on as the
# ingress controller (nginx-based, Azure-managed), and workload identity
# federation so pods can use id-<project>-aks-<env> (from Phase 1) instead
# of any stored credential. See docs/deployment_phases/phase-05-aks.md.

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = "${var.project_name}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  tags                = var.tags

  default_node_pool {
    name                = "system"
    vm_size             = var.node_vm_size
    vnet_subnet_id      = var.subnet_id
    node_count          = var.enable_auto_scaling ? null : var.node_count
    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.enable_auto_scaling ? var.node_min_count : null
    max_count           = var.enable_auto_scaling ? var.node_max_count : null
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  # Lets pods authenticate to Azure (Key Vault, Storage, etc.) via a
  # federated Kubernetes ServiceAccount instead of a stored credential.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # AKS-managed CSI Secrets Store driver for Key Vault — Phase 9 grants this
  # add-on's own identity read access to the vault; no manual Helm install.
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # Managed nginx ingress controller — Azure runs and patches it.
  web_app_routing {
    dns_zone_ids = []
  }

  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id == null ? [] : [1]
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }
}

# Nodes need to pull images from ACR — granted to the auto-created kubelet
# identity, not the cluster's control-plane identity (different principal).
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Federates the Phase-1 user-assigned identity with a Kubernetes
# ServiceAccount, so pods annotated with that ServiceAccount can request an
# Azure AD token for it — no secret, no CSI driver needed for this path.
resource "azurerm_federated_identity_credential" "workload" {
  name                = "fic-${var.project_name}-workload-${var.environment}"
  resource_group_name = var.resource_group_name
  parent_id           = var.workload_identity_id
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject             = "system:serviceaccount:${var.workload_identity_namespace}:${var.workload_identity_service_account_name}"
  audience            = ["api://AzureADTokenExchange"]
}
