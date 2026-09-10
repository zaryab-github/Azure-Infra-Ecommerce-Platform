# Service mesh

## What a service mesh actually does

A service mesh (Istio, Linkerd, etc.) injects a sidecar proxy into every pod and routes all pod-to-pod traffic through it, giving you — without changing application code — mutual TLS between services, fine-grained traffic splitting/canary routing, retries/circuit-breaking, and rich per-request observability (latency histograms, error rates, service dependency graphs).

## Why this project doesn't use one

At 3 services with one synchronous path each (through the Ingress, not to each other directly — see [`docs/services.md`](../services.md)) and one async path (Service Bus, which isn't mesh traffic at all), there's no meaningful traffic pattern for a mesh to manage. mTLS between 3 pods you already control isn't buying much; the roadmap's own Phase 12 already covers the actual security surface that matters here (WAF at the edge, NetworkPolicies, RBAC) without the operational overhead of running a mesh control plane.

## What happened on this project's cluster anyway

The AKS "Istio-based service mesh add-on" got enabled through the Portal wizard (a checkbox, easy to miss or default-check depending on the wizard version) — visible as `aks-istio-system` namespace, `istiod` control plane pods. On this project's single `Standard_B2s` node, that's 2 extra pods (`istiod`, HPA'd 2-5 replicas) competing for CPU against the actual application — which is exactly what caused the `Insufficient cpu` scheduling failures during setup.

**This add-on requires no sidecar injection to still cost you capacity** — `istiod` itself (the mesh control plane) runs regardless of whether any of your pods are enrolled in the mesh (none of this project's are — no namespace has the `istio-injection=enabled` label).

## Disabling it

```bash
az aks mesh disable --resource-group rg-ecommerce-prod --name aks-ecommerce-prod
kubectl get pods -n aks-istio-system   # should drain to nothing
```

## If you ever do want one

Given AKS already offers Istio as a one-flag managed add-on, that's the lowest-friction path — the command above, reversed:

```bash
az aks mesh enable --resource-group rg-ecommerce-prod --name aks-ecommerce-prod
kubectl label namespace ecommerce istio-injection=enabled
kubectl rollout restart deployment -n ecommerce   # pods need to restart to get the sidecar injected
```

Worth doing on a bigger node pool than this project's — budget real CPU/memory for `istiod` plus a sidecar per pod (roughly 50-100m CPU / 128Mi extra per pod with a sidecar).
