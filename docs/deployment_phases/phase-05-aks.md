# Phase 5 — AKS

Goal: the cluster running the three services, with an ingress controller, HPA, workload identity, and the Key Vault CSI provider add-on ready for Phase 9.

> **Where this runs**: from the management VM.

> For how AKS actually works once it exists — cluster management, networking, RBAC/identity, storage, service mesh, logging/monitoring, policies/CRDs, and troubleshooting — see [`docs/aks/`](../aks/README.md), a full deep-dive built alongside this phase.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_kubernetes_cluster` (`Standard_B2s`, 1 node, SKU tier Free) | The cluster, in `snet-aks` |
| AcrPull role assignment | Kubelet identity → ACR (Phase 4) |
| OIDC issuer + workload identity federation | Pods use `id-ecommerce-aks-prod` (Phase 1) via a Kubernetes ServiceAccount, no stored credential |
| Key Vault Secrets Provider add-on | AKS-managed CSI driver for Key Vault (Phase 9 grants it access) |
| Web Application Routing add-on | The ingress controller (nginx-based, Azure-managed) |

See [`docs/azure-services/azure-kubernetes-service.md`](../azure-services/azure-kubernetes-service.md) and [`managed-identity.md`](../azure-services/managed-identity.md).

## Track A — Terraform

```bash
terraform -chdir=terraform/environments/prod plan \
  -target=module.acr -target=module.aks
terraform -chdir=terraform/environments/prod apply \
  -target=module.acr -target=module.aks
```

(`enable_monitoring` defaults to `true` but the monitoring module itself isn't targeted here — the AKS module's `log_analytics_workspace_id` input just resolves to `null` until Phase 11's `module.monitoring` is actually applied, per the comment in `main.tf`.)

## Track B — Azure Portal

> For the full field-by-field walkthrough of every tab in this wizard (this summary is condensed), plus an annotated read of the resulting `kubectl get all -A` output, see [`docs/aks/aks-setup.md`](../aks/aks-setup.md).

1. Inside `rg-ecommerce-prod` → **+ Create a resource** → **Azure Kubernetes Service**.
2. **Basics**: name `aks-ecommerce-prod`, region matching the rest, **Free** tier.
3. **Node pools**: edit the default pool — size `Standard_B2s`, node count 1, **Virtual network**: select `vnet-ecommerce-prod` / `snet-aks`, network plugin **Azure CNI**.
4. **Networking**: network policy **Azure**.
5. **Integrations**: Container registry → select `acrecommerceprod` (Portal wires the AcrPull role assignment automatically). Enable **Key Vault Secrets Provider**.
6. **Add-ons**: enable **Web Application Routing**.
7. **Workload identity**: under Security, enable **OIDC issuer** and **Workload Identity**.
8. After creation, manually create the federated credential: cluster → **Workload Identity** → **+ Add** → select `id-ecommerce-aks-prod`, namespace `ecommerce`, service account name `ecommerce-workload-sa`.

## Deploy the manifests

```bash
az aks get-credentials --name aks-ecommerce-prod --resource-group rg-ecommerce-prod

