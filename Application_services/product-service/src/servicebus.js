const { ServiceBusClient } = require("@azure/service-bus");

// The "Inventory Service" side of the roadmap's messaging diagram (see
// docs/services.md) — product-service itself consumes the "orders" queue
// rather than introducing a fourth standalone service. Best-effort: if
// SERVICEBUS_CONNECTION_STRING isn't set (before Phase 7/9), this is a no-op.
function startOrderConsumer(decrementStock) {
  if (!process.env.SERVICEBUS_CONNECTION_STRING) {
    console.log("SERVICEBUS_CONNECTION_STRING not set — order consumer disabled.");
    return;
  }

  const client = new ServiceBusClient(process.env.SERVICEBUS_CONNECTION_STRING);
  const receiver = client.createReceiver("orders");

  receiver.subscribe({
    processMessage: async (message) => {
      const { productId, quantity } = message.body;
      console.log(`OrderCreated received — decrementing product ${productId} by ${quantity}`);
      await decrementStock(productId, quantity);
    },
    processError: async (err) => {
      console.error("Service Bus receive error:", err.message);
    },
  });

  console.log("Order consumer subscribed to the 'orders' queue.");
}

module.exports = { startOrderConsumer };
