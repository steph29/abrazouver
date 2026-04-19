-- Lien famille : user_with = id du responsable (NULL = compte principal / peut gérer la famille)
SET NAMES utf8mb4;

ALTER TABLE users
  ADD COLUMN user_with INT NULL DEFAULT NULL COMMENT 'ID du responsable famille (NULL = titulaire)' AFTER is_admin,
  ADD KEY idx_users_user_with (user_with),
  ADD CONSTRAINT fk_users_user_with FOREIGN KEY (user_with) REFERENCES users(id) ON DELETE CASCADE;
