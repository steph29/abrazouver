require('dotenv').config();
const mysql = require('mysql2/promise');

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'abrazouver_apel',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
};

let pool = null;

async function getPool() {
  if (!pool) {
    pool = mysql.createPool(dbConfig);
    try {
      const conn = await pool.getConnection();
      conn.release();
      console.log('✅ Connexion à la base SQL établie');
    } catch (err) {
      console.error('❌ Erreur connexion base de données:', err.message);
    }
  }
  return pool;
}

module.exports = { getPool, dbConfig };
