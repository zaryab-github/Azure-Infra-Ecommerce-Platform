
- To initialize terraform:
   terraform -chdir=terraform/environments/prod init \
     -backend-config="resource_group_name=rg-tfstate" \
     -backend-config="storage_account_name=stecommercetfstate1" \
     -backend-config="container_name=tfstate" \
     -backend-config="key=prod.terraform.tfstate"

-  To reinitialize terraform:

terraform -chdir=terraform/environments/prod init -reconfigure \
  -backend-config="resource_group_name=rg-tfstate" \
  -backend-config="storage_account_name=stecommercetfstate1" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=prod.terraform.tfstate"


- 
terraform -chdir=terraform/environments/prod fmt          # normalize formatting before every commit
terraform -chdir=terraform/environments/prod validate      # syntax/type check, no Azure calls needed
terraform -chdir=terraform/environments/prod plan          # review before applying
terraform -chdir=terraform/environments/prod apply         # apply



### Deleting the NAT Gateway (extended pause only)

terraform -chdir=terraform/environments/prod destroy \
  -target=module.network.azurerm_subnet_nat_gateway_association.aks \
  -target=module.network.azurerm_nat_gateway_public_ip_association.main \
  -target=module.network.azurerm_nat_gateway.main \
  -target=module.network.azurerm_public_ip.nat



### Destory the entire module - Example

terraform -chdir=terraform/environments/prod destroy \
  -target=module.management_vm

terraform -chdir=terraform/environments/prod destroy \
  -target=module.network

terraform -chdir=terraform/environments/prod destroy \
  -target=module.identity

