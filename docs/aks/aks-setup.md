# AKS setup — full Portal walkthrough and cluster verification

This is the complete record of creating `aks-ecommerce-prod` through the Azure Portal's "Create Kubernetes cluster" wizard — every tab, every field, what it does, why this project needs it (or doesn't), and what was actually selected. Read this before creating another AKS cluster through the Portal — it's everything you'd otherwise have to re-derive from scratch or re-ask about.

The second half of this file walks through the `kubectl get all -A -o wide` output from the actual running cluster, explaining every namespace, pod, and controller you'll see on a freshly created AKS cluster with this project's add-on selections.

> This documents the **Portal (manual)** build. The equivalent Terraform build lives in `terraform/modules/aks/` and is explained in [`docs/azure-services/azure-kubernetes-service.md`](../azure-services/azure-kubernetes-service.md) — the two are meant to produce an equivalent cluster, just through different mechanisms. See [`docs/aks/troubleshooting.md`](troubleshooting.md#terraform--portal-created-resources-diverging) for what it means to have built this manually and reconcile with Terraform later.

---

## 0. Entry point: which "create" option to pick

Azure's **Kubernetes center** offers three starting points. Picking the right one matters:

| Option | What it is | When to use it |
|---|---|---|
| **Kubernetes cluster** ✅ (what this project uses) | The full, manually configured AKS create wizard — every setting exposed, bring your own VNet/subnet, choose your own identity, add-ons | When you want to understand and control every piece — this project's whole purpose |
| **Automated deployments** (AKS Automatic) | A newer, opinionated AKS SKU — Azure auto-picks node sizing, autoscaling, networking, and security defaults, with far fewer knobs exposed | Fast production bootstrapping when you don't want to think about the details — the opposite of this project's learning goal |
| **Deploy application** | A wizard to push an app onto a cluster that **already exists** | Only relevant after a cluster exists — not a creation path |

---

## 1. Basics tab

| Field | What it is | This project's value | Why |
|---|---|---|---|
| Subscription | Which Azure subscription bills for and hosts this cluster | `E-Commerce platform PROD` | The project's one subscription |
| **Resource group** | Which resource group the AKS **resource itself** (the ARM object representing the cluster) lives in | `rg-ecommerce-prod` | **Must be the existing project RG**, not "Create new" — everything else in this project (identity, network, ACR, and later SQL/Key Vault/Service Bus) lives here too. Picking "Create new" here by accident is an easy mistake (it happened during this build) — it silently scatters the cluster into its own isolated resource group, breaking the "everything lives together" convention and any resource-group-scoped role assignments |
| **Cluster preset configuration** | A newer Portal feature — bulk-sets many fields below based on an intended-use template (`Dev/Test`, `Production Standard`, `Production Economy`, etc.) | `Production Standard` was the default; **not fully appropriate for a cost-constrained lab** — see the pricing tier note below | Presets are a shortcut, not a guarantee of the right defaults for your situation — always review what they picked |
| Kubernetes cluster name | The cluster's name | `aks-ecommerce-prod` | Matches this project's naming convention (`<type>-<project>-<env>`) |
| Region | Azure region | `(US) East US` | Same region as everything else in this project |
| **Fleet Manager** | Centrally manages *multiple* AKS clusters as a group (shared policy, coordinated multi-cluster upgrades) | `None` | You have exactly one cluster — Fleet Manager is for organizations running several |
| **Availability zones** | Spreads nodes across physically separate datacenters in the region for resilience against a single zone failing | `None` (grayed out — not available for this location/size combo) | Moot anyway with a single-node cluster — nothing to spread |
| **AKS pricing tier** | The **control-plane SLA tier**. `Free` = no uptime SLA, $0 extra cost. `Standard` = an SLA-backed control plane, ~$0.10/hr (~$73/mo) — billed **continuously, even while the cluster/nodes are stopped**, because it's a control-plane fee, not a node compute charge | **Change this to `Free`** | The `Production Standard` preset silently selects `Standard`. This is the single most important field to check on this whole tab — it's a real recurring cost that `az aks stop` does *not* stop |
| Enable long-term support | A paid add-on to keep running a Kubernetes version past its normal support window | Unchecked | Not relevant — this project tracks current versions |
| Kubernetes version | Which Kubernetes version the cluster runs | `1.35.7 (default)` | Latest default is fine |
| **Automatic upgrade** | Auto-applies Kubernetes patch-level upgrades on a schedule | `Enabled with patch (recommended)` | Reasonable default — but know that upgrades create temporary surge nodes, which can collide with a tight vCPU quota (see §9 and [`docs/aks/troubleshooting.md`](troubleshooting.md)). Set to `Disabled` if you want full manual control while quota-constrained |
| Automatic upgrade scheduler | When automatic upgrades run, if enabled | Weekly, Sunday | Only matters if the above is enabled |
| **Node security channel type** | Separate from Kubernetes version upgrades — auto-refreshes the underlying node **OS image** for security patches | `Node Image` | Reasonable default |
| Security channel scheduler | When node image refreshes run | Weekly, Sunday | Pairs with the above |
| **Authentication and Authorization** | How `kubectl` authenticates and how access to Kubernetes objects is governed | `Local accounts with Kubernetes RBAC` | ✅ Correct — this is exactly what [`docs/aks/rbac-and-identity.md`](rbac-and-identity.md) assumes: `az aks get-credentials` gives a certificate-based kubeconfig, and Kubernetes object access is plain `Role`/`RoleBinding`, not Azure-AD-mediated. The alternative ("Azure AD authentication with Azure RBAC") unifies the two RBAC systems that doc describes as separate — more enterprise-appropriate, not needed here |

---

## 2. Node pools tab

The overview table (before editing a pool):

| Field | What it is |
|---|---|
| **Node auto-provisioning (NAP)** | A Karpenter-like feature — AKS automatically picks VM sizes and creates/deletes node pools on its own based on pending pod requirements. Still needs real vCPU quota to provision anything — doesn't get around a quota cap, just automates around it. **Left unchecked** — this project's Terraform module doesn't use it, and manual control is easier to reason about on a tight quota |
| **Node pools table** | Two rows by default: `agentpool` (**System** mode — mandatory, runs core AKS components like CoreDNS and metrics-server) and `userpool` (**User** mode — optional, meant to separate app workloads from system pods). Both defaulted to `Standard_D8ds_v5` (8 vCPU/32GB) with autoscale ranges `2-5` and `2-100` — wildly oversized for this project's quota |
| **Enable virtual nodes** | Lets pods burst onto serverless Azure Container Instances instead of real VM nodes — bypasses node capacity entirely, at ACI's own separate cost/quota | Left unchecked — adds complexity (dedicated subnet, Linux-only) this lab doesn't need |
| **Node pool OS disk encryption** | All AKS disks are encrypted at rest by default with Microsoft-managed keys; the alternative is bring-your-own-key via a Key Vault-backed Disk Encryption Set | Left at default (Microsoft-managed key) — the BYOK option is a compliance feature for regulated environments |

### What was actually done here

Given this subscription's quota (≈2 vCPUs total, shared with the management VM's own `Standard_B2s`):

