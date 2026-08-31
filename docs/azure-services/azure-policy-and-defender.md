# Azure Policy & Microsoft Defender for Cloud — not yet implemented

Lands in **Phase 12 — Security** (see [`docs/ROADMAP.md`](../ROADMAP.md)), alongside Kubernetes Network Policies, RBAC hardening, private endpoints, and WAF tuning.

**What it will be**: Azure Policy assignments enforcing baseline guardrails (e.g., "no public IPs outside the mgmt/nat exceptions", "require tags"), and Microsoft Defender for Cloud (trial tier) for vulnerability scanning and security recommendations across the resources built in earlier phases.

**Why it's needed here**: earlier phases build things *correctly*, but nothing yet continuously checks that they *stay* correct as more is added — this phase is about ongoing governance, not one-time setup.

This file will be filled in with the actual policy definitions and Defender findings once Phase 12 is built.
