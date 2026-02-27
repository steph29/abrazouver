import 'package:flutter/material.dart';

import '../api/inscription_service.dart';
import '../model/inscription_detail.dart';
import '../model/user.dart';
import '../theme/app_theme.dart';

class MesPostesPage extends StatefulWidget {
  final User user;

  const MesPostesPage({super.key, required this.user});

  @override
  State<MesPostesPage> createState() => _MesPostesPageState();
}

class _MesPostesPageState extends State<MesPostesPage> {
  List<InscriptionDetail> _inscriptions = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInscriptions();
  }

  Future<void> _loadInscriptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await InscriptionService.getMesInscriptions(widget.user.id);
      final data = r['data'] as List?;
      setState(() {
        _inscriptions = (data ?? [])
            .map((e) => InscriptionDetail.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('ApiException (500): ', '').replaceAll('ApiException (401): ', '');
        _loading = false;
      });
    }
  }

  /// Groupe par jour, puis par poste (alphabétique), puis par horaire
  Map<DateTime, Map<PosteResume, List<InscriptionDetail>>> _groupByDay() {
    final Map<DateTime, Map<PosteResume, List<InscriptionDetail>>> byDay = {};
    for (final ins in _inscriptions) {
      final day = DateTime(
        ins.creneau.dateDebut.year,
        ins.creneau.dateDebut.month,
        ins.creneau.dateDebut.day,
      );
      byDay.putIfAbsent(day, () => {});
      final dayMap = byDay[day]!;
      dayMap.putIfAbsent(ins.poste, () => []);
      dayMap[ins.poste]!.add(ins);
    }
    for (final dayMap in byDay.values) {
      for (final list in dayMap.values) {
        list.sort((a, b) => a.creneau.dateDebut.compareTo(b.creneau.dateDebut));
      }
    }
    final sortedDays = byDay.keys.toList()..sort();
    final result = <DateTime, Map<PosteResume, List<InscriptionDetail>>>{};
    for (final d in sortedDays) {
      final postesForDay = byDay[d]!;
      final sortedPostes = postesForDay.keys.toList()
        ..sort((a, b) => a.titre.compareTo(b.titre));
      result[d] = {for (final p in sortedPostes) p: postesForDay[p]!};
    }
    return result;
  }

  Future<void> _annuler(InscriptionDetail ins) async {
    try {
      await InscriptionService.desinscrire(widget.user.id, ins.creneauId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inscription annulée'),
          backgroundColor: AppColors.primary,
        ),
      );
      _loadInscriptions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('ApiException (400): ', '').replaceAll('ApiException (404): ', ''),
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

  String _formatDateShort(DateTime d) {
    const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const mois = ['janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
    return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';
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
            'Vous n\'êtes inscrit à aucun créneau.\n\nAllez sur « Places libres » pour vous inscrire.',
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
                indicatorColor: AppColors.primaryDark,
                labelColor: AppColors.primaryDark,
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
                        final inscriptions = posteEntry.value;
                        return inscriptions.map((ins) => _buildCreneauCard(poste, ins));
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

  Widget _buildCreneauCard(PosteResume poste, InscriptionDetail ins) {
    final c = ins.creneau;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                            _formatHoraire(c.dateDebut, c.dateFin),
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
                FilledButton.tonalIcon(
                  onPressed: () => _annuler(ins),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Annuler'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
