# Remote state backend. Left empty deliberately — values are supplied at
# `terraform init` time via -backend-config flags, using the resource group /
# storage account / container that scripts/bootstrap-terraform-backend.ps1
# creates. See docs/phase-01-identity.md for the exact init command.
terraform {
  backend "azurerm" {}
}
