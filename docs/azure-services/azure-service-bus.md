# Azure Service Bus

Built in **Phase 7** (`terraform/modules/servicebus`). See [`docs/deployment_phases/phase-07-messaging.md`](../deployment_phases/phase-07-messaging.md) for setup steps.

## What it is

A Basic-tier namespace (`sb-ecommerce-prod`) with one queue, `orders`. Basic tier supports queues only (no topics) — this project doesn't need topics.

## Why this project uses it

The one place `order-service` and `product-service` actually communicate with each other (see [`docs/services.md`](../services.md#how-they-communicate--today-vs-planned)): `order-service` publishes an `OrderCreated` message on order creation (`src/servicebus.js`), and a background receiver inside `product-service` (also `src/servicebus.js`) consumes it and decrements stock — the "Order Processor → Inventory Service" step from the roadmap's messaging diagram, folded into the existing service rather than a 4th standalone one.

## Where it's wired in

`terraform/modules/servicebus/main.tf` — `azurerm_servicebus_namespace`, `azurerm_servicebus_queue`, and a scoped `azurerm_servicebus_namespace_authorization_rule` (Send+Listen only, not Manage — narrower than the namespace's default root key). The connection string is a plain Kubernetes Secret until Phase 9 moves it into Key Vault.
