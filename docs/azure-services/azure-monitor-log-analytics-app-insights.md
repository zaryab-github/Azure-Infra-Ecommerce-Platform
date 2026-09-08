# Azure Monitor, Log Analytics & Application Insights

Built in **Phase 11** (`terraform/modules/monitoring`). See [`docs/deployment_phases/phase-11-monitoring.md`](../deployment_phases/phase-11-monitoring.md) for setup steps.

## What it is

A Log Analytics workspace (`log-ecommerce-prod`) backing AKS container insights (wired back into the `aks` module's `oms_agent` block), workspace-based Application Insights for request tracing from the three services, diagnostic settings forwarding Key Vault + SQL logs, and two baseline metric alerts (AKS node CPU, SQL CPU, both >80%) via an email action group.

## Why this project uses it

Everything before this phase is provisioned correctly but effectively unobservable — this is what turns "the cluster is running" into "I can see what it's doing and get told when something's wrong."

## Where it's wired in

`terraform/modules/monitoring/main.tf`. The trickiest part is the cross-module dependency: the `aks` module (Phase 5) optionally takes `log_analytics_workspace_id` (gated behind `var.enable_monitoring`, default `true`) so the cluster can exist *before* Phase 11 is reached without erroring, and this monitoring module in turn takes `aks_id` for its alert scope — a valid, acyclic Terraform dependency chain (workspace → cluster → alert), not a circular one, since neither resource depends on the *other's* full completion. Each service optionally instruments itself via the `applicationinsights` npm package when `APPLICATIONINSIGHTS_CONNECTION_STRING` is set — see the first few lines of each `src/index.js`.
