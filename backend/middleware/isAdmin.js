/**
 * Middleware pour protéger les routes admin.
 * TODO: implémenter la vérification JWT + isAdmin lorsque l'auth API sera en place.
 */
function isAdmin(req, res, next) {
  next();
}

module.exports = { isAdmin };
