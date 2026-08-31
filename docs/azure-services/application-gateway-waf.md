# Application Gateway (WAF) — not yet implemented

Lands around **Phase 5** (ingress) and is hardened in **Phase 12 — Security** (see [`docs/ROADMAP.md`](../ROADMAP.md)).

**What it will be**: a layer-7 reverse proxy/load balancer with a Web Application Firewall (WAF) in front of AKS — the single public entry point for all traffic, per the architecture diagram. Runs in its own dedicated subnet, `snet-appgw` (already provisioned in Phase 2 — see [virtual-network-and-subnets.md](virtual-network-and-subnets.md) and [network-security-groups.md](network-security-groups.md) for the NSG rules already in place for it).

**Why it's needed here**: it's what makes "nothing is publicly exposed except through one WAF-protected entry point" true — the NSGs on every other subnet already deny inbound from the internet (see [network-security-groups.md](network-security-groups.md)), so Application Gateway is the deliberate, singular exception.

This file will be filled in with the actual configuration and AGIC (Application Gateway Ingress Controller) notes once it's built.
