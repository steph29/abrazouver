-- Donner les droits admin à un utilisateur
-- Remplacer VOTRE_EMAIL par l'email de l'utilisateur concerné
-- Exécuter sur la base du client (abrazouver_apel pour abrazouver-apel)

UPDATE users SET is_admin = 1 WHERE email = 'VOTRE_EMAIL@example.com';