# Substitute placeholders (see each file's header comment)
sed -i "s#<ACR_LOGIN_SERVER>#$(terraform -chdir=terraform/environments/prod output -raw acr_login_server)#g" kubernetes/deployments/*.yaml
sed -i "s#<WORKLOAD_IDENTITY_CLIENT_ID>#$(terraform -chdir=terraform/environments/prod output -raw aks_workload_identity_client_id 2>/dev/null || echo)#g" kubernetes/serviceaccount.yaml

kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/serviceaccount.yaml
kubectl apply -f kubernetes/deployments/
kubectl apply -f kubernetes/services/
kubectl apply -f kubernetes/ingress/
kubectl apply -f kubernetes/hpa/
```

Note: `kubernetes/deployments/*.yaml` still has `<SQL_SERVER_FQDN>` etc. placeholders — fine for now, the pods start and serve their in-memory fallback data (see `docs/services.md`); Phase 6 fills those in.

## Known gap — the AKS NSG blocks direct-to-Load-Balancer traffic (until Phase 12)

`nsg-ecommerce-aks-prod` (Phase 2) is deliberately locked down: its only inbound allowances are traffic from inside the VNet and from the `AzureLoadBalancer` service tag (health probes only) — everything else, including real internet client traffic, is denied by Azure's default rules. That design assumes **Application Gateway (Phase 12)** is the actual public entry point, sitting in front of the Load Balancer. Since Phase 12 doesn't exist yet at this point in the build, and you're hitting the ingress controller's `LoadBalancer` public IP **directly** from the internet to test it, that traffic gets silently dropped by the NSG.

**The telltale symptom**: `curl` to the ingress IP just **hangs indefinitely** — no error, no response, nothing — until you kill it. That's the signature of a dropped connection, not a rejected one (a rejected connection returns "connection refused" almost instantly). If you see an instant error instead of a hang, the problem is something else — see [`docs/aks/troubleshooting.md`](../aks/troubleshooting.md).

**Confirm it**:

```bash
az network nsg rule list --resource-group rg-ecommerce-prod --nsg-name nsg-ecommerce-aks-prod --output table
```

If this comes back **empty** (no custom rules at all), Azure's defaults apply — which do not include an allow for internet-sourced HTTP/HTTPS.

**Fix — a temporary rule, explicitly meant to be removed once Phase 12 exists**:

```bash
az network nsg rule create \
  --resource-group rg-ecommerce-prod \
  --nsg-name nsg-ecommerce-aks-prod \
  --name AllowInternetHTTP-Temporary \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 80 443
```

(Priority must be in the `100–4096` range — Azure rejects lower numbers.) Once Phase 12's Application Gateway is in place as the real front door, delete this rule (`az network nsg rule delete ...`) so the AKS subnet goes back to only accepting traffic that's already passed through the WAF, matching the original design intent.

**After adding the rule, you may briefly see a `502 Bad Gateway` instead of a hang** — that's nginx successfully receiving the request now, just needing a moment to sync its internal backend/endpoint state. It typically clears within seconds on the next request; if it persists, check `kubectl get networkpolicy -A` (a Phase 12 NetworkPolicy blocking ingress-to-pod traffic is the next most likely cause) and `kubectl describe ingress -n ecommerce` (confirms the Ingress is actually routing to the right Service/port).

## Verification

```bash
kubectl get nodes
kubectl get pods -n ecommerce
kubectl get svc -n app-routing-system nginx   # EXTERNAL-IP column — wait for a real IP, not <pending>
```

Full API smoke test, once you have a real `EXTERNAL-IP` (call it `$INGRESS_IP` below):

```bash
curl http://$INGRESS_IP/api/users       # -> JSON: Ada Lovelace, Grace Hopper (seed data)
curl http://$INGRESS_IP/api/products    # -> JSON: Mechanical Keyboard, USB-C Dock (seed data)
curl http://$INGRESS_IP/api/orders      # -> [] — correct; no orders created yet

# Create one, then confirm it shows up:
curl -X POST http://$INGRESS_IP/api/orders -H "Content-Type: application/json" -d "{\"userId\":1,\"productId\":2,\"quantity\":1}"
curl http://$INGRESS_IP/api/orders      # -> now shows the order just created
```


##### Flow of traffic from internet to services #####
Any internet client
  → connects to 52.224.205.77 (Azure Public IP — a real ARM resource)
  → Azure Standard Load Balancer (a real ARM resource, Azure's edge infrastructure)
  → LB rule: frontend port 80 → backend pool = your node, NodePort 30174
  → traffic now arrives at the AKS node's NIC, whose private IP lives inside snet-aks
  → *** THIS is where nsg-ecommerce-aks-prod evaluates it *** — the NSG is attached to
      the subnet, so it inspects traffic as it crosses into snet-aks, not at the
      public IP and not "inside" the Load Balancer itself
  → if NSG allows: node forwards NodePort 30174 traffic to the nginx ingress
      controller pod (the one actually backing that Service)
  → nginx reads its Ingress rules (path-based: /api/users → user-service, etc.)
      and proxies internally to the right Service → Pod




Run each line **directly**, not wrapped in `cat`/heredoc (a recurring mistake in this project's own build — see [`docs/aks/troubleshooting.md`](../aks/troubleshooting.md) for why that matters). If all four calls return real JSON, that confirms the entire path end-to-end: internet → NSG → Load Balancer → nginx Ingress → Kubernetes Service → Pod, working together.

## Cost / Teardown

AKS is the dominant cost in this project. Stop between sessions:

```bash
az aks stop --name aks-ecommerce-prod --resource-group rg-ecommerce-prod
az aks start --name aks-ecommerce-prod --resource-group rg-ecommerce-prod
```

See [`docs/cost-management.md`](../cost-management.md) for full teardown/recreate if pausing longer.

## Next

Phase 6 — Databases.
