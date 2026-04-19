import 'package:flutter/material.dart';

import '../api/inscription_service.dart';
import '../model/inscription_detail.dart';
import '../model/user.dart';
import '../theme/app_theme.dart';

class _MemberBucket {
  final int userId;
  final String label;
  final List<InscriptionDetail> inscriptions;

  _MemberBucket({
    required this.userId,
    required this.label,
    required this.inscriptions,
  });
}

class MesPostesPage extends StatefulWidget {
  final User user;

  const MesPostesPage({super.key, required this.user});

  @override
  State<MesPostesPage> createState() => _MesPostesPageState();
}

class _MesPostesPageState extends State<MesPostesPage> {
  List<_MemberBucket> _members = [];
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
      final r = await InscriptionService.getMesInscriptionsFamily(widget.user.id);
      final raw = r['members'] as List?;
      final list = <_MemberBucket>[];
      for (final m in raw ?? []) {
        final map = m as Map<String, dynamic>;
        final uid = (map['userId'] as num).toInt();
        final prenom = map['prenom'] as String? ?? '';
        final nom = map['nom'] as String? ?? '';
        final label = '$prenom $nom'.trim().isEmpty ? 'Membre $uid' : '$prenom $nom'.trim();
        final insList = (map['inscriptions'] as List?)
                ?.map((e) => InscriptionDetail.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <InscriptionDetail>[];
        list.add(_MemberBucket(userId: uid, label: label, inscriptions: insList));
      }
      setState(() {
        _members = list;
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
  Map<DateTime, Map<PosteResume, List<InscriptionDetail>>> _groupByDay(List<InscriptionDetail> items) {
    final Map<DateTime, Map<PosteResume, List<InscriptionDetail>>> byDay = {};
    for (final ins in items) {
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
      final bool headCancelsOther =
          widget.user.isFamilyHead && ins.userId != 0 && ins.userId != widget.user.id;
      await InscriptionService.desinscrire(
        widget.user.id,
        ins.creneauId,
        targetUserId: headCancelsOther ? ins.userId : null,
      );
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

  Widget _buildDayTabsForList(List<InscriptionDetail> inscriptions) {
    final grouped = _groupByDay(inscriptions);
    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucune inscription pour ce membre.\n\nAllez sur « Places libres » pour inscrire.',
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
                      final list = posteEntry.value;
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
                          subtitle: list.isNotEmpty
                              ? Text(
                                  '${list.length} inscription${list.length > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : null,
                          children: list.map((ins) => _buildCreneauCard(poste, ins)).toList(),
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
    );
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

    if (_members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucune donnée.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_members.length == 1) {
      final ins = _members.first.inscriptions;
      if (ins.isEmpty) {
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
      return SafeArea(child: _buildDayTabsForList(ins));
    }

    return SafeArea(
      child: DefaultTabController(
        length: _members.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Theme.of(context).colorScheme.primaryContainer,
                labelColor: Theme.of(context).colorScheme.primaryContainer,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: _members.map((m) => Tab(text: m.label)).toList(),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: _members.map((m) => _buildDayTabsForList(m.inscriptions)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreneauCard(PosteResume poste, InscriptionDetail ins) {
    final c = ins.creneau;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatHoraire(c.dateDebut, c.dateFin),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
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
        ),
      ),
    );
  }
}
