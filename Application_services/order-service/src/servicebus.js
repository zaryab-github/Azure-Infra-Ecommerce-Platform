const { ServiceBusClient } = require("@azure/service-bus");

// Best-effort publish — if SERVICEBUS_CONNECTION_STRING isn't set (before
// Phase 7/9), this is a no-op so order creation still works standalone.
// See docs/services.md for the full flow.
async function publishOrderCreated(order) {
  if (!process.env.SERVICEBUS_CONNECTION_STRING) return;
  const client = new ServiceBusClient(process.env.SERVICEBUS_CONNECTION_STRING);
  const sender = client.createSender("orders");
  try {
    await sender.sendMessages({
      body: { type: "OrderCreated", ...order },
      contentType: "application/json",
    });
  } finally {
    await sender.close();
    await client.close();
  }
}

module.exports = { publishOrderCreated };
