require("dotenv").config();
const express = require("express");
const cors = require("cors");
const authRoutes = require("./routes/auth");
const { router: twofaRoutes } = require("./routes/twofa");
const { postesReadRouter, postesAdminRouter } = require("./routes/postes");
const { isAdmin } = require("./middleware/isAdmin");
const crudRoutes = require("./routes/crud");
const { getPool } = require("./config/database");

const app = express();
const PORT = process.env.PORT || 3000;

const corsOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(",").map((o) => o.trim())
  : ["*"];
app.use(
  cors({
    origin: corsOrigins.includes("*") ? true : corsOrigins,
    credentials: true,
  }),
);
app.use(express.json());

app.get("/api/health", (req, res) => {
  res.json({ status: "ok", message: "API Abrazouver" });
});

// Lecture publique (Places libres)
app.use("/api/postes", postesReadRouter);

// Admin (gestion postes/créneaux)
app.use("/api/admin/postes", isAdmin, postesAdminRouter);

app.use("/api/auth", authRoutes);
app.use("/api/auth/2fa", twofaRoutes);
app.use("/api", crudRoutes);

async function start() {
  await getPool();
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Serveur API sur http://0.0.0.0:${PORT}`);
    console.log(`   - Health: GET /api/health`);
    console.log(`   - Auth:   POST /api/auth/login, POST /api/auth/register`);
    console.log(`   - Postes: GET /api/postes (public), POST/PUT/DELETE /api/admin/postes (admin)`);
    console.log(`   - CRUD:   GET/POST/PUT/DELETE /api/:table`);
  });
}

start().catch((err) => {
  console.error("❌ Démarrage impossible:", err.message);
  process.exit(1);
});
