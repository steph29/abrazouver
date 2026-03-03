require("dotenv").config({ path: require("path").join(__dirname, ".env") });

// Capturer les erreurs non gérées pour éviter les crashes silencieux (502)
process.on("uncaughtException", (err) => {
  console.error("❌ uncaughtException:", err.message);
  console.error(err.stack);
});
process.on("unhandledRejection", (reason, promise) => {
  console.error("❌ unhandledRejection:", reason);
});

const express = require("express");
const cors = require("cors");
const authRoutes = require("./routes/auth");
const { router: twofaRoutes } = require("./routes/twofa");
const { postesReadRouter, postesAdminRouter } = require("./routes/postes");
const { isAdmin } = require("./middleware/isAdmin");
const inscriptionsRoutes = require("./routes/inscriptions");
const preferencesRoutes = require("./routes/preferences");
const { contactRouter, contactAdminRouter } = require("./routes/contact");
const analyseRoutes = require("./routes/analyse");
const crudRoutes = require("./routes/crud");
const { getPool } = require("./config/database");
const { hasSmtp } = require("./config/email");

const app = express();
const PORT = process.env.PORT || 3000;

const { tenantMiddleware } = require("./middleware/tenant");
const tenantsRoutes = require("./routes/tenants");

// CORS : une seule source de vérité (pas de doublons avec nginx)
// CORS_ORIGINS = origines autorisées, séparées par des virgules
const corsOriginsEnv = (process.env.CORS_ORIGINS || "").trim();
const corsOrigins = corsOriginsEnv ? corsOriginsEnv.split(",").map((o) => o.trim()).filter(Boolean) : [];
app.use(
  cors({
    origin: corsOrigins.length === 0 || corsOrigins.includes("*") ? true : corsOrigins,
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "X-Super-Admin-Secret", "X-User-Id"],
  }),
);
app.use(express.json({ limit: "8mb" }));

app.get("/", (req, res) => {
  res.redirect(301, "/api/health");
});
app.get("/api/health", (req, res) => {
  res.json({ status: "ok", message: "API Abrazouver" });
});

// Multi-tenant : extrait le client du Host (api.client.xxx)
app.use((req, res, next) => {
  if (req.path === "/api/health") return next();
  return tenantMiddleware(req, res, next);
});

// Auth et 2FA en premier (avant le CRUD générique)
// Routes explicites pour éviter que le CRUD ne capture /api/auth/register comme /:table/:id
app.use("/api/auth", authRoutes);
app.use("/api/auth/2fa", twofaRoutes);

// Le CRUD matche /api/:table/:id (ex: GET /auth/register) - rediriger auth vers le routeur auth
const crudWrapper = (req, res, next) => {
  const p = (req.path || req.url || "").split("?")[0].replace(/^\/api/, "") || "/";
  if (p.startsWith("/auth")) {
    req.url = (p.replace(/^\/auth/, "") || "/") + (req.url?.includes("?") ? "?" + req.url.split("?")[1] : "");
    return authRoutes(req, res, next);
  }
  return crudRoutes(req, res, next);
};

// Gestion des clients (api.admin.xxx uniquement)
app.use("/api/superadmin/tenants", tenantsRoutes);

// Lecture publique (Places libres)
app.use("/api/postes", postesReadRouter);

// Admin (gestion postes/créneaux)
app.use("/api/admin/postes", isAdmin, postesAdminRouter);

app.use("/api/benevoles/inscriptions", inscriptionsRoutes);
app.use("/api/preferences", preferencesRoutes);
app.use("/api/contact", contactRouter);
app.use("/api/admin/contact-messages", contactAdminRouter);
app.use("/api/admin/analyse", isAdmin, analyseRoutes);
app.use("/api", crudWrapper);

// Middleware d'erreur (attrape les erreurs passées à next(err))
app.use((err, req, res, next) => {
  console.error("❌ Erreur API:", err.message);
  res.status(500).json({ message: err.message || "Erreur serveur" });
});

async function start() {
  // Pas de getPool() au démarrage - connexion par requête selon le tenant
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Serveur API sur http://0.0.0.0:${PORT}`);
    const emailMode = process.env.EMAIL_SENDMAIL === "true" || process.env.EMAIL_SENDMAIL === "1"
  ? "sendmail"
  : process.env.SMTP_HOST ? "SMTP" : "non configuré";
console.log(`   📧 Emails Contact: ${emailMode}`);
    console.log(`   - Health: GET /api/health`);
    console.log(`   - Auth:   POST /api/auth/login, POST /api/auth/register`);
    console.log(`   - Postes: GET /api/postes (public), POST/PUT/DELETE /api/admin/postes (admin)`);
    console.log(`   - Bénévoles: GET/POST/DELETE /api/benevoles/inscriptions`);
    console.log(`   - CRUD:   GET/POST/PUT/DELETE /api/:table`);
  });
}

start().catch((err) => {
  console.error("❌ Démarrage impossible:", err.message);
  process.exit(1);
});
