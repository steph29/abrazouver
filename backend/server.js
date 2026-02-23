require('dotenv').config();
const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const { router: twofaRoutes } = require('./routes/twofa');
const crudRoutes = require('./routes/crud');

const app = express();
const PORT = process.env.PORT || 3000;

const corsOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',').map((o) => o.trim())
  : ['*'];
app.use(
  cors({
    origin: corsOrigins.includes('*') ? true : corsOrigins,
    credentials: true,
  })
);
app.use(express.json());

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'API Abrazouver' });
});

app.use('/api/auth', authRoutes);
app.use('/api/auth/2fa', twofaRoutes);
app.use('/api', crudRoutes);

app.listen(PORT, () => {
  console.log(`🚀 Serveur API sur http://localhost:${PORT}`);
  console.log(`   - Health: GET /api/health`);
  console.log(`   - Auth:   POST /api/auth/login, POST /api/auth/register`);
  console.log(`   - CRUD:   GET/POST/PUT/DELETE /api/:table`);
});
