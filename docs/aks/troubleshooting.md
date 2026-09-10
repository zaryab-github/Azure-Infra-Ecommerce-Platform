# Troubleshooting

A runbook built from what this project's own setup actually hit, generalized so you recognize the pattern next time — not a generic Kubernetes troubleshooting article.

## The general diagnostic order

```bash
kubectl get pods -n ecommerce                          # what's the STATUS column say?
kubectl describe pod <pod-name> -n ecommerce            # Events section at the bottom is almost always the answer
kubectl logs <pod-name> -n ecommerce                    # only useful if the container actually started
kubectl get events -n ecommerce --sort-by='.lastTimestamp'   # cluster-wide recent events, chronological
```

`describe pod`'s **Events** section is the single highest-value command in this whole list — it's where scheduling failures, image pull errors, and probe failures all surface with a human-readable reason.

## `InvalidImageName`

**What it means**: the `image:` field in the pod spec isn't a syntactically valid image reference — most commonly a placeholder substitution that silently produced an empty or malformed value (this project hit exactly this: `<ACR_LOGIN_SERVER>` never got replaced, leaving `image: /order-service:latest` — a leading `/` with nothing before it).

**Diagnose**:
```bash
kubectl get deployment order-service -n ecommerce -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Fix**: correct the source YAML and re-`kubectl apply` — never `kubectl edit` a Deployment as a one-off fix without also fixing the source file, or the next `apply` from the repo reverts it.

## `ImagePullBackOff` / `ErrImagePull`

Different from the above — the image *reference* is syntactically valid, but the pull itself fails. Almost always: (a) the image was never actually pushed (`az acr repository list --name <acr>` to check), or (b) the node's identity lacks `AcrPull` on the registry (check `az role assignment list --scope <acr-resource-id>`), or (c) a typo in the tag.

## `Pending` with `FailedScheduling` / `Insufficient cpu` (or `memory`)

**What it means**: no node has enough *unreserved* capacity to place the pod. Kubernetes reserves a pod's requested CPU/memory the moment it's scheduled — **even if the container inside never successfully starts**. This project hit this exact trap: old pods stuck in `InvalidImageName` were still holding their `100m` CPU reservation, on a node also crowded with Istio + Gatekeeper add-ons never part of the design, on a single `Standard_B2s` (2 vCPU) node.

**Diagnose**:
```bash
kubectl describe node <node-name> | grep -A 15 "Allocated resources"
kubectl get pods -A -o wide | grep <node-name>   # everything currently claiming space on it
```

**Fix, cheapest to most drastic**:
1. Delete stuck/broken pods that will never recover (`kubectl delete rs <bad-replicaset> -n <ns>`) — frees their reservation immediately.
2. Disable add-ons you don't need (see [service-mesh.md](service-mesh.md), [policies-and-crds.md](policies-and-crds.md)).
3. Lower this project's own resource `requests` in the Deployment YAMLs (currently `100m`/`128Mi` per container — already fairly lean).
4. Scale the node pool up — only if your regional vCPU quota allows it (see [cluster-management.md](cluster-management.md)).

## `InsufficientVCPUQuota` at cluster/node-pool creation time

Not a Kubernetes-level problem at all — this is Azure refusing the ARM deployment before anything Kubernetes-related even starts. Your subscription/region has a cap on total VM cores of a given family. Check and request more:

```bash
az vm list-usage --location eastus --output table
```

Or (faster, no waiting on a quota request): pick a smaller node size, fewer nodes, or free up quota by stopping/deleting other VMs in the same region/family (this project's management VM competes for the same quota family if it's also `Standard_B_v2`-series).

## `CrashLoopBackOff`

The container starts, then exits (crashes or completes) repeatedly. `kubectl logs --previous` shows the last crash's output — for this project's services, the most likely cause is an uncaught exception on startup, e.g. the DB init routine throwing if `SQL_SERVER` is set to a value that doesn't actually resolve (check `Application_services/*/src/db.js`'s `getPool()` — it only skips the DB path when the env var is entirely *unset*, not when it's set to something bad).

## Pod stuck in `Pending`, `Node: <none>`, no `FailedScheduling` event yet

Give it a few seconds — the scheduler runs periodically, not instantly. If it persists beyond ~30s with genuinely no event, check `kubectl get nodes` for a node that's `NotReady` (rare, but happens right after a node reboot/patch).

## Secrets not appearing (`app-secrets` missing or empty, Phase 9)

The `SecretProviderClass`'s `secretObjects` sync only triggers once **some pod actually mounts it** — see [`docs/deployment_phases/phase-09-secrets.md`](../deployment_phases/phase-09-secrets.md). Confirm the volume mount exists on the Deployment and that the pod is actually `Running` (a `Pending` pod never mounts anything, so the sync never fires).

## Terraform + Portal-created resources diverging

If you build phases manually through the Portal (as this project's current pass is doing) and later switch to Terraform for the same resources, Terraform has no record of what you built — `terraform plan` will propose *creating* a duplicate of everything, which fails on naming conflicts for anything with a globally-unique or resource-group-unique name (like `aks-ecommerce-prod`). Either `terraform import` each resource into state first, or — the simpler path if you're doing a full from-scratch redo, as this project's user is — delete everything Portal-built (`az group delete --name rg-ecommerce-prod`, plus the separate `rg-tfstate`, since that's untouched either way) and re-apply purely from Terraform.
