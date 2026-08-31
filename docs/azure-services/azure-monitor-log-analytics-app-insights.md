# Azure Monitor, Log Analytics & Application Insights — not yet implemented

Lands in **Phase 11** (see [`docs/ROADMAP.md`](../ROADMAP.md), Terraform module `terraform/modules/monitoring`).

**What it will be**: a Log Analytics workspace collecting container logs and metrics, Application Insights for request tracing/exceptions from the three services, and baseline alert rules (CPU, memory, exceptions) in Azure Monitor.

**Why it's needed here**: everything before this phase is provisioned correctly but effectively unobservable — this is what turns "the cluster is running" into "I can see what it's doing and be told when something's wrong."

This file will be filled in with the actual dashboards/alerts and how the services are instrumented once Phase 11 is built.
