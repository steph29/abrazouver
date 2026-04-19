-- Membres famille sans compte séparé : email et mot de passe optionnels (NULL).
SET NAMES utf8mb4;

ALTER TABLE users MODIFY email VARCHAR(255) NULL;
ALTER TABLE users MODIFY password_hash VARCHAR(255) NULL;
