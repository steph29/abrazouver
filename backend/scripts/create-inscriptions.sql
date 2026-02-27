-- Crée uniquement la table inscriptions (si elle n'existe pas)
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
