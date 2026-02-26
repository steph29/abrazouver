class Creneau {
  final int? id;
  final DateTime dateDebut;
  final DateTime dateFin;
  final int nbBenevolesRequis;

  Creneau({
    this.id,
    required this.dateDebut,
    required this.dateFin,
    this.nbBenevolesRequis = 1,
  });

  factory Creneau.fromJson(Map<String, dynamic> json) {
    return Creneau(
      id: json['id'] as int?,
      dateDebut: DateTime.parse(json['dateDebut'] as String),
      dateFin: DateTime.parse(json['dateFin'] as String),
      nbBenevolesRequis: (json['nbBenevolesRequis'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'dateDebut': dateDebut.toIso8601String(),
        'dateFin': dateFin.toIso8601String(),
        'nbBenevolesRequis': nbBenevolesRequis,
      };

  Creneau copyWith({
    int? id,
    DateTime? dateDebut,
    DateTime? dateFin,
    int? nbBenevolesRequis,
  }) =>
      Creneau(
        id: id ?? this.id,
        dateDebut: dateDebut ?? this.dateDebut,
        dateFin: dateFin ?? this.dateFin,
        nbBenevolesRequis: nbBenevolesRequis ?? this.nbBenevolesRequis,
      );
}

class Poste {
  final int? id;
  final String titre;
  final String? description;
  final List<Creneau> creneaux;

  Poste({
    this.id,
    required this.titre,
    this.description,
    this.creneaux = const [],
  });

  factory Poste.fromJson(Map<String, dynamic> json) {
    final creneauxRaw = json['creneaux'];
    return Poste(
      id: json['id'] as int?,
      titre: json['titre'] as String,
      description: json['description'] as String?,
      creneaux: creneauxRaw is List
          ? (creneauxRaw)
              .map((c) => Creneau.fromJson(c as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'titre': titre,
        if (description != null && description!.isNotEmpty) 'description': description,
        'creneaux': creneaux.map((c) => c.toJson()).toList(),
      };
}
