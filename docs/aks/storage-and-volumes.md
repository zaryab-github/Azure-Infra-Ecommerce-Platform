# Storage and volumes

## Does this project need persistent volumes? No — and that's deliberate

The three services are stateless — all real persistence lives in Azure SQL (Phase 6), not on disk inside a pod. No `PersistentVolumeClaim` exists anywhere in `kubernetes/`. This section exists because the CSI drivers for volumes are still running on your cluster as baseline AKS infrastructure (you'll see them in `kubectl get all -A`) even though nothing currently uses them, and because Phase 9's Key Vault integration *does* use a CSI driver — just not for block/file storage.

## The concepts, briefly

- **PersistentVolume (PV)**: a piece of actual storage (an Azure Disk, an Azure Files share) represented as a cluster object.
- **PersistentVolumeClaim (PVC)**: a pod's *request* for storage matching some criteria (size, access mode) — Kubernetes binds it to a matching PV.
- **StorageClass**: a template for *dynamically* provisioning a PV on demand when a PVC references it, instead of an admin pre-creating PVs by hand. AKS ships built-in StorageClasses:

```bash
kubectl get storageclass
```

Typically shows `default` (Azure Disk, `managed-csi`), `azurefile-csi`, etc. — provisioned by the CSI drivers already running on your node (`csi-azuredisk-node`, `csi-azurefile-node` DaemonSets in `kube-system`).

## When you *would* need this

If a future service needed local scratch space that survives pod restarts (not this project's services), you'd add a PVC referencing a StorageClass:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-data
  namespace: ecommerce
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: managed-csi
  resources:
    requests:
      storage: 5Gi
```

Then mount it in a pod spec via `volumes` + `volumeMounts`, the same pattern already used for the Key Vault CSI volume (Phase 9) — just a different `driver` and `volumeAttributes`.

## The Key Vault CSI driver is the same mechanism, different purpose

`kubernetes/secrets/secretproviderclass.yaml` uses the **Secrets Store CSI Driver** — architecturally a volume driver just like the disk/file ones above, except instead of mounting a disk it mounts secret values from Key Vault as in-memory files, and optionally syncs them into a Kubernetes `Secret` (`secretObjects`). See [`docs/deployment_phases/phase-09-secrets.md`](../deployment_phases/phase-09-secrets.md) for the full wiring.

## Backups

Azure Disk snapshots are the mechanism for PV-backed data (not used here); see [backup-and-disaster-recovery.md](backup-and-disaster-recovery.md) for what actually needs backing up in this project (spoiler: mainly Azure SQL, not anything in the cluster).
