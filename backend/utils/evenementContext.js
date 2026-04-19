/**
 * ID de l'événement « en cours » (bénévoles, préférences, postes publics).
 */
async function getCurrentEvenementId(pool) {
  const [[row]] = await pool.query(
    "SELECT pref_value FROM app_preferences WHERE pref_key = 'currentEvenementId'"
  );
  if (row?.pref_value) {
    const id = parseInt(row.pref_value, 10);
    if (!Number.isNaN(id)) {
      const [[ex]] = await pool.query("SELECT id FROM evenements WHERE id = ?", [id]);
      if (ex) return id;
    }
  }
  const [[e]] = await pool.query("SELECT id FROM evenements ORDER BY id ASC LIMIT 1");
  return e?.id ?? null;
}

module.exports = { getCurrentEvenementId };
