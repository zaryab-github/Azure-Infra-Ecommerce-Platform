# Phase 9 — Secrets

Goal: move the SQL password and Service Bus connection string out of the plain Kubernetes Secret you created by hand in Phases 6/7, into Key Vault — read by pods via the CSI driver (Phase 5's add-on), not any SDK code in the services.

> **Where this runs**: from the management VM.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_key_vault` (RBAC-authorized, not access-policy) | The vault |
| Secrets: `sql-admin-password`, `sql-connection-string`, `servicebus-connection-string`, `jwt-secret` | Sourced from the sql/servicebus modules' outputs; `jwt-secret` is reserved for future auth work |
| Role assignments | `Key Vault Secrets User` → AKS's CSI provider identity; `Key Vault Secrets Officer` → management VM identity + the deploying identity itself |

See [`docs/azure-services/azure-key-vault.md`](../azure-services/azure-key-vault.md).

**Caveat, read before applying**: the identity running `terraform apply` needs `Key Vault Secrets Officer` on the vault to create the secret resources — the module self-grants this to the deploying identity (`data.azurerm_client_config.current`), but Azure RBAC can take a minute or two to propagate. If the first apply fails specifically on the `azurerm_key_vault_secret` resources, just re-run `apply` once more.

## Track A — Terraform

```bash
terraform -chdir=terraform/environments/prod plan -target=module.keyvault
terraform -chdir=terraform/environments/prod apply -target=module.keyvault
```

## Track B — Azure Portal

1. Inside `rg-ecommerce-prod` → **+ Create a resource** → **Key Vault** → name `kv-ecommerce-prod`, **Permission model: Azure role-based access control**.
2. **Access control (IAM)** on the vault → **Add role assignment** → **Key Vault Secrets Officer** → assign to yourself (to add secrets manually) and to the management VM's identity.
3. **Secrets** → **+ Generate/Import** × 4: `sql-admin-password`, `sql-connection-string`, `servicebus-connection-string`, `jwt-secret` (paste the values from Phase 6/7's Terraform outputs, or generate a new random one for jwt-secret).
4. **Access control (IAM)** → **Add role assignment** → **Key Vault Secrets User** → assign to the AKS cluster's Key Vault Secrets Provider add-on identity (find it: cluster → **Add-ons** → **Key Vault Secrets Provider** → its identity).

## Wire it into the cluster

1. Apply the SecretProviderClass (fill in the placeholders first):

   ```bash
   sed -i "s#<KEY_VAULT_NAME>#kv-ecommerce-prod#g; \
           s#<TENANT_ID>#$(az account show --query tenantId -o tsv)#g; \
           s#<WORKLOAD_IDENTITY_CLIENT_ID>#$(terraform -chdir=terraform/environments/prod output -raw aks_workload_identity_client_id)#g" \
     kubernetes/secrets/secretproviderclass.yaml
   kubectl apply -f kubernetes/secrets/secretproviderclass.yaml
   ```

2. Add the CSI volume mount to each `kubernetes/deployments/*.yaml`, replacing the comment placeholder left there in Phase 5, so the driver actually syncs the secret (a SecretProviderClass only syncs once something mounts it):

   ```yaml
         volumeMounts:
           - name: secrets-store
             mountPath: "/mnt/secrets-store"
             readOnly: true
     volumes:
       - name: secrets-store
         csi:
           driver: secrets-store.csi.k8s.io
           readOnly: true
           volumeAttributes:
             secretProviderClass: ecommerce-secrets
   ```

3. Delete the manual Secret from Phases 6/7 and re-apply — the CSI driver's `secretObjects` sync recreates `app-secrets` from Key Vault instead:

   ```bash
   kubectl delete secret app-secrets -n ecommerce
   kubectl apply -f kubernetes/deployments/
   kubectl rollout restart deployment -n ecommerce
   ```

## Verification

```bash
kubectl exec -n ecommerce deployment/order-service -- ls /mnt/secrets-store
kubectl get secret app-secrets -n ecommerce -o jsonpath='{.data.SQL_PASSWORD}' | base64 -d | head -c 5; echo
curl http://<ingress-ip>/api/orders   # still works — secrets now come from Key Vault
```

## Cost / Teardown

Negligible at this scale. See [`docs/cost-management.md`](../cost-management.md). Note `purge_protection_enabled = false` in the module — a deliberate lab convenience for clean teardown, not what a real production vault would use.

## Next

Phase 10 — CI/CD.
