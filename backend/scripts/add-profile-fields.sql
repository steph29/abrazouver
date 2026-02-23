-- Migration : ajouter téléphone, 2FA et secret TOTP
-- À exécuter si votre base existait avant cette mise à jour
ALTER TABLE users ADD COLUMN telephone VARCHAR(20) DEFAULT NULL;
ALTER TABLE users ADD COLUMN two_factor_secret VARCHAR(64) DEFAULT NULL;
ALTER TABLE users ADD COLUMN two_factor_enabled TINYINT(1) DEFAULT 0;