1. **Deleted `userpool` entirely** — no quota headroom for a second pool. This isn't a compromise; running system pods and app pods on one pool is exactly what this project's Terraform module does too.
2. **Resized `agentpool`** away from `Standard_D8ds_v5` (blocked anyway — unavailable for this subscription) to a size that fits the quota.

### The "Update node pool" panel, field by field

| Field | Value used | Notes |
|---|---|---|
| Node pool name | `agentpool` | |
| Mode | `System` | Required — the primary pool must be System mode |
| OS type | `Linux` | Required for System pools |
| OS SKU | `Ubuntu Linux` | Standard |
| Availability zones | `Zones 1, 2, 3` | Harmless but moot with a single node — nothing to spread across zones. `None` would be equally correct |
| Enable Azure Spot instances | Grayed out — not allowed for System pools (a System pool must be reliably available; Spot VMs can be reclaimed by Azure anytime) | N/A |
| **Node size** | `Standard D2as v7` — **2 vCPU, 8 GiB** | Fits the 2-vCPU quota exactly, and 8GB memory is comfortably above the ~4GB floor needed so AKS's own memory reservation doesn't starve app pods. Bonus: `Dasv7` is a **different VM family** than the management VM's `Bsv2`, so it draws from a **separate regional quota pool** — doesn't compete with the management VM for the same vCPUs, which was the root cause of the very first `InsufficientVCPUQuota` error hit during setup |
| Scale method | `Autoscale`, Min `1` / Max `1` | Functionally identical to a fixed count of 1 (min = max = no room to scale) — works fine. For exact parity with the Terraform module (`enable_auto_scaling = false`, fixed `node_count = 1`), `Manual` + count 1 would be the literal equivalent, but there's no functional difference |

