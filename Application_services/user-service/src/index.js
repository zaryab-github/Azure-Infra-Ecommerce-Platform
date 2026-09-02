const express = require("express");

const app = express();
const PORT = process.env.PORT || 3001;
const SERVICE_NAME = "user-service";

// In-memory placeholder data. Replaced with Azure SQL in Phase 6, and the
// connection string will be read from Key Vault via managed identity in
// Phase 9 — no credentials will be hardcoded here.
const users = [
  { id: 1, name: "Ada Lovelace", email: "ada@example.com" },
  { id: 2, name: "Grace Hopper", email: "grace@example.com" },
];

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: SERVICE_NAME });
});

app.get("/api/users", (req, res) => {
  res.json(users);
});

app.get("/api/users/:id", (req, res) => {
  const user = users.find((u) => u.id === Number(req.params.id));
  if (!user) return res.status(404).json({ error: "user not found" });
  res.json(user);
});

app.listen(PORT, () => {
  console.log(`${SERVICE_NAME} listening on port ${PORT}`);
});
