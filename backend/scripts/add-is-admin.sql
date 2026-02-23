-- Migration : ajouter la colonne is_admin
-- À exécuter si votre base existait avant cette mise à jour
-- (Erreur "duplicate column" = la colonne existe déjà, c'est bon)
ALTER TABLE users ADD COLUMN is_admin TINYINT(1) DEFAULT 0;
UPDATE users SET is_admin = 1 WHERE email = 'admin@abrazouver.fr';
