# Policies and CRDs

## What a CRD is

A **CustomResourceDefinition** teaches the Kubernetes API server a brand-new object type — after registering one, `kubectl get <your-new-type>` works exactly like `kubectl get pods`, backed by whatever controller watches it. This is how Kubernetes gets extended without forking the core API server.

## CRDs actually present on this cluster

```bash
kubectl get crd
```

You'll see (grouped by what added them):

| CRD group | Added by | Used by this project? |
|---|---|---|
| `secretproviderclasses.secrets-store.csi.x-k8s.io`, `secretproviderclasspodstatuses...` | Key Vault Secrets Provider add-on (Phase 5) | **Yes** — `kubernetes/secrets/secretproviderclass.yaml` (Phase 9) |
| `constrainttemplates.templates.gatekeeper.sh`, `constraints.*` (many, one per policy type) | Azure Policy for AKS / Gatekeeper add-on | No — this add-on isn't part of the design (see below) |
| `*.cilium.io` (CiliumNetworkPolicy, CiliumEndpoint, etc.) | Cilium CNI | Indirectly — Cilium enforces the plain `NetworkPolicy` objects this project uses, but nothing here uses Cilium's own CRD types directly |
| Istio CRDs (`virtualservices.networking.istio.io`, etc.), if the mesh add-on is enabled | Istio service mesh add-on | No — see [service-mesh.md](service-mesh.md) |

## Azure Policy for AKS (Gatekeeper) vs. this project's own policy

Two different things share the name "policy," and it's worth being precise:

- **This project's `security` Terraform module** (`terraform/modules/security`) creates `azurerm_resource_group_policy_assignment` resources — **ARM-level** policy, evaluated by Azure itself against your *resource group's* resources (e.g., "does everything have a `project` tag," "is everything in the allowed region"). Nothing to do with Kubernetes objects.
- **The AKS "Azure Policy" add-on** — installs Gatekeeper (an OPA — Open Policy Agent — admission controller) *inside the cluster*, which can block/audit Kubernetes objects themselves (e.g., "reject any Pod without resource limits," "require a specific label"). This is what showed up as the `gatekeeper-system` namespace on your cluster — enabled via the Portal wizard, not something this project's Terraform specifies.

Check what's actually enabled:

```bash
az aks show --resource-group rg-ecommerce-prod --name aks-ecommerce-prod --query addonProfiles.azurepolicy.enabled
kubectl get constrainttemplates    # the actual policy rules Gatekeeper is enforcing, if any are assigned
```

Disable it (frees real node capacity — see [troubleshooting.md](troubleshooting.md)):

```bash
az aks disable-addons --addons azure-policy --resource-group rg-ecommerce-prod --name aks-ecommerce-prod
```

## Other built-in (non-CRD) admission control already in play

- `azure-wi-webhook` — a **mutating** admission webhook (not a CRD) that injects the workload-identity environment variables/volume into any pod labeled `azure.workload.identity/use: "true"`. This is how [rbac-and-identity.md](rbac-and-identity.md)'s workload identity mechanism actually gets applied to your pods without you writing that boilerplate yourself.
- Kubernetes' own built-in `NetworkPolicy` API (not a CRD — it's core Kubernetes) — what `kubernetes/security/networkpolicy.yaml` uses, enforced by whichever CNI dataplane you have (Cilium or Azure, see [networking.md](networking.md)).
