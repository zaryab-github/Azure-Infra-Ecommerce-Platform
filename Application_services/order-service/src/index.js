if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  require("applicationinsights").setup().start();
}

const express = require("express");
const { getPool } = require("./db");
const { publishOrderCreated } = require("./servicebus");

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3003;
const SERVICE_NAME = "order-service";

// In-memory fallback when no SQL_SERVER is configured (local dev, or before
// Phase 6/9). Against Azure SQL, orders persist in the Orders table instead.
const orders = [];
let nextId = 1;

async function initDb() {
  const pool = await getPool();
  if (!pool) return;
  await pool.request().query(`
    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Orders' AND xtype='U')
    CREATE TABLE Orders (id INT IDENTITY(1,1) PRIMARY KEY, userId INT, productId INT, quantity INT, status NVARCHAR(50))
  `);
}

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: SERVICE_NAME });
});

app.get("/api/orders", async (req, res) => {
  const pool = await getPool();
  if (!pool) return res.json(orders);
  const { recordset } = await pool.request().query("SELECT * FROM Orders");
  res.json(recordset);
});

app.post("/api/orders", async (req, res) => {
  const { userId, productId, quantity } = req.body || {};
  if (!userId || !productId || !quantity) {
    return res.status(400).json({ error: "userId, productId, and quantity are required" });
  }

  const pool = await getPool();
  let order;
  if (!pool) {
    order = { id: nextId++, userId, productId, quantity, status: "created" };
    orders.push(order);
  } else {
    const { recordset } = await pool
      .request()
      .input("userId", userId)
      .input("productId", productId)
      .input("quantity", quantity)
      .input("status", "created")
      .query(
        "INSERT INTO Orders (userId, productId, quantity, status) OUTPUT INSERTED.* VALUES (@userId, @productId, @quantity, @status)"
      );
    order = recordset[0];
  }

  publishOrderCreated(order).catch((err) => console.error("Failed to publish OrderCreated:", err.message));

  res.status(201).json(order);
});

initDb().catch((err) => console.error("DB init failed:", err.message));

app.listen(PORT, () => {
  console.log(`${SERVICE_NAME} listening on port ${PORT}`);
});
