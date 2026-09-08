# monitoring module

Built in **Phase 11 — Monitoring** (see [`docs/ROADMAP.md`](../../../docs/ROADMAP.md), [`docs/deployment_phases/phase-11-monitoring.md`](../../../docs/deployment_phases/phase-11-monitoring.md)).

Provisions: Log Analytics workspace, workspace-based Application Insights, diagnostic settings on Key Vault + SQL, an action group, and two baseline metric alerts (AKS node CPU, SQL CPU). Feeds back into the `aks` module's `oms_agent` add-on via `log_analytics_workspace_id`.
