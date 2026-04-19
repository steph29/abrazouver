/**
 * Postes dont un utilisateur est référent (hors rôle admin).
 */
async function getReferentPosteIds(pool, userId) {
  if (!userId) return [];
  try {
    const [rows] = await pool.query("SELECT poste_id FROM referent_postes WHERE user_id = ?", [userId]);
    return rows.map((r) => Number(r.poste_id));
  } catch (e) {
    if (e && e.code === "ER_NO_SUCH_TABLE") return [];
    throw e;
  }
}

module.exports = { getReferentPosteIds };
