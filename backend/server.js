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

const corsOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(",").map((o) => o.trim())
  : ["*"];
app.use(
  cors({
    origin: corsOrigins.includes("*") ? true : corsOrigins,
    credentials: true,
  }),
);
app.use(express.json({ limit: "8mb" }));

app.get("/api/health", (req, res) => {
  res.json({ status: "ok", message: "API Abrazouver" });
});

// Lecture publique (Places libres)
app.use("/api/postes", postesReadRouter);

// Admin (gestion postes/créneaux)
app.use("/api/admin/postes", isAdmin, postesAdminRouter);

app.use("/api/benevoles/inscriptions", inscriptionsRoutes);
app.use("/api/preferences", preferencesRoutes);
app.use("/api/contact", contactRouter);
app.use("/api/admin/contact-messages", contactAdminRouter);
app.use("/api/admin/analyse", isAdmin, analyseRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/auth/2fa", twofaRoutes);
app.use("/api", crudRoutes);

// Middleware d'erreur (attrape les erreurs passées à next(err))
app.use((err, req, res, next) => {
  console.error("❌ Erreur API:", err.message);
  res.status(500).json({ message: err.message || "Erreur serveur" });
});

async function start() {
  await getPool();
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