**General lesson for future node sizing on a constrained subscription**: pick a VM size that (a) fits your vCPU quota exactly or under, (b) has enough memory headroom (≥4GB) for AKS's own overhead, and (c) ideally sits in a *different VM family* than any other VM you're running in the same region, so you're not drawing from the same shared quota pool.

---

## 3. Networking tab

| Field | What it does | This project's value | Why |
|---|---|---|---|
| **Enable private cluster** | Restricts the API server to a private endpoint only reachable from inside the VNet | Unchecked | Simpler for a lab — otherwise every `kubectl` command requires being on the VNet |
| **Set authorized IP ranges** | Allow-lists which public IPs can reach the (still-public) API server | Unchecked | Good future hardening step (lock to the management VM's IP); skipped for now |
| **Network configuration**: `Azure CNI Node Subnet` (not `Azure CNI Overlay`) | Node Subnet = pods get real, routable IPs from the cluster's VNet subnet. Overlay = pods get IPs from a separate virtual range, more IP-efficient but not directly reachable from other VNet resources | `Azure CNI Node Subnet` | ✅ Correct — matches this project's Terraform (`network_plugin = "azure"`, classic mode) and is why `snet-aks` was deliberately sized `/20` back in Phase 2 |
| **Bring your own Azure virtual network** ✅ | Reuses an existing VNet/subnet instead of Azure creating an isolated one | Checked, `vnet-ecommerce-prod` / `snet-aks (10.0.0.0/20)` | Reuses Phase 2's network |
| **User assigned managed identity** | The identity AKS's control plane uses for Azure-level operations (managing the Load Balancer, Public IPs, route tables) — **required** the moment you bring your own VNet, because Azure needs an explicit identity it can pre-authorize on your specific subnet, rather than silently generating a hidden one | `id-ecommerce-aks-prod` (the same identity Phase 1 created for pod-level workload identity — reused here for the control plane too, since it's the only user-assigned identity available; a stricter setup would use two separate identities) | Required whenever "bring your own VNet" is checked. May need `Network Contributor` granted on the VNet/subnet if cluster creation fails on permissions |
| **Kubernetes service address range** | The **virtual**, non-VNet-routable CIDR backing ClusterIP Services (e.g. `kube-dns`, and this project's `user-service`/`product-service`/`order-service` Services). Must not overlap the VNet at all | `172.16.0.0/16` | Azure's default guess (`10.0.0.0/16` or `10.0.0.0/20`) **collides with this project's VNet** (`10.0.0.0/16`) — hit this error twice during setup before settling on a genuinely disjoint range |
| **Kubernetes DNS service IP** | The cluster DNS service's virtual IP — must fall inside the service range above | `172.16.0.10` | Convention: `.0.10` within the service range |
| DNS name prefix | Label used to build the API server's public FQDN | `aks-ecommerce-prod-dns` | Cosmetic |
| **Enable Cilium dataplane and network policy engine** | Cilium (eBPF-based) vs. Azure's iptables-based `NetworkPolicy` engine — both enforce the same standard `networking.k8s.io/v1 NetworkPolicy` objects this project's `kubernetes/security/networkpolicy.yaml` uses | Left enabled (Cilium) | Legitimate choice either way — this project's Terraform literally specifies `network_policy = "azure"`, but Cilium works identically for this project's needs, just a different engine underneath |
| Load balancer | The Azure Load Balancer SKU for any `LoadBalancer`-type Service | `Standard` (fixed, not editable) | Modern default; `Basic` SKU is legacy |

---

## 4. Integrations tab

| Field | What it does | This project's value | Why |
|---|---|---|---|
| **Container registry** | Links a specific ACR to the cluster — Azure auto-creates the `AcrPull` role assignment for the kubelet identity, so nodes can pull images with no manual role-assignment step | `acrecommerceprod1999` | This project's real registry from Phase 4 |
| **Service mesh – Istio / Enable Istio** | Sidecar-proxy service mesh — mTLS, traffic management, service-to-service observability, injected without app code changes | **Unchecked** | This project has no mesh design (see [`docs/aks/service-mesh.md`](service-mesh.md)). This is one of two add-ons that caused the original `Insufficient cpu` scheduling failures when it got enabled elsewhere in an earlier attempt |
| **Azure Policy** | The in-cluster Gatekeeper/OPA admission-controller add-on (adds 3 pods: `gatekeeper-audit`, `gatekeeper-controller` ×2) — different from this project's own **ARM-level** policy (`terraform/modules/security`'s `azurerm_resource_group_policy_assignment` resources, unaffected by this setting) | **Disabled** | The other add-on that ate real node capacity in the earlier attempt. Not part of this project's design; can be re-enabled later with no downside if quota improves |

