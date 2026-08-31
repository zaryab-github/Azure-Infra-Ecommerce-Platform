# Route Tables (User-Defined Routes)

## What it is

Azure gives every subnet a set of default routes automatically (to the internet, to other subnets in the VNet, etc.). A **Route Table** lets you override those defaults with your own — a "User-Defined Route" (UDR) — for example, forcing all outbound traffic from a subnet through a firewall or NAT device instead of straight to the internet.

## Why this project uses it

`snet-aks` gets its own route table today mainly to **establish the pattern and the attachment point** this early — an empty route table with no custom routes yet behaves identically to the subnet's default routing, but having it wired in means later phases (e.g., forcing egress through a specific path, or Azure Firewall in a more advanced setup) are a matter of adding routes to an existing table, not introducing a new resource and re-associating the subnet.

## Where it's wired in

`terraform/modules/network/main.tf` — `azurerm_route_table.aks`, associated to `snet-aks` via `azurerm_subnet_route_table_association.aks`.

## What it's not doing (yet)

There are no custom routes defined in it today — `snet-aks` still reaches the internet via the NAT Gateway (see [nat-gateway-and-public-ip.md](nat-gateway-and-public-ip.md)) using Azure's default system routes for that. This resource exists as the attachment point for future custom routing, not because anything currently depends on non-default routes.
