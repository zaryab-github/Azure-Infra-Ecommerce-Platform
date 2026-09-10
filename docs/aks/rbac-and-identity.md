# RBAC and identity

Two entirely separate RBAC systems are in play, and mixing them up is a common source of confusion.

## Azure RBAC — controls access to the *Azure resource* `aks-ecommerce-prod`

"Can this user/service principal start, stop, scale, or delete the AKS resource itself?" — governed by role assignments on the AKS resource or its resource group (see [`docs/azure-services/azure-rbac.md`](../azure-services/azure-rbac.md)). Has nothing to do with what happens *inside* the cluster once it's running.

## Kubernetes RBAC — controls access to *objects inside the cluster*

"Can this identity `get`/`list`/`create`/`delete` Pods, Deployments, Secrets, etc., in which namespaces?" — governed by `Role`/`ClusterRole` + `RoleBinding`/`ClusterRoleBinding` objects inside Kubernetes itself. AKS can be configured to let Azure AD identities authenticate for this too ("Azure RBAC for Kubernetes Authorization"), unifying the two — not enabled in this project (the management VM's identity authenticates to Kubernetes via the kubeconfig from `az aks get-credentials`, which uses a client certificate/token, not Azure AD-mediated K8s RBAC).

Check what a given identity can do inside the cluster:

```bash
kubectl auth can-i create deployments --namespace ecommerce
kubectl auth can-i delete secrets --namespace ecommerce --as=system:serviceaccount:ecommerce:ecommerce-workload-sa
```

## ServiceAccounts — identity *inside* the cluster

Every pod runs as some ServiceAccount (defaults to `default` if unspecified). This project's Deployments explicitly use `ecommerce-workload-sa` (`kubernetes/serviceaccount.yaml`) — not for Kubernetes RBAC purposes here, but as the anchor for workload identity federation (below).

## Workload identity — how a pod gets *Azure* permissions, not just Kubernetes permissions

This is the mechanism that lets a pod call Azure APIs (Key Vault, Service Bus, etc.) without any credential baked into an image or env var. Three pieces have to line up:

1. **The cluster** has `oidc_issuer_enabled` + `workload_identity_enabled` turned on — this makes the cluster capable of minting OIDC tokens that Azure AD trusts, and gives it a public issuer URL (`az aks show --query oidcIssuerProfile.issuerUrl`).
2. **A federated identity credential** on the Azure managed identity (`id-ecommerce-aks-prod`) says: "trust tokens for ServiceAccount `ecommerce-workload-sa` in namespace `ecommerce`, issued by *this specific cluster's* OIDC issuer." Create it manually (Portal) or via Terraform (`azurerm_federated_identity_credential` in `terraform/modules/aks/main.tf`).
3. **The pod** runs as that ServiceAccount, with the label `azure.workload.identity/use: "true"` — this triggers the `azure-wi-webhook` (visible in your `kube-system` pods) to inject the right environment variables (`AZURE_TENANT_ID`, `AZURE_FEDERATED_TOKEN_FILE`, `AZURE_AUTHORITY_HOST` — visible in your `kubectl describe pod` output) and mount a projected token volume.

Inside the pod, any Azure SDK using `DefaultAzureCredential` picks these up automatically and exchanges the projected token for a real Azure AD access token — no code changes needed beyond using a standard Azure SDK.

Verify the federated credential exists:

```bash
az identity federated-credential list --identity-name id-ecommerce-aks-prod --resource-group rg-ecommerce-prod --output table
```

## Namespaces as a soft RBAC/isolation boundary

`ecommerce` (the app), `kube-system` (Azure/AKS internals), `gatekeeper-system`/`aks-istio-system` (add-ons, if enabled) — namespaces don't provide network isolation by themselves (that's [`kubernetes/security/networkpolicy.yaml`](../../kubernetes/security/networkpolicy.yaml)'s job), but they do scope RBAC `Role`s and are the natural boundary for `kubectl` commands (`-n ecommerce`) and resource quotas if you ever add them.