*Not on this tab in this Portal version*: the **Key Vault Secrets Provider** — moved to the **Security** tab in this newer wizard layout (see §6).

---

## 5. Monitoring tab

None of these are required to create the cluster — all optional, layered observability add-ons.

| Section | What it does | Why/when you'd need it | This project |
|---|---|---|---|
| **Container Insights / Enable Container Logs** | This *is* the `oms_agent` add-on — ships container stdout/stderr and performance data into a Log Analytics workspace. Exactly what this project's **Phase 11** Terraform module wires up | Needed the moment you want historical logs (`kubectl logs` only shows the current/previous container instance) or cluster-wide health trends | **Left disabled** — deferred to Phase 11 deliberately, as its own dedicated step, after the app is running. Nothing breaks either way; pure sequencing choice. Add later with `az aks enable-addons -a monitoring`, using workspace name `log-ecommerce-prod` for naming consistency |
| Cost Preset | Controls how much telemetry gets collected/billed once Container Insights is on | Only relevant once enabled | N/A while disabled |
| **Managed Prometheus / Enable Prometheus metrics** | A separate, fully-managed Prometheus-compatible metrics backend — richer, higher-cardinality metrics than Container Insights | Worth it once you want Grafana-style dashboards and PromQL querying at scale | **Skip** — not part of this project's design; Application Insights (Phase 11) covers the "what is my app doing" need at this project's scale |
| **Managed Grafana / Enable Grafana** | A fully-managed Grafana instance visualizing Managed Prometheus data — its own billed resource | Only useful paired with Managed Prometheus | **Skip** — same reasoning |
| **Container Network Observability (ACNS)** | Deep network-level telemetry — pod-to-pod flow logs, DNS query metrics, built on Cilium's advanced observability | Valuable for debugging complex traffic across many services | **Skip** — 3 services, one simple traffic path each, doesn't need this |
| **Alerts / Enable recommended alert rules** | A pre-built, Azure-curated AKS-specific alert set (node not ready, pods crash-looping, etc.) — complements, doesn't replace, this project's own 2 custom Terraform alerts (AKS node CPU, SQL CPU) | Genuinely useful low-effort safety net | **Optional** — no downside to enabling; skipped here to keep this pass focused, can add in Phase 11 |

---

## 6. Security tab

