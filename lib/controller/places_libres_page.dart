import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../api/inscription_service.dart';
import '../api/poste_service.dart';
import '../model/family_member.dart';
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
  List<FamilyMember> _famille = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPostes();
    _loadFamille();
  }

  Future<void> _loadFamille() async {
    try {
      final raw = await AuthService.getFamilyMembers(widget.user.id);
      if (!mounted) return;
      setState(() {
        _famille = raw.map((e) => FamilyMember.fromJson(e)).toList();
      });
    } catch (_) {
      if (mounted) setState(() => _famille = []);
    }
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

    List<int> targetUserIds = [widget.user.id];

    if (_famille.length > 1) {
      final selected = <int, bool>{
        for (final m in _famille) m.id: true,
      };
      final validated = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx2, setLocal) {
              return AlertDialog(
                title: const Text('Inscrire des membres'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _famille.map((m) {
                      return CheckboxListTile(
                        value: selected[m.id] ?? false,
                        onChanged: (v) {
                          setLocal(() => selected[m.id] = v ?? false);
                        },
                        title: Text(
                          m.displayName.isEmpty ? (m.email ?? 'Membre') : m.displayName,
                          style: const TextStyle(fontSize: 15),
                        ),
                        subtitle: m.isHead
                            ? const Text('Responsable', style: TextStyle(fontSize: 12))
                            : Text(
                                m.canLogin && (m.email?.isNotEmpty ?? false)
                                    ? m.email!
                                    : 'Compte géré par le titulaire',
                                style: const TextStyle(fontSize: 12),
                              ),
                        activeColor: Theme.of(context).colorScheme.primaryContainer,
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Valider'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (validated != true || !mounted) return;
      targetUserIds = selected.entries.where((e) => e.value).map((e) => e.key).toList();
      if (targetUserIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sélectionnez au moins un membre.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    try {
      await InscriptionService.inscrire(
        widget.user.id,
        c.id!,
        targetUserIds: targetUserIds,
      );
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
                      children: postesMap.entries.map((posteEntry) {
                        final poste = posteEntry.key;
                        final creneaux = posteEntry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            leading: Icon(
                              Icons.work_rounded,
                              color: Theme.of(context).colorScheme.primaryContainer,
                            ),
                            title: Text(
                              poste.titre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: creneaux.isNotEmpty
                                ? Text(
                                    '${creneaux.length} créneau${creneaux.length > 1 ? 'x' : ''}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                : null,
                            children: creneaux.map((c) => _buildCreneauCard(poste, c)).toList(),
                          ),
                        );
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

  String _formatDateShort(DateTime d) {
    const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const mois = ['janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
    return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';
  }

  Widget _buildCreneauCard(Poste poste, Creneau creneau) {
    final canClick = !creneau.complet && creneau.id != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: canClick ? () => _inscrire(creneau, poste) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _formatHoraire(creneau.dateDebut, creneau.dateFin),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (creneau.complet)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Complet',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Colors.red.shade700,
                      ),
                    ),
                  )
                else ...[
                  Text(
                    '${creneau.placesRestantes}/${creneau.nbBenevolesRequis} (${(creneau.placesRestantes / creneau.nbBenevolesRequis * 100).round()} %)',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _inscrire(creneau, poste),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: Text(_famille.length > 1 ? 'Inscrire…' : 'M\'inscrire'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
