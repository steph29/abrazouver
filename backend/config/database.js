require("dotenv").config();
const mysql = require("mysql2/promise");
const { ensureSchema } = require("./ensureSchema");

const dbConfig = {
  host: process.env.DB_HOST || "localhost",
  port: parseInt(process.env.DB_PORT, 10) || 3306,
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "abrazouver_apel",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  multipleStatements: true,
};

let pool = null;

async function getPool() {
  if (!pool) {
    pool = mysql.createPool(dbConfig);
    try {
      const conn = await pool.getConnection();
      let db = dbConfig.database;
      let tables = [];
      try {
        const [[row]] = await conn.query("SELECT DATABASE() as d");
        db = row?.d || db;
        [tables] = await conn.query("SHOW TABLES");
      } catch (_) {}
      conn.release();
      console.log(`✅ Connexion à la base SQL établie (${dbConfig.host}:${dbConfig.port} / ${db})`);
      const tableNames = tables.map((t) => Object.values(t)[0]).filter(Boolean);
      console.log(`   Tables: ${tableNames.length ? tableNames.join(", ") : "(aucune)"}`);
      if (process.env.AUTO_INIT_SCHEMA !== "false") {
        await ensureSchema(pool);
      }
    } catch (err) {
      console.error("❌ Erreur connexion base de données:", err.message);
      throw err;
    }
  }
  return pool;
}

module.exports = { getPool, dbConfig };
