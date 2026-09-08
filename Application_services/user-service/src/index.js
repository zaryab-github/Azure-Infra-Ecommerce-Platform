if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  require("applicationinsights").setup().start();
}

const express = require("express");
const { getPool } = require("./db");

const app = express();
const PORT = process.env.PORT || 3001;
const SERVICE_NAME = "user-service";

// Seed data — used directly when no SQL_SERVER is configured (local dev),
// and used once to seed the Users table on first startup against Azure SQL
// (Phase 6). See db.js and docs/deployment_phases/phase-06-databases.md.
const users = [
  { id: 1, name: "Ada Lovelace", email: "ada@example.com" },
  { id: 2, name: "Grace Hopper", email: "grace@example.com" },
];

async function initDb() {
  const pool = await getPool();
  if (!pool) return;
  await pool.request().query(`
    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Users' AND xtype='U')
    CREATE TABLE Users (id INT PRIMARY KEY, name NVARCHAR(200), email NVARCHAR(200))
  `);
  const { recordset } = await pool.request().query("SELECT COUNT(*) AS count FROM Users");
  if (recordset[0].count === 0) {
    for (const u of users) {
      await pool
        .request()
        .input("id", u.id)
        .input("name", u.name)
        .input("email", u.email)
        .query("INSERT INTO Users (id, name, email) VALUES (@id, @name, @email)");
    }
  }
}

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: SERVICE_NAME });
});

app.get("/api/users", async (req, res) => {
  const pool = await getPool();
  if (!pool) return res.json(users);
  const { recordset } = await pool.request().query("SELECT * FROM Users");
  res.json(recordset);
});

app.get("/api/users/:id", async (req, res) => {
  const pool = await getPool();
  if (!pool) {
    const user = users.find((u) => u.id === Number(req.params.id));
    if (!user) return res.status(404).json({ error: "user not found" });
    return res.json(user);
  }
  const { recordset } = await pool.request().input("id", req.params.id).query("SELECT * FROM Users WHERE id = @id");
  if (!recordset.length) return res.status(404).json({ error: "user not found" });
  res.json(recordset[0]);
});

initDb().catch((err) => console.error("DB init failed:", err.message));

app.listen(PORT, () => {
  console.log(`${SERVICE_NAME} listening on port ${PORT}`);
});
