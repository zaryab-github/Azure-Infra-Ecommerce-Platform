<#
.SYNOPSIS
    Deallocates (stops billing for) the management VM at the end of a session.
    This does NOT delete the VM or touch Terraform state — it's purely a power
    state change, so `terraform plan` stays clean and the VM is exactly as you
    left it next time you start it back up.

.PARAMETER ResourceGroupName
    Default: rg-ecommerce-prod (matches terraform/environments/prod defaults).

.PARAMETER VmName
    Default: vm-ecommerce-mgmt-prod (matches the management-vm module's naming).

.EXAMPLE
    ./stop-management-vm.ps1
#>

param(
    [string]$ResourceGroupName = "rg-ecommerce-prod",
    [string]$VmName = "vm-ecommerce-mgmt-prod"
)

$ErrorActionPreference = "Stop"

Write-Host "Deallocating $VmName in $ResourceGroupName (stops compute billing)..." -ForegroundColor Cyan
az vm deallocate --name $VmName --resource-group $ResourceGroupName --output none
Write-Host "Done. Start it again with ./start-management-vm.ps1 when you're back." -ForegroundColor Green