| Section | What it does | This project's value | Why |
|---|---|---|---|
| **Microsoft Defender for Cloud** | Not a toggle here — informational. Shows which Defender for Containers tier is active **at the subscription level** (governed by this project's `security` Terraform module, `azurerm_security_center_subscription_pricing`, resource type `Containers`) | Confirmed **`Free`** | The `Standard` tier has a real recurring per-vCore cost — worth explicitly verifying this rather than assuming, since it's set at the subscription level, not per-cluster |
| **OpenID Connect (OIDC) / Enable OIDC** | Makes the cluster capable of issuing OIDC tokens Azure AD will trust — the platform prerequisite for workload identity | ✅ Enabled | Matches `oidc_issuer_enabled = true` in this project's Terraform |
| **Workload Identity / Enable Workload Identity** | The webhook + mechanism (`azure-wi-webhook`) that lets a pod exchange its projected OIDC token for a real Azure AD access token | ✅ Enabled | Matches `workload_identity_enabled = true`. Still requires a separate **federated credential** step after cluster creation, binding `id-ecommerce-aks-prod` to the `ecommerce-workload-sa` ServiceAccount — see [`docs/deployment_phases/phase-05-aks.md`](../deployment_phases/phase-05-aks.md) Track B step 8 |
| **Image Cleaner / Enable Image Cleaner** | Automatically deletes stale, unreferenced cached container images from nodes — disk-space and security hygiene (old images can carry old vulnerabilities). This is the `eraser-controller-manager`/`eraser-*` pods. Runs weekly. | ✅ Enabled | No real cost, good practice |
| **Azure Key Vault / Enable secret store CSI driver** | **This is the Key Vault Secrets Provider add-on** — the CSI driver Phase 9's `kubernetes/secrets/secretproviderclass.yaml` depends on entirely | ✅ **Enabled** | Critical to check — without it, nothing about the Key Vault secret-mounting flow works. No cost to enabling (a driver DaemonSet, not a paid service) |
| **Container Network Security (ACNS) / Enable Container Network Security with ACNS** | A *different* ACNS feature than the Monitoring tab's version — advanced network **security** capabilities (encryption, richer policy enforcement). Creates **no policies by default** even when enabled | Disabled | This project already covers network policy the standard way (`kubernetes/security/networkpolicy.yaml`), which works identically with or without this toggle |

---

## 7. Advanced tab

| Field | What it does | This project's value | Why |
|---|---|---|---|
| **Infrastructure resource group** | The auto-generated **"node resource group"** (`MC_...` prefix) — a *second*, AKS-managed resource group, separate from `rg-ecommerce-prod`, where Azure places the actual infrastructure: node VM(s), disks, NICs, the Standard Load Balancer + its public IP. You generally shouldn't hand-edit resources in it — Azure reconciles it to match cluster state | Left at default: `MC_aks-ecommerce-prod_group_aks-ecommerce-prod_eastus` (name reflects the resource group and cluster name at creation time) | Deleting the AKS cluster automatically deletes this entire resource group too — a clean one-step teardown of everything cluster-infrastructure-related |
| **Managed Kubernetes Namespaces** | A newer feature to create/configure namespaces (quotas, network policies, RBAC) directly through the Azure control plane / ARM API instead of `kubectl apply` | Left empty — **no items added** | This project creates its `ecommerce` namespace the plain-Kubernetes way (`kubernetes/namespace.yaml`, `kubectl apply`), consistent with every other manifest in this repo and with the Terraform rebuild, where Kubernetes objects are managed via manifests, not the `azurerm` provider |

---

## 8. Tags tab

Left as `None` for this build. Optionally add `project = ecommerce-platform`, `managed_by = portal` for consistency with the tagging convention this project's Terraform modules use (every resource takes a `tags` variable) — cosmetic, not required.

---

## 9. Review + create — final checks before clicking Create

Before creating, the full summary was checked line by line against this project's design. What to verify on your own future run:

1. **Resource group** = `rg-ecommerce-prod`, not an auto-generated one (the actual blocker hit during this build — caught here).
2. **Node pool size/count** — the Review page's Node pools section is abbreviated (just says how many pools, not size/count) — go back to the Node pools tab to visually confirm size and count, since a wrong pick here is what caused the original quota failure.
3. **AKS pricing tier** = `Free` (checked back on Basics).
4. **Kubernetes service address range** does not overlap the VNet CIDR.
5. **Microsoft Defender for Cloud** = `Free` unless you deliberately want the paid tier.
6. A minor, non-blocking oddity worth knowing: **Access → Resource identity** may show `System-assigned managed identity` even though **Networking → User assigned managed identity** shows `id-ecommerce-aks-prod`. This is expected — AKS can use a system-assigned identity for general control-plane operations while separately using the user-assigned identity specifically for the custom-VNet attachment permission. Verify after creation if you want certainty:
   ```bash
   az aks show --resource-group rg-ecommerce-prod --name aks-ecommerce-prod --query identity
   ```

---

## 10. Post-creation steps

The wizard creates the cluster and its node pool — three things still need doing afterward, none of them in the wizard:

```bash
# 1. Connect kubectl to the new cluster
az aks get-credentials --name aks-ecommerce-prod --resource-group rg-ecommerce-prod

# 2. Enable the ingress controller (Web Application Routing) — NOT on by default
#    in this Portal version; nothing in the Ingress will route traffic without it
az aks approuting enable --resource-group rg-ecommerce-prod --name aks-ecommerce-prod

# 3. Create the federated credential binding the Phase-1 workload identity
#    to the ServiceAccount pods will actually use (Security tab only turned
#    on the platform *capability* for this — this step is the actual binding)
az identity federated-credential create \
  --name fic-ecommerce-workload-prod \
  --identity-name id-ecommerce-aks-prod \
  --resource-group rg-ecommerce-prod \
  --issuer "$(az aks show --resource-group rg-ecommerce-prod --name aks-ecommerce-prod --query oidcIssuerProfile.issuerUrl -o tsv)" \
  --subject "system:serviceaccount:ecommerce:ecommerce-workload-sa" \
  --audience "api://AzureADTokenExchange"
```

Then deploy the workload — see [`docs/deployment_phases/phase-05-aks.md`](../deployment_phases/phase-05-aks.md) for the full `kubectl apply` sequence.

---

## 11. Reading the running cluster — annotated `kubectl get all -A -o wide`

This is the actual output from `aks-ecommerce-prod` right after creation and enabling the ingress add-on, explained namespace by namespace, row by row.

### `app-routing-system` namespace — the ingress controller

```
pod/nginx-cc9466c98-5sm62      1/1     Running     0          5m24s
pod/nginx-cc9466c98-ghq79      0/1     Pending     0          4m42s
```

This is the Web Application Routing add-on's nginx ingress controller, created by `az aks approuting enable`. Its Deployment ships with an HPA (see below) whose **default minimum is 2 replicas** — this single-node cluster only has capacity for 1, so the second pod sat `Pending` (`Node: <none>` — no node had room), the same "old/extra pod holds a reservation it can't use" pattern covered in [`docs/aks/troubleshooting.md`](troubleshooting.md#pending-with-failedscheduling--insufficient-cpu-or-memory). The single `Running` replica was still serving traffic fine — not an outage — but the `Pending` one was permanently unschedulable on this quota, so it was worth clearing rather than leaving around.

**Fix applied**: lowered the HPA's minimum to match actual node capacity:

```bash
kubectl patch hpa nginx -n app-routing-system --type='merge' -p '{"spec":{"minReplicas":1}}'
```

(or `kubectl edit hpa nginx -n app-routing-system` and change `minReplicas` interactively). After this, the Deployment scales down to the 1 replica the node can actually support, and `kubectl get pods -n app-routing-system` shows a single `Running` pod with nothing stuck `Pending`. Worth remembering for any other AKS add-on whose default HPA minimum assumes more node capacity than a small lab cluster actually has.

```
service/nginx           LoadBalancer   172.16.32.116   <pending>   80:30174/TCP,443:32594/TCP
service/nginx-metrics    ClusterIP      172.16.185.4    <none>      10254/TCP
```

`service/nginx` is the public entry point — its `EXTERNAL-IP` shows `<pending>` because Azure is still provisioning the actual Load Balancer public IP (takes 1-3 minutes after the Service is created). Check again shortly with:
```bash
kubectl get svc -n app-routing-system nginx
```
`nginx-metrics` is a separate internal-only Service exposing the ingress controller's own Prometheus-format metrics endpoint (port `10254`) — for scraping, not for your traffic.

```
horizontalpodautoscaler.autoscaling/nginx   Deployment/nginx   cpu: 0%/70%   2   100   2
```
The add-on's own HPA — min 2, max 100 replicas, scaling on CPU. This is what's demanding the second replica the node can't currently provide. Not something you configured; it's the add-on's built-in default.

### `kube-system` namespace — unavoidable AKS baseline, plus the two add-ons you explicitly enabled

Everything here was either already covered in [`docs/aks/README.md`](README.md)'s mental model or is one of your two Security-tab selections:

| Pod / controller | What it is |
|---|---|
| `azure-cns`, `azure-ip-masq-agent`, `cloud-node-manager` | Core Azure/AKS node networking plumbing — always present |
| `cilium`, `cilium-operator` | The network dataplane you selected on the Networking tab (enforces `NetworkPolicy`, handles pod networking) |
| `coredns`, `coredns-autoscaler` | Cluster DNS — resolves `*.svc.cluster.local` names, including `user-service`/`product-service`/`order-service` once deployed |
| `csi-azuredisk-node`, `csi-azurefile-node` | Storage CSI drivers — see [`docs/aks/storage-and-volumes.md`](storage-and-volumes.md); unused by this project's stateless services but always present |
| `konnectivity-agent`, `konnectivity-agent-autoscaler` | The tunnel letting the (Azure-managed) control plane reach into your VNet to talk to nodes — always present |
| `metrics-server` | Feeds live CPU/memory to `kubectl top` and every HPA in the cluster — always present |
| `azure-wi-webhook-controller-manager` | **Your Workload Identity selection** — injects the Azure AD token projection into any pod labeled `azure.workload.identity/use: "true"` |
| `aks-secrets-store-csi-driver`, `aks-secrets-store-provider-azure` | **Your "Enable secret store CSI driver" selection** — the Key Vault CSI driver Phase 9 depends on |
| `eraser-controller-manager` (`Running`), `eraser-aks-agentpool-...` (`0/3 Completed`) | **Your Image Cleaner selection.** The controller runs continuously; the `eraser-aks-agentpool-...` pod is a **one-shot scan job** that already finished — `0/3 Completed` means all 3 of its containers exited successfully (status 0), not a failure. It'll reappear on its weekly schedule |

Notably **absent**: no `gatekeeper-system` namespace (Azure Policy add-on correctly left disabled), no `aks-istio-system` namespace (Istio mesh correctly left disabled) — confirming both Integrations-tab choices took effect and this cluster isn't carrying the extra weight that caused problems in an earlier attempt.

### `default` namespace

```
service/kubernetes   ClusterIP   172.16.0.1   443/TCP
```
The Kubernetes API server itself, exposed internally as a Service so in-cluster clients (like `kubectl` running as a pod, or any SDK using in-cluster config) can reach it at a stable address — present on every Kubernetes cluster, not something you configured.

### Node-level summary

```
kubectl get nodes -o wide
aks-agentpool-35118308-vmss000000   Ready   v1.35.7   Ubuntu 24.04.4 LTS   containerd://2.3.3-2
```
One `Ready` node, the `Standard D2as v7` from §2, running the Kubernetes version from §1, on Ubuntu with `containerd` as the container runtime (standard for AKS — not Docker directly). `ROLES` shows `<none>` — normal for a System-mode pool in current AKS versions; the "System" designation is a Kubernetes label/taint under the hood, not surfaced in this column.

### The overall verdict on this snapshot

Cluster is healthy. The one thing that looked like a problem (`nginx` ingress pod `Pending`) was an expected consequence of the add-on's default HPA minimum (2) exceeding this subscription's single-node capacity — not a misconfiguration, and it wasn't blocking actual traffic even before the fix, since the 1 `Running` replica already served requests through the `LoadBalancer` Service. Resolved by patching the HPA's `minReplicas` down to `1` (§ above) to match real node capacity — `kubectl get pods -n app-routing-system` now shows a clean single `Running` pod with nothing stuck `Pending`.
