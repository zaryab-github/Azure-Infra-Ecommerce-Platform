# Application Gateway (WAF)

Built in **Phase 12** (`terraform/modules/appgateway`). See [`docs/deployment_phases/phase-12-security.md`](../deployment_phases/phase-12-security.md) for the two-step deploy.

## What it is

A layer-7 reverse proxy + Web Application Firewall (WAF_v2, OWASP 3.2 ruleset, Prevention mode) — the single public entry point for all traffic, per the architecture diagram. Runs in `snet-appgw` (dedicated, provisioned back in Phase 2 specifically for this).

## Why this project uses it

It's what makes "nothing is publicly exposed except through one WAF-protected entry point" true — every other subnet's NSG explicitly denies inbound from the internet (see [network-security-groups.md](network-security-groups.md)); Application Gateway is the deliberate, singular exception.

## Where it's wired in, and the two-step deploy

`terraform/modules/appgateway/main.tf` — `azurerm_application_gateway` + `azurerm_web_application_firewall_policy`. Gated behind `var.deploy_appgateway` (default `false`, `count = 0`) because its backend pool needs the AKS ingress controller's real public IP, which doesn't exist until Phase 5 is applied and `kubectl get svc` has been run — see [azure-load-balancer.md](azure-load-balancer.md).

## Known gap

HTTP-only listener — no TLS. A real domain + certificate would be needed for HTTPS termination here, which this lab doesn't have. Stated plainly in the module and phase doc rather than glossed over.
