if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  require("applicationinsights").setup().start();
}

const express = require("express");
const { getPool } = require("./db");
const { startOrderConsumer } = require("./servicebus");

const app = express();
const PORT = process.env.PORT || 3002;
const SERVICE_NAME = "product-service";

// Seed data — used directly when no SQL_SERVER is configured (local dev),
// and used once to seed the Products table on first startup against Azure
// SQL (Phase 6). See db.js and docs/deployment_phases/phase-06-databases.md.
const products = [
  { id: 1, name: "Mechanical Keyboard", price: 89.99, stock: 42 },
  { id: 2, name: "USB-C Dock", price: 54.5, stock: 17 },
];

function withImageUrl(product) {
  const base = process.env.STORAGE_ACCOUNT_URL;
  if (!base) return product;
  return { ...product, imageUrl: `${base}product-images/${product.id}.jpg` };
}

async function initDb() {
  const pool = await getPool();
  if (!pool) return;
  await pool.request().query(`
    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Products' AND xtype='U')
    CREATE TABLE Products (id INT PRIMARY KEY, name NVARCHAR(200), price DECIMAL(10,2), stock INT)
  `);
  const { recordset } = await pool.request().query("SELECT COUNT(*) AS count FROM Products");
  if (recordset[0].count === 0) {
    for (const p of products) {
      await pool
        .request()
        .input("id", p.id)
        .input("name", p.name)
        .input("price", p.price)
        .input("stock", p.stock)
        .query("INSERT INTO Products (id, name, price, stock) VALUES (@id, @name, @price, @stock)");
    }
  }
}

async function decrementStock(productId, quantity) {
  const pool = await getPool();
  if (!pool) {
    const product = products.find((p) => p.id === Number(productId));
    if (product) product.stock = Math.max(0, product.stock - quantity);
    return;
  }
  await pool
    .request()
    .input("id", productId)
    .input("qty", quantity)
    .query("UPDATE Products SET stock = CASE WHEN stock - @qty < 0 THEN 0 ELSE stock - @qty END WHERE id = @id");
}

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: SERVICE_NAME });
});

app.get("/api/products", async (req, res) => {
  const pool = await getPool();
  if (!pool) return res.json(products.map(withImageUrl));
  const { recordset } = await pool.request().query("SELECT * FROM Products");
  res.json(recordset.map(withImageUrl));
});

app.get("/api/products/:id", async (req, res) => {
  const pool = await getPool();
  if (!pool) {
    const product = products.find((p) => p.id === Number(req.params.id));
    if (!product) return res.status(404).json({ error: "product not found" });
    return res.json(withImageUrl(product));
  }
  const { recordset } = await pool.request().input("id", req.params.id).query("SELECT * FROM Products WHERE id = @id");
  if (!recordset.length) return res.status(404).json({ error: "product not found" });
  res.json(withImageUrl(recordset[0]));
});

initDb().catch((err) => console.error("DB init failed:", err.message));
startOrderConsumer(decrementStock);

app.listen(PORT, () => {
  console.log(`${SERVICE_NAME} listening on port ${PORT}`);
});
