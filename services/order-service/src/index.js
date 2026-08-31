const express = require("express");

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3003;
const SERVICE_NAME = "order-service";

// In-memory placeholder data. Replaced with Azure SQL in Phase 6. Creating an
// order will publish a message to the Service Bus "orders" queue in Phase 7,
// consumed by an order processor that notifies product-service of stock
// changes — see the architecture diagram in docs/ROADMAP.md.
const orders = [];
let nextId = 1;

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: SERVICE_NAME });
});

app.get("/api/orders", (req, res) => {
  res.json(orders);
});

app.post("/api/orders", (req, res) => {
  const { userId, productId, quantity } = req.body || {};
  if (!userId || !productId || !quantity) {
    return res.status(400).json({ error: "userId, productId, and quantity are required" });
  }
  const order = { id: nextId++, userId, productId, quantity, status: "created" };
  orders.push(order);
  res.status(201).json(order);
});

app.listen(PORT, () => {
  console.log(`${SERVICE_NAME} listening on port ${PORT}`);
});
