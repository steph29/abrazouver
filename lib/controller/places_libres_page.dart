import 'package:flutter/material.dart';

import '../api/inscription_service.dart';
import '../api/poste_service.dart';
import '../model/poste.dart';
import '../model/user.dart';
import '../theme/app_theme.dart';

class PlacesLibresPage extends StatefulWidget {
  final User user;

  const PlacesLibresPage({super.key, required this.user});

  @override
  State<PlacesLibresPage> createState() => _PlacesLibresPageState();
}

class _PlacesLibresPageState extends State<PlacesLibresPage> {
  List<Poste> _postes = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPostes();
  }

  Future<void> _loadPostes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await PosteService.getPostes();
      final data = r['data'] as List?;
      setState(() {
        _postes = (data ?? [])
            .map((e) => Poste.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('ApiException (500): ', '');
        _loading = false;
      });
    }
  }

  /// Groupe les créneaux par jour, puis par poste (alphabétique), puis par horaire
  Map<DateTime, Map<Poste, List<Creneau>>> _groupByDay() {
    final Map<DateTime, Map<Poste, List<Creneau>>> byDay = {};
    for (final poste in _postes) {
      for (final c in poste.creneaux) {
        final day = DateTime(
          c.dateDebut.year,
          c.dateDebut.month,
          c.dateDebut.day,
        );
        byDay.putIfAbsent(day, () => {});
        final dayMap = byDay[day]!;
        dayMap.putIfAbsent(poste, () => []);
        dayMap[poste]!.add(c);
      }
    }
    for (final dayMap in byDay.values) {
      for (final creneaux in dayMap.values) {
        creneaux.sort((a, b) => a.dateDebut.compareTo(b.dateDebut));
      }
    }
    final sortedDays = byDay.keys.toList()..sort();
    final result = <DateTime, Map<Poste, List<Creneau>>>{};
    for (final d in sortedDays) {
      final postesForDay = byDay[d]!;
      final sortedPostes = postesForDay.keys.toList()
        ..sort((a, b) => a.titre.compareTo(b.titre));
      result[d] = {for (final p in sortedPostes) p: postesForDay[p]!};
    }
    return result;
  }

  Future<void> _inscrire(Creneau c, Poste p) async {
    if (c.complet || c.id == null) return;
    try {
      await InscriptionService.inscrire(widget.user.id, c.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inscription enregistrée'),
          backgroundColor: AppColors.primary,
        ),
      );
      _loadPostes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('ApiException (400): ', '').replaceAll('ApiException (409): ', ''),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _formatHoraire(DateTime deb, DateTime fin) {
    return '${deb.hour.toString().padLeft(2, '0')}:${deb.minute.toString().padLeft(2, '0')} - '
        '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final grouped = _groupByDay();
    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucun créneau disponible pour le moment.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final days = grouped.keys.toList();
    return DefaultTabController(
      length: days.length,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 46,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Theme.of(context).colorScheme.primaryContainer,
                labelColor: Theme.of(context).colorScheme.primaryContainer,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: days.map((d) => Tab(text: _formatDateShort(d))).toList(),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: days.map((day) {
                  final postesMap = grouped[day]!;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: postesMap.entries.expand((posteEntry) {
                        final poste = posteEntry.key;
                        final creneaux = posteEntry.value;
                        return creneaux.map((c) => _buildCreneauCard(poste, c));
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Label court pour les onglets (ex: "Lun 27 janv")
  String _formatDateShort(DateTime d) {
    const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const mois = ['janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
    return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';
  }

  Widget _buildCreneauCard(Poste poste, Creneau creneau) {
    final canClick = !creneau.complet && creneau.id != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: canClick ? () => _inscrire(creneau, poste) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poste.titre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (poste.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            poste.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              _formatHoraire(creneau.dateDebut, creneau.dateFin),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (creneau.complet)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'COMPLET',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${creneau.placesRestantes}/${creneau.nbBenevolesRequis}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              if (canClick) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _inscrire(creneau, poste),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('M\'inscrire'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
