# servicebus module — not yet implemented

Built in **Phase 7 — Messaging** (see [`docs/ROADMAP.md`](../../../docs/ROADMAP.md)).

Will provision: Service Bus namespace (Basic tier) and an `orders` queue, used for the async flow `order-service` (publisher) → queue → an order processor that notifies `product-service` of inventory changes.
