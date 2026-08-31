<#
.SYNOPSIS
    Starts the management VM back up for a session. Pairs with
    stop-management-vm.ps1. The VM's Static Standard public IP is retained
    across deallocate/start, so its address doesn't change.

.PARAMETER ResourceGroupName
    Default: rg-ecommerce-prod (matches terraform/environments/prod defaults).

.PARAMETER VmName
    Default: vm-ecommerce-mgmt-prod (matches the management-vm module's naming).

.EXAMPLE
    ./start-management-vm.ps1
#>

param(
    [string]$ResourceGroupName = "rg-ecommerce-prod",
    [string]$VmName = "vm-ecommerce-mgmt-prod"
)

$ErrorActionPreference = "Stop"

Write-Host "Starting $VmName in $ResourceGroupName..." -ForegroundColor Cyan
az vm start --name $VmName --resource-group $ResourceGroupName --output none

$ip = az vm show -d --name $VmName --resource-group $ResourceGroupName --query publicIps -o tsv
Write-Host "Done. Public IP: $ip" -ForegroundColor Green
Write-Host "ssh -i ~/.ssh/ecommerce_mgmt_vm azureadmin@$ip" -ForegroundColor Cyan
