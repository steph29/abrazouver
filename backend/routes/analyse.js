const express = require("express");
const router = express.Router();
const { getPool } = require("../config/database");
const ExcelJS = require("exceljs");

/** Construit les clauses WHERE pour filtrer par date et postes */
function buildCreneauFilter(dateFrom, dateTo, posteIds) {
  const conditions = [];
  const params = [];
  if (dateFrom) {
    conditions.push("c.date_debut >= ?");
    params.push(dateFrom);
  }
  if (dateTo) {
    conditions.push("c.date_fin <= ?");
    params.push(dateTo);
  }
  if (posteIds && Array.isArray(posteIds) && posteIds.length > 0) {
    const ids = posteIds.filter((id) => !Number.isNaN(parseInt(id, 10)));
    if (ids.length > 0) {
      conditions.push(`c.poste_id IN (${ids.map(() => "?").join(",")})`);
      params.push(...ids.map((id) => parseInt(id, 10)));
    }
  }
  return {
    where: conditions.length > 0 ? `AND ${conditions.join(" AND ")}` : "",
    params,
  };
}

/** GET /api/admin/analyse/benevoles-manuels?annee=2025 - Liste des bénévoles inscrits à la main */
router.get("/benevoles-manuels", async (req, res) => {
  try {
    const annee = parseInt(req.query.annee, 10) || new Date().getFullYear();
    const pool = await getPool();
    const [rows] = await pool.query(
      "SELECT id, nom, prenom, annee, created_at FROM benevoles_manuels WHERE annee = ? ORDER BY nom, prenom",
      [annee]
    );
    res.json({ benevoles: rows });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** POST /api/admin/analyse/benevoles-manuels - Ajouter un bénévole inscrit à la main */
router.post("/benevoles-manuels", async (req, res) => {
  try {
    const { nom, prenom } = req.body || {};
    if (!nom || typeof nom !== "string" || !prenom || typeof prenom !== "string") {
      return res.status(400).json({ message: "nom et prenom requis" });
    }
    const annee = parseInt(req.body.annee, 10) || new Date().getFullYear();
    const pool = await getPool();
    const [result] = await pool.query(
      "INSERT INTO benevoles_manuels (nom, prenom, annee) VALUES (?, ?, ?)",
      [nom.trim(), prenom.trim(), annee]
    );
    res.status(201).json({
      id: result.insertId,
      nom: nom.trim(),
      prenom: prenom.trim(),
      annee,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** DELETE /api/admin/analyse/benevoles-manuels/:id - Supprimer un bénévole inscrit à la main */
router.delete("/benevoles-manuels/:id", async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ message: "ID invalide" });
    const pool = await getPool();
    const [result] = await pool.query("DELETE FROM benevoles_manuels WHERE id = ?", [id]);
    if (result.affectedRows === 0) return res.status(404).json({ message: "Non trouvé" });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** GET /api/admin/analyse/export - Export XLSX (filtres: dateFrom, dateTo, posteIds) */
router.get("/export", async (req, res) => {
  try {
    const pool = await getPool();
    const anneeExport = parseInt(req.query.annee, 10) || new Date().getFullYear();
    const { dateFrom, dateTo, posteIds: posteIdsParam } = req.query || {};
    const posteIds = typeof posteIdsParam === "string"
      ? (posteIdsParam ? posteIdsParam.split(",").map((id) => parseInt(id, 10)).filter((id) => !Number.isNaN(id)) : [])
      : Array.isArray(posteIdsParam) ? posteIdsParam.map((id) => parseInt(id, 10)).filter((id) => !Number.isNaN(id)) : [];

    const filter = buildCreneauFilter(dateFrom, dateTo, posteIds.length > 0 ? posteIds : null);
    let benevoles = [];
    if (filter.params.length > 0) {
      const [creneauxRows] = await pool.query(
        `SELECT id FROM creneaux c WHERE 1=1 ${filter.where}`,
        filter.params
      );
      const creneauIds = creneauxRows.map((r) => r.id);
      if (creneauIds.length > 0) {
        const placeholders = creneauIds.map(() => "?").join(",");
        const [rows] = await pool.query(
          `SELECT DISTINCT u.id, u.nom, u.prenom, u.email
           FROM inscriptions i
           JOIN users u ON u.id = i.user_id
           WHERE i.creneau_id IN (${placeholders})
           ORDER BY u.nom, u.prenom`,
          creneauIds
        );
        benevoles = rows;
      }
    } else {
      const [rows] = await pool.query(
        `SELECT DISTINCT u.id, u.nom, u.prenom, u.email
         FROM inscriptions i
         JOIN users u ON u.id = i.user_id
         ORDER BY u.nom, u.prenom`
      );
      benevoles = rows;
    }

    const [benevolesManuels] = await pool.query(
      "SELECT nom, prenom FROM benevoles_manuels WHERE annee = ? ORDER BY nom, prenom",
      [anneeExport]
    );

    const [[logoRow]] = await pool.query("SELECT pref_value FROM app_preferences WHERE pref_key = 'logo'");
    let logoBase64 = null;
    let logoExt = "png";
    if (logoRow?.pref_value) {
      const match = String(logoRow.pref_value).match(/^data:image\/(\w+);base64,(.+)$/);
      if (match) {
        logoExt = match[1] === "jpeg" || match[1] === "jpg" ? "jpeg" : "png";
        logoBase64 = match[2];
      }
    }

    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet("Bénévoles", { properties: { defaultRowHeight: 25 } });

    let rowNum = 1;
    if (logoBase64) {
      const imageId = workbook.addImage({
        base64: logoBase64,
        extension: logoExt,
      });
      sheet.addImage(imageId, {
        tl: { col: 0, row: 0 },
        ext: { width: 120, height: 60 },
        editAs: "oneCell",
      });
      rowNum = 4;
    }

    sheet.getCell(rowNum, 1).value = "Nom";
    sheet.getCell(rowNum, 2).value = "Prénom";
    sheet.getCell(rowNum, 3).value = "Email";
    sheet.getCell(rowNum, 4).value = "Source";
    sheet.getCell(rowNum, 1).font = { bold: true };
    sheet.getCell(rowNum, 2).font = { bold: true };
    sheet.getCell(rowNum, 3).font = { bold: true };
    sheet.getCell(rowNum, 4).font = { bold: true };
    rowNum++;

    for (const b of benevoles) {
      sheet.getCell(rowNum, 1).value = b.nom;
      sheet.getCell(rowNum, 2).value = b.prenom;
      sheet.getCell(rowNum, 3).value = b.email || "";
      sheet.getCell(rowNum, 4).value = "App";
      rowNum++;
    }
    for (const b of benevolesManuels) {
      sheet.getCell(rowNum, 1).value = b.nom;
      sheet.getCell(rowNum, 2).value = b.prenom;
      sheet.getCell(rowNum, 3).value = "";
      sheet.getCell(rowNum, 4).value = "Manuel";
      rowNum++;
    }

    sheet.getColumn(1).width = 25;
    sheet.getColumn(2).width = 25;
    sheet.getColumn(3).width = 30;
    sheet.getColumn(4).width = 12;

    const buffer = await workbook.xlsx.writeBuffer();

    res.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    res.setHeader("Content-Disposition", 'attachment; filename="benevoles_inscrits.xlsx"');
    res.send(buffer);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

/** GET /api/admin/analyse - Stats KPI + taux remplissage par poste + liste bénévoles */
router.get("/", async (req, res) => {
  try {
    const { dateFrom, dateTo, posteIds: posteIdsParam } = req.query || {};
    const posteIds = typeof posteIdsParam === "string"
      ? (posteIdsParam ? posteIdsParam.split(",").map((id) => parseInt(id, 10)).filter((id) => !Number.isNaN(id)) : [])
      : Array.isArray(posteIdsParam) ? posteIdsParam.map((id) => parseInt(id, 10)).filter((id) => !Number.isNaN(id)) : [];
    const filter = buildCreneauFilter(dateFrom, dateTo, posteIds.length > 0 ? posteIds : null);

    const pool = await getPool();

    let creneauIdsFiltered = null;
    if (filter.params.length > 0) {
      const [creneauxRows] = await pool.query(
        `SELECT id FROM creneaux c WHERE 1=1 ${filter.where}`,
        filter.params
      );
      creneauIdsFiltered = creneauxRows.map((r) => r.id);
      if (creneauIdsFiltered.length === 0) {
        const [postesAll] = await pool.query("SELECT id, titre FROM postes ORDER BY titre");
        return res.json({
          nbPlacesPrises: 0,
          nbBenevoles: 0,
          tauxRemplissageParPoste: [],
          postes: postesAll.map((p) => ({ id: p.id, titre: p.titre })),
          benevoles: [],
        });
      }
    }

    const creneauFilterSql =
      creneauIdsFiltered && creneauIdsFiltered.length > 0
        ? `AND i.creneau_id IN (${creneauIdsFiltered.map(() => "?").join(",")})`
        : "";
    const creneauFilterParams = creneauIdsFiltered && creneauIdsFiltered.length > 0 ? creneauIdsFiltered : [];

    const [[stats]] = await pool.query(
      `SELECT COUNT(i.id) as nb_places_prises, COUNT(DISTINCT i.user_id) as nb_benevoles
       FROM inscriptions i
       WHERE 1=1 ${creneauFilterSql}`,
      creneauFilterParams
    );

    const [postesRaw] = await pool.query(
      `SELECT p.id, p.titre, c.id as creneau_id, c.nb_benevoles_requis,
         COALESCE(nb.n, 0) as nb_inscrits
       FROM postes p
       JOIN creneaux c ON c.poste_id = p.id
       LEFT JOIN (SELECT creneau_id, COUNT(*) as n FROM inscriptions GROUP BY creneau_id) nb ON nb.creneau_id = c.id
       ORDER BY p.titre, c.date_debut`
    );

    const [postesAll] = await pool.query("SELECT id, titre FROM postes ORDER BY titre");
    const postes = postesAll.map((p) => ({ id: p.id, titre: p.titre }));

    const postesAgg = {};
    for (const row of postesRaw) {
      if (creneauIdsFiltered && creneauIdsFiltered.length > 0 && !creneauIdsFiltered.includes(row.creneau_id)) {
        continue;
      }
      if (!postesAgg[row.id]) {
        postesAgg[row.id] = { id: row.id, titre: row.titre, totalPlaces: 0, totalPrises: 0 };
      }
      postesAgg[row.id].totalPlaces += row.nb_benevoles_requis;
      postesAgg[row.id].totalPrises += Number(row.nb_inscrits) || 0;
    }
    const tauxParPoste = Object.values(postesAgg).map((p) => ({
      posteId: p.id,
      titre: p.titre,
      tauxRemplissage: p.totalPlaces > 0 ? Math.round((p.totalPrises / p.totalPlaces) * 100) : 0,
      totalPlaces: p.totalPlaces,
      totalPrises: p.totalPrises,
    }));

    const [inscriptionsRows] = await pool.query(
      `SELECT u.id, u.nom, u.prenom, u.email,
              i.creneau_id, c.date_debut, c.date_fin, p.titre as poste_titre, p.id as poste_id
       FROM inscriptions i
       JOIN users u ON u.id = i.user_id
       JOIN creneaux c ON c.id = i.creneau_id
       JOIN postes p ON p.id = c.poste_id
       WHERE 1=1 ${creneauFilterSql}
       ORDER BY u.nom, u.prenom, c.date_debut`,
      creneauFilterParams
    );

    const benevolesMap = new Map();
    for (const row of inscriptionsRows) {
      if (!benevolesMap.has(row.id)) {
        benevolesMap.set(row.id, {
          id: row.id,
          nom: row.nom,
          prenom: row.prenom,
          email: row.email,
          postes: [],
        });
      }
      benevolesMap.get(row.id).postes.push({
        posteTitre: row.poste_titre,
        posteId: row.poste_id,
        dateDebut: row.date_debut,
        dateFin: row.date_fin,
      });
    }
    const benevoles = [...benevolesMap.values()];

    res.json({
      nbPlacesPrises: Number(stats?.nb_places_prises) || 0,
      nbBenevoles: Number(stats?.nb_benevoles) || 0,
      tauxRemplissageParPoste: tauxParPoste,
      postes,
      benevoles,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
