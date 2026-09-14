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

The container starts, then exits (crashes or completes) repeatedly. `kubectl logs <pod>` (the container restarts fast enough that you usually don't even need `--previous`) shows the exact crash — for this project's services, look at *where* the stack trace points: if it's inside `Application_services/*/src/db.js`'s `getPool()`, that's harmless — it's `.catch()`-guarded and never crashes the process, only logs `DB init failed`. If the trace instead points at the very top of `src/index.js` (line 1-2), it's almost certainly the `applicationinsights.setup()` call throwing **synchronously, before the server even starts listening** — which happens the instant `APPLICATIONINSIGHTS_CONNECTION_STRING` is set to *anything* non-empty, including a literal unresolved placeholder like `<APP_INSIGHTS_CONNECTION_STRING>`. The fix is to remove that env var entirely (not set it to a placeholder) until Phase 11 actually provides a real value — see [`docs/deployment_phases/phase-06-databases.md`](../deployment_phases/phase-06-databases.md#24--three-real-failure-modes-worth-knowing-before-you-hit-them) for the full story and the general rule this generalizes into: **a placeholder value is not the same as "unset" to application code** — `if (process.env.X)` is true for garbage text just as much as for a real value.

## `502 Bad Gateway` or an indefinitely hanging `curl` from outside the cluster

Two different symptoms, two different layers — tell them apart first:

- **`curl` hangs forever, no response, no error** → the connection is being silently **dropped**, not rejected. On this project, the cause was the AKS subnet's NSG denying internet-sourced traffic by default (it's designed to only accept traffic that's already passed through Application Gateway, Phase 12 — which doesn't exist yet early in the build). See [`docs/deployment_phases/phase-05-aks.md`](../deployment_phases/phase-05-aks.md#known-gap--the-aks-nsg-blocks-direct-to-load-balancer-traffic-until-phase-12) for the diagnosis and the temporary fix.
- **`curl` gets a fast `502 Bad Gateway` response** → the request *is* reaching nginx, but nginx can't get a valid response from your Service's backend pods. Check, in order: (1) `kubectl get pods -n ecommerce` — are the pods actually `Running 1/1`? (2) `kubectl get networkpolicy -A` — any policy that might block traffic from the ingress controller's namespace (`app-routing-system`) into `ecommerce`? (3) `kubectl describe ingress -n ecommerce` — is it actually pointing at the right Service name/port? In this project's own build, a `502` appeared briefly right after fixing the NSG issue above and cleared on its own within seconds — nginx just needed a moment to sync its backend state; if yours persists past a few retries, it's one of the three checks above, not a timing fluke.

## `Login failed for user '<name>'` when a service connects to SQL

This looks like a wrong password, but check the *simpler* explanation first: every Deployment references the `app-secrets` Secret via `envFrom: secretRef: ..., optional: true` — that `optional: true` means if the Secret **doesn't exist at all**, Kubernetes doesn't error, it just silently omits `SQL_PASSWORD` from the pod's environment, and the app connects with a blank password. SQL Server reports that exactly the same way it reports an actually-wrong password. Check existence first, before assuming the password itself is wrong:

```bash
kubectl get secret app-secrets -n ecommerce
```

A `NotFound` error means the Secret was never actually applied — see [`docs/deployment_phases/phase-06-databases.md`](../deployment_phases/phase-06-databases.md#22--create-the-secret-as-a-yaml-file-not-a-one-off-kubectl-create-command) for the fix.

## "I ran the command but nothing happened"

If you're pasting multi-line command blocks and wrapping them in `cat << 'EOF' ... EOF` to read them first — remember that `cat` **only prints** whatever's inside the heredoc, it doesn't execute it. This project's own build hit this repeatedly: a fix would get "run" (the text would scroll past on screen, looking exactly like normal output) but never actually take effect, because it was only ever echoed, not executed. If a command you were sure you ran doesn't seem to have changed anything, check whether it was wrapped in `cat`/`echo` — copy just the bare command and run it directly instead.

## Pod stuck in `Pending`, `Node: <none>`, no `FailedScheduling` event yet

Give it a few seconds — the scheduler runs periodically, not instantly. If it persists beyond ~30s with genuinely no event, check `kubectl get nodes` for a node that's `NotReady` (rare, but happens right after a node reboot/patch).

## Secrets not appearing (`app-secrets` missing or empty, Phase 9)

The `SecretProviderClass`'s `secretObjects` sync only triggers once **some pod actually mounts it** — see [`docs/deployment_phases/phase-09-secrets.md`](../deployment_phases/phase-09-secrets.md). Confirm the volume mount exists on the Deployment and that the pod is actually `Running` (a `Pending` pod never mounts anything, so the sync never fires).

## Terraform + Portal-created resources diverging

If you build phases manually through the Portal (as this project's current pass is doing) and later switch to Terraform for the same resources, Terraform has no record of what you built — `terraform plan` will propose *creating* a duplicate of everything, which fails on naming conflicts for anything with a globally-unique or resource-group-unique name (like `aks-ecommerce-prod`). Either `terraform import` each resource into state first, or — the simpler path if you're doing a full from-scratch redo, as this project's user is — delete everything Portal-built (`az group delete --name rg-ecommerce-prod`, plus the separate `rg-tfstate`, since that's untouched either way) and re-apply purely from Terraform.
