# Azure DevOps Pipelines — not yet implemented

Lands in **Phase 10** (see [`docs/ROADMAP.md`](../ROADMAP.md), `pipelines/ci.yml` and `pipelines/cd.yml`).

**What it will be**: `ci.yml` (build → unit test → docker build → push to ACR) and `cd.yml` (terraform plan/apply → deploy to AKS → smoke test), per the flow in [`docs/ROADMAP.md`](../ROADMAP.md).

**Why it's needed here**: it's what turns "I manually ran terraform apply and kubectl apply from the management VM" into a repeatable, auditable process — the difference between a lab exercise and an actual delivery pipeline.

This file will be filled in with the actual pipeline structure and how it authenticates to Azure once Phase 10 is built.
