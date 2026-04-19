class User {
  final int id;
  final String email;
  final String nom;
  final String prenom;
  final String? telephone;
  final bool twoFactorEnabled;
  final bool isAdmin;
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
    this.userWith,
  });

  /// Titulaire : peut ajouter / retirer des membres et inscrire toute la famille.
  bool get isFamilyHead => userWith == null;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String? ?? '',
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      telephone: json['telephone'] as String?,
      twoFactorEnabled: json['twoFactorEnabled'] == true,
      isAdmin: json['isAdmin'] == true,
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
      userWith: userWith ?? this.userWith,
    );
  }
}
