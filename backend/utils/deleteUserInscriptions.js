/**
 * Supprime toutes les inscriptions d’un utilisateur (libère les places sur les créneaux).
 * À appeler avant DELETE sur users si la contrainte FK n’est pas garantie partout.
 */
async function deleteUserInscriptions(pool, userId) {
  const [r] = await pool.query("DELETE FROM inscriptions WHERE user_id = ?", [userId]);
  return r.affectedRows;
}

module.exports = { deleteUserInscriptions };
