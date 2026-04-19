/// Membre du foyer (réponse API /auth/family ou /mes/family).
class FamilyMember {
  final int id;
  final String? email;
  final String nom;
  final String prenom;
  final String? telephone;
  final bool isHead;
  /// Peut se connecter avec email / mot de passe (sinon géré uniquement par le titulaire).
  final bool canLogin;

  FamilyMember({
    required this.id,
    this.email,
    required this.nom,
    required this.prenom,
    this.telephone,
    required this.isHead,
    this.canLogin = false,
  });

  String get displayName => '$prenom $nom'.trim();

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String?,
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      telephone: json['telephone'] as String?,
      isHead: json['isHead'] == true,
      canLogin: json['canLogin'] == true,
    );
  }
}
