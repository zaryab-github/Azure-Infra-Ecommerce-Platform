const sql = require("mssql");

let pool = null;

async function getPool() {
  if (!process.env.SQL_SERVER) return null;
  if (pool) return pool;
  pool = await sql.connect({
    server: process.env.SQL_SERVER,
    database: process.env.SQL_DATABASE,
    user: process.env.SQL_USER,
    password: process.env.SQL_PASSWORD,
    options: { encrypt: true },
  });
  return pool;
}

module.exports = { getPool };
