class User {
  final int id;
  final String email;
  final String nom;
  final String prenom;
  final String? telephone;
  final bool twoFactorEnabled;
  final bool isAdmin;

  User({
    required this.id,
    required this.email,
    required this.nom,
    required this.prenom,
    this.telephone,
    this.twoFactorEnabled = false,
    this.isAdmin = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      telephone: json['telephone'] as String?,
      twoFactorEnabled: json['twoFactorEnabled'] == true,
      isAdmin: json['isAdmin'] == true,
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
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
