const express = require("express");

const app = express();
const PORT = process.env.PORT || 3002;
const SERVICE_NAME = "product-service";

// In-memory placeholder data. Replaced with Azure SQL in Phase 6, and product
// images will move to Azure Storage in Phase 8. Inventory updates will arrive
// via Service Bus from order-service in Phase 7.
const products = [
  { id: 1, name: "Mechanical Keyboard", price: 89.99, stock: 42 },
  { id: 2, name: "USB-C Dock", price: 54.5, stock: 17 },
];

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: SERVICE_NAME });
});

app.get("/api/products", (req, res) => {
  res.json(products);
});

app.get("/api/products/:id", (req, res) => {
  const product = products.find((p) => p.id === Number(req.params.id));
  if (!product) return res.status(404).json({ error: "product not found" });
  res.json(product);
});

app.listen(PORT, () => {
  console.log(`${SERVICE_NAME} listening on port ${PORT}`);
});
