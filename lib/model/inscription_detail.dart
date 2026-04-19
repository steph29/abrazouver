/// Détail d'une inscription (poste + créneau) pour la page Mes Postes
class InscriptionDetail {
  final int inscriptionId;
  final int creneauId;
  /// Utilisateur inscrit sur ce créneau (pour annulation / famille).
  final int userId;
  final PosteResume poste;
  final CreneauResume creneau;

  InscriptionDetail({
    required this.inscriptionId,
    required this.creneauId,
    required this.userId,
    required this.poste,
    required this.creneau,
  });

  factory InscriptionDetail.fromJson(Map<String, dynamic> json) {
    return InscriptionDetail(
      inscriptionId: (json['inscriptionId'] as num).toInt(),
      creneauId: (json['creneauId'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      poste: PosteResume.fromJson(json['poste'] as Map<String, dynamic>),
      creneau: CreneauResume.fromJson(json['creneau'] as Map<String, dynamic>),
    );
  }
}

class PosteResume {
  final int id;
  final String titre;
  final String? description;

  PosteResume({required this.id, required this.titre, this.description});

  factory PosteResume.fromJson(Map<String, dynamic> json) {
    return PosteResume(
      id: json['id'] as int,
      titre: json['titre'] as String,
      description: json['description'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosteResume &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          titre == other.titre;

  @override
  int get hashCode => Object.hash(id, titre);
}

class CreneauResume {
  final int id;
  final DateTime dateDebut;
  final DateTime dateFin;
  final int nbBenevolesRequis;

  CreneauResume({
    required this.id,
    required this.dateDebut,
    required this.dateFin,
    this.nbBenevolesRequis = 1,
  });

  factory CreneauResume.fromJson(Map<String, dynamic> json) {
    return CreneauResume(
      id: json['id'] as int,
      dateDebut: DateTime.parse(json['dateDebut'] as String),
      dateFin: DateTime.parse(json['dateFin'] as String),
      nbBenevolesRequis: (json['nbBenevolesRequis'] as num?)?.toInt() ?? 1,
    );
  }
}
