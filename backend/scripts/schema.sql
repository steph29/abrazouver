-- =============================================================================
-- Schéma BDD Abrazouver
-- =============================================================================
-- Ce fichier est exécuté automatiquement au démarrage du serveur et par deploy.sh
-- Pour ajouter de nouvelles tables : éditez ce fichier uniquement, puis déployez.
-- =============================================================================

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  nom VARCHAR(100) NOT NULL,
  prenom VARCHAR(100) NOT NULL,
  telephone VARCHAR(20) DEFAULT NULL,
  two_factor_secret VARCHAR(64) DEFAULT NULL,
  two_factor_enabled TINYINT(1) DEFAULT 0,
  is_admin TINYINT(1) DEFAULT 0,
  password_reset_token VARCHAR(64) DEFAULT NULL,
  password_reset_expires_at DATETIME DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Postes de bénévolat
CREATE TABLE IF NOT EXISTS postes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  titre VARCHAR(255) NOT NULL,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Créneaux horaires par poste (date_debut < date_fin pour faciliter les vérifications)
CREATE TABLE IF NOT EXISTS creneaux (
  id INT AUTO_INCREMENT PRIMARY KEY,
  poste_id INT NOT NULL,
  date_debut DATETIME NOT NULL,
  date_fin DATETIME NOT NULL,
  nb_benevoles_requis INT NOT NULL DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (poste_id) REFERENCES postes(id) ON DELETE CASCADE
);

CREATE INDEX idx_creneaux_poste ON creneaux(poste_id);
CREATE INDEX idx_creneaux_dates ON creneaux(date_debut, date_fin);

-- Bénévoles ajoutés manuellement (hors inscription app)
CREATE TABLE IF NOT EXISTS benevoles_manuels (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nom VARCHAR(100) NOT NULL,
  prenom VARCHAR(100) NOT NULL,
  email VARCHAR(255) DEFAULT NULL,
  telephone VARCHAR(20) DEFAULT NULL,
  creneau_id INT DEFAULT NULL,
  notes TEXT DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_benevoles_manuels_creneau (creneau_id),
  FOREIGN KEY (creneau_id) REFERENCES creneaux(id) ON DELETE SET NULL
);

-- Inscriptions des bénévoles aux créneaux
CREATE TABLE IF NOT EXISTS inscriptions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  creneau_id INT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_user_creneau (user_id, creneau_id),
  KEY idx_inscriptions_creneau (creneau_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (creneau_id) REFERENCES creneaux(id) ON DELETE CASCADE
);

-- Préférences de l'appli (thème, logo, etc.) - modifiables par les admins
CREATE TABLE IF NOT EXISTS app_preferences (
  pref_key VARCHAR(100) PRIMARY KEY,
  pref_value MEDIUMTEXT
);
INSERT IGNORE INTO app_preferences (pref_key, pref_value) VALUES
  ('primaryColor', '#4CAF50'),
  ('secondaryColor', '#2b5a72'),
  ('contactEmail', ''),
  ('accueilTitre', ''),
  ('accueilDescription', '');

-- Bénévoles inscrits manuellement (ne souhaitent pas créer de compte)
CREATE TABLE IF NOT EXISTS benevoles_manuels (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nom VARCHAR(100) NOT NULL,
  prenom VARCHAR(100) NOT NULL,
  annee INT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  KEY idx_annee (annee)
);

-- Messages envoyés depuis la page Contact (utilisateur -> admin)
CREATE TABLE IF NOT EXISTS contact_messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  email VARCHAR(255) NOT NULL,
  subject VARCHAR(500) NOT NULL,
  body TEXT NOT NULL,
  attachment_name VARCHAR(255) DEFAULT NULL,
  attachment_data MEDIUMBLOB DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  KEY idx_contact_user (user_id),
  KEY idx_contact_created (created_at)
);
