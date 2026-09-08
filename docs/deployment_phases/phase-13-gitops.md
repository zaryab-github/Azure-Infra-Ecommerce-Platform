# Phase 13 — GitOps (optional)

Goal: replace manual `kubectl apply` with FluxCD watching this repo's `kubernetes/` directory — Git becomes the source of truth, and drift between the cluster and the repo gets auto-corrected instead of silently accumulating.

> Optional per the roadmap. Skip this phase entirely if `kubectl apply` from the management VM (Phases 5–12) already meets your needs.

## Why this isn't a Terraform module

Flux is installed *into* the cluster via its own CLI/controller bootstrap, not as an ARM resource — there's no `azurerm_*` resource for "install Flux." This phase is CLI-driven, similar in spirit to Phase 10's Portal-driven nature.

## Setup

1. Install the Flux CLI on the management VM:

   ```bash
   curl -s https://fluxcd.io/install.sh | sudo bash
   ```

2. Create a GitHub personal access token with `repo` scope (Flux needs it to write its own manifests back to the repo on bootstrap).

3. Bootstrap Flux against this repo, pointing it at the `kubernetes/` directory:

   ```bash
   export GITHUB_TOKEN=<your-pat>
   flux bootstrap github \
     --owner=zaryab-github \
     --repository=Azure-Infra-Ecommerce-Platform \
     --branch=main \
     --path=kubernetes \
     --personal
   ```

   This installs Flux's controllers into a new `flux-system` namespace and commits a `GitRepository` + `Kustomization` pair back into the repo under `kubernetes/flux-system/`.

4. From this point on, **stop running `kubectl apply` by hand** — edit files under `kubernetes/`, commit, push. Flux reconciles the cluster to match within its polling interval (default 1 minute).

## What changes about the workflow

| Before (Phases 5–12) | After Phase 13 |
|---|---|
| `kubectl apply -f kubernetes/...` from the VM | `git push`; Flux applies it |
| Drift (someone `kubectl edit`s something) persists until noticed | Flux reverts drift back to what's in Git on its next reconcile |
| CD pipeline's `kubectl apply` step (Phase 10) | Replaced — `cd.yml`'s Kubernetes stage becomes just "wait for Flux to reconcile" or is removed entirely |

## Verification

```bash
flux get kustomizations
flux get sources git
kubectl get pods -n flux-system
```

## Cost / Teardown

No additional Azure cost — Flux's controllers run as regular pods inside the existing AKS cluster. `flux uninstall` removes it cleanly if you want to go back to manual `kubectl apply`.

## This completes the roadmap

All 13 phases (12 core + this optional one) are now built. See [`docs/ROADMAP.md`](../ROADMAP.md) for the full picture and [`docs/services.md`](../services.md) for how the application layer ties it all together.
