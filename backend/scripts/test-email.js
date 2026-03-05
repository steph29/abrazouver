/**
 * Test d'envoi d'email (mot de passe perdu, contact, etc.)
 * Usage: node scripts/test-email.js destinaire@email.com
 * ou: npm run test-email destinaire@email.com
 */
require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const { sendMail } = require("../config/email");

async function main() {
  const to = process.argv[2] || process.env.EMAIL_FROM;
  if (!to) {
    console.error("Usage: npm run test-email votre@email.com");
    process.exit(1);
  }

  console.log(`Envoi d'un email test vers ${to}...`);

  const sent = await sendMail({
    to,
    subject: "Abrazouver - Test email (mot de passe perdu)",
    text: "Ceci est un email de test pour vérifier la configuration Sendmail.",
    html: "<p>Ceci est un <strong>email de test</strong> pour vérifier la configuration Sendmail.</p>",
  });

  if (sent) {
    console.log("✅ Email envoyé avec succès. Vérifiez la boîte de réception (et les spams).");
  } else {
    console.error("❌ Échec de l'envoi. Vérifiez :");
    console.error("   - EMAIL_SENDMAIL=true et EMAIL_FROM dans .env");
    console.error("   - Sendmail installé : which sendmail");
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("❌ Erreur:", err.message);
  process.exit(1);
});
