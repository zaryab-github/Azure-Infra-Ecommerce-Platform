# Azure DevOps Pipelines

Built in **Phase 10** (`pipelines/ci.yml`, `pipelines/cd.yml`). See [`docs/deployment_phases/phase-10-cicd.md`](../deployment_phases/phase-10-cicd.md) for the Portal setup steps — this is the one phase that's Portal-primary rather than Terraform-primary, since an Azure DevOps org/project/pipeline isn't an ARM resource.

## What it is

`ci.yml`: on push to `main`, for each of the 3 services — `npm ci`, `npm test --if-present` (no fake passing tests; skipped gracefully since no test suites exist yet), `docker build` + push to ACR — then a `terraform fmt -check`/`validate` stage. `cd.yml`: manually triggered (or gated behind an environment approval), runs `terraform plan`/`apply`, then `kubectl apply`s the manifests with the freshly built image tags substituted in, then a smoke test against the ingress.

## Why this project uses it

Turns "I manually ran `terraform apply` and `kubectl apply` from the management VM" into a repeatable, auditable, approval-gated process — the difference between a lab exercise and an actual delivery pipeline.

## Where it's wired in

Two Service Connections: `acr-service-connection` (Docker Registry type, for `ci.yml`'s push step) and `azure-service-connection` (ARM type, workload identity federation preferred, for `cd.yml`'s Terraform/kubectl steps). Both created in the Azure DevOps Portal, not Terraform.
