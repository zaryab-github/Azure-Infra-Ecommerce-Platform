# Logging and monitoring

Three layers, from "immediate, no setup" to "historical, queryable, alertable."

## Layer 1 — `kubectl` directly (always available, zero cost)

```bash
kubectl logs -n ecommerce deployment/order-service              # last logs
kubectl logs -n ecommerce deployment/order-service --follow      # tail live
kubectl logs -n ecommerce deployment/order-service --previous    # logs from the pod BEFORE a crash/restart
kubectl describe pod <pod-name> -n ecommerce                     # events, resource requests, last state, why it's Pending/CrashLooping
kubectl top pods -n ecommerce                                    # live CPU/memory (needs metrics-server — already running)
kubectl top nodes                                                # same, per node — what you'd check for "Insufficient cpu" errors
```

This is what you were already using to diagnose the image/scheduling issues — it's the right first move for anything happening *right now*. It does not persist — once a pod is deleted, its logs are usually gone (unless `--previous` still has the last crashed instance cached).

## Layer 2 — Container Insights / Log Analytics (historical, queryable)

Built in Phase 11 (`terraform/modules/monitoring`) — a Log Analytics workspace wired into AKS via the `oms_agent` add-on. Once enabled, every container's stdout/stderr and key metrics get shipped there automatically, queryable with **KQL** (Kusto Query Language) long after a pod is gone:

```kql
ContainerLogV2
| where PodNamespace == "ecommerce"
| where ContainerName == "order-service"
| order by TimeGenerated desc
| take 100
```

```kql
Perf
| where ObjectName == "K8SContainer" and CounterName == "cpuUsageNanoCores"
| where InstanceName contains "order-service"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m)
```

Run these in the Portal (Log Analytics workspace → **Logs**) or `az monitor log-analytics query`.

## Layer 3 — Application Insights (request-level tracing, inside the app)

Also Phase 11 — each service auto-instruments itself via the `applicationinsights` npm package when `APPLICATIONINSIGHTS_CONNECTION_STRING` is set (see the top of each `src/index.js`). This gives you request durations, dependency calls (SQL queries, Service Bus sends), and exception stack traces per request — the thing Layer 2 can't give you, since container logs are just whatever you `console.log`, not structured request telemetry. Portal → Application Insights → **Live Metrics** / **Transaction search** / **Failures**.

## Metrics-server and the HPA

`metrics-server` (already running in `kube-system`, part of the AKS baseline — not something this project added) is what the HPA reads from:

```bash
kubectl get hpa -n ecommerce
```

The `TARGETS` column showing `cpu: <unknown>/70%` (as in your output) means metrics-server hasn't reported a value yet — usually because the pod hasn't been running long enough, or is stuck `Pending`/`InvalidImageName` and was never actually consuming CPU to measure. Once pods are healthy and running for a minute or two, this resolves to a real percentage.

## Alerts

Phase 11 also creates two baseline `azurerm_monitor_metric_alert`s (AKS node CPU, SQL CPU, both >80%) firing to an email action group — Portal → your Log Analytics workspace or directly the AKS resource → **Alerts**, to see/edit them.
