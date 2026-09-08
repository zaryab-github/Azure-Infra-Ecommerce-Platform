# Phase 12 — Application Gateway (WAF)
#
# The one deliberate public entry point (see the architecture diagram in
# docs/ROADMAP.md and the NSG posture in docs/azure-services/network-security-groups.md
# — every other subnet explicitly denies inbound from the Internet). WAF_v2,
# OWASP 3.2 ruleset in Prevention mode. Backend pool points at the AKS
# ingress controller's IP — a two-step deploy, see variables.tf and
# docs/deployment_phases/phase-12-security.md.
#
# No TLS listener here — that needs a real domain + certificate, which this
# project doesn't have. HTTP-only is a known, documented gap for a lab; a
# real deployment would terminate TLS here with a cert from Key Vault.

resource "azurerm_public_ip" "appgw" {
  name                = "pip-${var.project_name}-appgw-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_application_gateway" "main" {
  name                = "agw-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.main.id
  tags                = var.tags

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = 0
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  backend_address_pool {
    name         = "aks-ingress"
    ip_addresses = [var.backend_address]
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "aks-ingress"
    backend_http_settings_name = "http-settings"
  }

  lifecycle {
    precondition {
      condition     = var.backend_address != "0.0.0.0"
      error_message = "backend_address is still the placeholder 0.0.0.0 — deploy AKS + ingress first, get its public IP (kubectl get svc -n app-routing-system), then set backend_address before applying this module."
    }
  }
}
