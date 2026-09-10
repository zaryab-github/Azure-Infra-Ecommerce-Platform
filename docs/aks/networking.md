# Networking

## Three different kinds of IP, not one

This is the single most common source of confusion (it's what caused the "Kubernetes service address range" Portal error you hit) — there are three genuinely separate address spaces in play:

| | Where it comes from | Routable outside the cluster? | Example from your cluster |
|---|---|---|---|
| **Node IPs** | `snet-aks` (the real VNet subnet) | Yes — real VNet addresses | `10.0.0.4` (your node) |
| **Pod IPs** | Also `snet-aks`, because this project uses classic Azure CNI (not overlay mode) | Yes — real VNet addresses, same subnet as nodes | `10.0.0.32`, `10.0.0.10`, `10.0.0.25` (your app pods) |
| **Service (ClusterIP) IPs** | A separate *virtual* range, chosen at cluster creation, never a real VNet address | No — only meaningful inside the cluster's iptables/eBPF rules | `172.16.67.11` (`order-service`), `172.16.0.1` (the `kubernetes` API service itself) |

Because pods get real subnet IPs in this mode, `snet-aks` was deliberately sized `/20` (4,091 addresses) back in Phase 2 — with an overlay-mode CNI this wouldn't matter, but classic Azure CNI burns a real VNet IP per pod.

## DNS

`CoreDNS` (the `coredns` Deployment in `kube-system`) resolves `*.svc.cluster.local` names to Service ClusterIPs. Every pod's `/etc/resolv.conf` points at `kube-dns` (`172.16.0.10`). From inside the cluster, `user-service` (short form, same namespace) or `user-service.ecommerce.svc.cluster.local` (fully qualified) both resolve to the `user-service` Service's ClusterIP — this is what lets `order-service` and `product-service` talk to each other without hardcoded IPs, if this project ever added direct service-to-service HTTP calls (right now they only talk via Service Bus — see `docs/services.md`).

## How a request actually gets from the internet to a pod

```
Internet
  -> (Phase 12, optional) Application Gateway + WAF   — public IP, TLS/WAF inspection
  -> Azure Load Balancer                                — auto-created because...
  -> nginx Ingress Controller pod (Web App Routing add-on) — routes by path
  -> Service (ClusterIP)                                — stable virtual IP + DNS name
  -> kube-proxy / Cilium eBPF rules                     — pick a healthy pod IP
  -> Pod (real VNet IP)
```

Find the ingress controller's actual public IP:

```bash
kubectl get svc -n app-routing-system nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

That's the *Azure Load Balancer's* IP — AKS creates a Standard Load Balancer automatically the moment any `LoadBalancer`-type Service exists (see [`docs/azure-services/azure-load-balancer.md`](../azure-services/azure-load-balancer.md)); you never provision it yourself.

## CNI modes — what this project uses, and the alternative

- **Azure CNI (classic)** — what this project uses (`network_plugin = "azure"` in Terraform, and what the Portal wizard produced too). Pods get real VNet IPs. Simple to reason about, but burns subnet address space fast — this is why Microsoft's newer default recommendation for most workloads is:
- **Azure CNI Overlay** — pods get IPs from a separate, virtual overlay range (like the Service CIDR, but for pods) that never touches the VNet at all. Massively more IP-efficient, but pods aren't directly reachable from other VNet resources without going through a Service. Not used here — changing it would mean resizing the subnet plan from Phase 2.

## Network Policy — Azure vs. Cilium

The Terraform module specifies `network_policy = "azure"`. Your Portal-created cluster ended up with **Cilium** instead (the "Enable Cilium dataplane" checkbox, checked by default in the newer wizard) — visible as the `cilium` DaemonSet in `kube-system`. Functionally, both enforce the same standard `networking.k8s.io/v1 NetworkPolicy` objects (`kubernetes/security/networkpolicy.yaml` in this repo works unmodified under either), but Cilium is eBPF-based (generally faster, more features like L7 policy) vs. Azure's iptables-based engine. Worth knowing which one you actually have when reading Cilium-specific troubleshooting docs online — check with:

```bash
kubectl get ds -n kube-system | grep -i cilium
```

## Ingress vs. Load Balancer vs. NodePort — why this project uses Ingress

- `NodePort` — opens a port on every node directly. Not used here; too crude for routing 3 services by path.
- `LoadBalancer` Service — gets its *own* Azure Load Balancer + public IP per Service. Used exactly once in this project (by the ingress controller itself), not per-app-service — otherwise you'd pay for 3 load balancers instead of 1.
- `Ingress` — a single entry point that fans out to multiple Services by path (`/api/users`, `/api/products`, `/api/orders`) or hostname. What `kubernetes/ingress/ingress.yaml` actually is.
