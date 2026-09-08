# servicebus module

Built in **Phase 7 — Messaging** (see [`docs/ROADMAP.md`](../../../docs/ROADMAP.md), [`docs/deployment_phases/phase-07-messaging.md`](../../../docs/deployment_phases/phase-07-messaging.md)).

Provisions: Service Bus namespace (Basic tier), an `orders` queue, and a scoped Send+Listen auth rule. Used for the async flow `order-service` (publisher) → queue → `product-service`'s background receiver, which decrements stock — see [`docs/services.md`](../../../docs/services.md).
