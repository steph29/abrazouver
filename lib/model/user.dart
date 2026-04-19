class User {
  final int id;
  final String email;
  final String nom;
  final String prenom;
  final String? telephone;
  final bool twoFactorEnabled;
  final bool isAdmin;
  /// Postes dont ce bénévole est référent (édition limitée à ces postes).
  final List<int> referentPosteIds;
  /// ID du responsable famille ; `null` = titulaire du compte (peut gérer la famille).
  final int? userWith;

  User({
    required this.id,
    required this.email,
    required this.nom,
    required this.prenom,
    this.telephone,
    this.twoFactorEnabled = false,
    this.isAdmin = false,
    this.referentPosteIds = const [],
    this.userWith,
  });

  /// Titulaire : peut ajouter / retirer des membres et inscrire toute la famille.
  bool get isFamilyHead => userWith == null;

  bool get isReferent => referentPosteIds.isNotEmpty;

  /// Accès à la gestion des postes (admin ou référent).
  bool get canManagePostes => isAdmin || isReferent;

  factory User.fromJson(Map<String, dynamic> json) {
    final rp = json['referentPosteIds'];
    return User(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String? ?? '',
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      telephone: json['telephone'] as String?,
      twoFactorEnabled: json['twoFactorEnabled'] == true,
      isAdmin: json['isAdmin'] == true,
      referentPosteIds: rp is List
          ? rp.map((e) => (e as num).toInt()).toList()
          : const [],
      userWith: json['userWith'] == null ? null : (json['userWith'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nom': nom,
        'prenom': prenom,
        'telephone': telephone,
        'twoFactorEnabled': twoFactorEnabled,
        'isAdmin': isAdmin,
        'referentPosteIds': referentPosteIds,
        'userWith': userWith,
      };

  String get displayName => '$prenom $nom';

  User copyWith({
    int? id,
    String? email,
    String? nom,
    String? prenom,
    String? telephone,
    bool? twoFactorEnabled,
    bool? isAdmin,
    List<int>? referentPosteIds,
    int? userWith,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      isAdmin: isAdmin ?? this.isAdmin,
      referentPosteIds: referentPosteIds ?? this.referentPosteIds,
      userWith: userWith ?? this.userWith,
    );
  }
}
