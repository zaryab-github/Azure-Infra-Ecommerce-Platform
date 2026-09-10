# Backup and disaster recovery

## What Azure already protects for you, with zero effort

- **The control plane** (API server, etcd holding all your cluster objects — Deployments, Services, Secrets, etc.) — fully managed and backed by Azure's own infrastructure. You don't back up etcd yourself on AKS the way you would on a self-managed cluster.
- **Azure SQL** (Phase 6) — automated backups are on by default for any Azure SQL database, with **point-in-time restore** typically available for the last 7+ days, no configuration needed:
  ```bash
  az sql db list-backups --server sql-ecommerce-prod --resource-group rg-ecommerce-prod
  az sql db restore --dest-name sqldb-ecommerce-prod-restored --name sqldb-ecommerce-prod \
    --resource-group rg-ecommerce-prod --server sql-ecommerce-prod --time "2026-09-01T00:00:00Z"
  ```
- **ACR images** — once pushed, they persist independently of the cluster; re-pulling after a cluster rebuild is instant, no backup needed. (Geo-replication, a paid ACR tier feature, adds region-level redundancy — not used here.)
- **Key Vault** — soft-delete is on by default (deleted secrets/vaults are recoverable for a retention window); this project explicitly sets `purge_protection_enabled = false` for easy lab teardown — a real production vault would flip that on, trading "can I `terraform destroy` cleanly" for "can this ever be permanently deleted by accident."

## What Azure does *not* back up for you

- **Anything inside the cluster that isn't in Git** — if you `kubectl edit` something live and never commit the change, it's gone the moment the object is deleted or the cluster is rebuilt. This is the core argument for Phase 13 (GitOps): when `kubernetes/` in this repo is the actual source of truth, "backup" of your cluster config *is* your git history.
- **Anything on a PersistentVolume** — not applicable to this project (no PVs — see [storage-and-volumes.md](storage-and-volumes.md)), but if you ever add one, Azure Disk snapshots (`az snapshot create`) are the mechanism, and nothing does this automatically.
- **The application's in-memory fallback data** — when `SQL_SERVER` isn't configured, each service's seed data lives only in process memory; restarting a pod resets it. Not a real concern (it's fallback/demo data by design), but worth knowing it's not "data" in any durable sense.

## What a real DR story for this project would add (not built here — scope call)

- **Multi-region**: this project is single-region (`eastus`) by design (`allowed_location` in the `security` module's Azure Policy assignment literally enforces this) — a real DR setup would deploy a second AKS cluster + SQL replica in a paired region and use Traffic Manager/Front Door to fail over.
- **Velero** (or similar) for actual Kubernetes-object + PV-snapshot backup/restore as a portable artifact — relevant once you have stateful workloads or want to migrate a cluster's config wholesale rather than reapply from Git.
- **`terraform state` itself** is arguably the most business-critical "backup" in this whole project — it's the record of what Terraform believes exists. It already lives in a separate, durable Azure Storage Account (`rg-tfstate`, set up in `docs/00-prerequisites.md` §5) rather than on the management VM's disk, specifically so it survives the VM or even the whole `rg-ecommerce-prod` resource group being deleted. Enable [blob versioning or soft-delete](https://learn.microsoft.com/azure/storage/blobs/versioning-overview) on that storage account if you want extra protection against a bad `terraform apply` overwriting good state.

## The practical takeaway for this project specifically

Given the design (stateless services, real data only in Azure SQL, infra fully defined as code), disaster recovery here mostly reduces to two questions: **"is `terraform.tfstate` intact?"** and **"is the SQL database's point-in-time restore window sufficient?"** — everything else (the cluster, the app pods, the registry images) is cheaply and quickly reproducible from code, which is the whole reason this project is built as Infrastructure-as-Code in the first place.
