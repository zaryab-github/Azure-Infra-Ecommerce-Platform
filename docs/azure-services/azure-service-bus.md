# Azure Service Bus — not yet implemented

Lands in **Phase 7** (see [`docs/ROADMAP.md`](../ROADMAP.md), Terraform module `terraform/modules/servicebus`).

**What it will be**: a Service Bus namespace (Basic tier) with an `orders` queue.

**Why it's needed here**: this is the one place `order-service` and `product-service` actually communicate with each other (see [`docs/services.md`](../services.md#how-they-communicate--today-vs-planned) for the full flow) — `order-service` publishes an `OrderCreated` message, a processor consumes it and updates `product-service`'s inventory. It demonstrates asynchronous, decoupled inter-service communication as distinct from the synchronous REST calls used elsewhere.

This file will be filled in with the actual queue/topic design and consumer implementation once Phase 7 is built.
