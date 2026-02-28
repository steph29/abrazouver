const express = require("express");
const router = express.Router();
const { getPool } = require("../config/database");
const { isAdmin } = require("../middleware/isAdmin");
const { sendMail, hasSmtp } = require("../config/email");

const MAX_ATTACHMENT_BYTES = 5 * 1024 * 1024; // 5 Mo

/** Vérifie que l'utilisateur est authentifié (X-User-Id) */
function requireAuth(req, res, next) {
  const userId = req.headers["x-user-id"];
  if (!userId) {
    return res.status(401).json({ message: "Authentification requise (X-User-Id)" });
  }
  const id = parseInt(userId, 10);
  if (Number.isNaN(id)) {
    return res.status(401).json({ message: "X-User-Id invalide" });
  }
  req.userId = id;
  next();
}

/** Valide un email */
function isValidEmail(s) {
  if (!s || typeof s !== "string") return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s.trim());
}

/** POST /api/contact - Envoyer un message depuis la page Contact */
router.post("/", requireAuth, async (req, res) => {
  try {
    const { email, subject, body, attachmentFileName, attachmentBase64 } = req.body || {};

    const em = (email || "").trim();
    const subj = (subject || "").trim();
    const b = (body || "").trim();

    if (!isValidEmail(em)) {
      return res.status(400).json({ message: "Email invalide" });
    }
    if (subj.length === 0) {
      return res.status(400).json({ message: "L'objet est obligatoire" });
    }
    if (b.length === 0) {
      return res.status(400).json({ message: "Le message est obligatoire" });
    }

    let attachmentData = null;
    let attachmentName = null;

    if (attachmentBase64) {
      try {
        const buf = Buffer.from(attachmentBase64, "base64");
        if (buf.length > MAX_ATTACHMENT_BYTES) {
          return res.status(400).json({
            message: `Pièce jointe trop volumineuse (max ${MAX_ATTACHMENT_BYTES / 1024 / 1024} Mo)`,
          });
        }
        attachmentData = buf;
        attachmentName =
          typeof attachmentFileName === "string" && attachmentFileName.trim().length > 0
            ? attachmentFileName.trim()
            : "piece_jointe";
      } catch {
        return res.status(400).json({ message: "Pièce jointe invalide (base64 requis)" });
      }
    }

    const pool = await getPool();
    const [result] = await pool.query(
      `INSERT INTO contact_messages (user_id, email, subject, body, attachment_name, attachment_data)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [req.userId, em, subj, b, attachmentName, attachmentData]
    );

    // Envoyer par email si SMTP configuré
    const [[prefRow]] = await pool.query(
      "SELECT pref_value FROM app_preferences WHERE pref_key = 'contactEmail'"
    );
    const destEmail = prefRow?.pref_value?.trim?.();

    if (!hasSmtp) {
      console.log("📧 Contact: Email non configuré (vérifiez EMAIL_SENDMAIL=true et EMAIL_FROM dans .env).");
    } else if (!destEmail || !isValidEmail(destEmail)) {
      console.log("📧 Contact: Email de contact non configuré dans Préférences (admin).");
    } else {
      const attachments = [];
      if (attachmentData && attachmentName) {
        attachments.push({
          filename: attachmentName,
          content: attachmentData,
        });
      }
      const sent = await sendMail({
        to: destEmail,
        replyTo: em,
        subject: `[Abrazouver Contact] ${subj}`,
        text: `Message envoyé depuis la page Contact.\n\nDe : ${em}\n\nObjet : ${subj}\n\n---\n\n${b}`,
        html: `<p>Message envoyé depuis la page Contact.</p><p><strong>De :</strong> ${em}</p><p><strong>Objet :</strong> ${subj}</p><hr><pre style="white-space:pre-wrap;font-family:inherit">${b.replace(/</g, "&lt;")}</pre>`,
        attachments,
      });
      if (sent) {
        console.log(`📧 Contact: Email envoyé à ${destEmail}`);
      } else {
        console.warn("📧 Contact: Envoi email échoué (voir erreur ci-dessus).");
      }
    }

    res.status(201).json({
      success: true,
      message: "Message envoyé",
      id: result.insertId,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

const adminRouter = express.Router();

/** GET /api/admin/contact-messages/count - Admin : nombre de messages (pour badge) */
adminRouter.get("/count", isAdmin, async (req, res) => {
  try {
    const pool = await getPool();
    const [[row]] = await pool.query("SELECT COUNT(*) as n FROM contact_messages");
    res.json({ count: row?.n ?? 0 });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** GET /api/admin/contact-messages - Admin : liste des messages reçus */
adminRouter.get("/", isAdmin, async (req, res) => {
  try {
    const pool = await getPool();
    const [rows] = await pool.query(
      `SELECT cm.id, cm.user_id, cm.email, cm.subject, cm.body, cm.attachment_name, cm.created_at
       FROM contact_messages cm
       ORDER BY cm.created_at DESC
       LIMIT 200`
    );
    res.json({ messages: rows });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** GET /api/admin/contact-messages/:id/attachment - Admin : télécharger la pièce jointe */
adminRouter.get("/:id/attachment", isAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) {
      return res.status(400).json({ message: "ID invalide" });
    }
    const pool = await getPool();
    const [[row]] = await pool.query(
      "SELECT attachment_name, attachment_data FROM contact_messages WHERE id = ? AND attachment_data IS NOT NULL",
      [id]
    );
    if (!row) {
      return res.status(404).json({ message: "Pièce jointe introuvable" });
    }
    res.setHeader("Content-Type", "application/octet-stream");
    res.setHeader("Content-Disposition", `attachment; filename="${encodeURIComponent(row.attachment_name || "piece_jointe")}"`);
    res.send(row.attachment_data);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = { contactRouter: router, contactAdminRouter: adminRouter };
