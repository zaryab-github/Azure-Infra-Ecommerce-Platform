<#
.SYNOPSIS
    One-time bootstrap of the Azure resources Terraform's remote state backend needs.
    This is the only infrastructure in the project created outside of Terraform,
    because the backend storage account must exist before `terraform init` can use it.

.DESCRIPTION
    Idempotent: safe to re-run. Creates (only if missing):
      - Resource group  rg-tfstate
      - Storage account st<random-suffix> (Standard_LRS, TLS1.2 minimum)
      - Blob container  tfstate

.PARAMETER Location
    Azure region for the state resource group/storage account. Default: eastus.

.PARAMETER ResourceGroupName
    Name of the resource group that holds Terraform state resources. Default: rg-tfstate.

.EXAMPLE
    ./bootstrap-terraform-backend.ps1 -Location "eastus"
#>

param(
    [string]$Location = "eastus",
    [string]$ResourceGroupName = "rg-tfstate"
)

$ErrorActionPreference = "Stop"

Write-Host "Checking Azure CLI login..." -ForegroundColor Cyan
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Not logged in. Run 'az login' first, then re-run this script." -ForegroundColor Red
    exit 1
}
Write-Host "Using subscription: $($account.name) ($($account.id))" -ForegroundColor Green

# --- Resource group -------------------------------------------------------
$rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
if ($rgExists) {
    Write-Host "Resource group '$ResourceGroupName' already exists — skipping." -ForegroundColor Yellow
} else {
    Write-Host "Creating resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Cyan
    az group create --name $ResourceGroupName --location $Location --output none
}

# --- Storage account --------------------------------------------------------
# Storage account names must be globally unique, lowercase, 3-24 chars, no dashes.
$existing = az storage account list --resource-group $ResourceGroupName --query "[?starts_with(name, 'sttfstate')].name" -o tsv
if ($existing) {
    $StorageAccountName = ($existing -split "`n")[0]
    Write-Host "Storage account already exists — reusing '$StorageAccountName'." -ForegroundColor Yellow
} else {
    $suffix = -join ((48..57) + (97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
    $StorageAccountName = "sttfstate$suffix"
    Write-Host "Creating storage account '$StorageAccountName'..." -ForegroundColor Cyan
    az storage account create `
        --name $StorageAccountName `
        --resource-group $ResourceGroupName `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 `
        --min-tls-version TLS1_2 `
        --allow-blob-public-access false `
        --output none
}

# --- Blob container ---------------------------------------------------------
$accountKey = az storage account keys list --resource-group $ResourceGroupName --account-name $StorageAccountName --query "[0].value" -o tsv

$containerExists = az storage container exists --name tfstate --account-name $StorageAccountName --account-key $accountKey | ConvertFrom-Json
if ($containerExists.exists) {
    Write-Host "Container 'tfstate' already exists — skipping." -ForegroundColor Yellow
} else {
    Write-Host "Creating blob container 'tfstate'..." -ForegroundColor Cyan
    az storage container create --name tfstate --account-name $StorageAccountName --account-key $accountKey --output none
}

Write-Host "`nBootstrap complete." -ForegroundColor Green
Write-Host "Resource group:     $ResourceGroupName"
Write-Host "Storage account:    $StorageAccountName"
Write-Host "Container:          tfstate"
Write-Host "`nUse these when running terraform init (see docs/phases/phase-01-identity.md):" -ForegroundColor Cyan
Write-Host "  terraform -chdir=terraform/environments/prod init ``"
Write-Host "    -backend-config=""resource_group_name=$ResourceGroupName"" ``"
Write-Host "    -backend-config=""storage_account_name=$StorageAccountName"" ``"
Write-Host "    -backend-config=""container_name=tfstate"" ``"
Write-Host "    -backend-config=""key=prod.terraform.tfstate"""
