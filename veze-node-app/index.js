require('dotenv').config();

const express = require('express');
const mysql = require('mysql2/promise');

const app = express();
const port = Number(process.env.APP_PORT) || 3000;

// У Docker змінні DB_* приходять із docker-compose.yml.
// При локальному запуску (npm run dev) - з .env: хост localhost, порт DB_PORT з хоста.
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT) || 3306,
  database: process.env.DB_NAME || process.env.MYSQL_DATABASE,
  user: process.env.DB_USER || process.env.MYSQL_USER,
  password: process.env.DB_PASSWORD || process.env.MYSQL_PASSWORD,
  timezone: 'Z',
  waitForConnections: true,
  connectionLimit: 10,
});

app.get('/health', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT NOW() AS serverTime');
    res.json({ status: 'ok', db: 'ok', serverTime: rows[0].serverTime });
  } catch (err) {
    res.status(503).json({ status: 'error', db: err.message });
  }
});

async function startServer() {
  try {
    await pool.query('SELECT 1');
    console.log('✅ Підключення до MySQL встановлено');
  } catch (err) {
    console.error('❌ Не вдалося підключитися до MySQL:', err.message);
    process.exit(1);
  }

  const server = app.listen(port, () => console.log(`Сервер запущено на порту ${port}`));

  // коректне завершення: docker stop шле SIGTERM
  process.on('SIGTERM', () => {
    server.close(() => pool.end().then(() => process.exit(0)));
  });
}

startServer();
