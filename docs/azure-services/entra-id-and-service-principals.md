# Microsoft Entra ID — App Registrations & Service Principals

## What it is

Microsoft Entra ID (formerly Azure AD) is Azure's identity provider — every human sign-in and every non-human ("application") identity is represented there. An **App Registration** defines an application identity in your tenant (a name, an application/client ID). A **Service Principal** is the local representation of that application in a specific tenant — the thing that actually gets granted permissions and can authenticate. In practice, for a single-tenant setup like this project, "create an App Registration" and "create its Service Principal" happen together and are often talked about as one step: "create a service principal."

## Why this project uses it

Terraform needs to authenticate to Azure to create/manage resources. Two ways to do that: run it as *you* (your own `az login` identity), or run it as a dedicated, purpose-built identity scoped only to what it needs. This project uses the second option for anything beyond the very first bootstrap, because:

- It's what a CI/CD pipeline (Phase 10, Azure Pipelines) will need anyway — pipelines can't interactively `az login` as a human.
- It demonstrates the IAM pattern the roadmap explicitly calls out for Phase 1 (App registrations, service principals) rather than skipping past it by using personal credentials everywhere.

## Where it's wired in

`terraform/modules/identity/main.tf`:
- `azuread_application.terraform` — the App Registration, named `sp-ecommerce-terraform-prod`
- `azuread_service_principal.terraform` — its Service Principal
- `azuread_service_principal_password.terraform` — a client secret, 1-year expiry

This is all gated behind `var.create_terraform_service_principal` (default `true`) — see the module's `variables.tf` for the escape hatch if you'd rather run Terraform under your own identity for a quick solo session.

## A note on the client secret

A stored client secret is the simplest way to authenticate a service principal, and it's what this project uses for now — appropriate for a portfolio lab. It is **not** what a real production CI/CD setup should do long-term: the better pattern is **OIDC workload identity federation**, where Azure DevOps/GitHub Actions exchanges a short-lived OIDC token for Azure credentials with no secret stored anywhere. This project doesn't wire that up (yet) to keep Phase 1 approachable, but it's worth knowing the difference — see the comment in `terraform/modules/identity/main.tf` above the `azuread_service_principal_password` resource.

## How it relates to the management VM (Phase 2b)

The management VM does **not** use this service principal at all — it authenticates as its own **managed identity** instead (see [managed-identity.md](managed-identity.md)), specifically so no copy of this secret ever needs to exist on the VM's disk. The Terraform service principal exists for cases where a managed identity isn't an option (e.g., a future Azure DevOps pipeline running outside Azure's compute, before OIDC federation is set up).
