# Phase 12 — Security

Goal: the last piece of the architecture diagram (Application Gateway + WAF as the single public entry point), Kubernetes NetworkPolicies, baseline Azure Policy guardrails, and Microsoft Defender for Cloud.

> **Where this runs**: from the management VM.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_application_gateway` (WAF_v2, autoscale 0-2) + `azurerm_web_application_firewall_policy` (OWASP 3.2, Prevention) | The public entry point — see [`docs/azure-services/application-gateway-waf.md`](../azure-services/application-gateway-waf.md) |
| `azurerm_resource_group_policy_assignment` × 2 (Require a tag, Allowed locations) | Governance guardrails on `rg-ecommerce-prod` |
| `azurerm_security_center_subscription_pricing` × 4 (VMs, SQL, Key Vaults, Containers) | Defender for Cloud — Free tier by default |
| `kubernetes/security/networkpolicy.yaml` | Default-deny + explicit allows within the `ecommerce` namespace |

**Known gap, stated plainly**: this project's HTTP-only Application Gateway listener has no TLS — that needs a real domain + certificate, which this lab doesn't have. A real deployment would terminate TLS here with a cert from Key Vault. Also, deep private-endpoint hardening (Key Vault, beyond what SQL already has) is a documented stretch, not done in this pass.

## Two-step deploy — App Gateway needs the ingress controller's real IP

App Gateway's backend pool must point at a real IP, which doesn't exist until AKS + its ingress are running (Phase 5). So:

```bash
# 1. Get the ingress controller's public IP (already running since Phase 5)
INGRESS_IP=$(kubectl get svc -n app-routing-system nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# 2. Set it in terraform.tfvars
#    deploy_appgateway      = true
#    appgw_backend_address  = "<INGRESS_IP>"

# 3. Apply
terraform -chdir=terraform/environments/prod plan -target=module.appgateway -target=module.security
terraform -chdir=terraform/environments/prod apply -target=module.appgateway -target=module.security
```

Until `deploy_appgateway = true`, `module.appgateway` has `count = 0` — it's entirely skipped, so nothing about earlier phases breaks while you're not ready for this one yet.

## Track B — Azure Portal

**Application Gateway**: `rg-ecommerce-prod` → **+ Create a resource** → **Application Gateway** → tier **WAF V2**, subnet `snet-appgw`, frontend **Public**, backend pool target = the ingress IP above, HTTP settings port 80, listener port 80 → **WAF policy** tab → create new, ruleset **OWASP 3.2**, mode **Prevention**.

**Policy**: Subscription → **Policy** → **Definitions** → search "Require a tag on resources" / "Allowed locations" → **Assign**, scope = `rg-ecommerce-prod`.

**Defender**: Subscription → **Microsoft Defender for Cloud** → **Environment settings** → your subscription → toggle plans for Servers/SQL/Key Vault/Containers (Free tier, or Standard if you want the paid trial).

**Network Policy**: no Portal path — Kubernetes NetworkPolicy is always `kubectl apply`:

```bash
kubectl apply -f kubernetes/security/networkpolicy.yaml
```

## Verification

```bash
curl http://<appgateway-public-ip>/api/users   # now via App Gateway + WAF, not the raw ingress IP
az policy assignment list --resource-group rg-ecommerce-prod --output table
az security pricing list --output table
kubectl get networkpolicy -n ecommerce
```

## Cost / Teardown

App Gateway WAF_v2 is the notable new cost here (autoscale min 0 keeps it low when idle, but it's not a hard stop). Policy/Defender Free tier cost nothing. See [`docs/cost-management.md`](../cost-management.md) — `terraform destroy -target=module.appgateway` removes it cleanly; flip `deploy_appgateway` back to `false` first so a subsequent `apply` doesn't recreate it.

## Next

Phase 13 (optional) — GitOps.
