# Cluster management

## Control plane vs. node pools — the core split

- **Control plane** (API server, etcd, scheduler, controller-manager): fully managed by Azure. You never SSH into it, never patch it, never see its VMs. At the **Free** SKU tier (what this project uses), it has no uptime SLA and costs nothing beyond the nodes. At **Standard** tier, Azure gives it an SLA and it costs more — not needed for a lab.
- **Node pools**: real VMs, provisioned into *your* VNet subnet (`snet-aks`), that you choose the size/count for. Azure handles OS patching and Kubernetes version alignment on them, but you pay for the VM time and you're the one who decides how many/how big.

This project has one node pool, `system` (the default), 1 node, `Standard_B2s`. A real production cluster typically splits this into a `system` pool (small, runs only Kubernetes/Azure system pods, tainted so your app can't land there) and one or more `user` pools (where your actual workloads run) — skipped here to keep cost down, but worth knowing as the next step up in sophistication.

## Scaling

**Manually**, via `az`:

```bash
az aks nodepool scale --resource-group rg-ecommerce-prod --cluster-name aks-ecommerce-prod --name system --node-count 2
```

**Autoscaling** (node pool grows/shrinks based on unschedulable pods — different from the HPA, which scales pod *replica count*, not node count):

```bash
az aks nodepool update --resource-group rg-ecommerce-prod --cluster-name aks-ecommerce-prod --name system \
  --enable-cluster-autoscaler --min-count 1 --max-count 3
```

Watch your **regional vCPU quota** before scaling — this project hit `Insufficient regional vcpu quota` during initial creation. Check it with:

```bash
az vm list-usage --location eastus --output table | grep -i "standard bsv2\|total regional"
```

If you're quota-constrained, growing node count/size isn't available to you — freeing capacity by disabling unneeded add-ons (see [service-mesh.md](service-mesh.md), [policies-and-crds.md](policies-and-crds.md)) is the more available lever, which is exactly what this project's cluster needed.

## Stopping and starting (cost control)

```bash
az aks stop --name aks-ecommerce-prod --resource-group rg-ecommerce-prod
az aks start --name aks-ecommerce-prod --resource-group rg-ecommerce-prod
```

`stop` deallocates the node pool VMs (compute billing stops) but keeps the cluster's configuration and control plane state intact — `start` brings it back exactly as it was. This is the AKS equivalent of the management VM's `az vm deallocate`/`start` pattern — see [`docs/cost-management.md`](../cost-management.md).

## Upgrades

```bash
az aks get-upgrades --resource-group rg-ecommerce-prod --name aks-ecommerce-prod --output table
az aks upgrade --resource-group rg-ecommerce-prod --name aks-ecommerce-prod --kubernetes-version <version>
```

Upgrades happen node-by-node with surge nodes by default (temporarily *more* nodes than your steady-state count, to avoid downtime) — which is exactly the kind of moment that can also trip a tight vCPU quota (the error message you saw during creation explicitly mentions this: *"Surge nodes would also consume vcpu quota, please consider use smaller maxSurge"*). For a 1-node cluster, consider setting `--max-surge 0` or accepting brief unavailability instead.

## Connecting `kubectl` to the cluster

```bash
az aks get-credentials --name aks-ecommerce-prod --resource-group rg-ecommerce-prod
kubectl config current-context   # confirms you're pointed at the right cluster
```

This merges cluster credentials into `~/.kube/config` — if you're managing multiple clusters from the same machine, `kubectl config get-contexts` / `kubectl config use-context` switches between them.

## Deleting the cluster entirely

```bash
az aks delete --name aks-ecommerce-prod --resource-group rg-ecommerce-prod --yes --no-wait
```

This is what you'll do once you're done with the Portal-built version of this project and ready to rebuild it purely through Terraform — see the note on this in [troubleshooting.md](troubleshooting.md) about state drift between the two approaches.
