/**
 * Service d'envoi d'emails.
 * Deux modes possibles :
 * 1) SMTP : SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS
 * 2) Sendmail (mail local du VPS) : EMAIL_SENDMAIL=true, EMAIL_FROM=votre@domaine.fr
 */
require("dotenv").config({
  path: require("path").join(__dirname, "..", ".env"),
  override: true,
});
const nodemailer = require("nodemailer");

const _sendmail = String(process.env.EMAIL_SENDMAIL || "").trim().toLowerCase();
const useSendmail = ["true", "1", "yes"].includes(_sendmail);
const _from = (process.env.EMAIL_FROM || "").trim();
const hasSmtp =
  !useSendmail &&
  process.env.SMTP_HOST &&
  process.env.SMTP_USER &&
  process.env.SMTP_PASS;
const hasEmailConfig = hasSmtp || (useSendmail && _from);

let transporter = null;

function getTransporter() {
  if (!hasSmtp && !useSendmail) return null;
  if (transporter) return transporter;

  if (useSendmail) {
    transporter = nodemailer.createTransport({
      sendmail: true,
      newline: "unix",
    });
  } else {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || "587", 10),
      secure: process.env.SMTP_SECURE === "true",
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }
  return transporter;
}

/**
 * Envoie un email.
 * @param {Object} opts - { to, from, subject, text, html, attachments, replyTo }
 * @returns {Promise<boolean>} true si envoyé, false si non configuré ou erreur
 */
async function sendMail(opts) {
  const transport = getTransporter();
  if (!transport) return false;

  const from = opts.from || _from || process.env.SMTP_FROM || process.env.SMTP_USER;
  if (!from) return false;

  try {
    await transport.sendMail({
      from,
      to: opts.to,
      replyTo: opts.replyTo,
      subject: opts.subject,
      text: opts.text || opts.body,
      html: opts.html,
      attachments: opts.attachments,
    });
    return true;
  } catch (err) {
    console.error("❌ Erreur envoi email:", err.message);
    if (err.response) console.error("   Réponse serveur:", err.response);
    return false;
  }
}

module.exports = { sendMail, hasSmtp: hasEmailConfig };
