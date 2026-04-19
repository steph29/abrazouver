import 'package:flutter/material.dart';

import '../api/evenement_service.dart';
import '../model/user.dart';
import 'retroplanning_editor.dart';

class EvenementsPage extends StatefulWidget {
  final User user;

  const EvenementsPage({super.key, required this.user});

  @override
  State<EvenementsPage> createState() => _EvenementsPageState();
}

class _EvenementsPageState extends State<EvenementsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _evenements = [];
  int? _currentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await EvenementService.listAdmin(widget.user.id);
      final list = (r['evenements'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final cur = r['currentEvenementId'];
      setState(() {
        _evenements = list;
        _currentId = cur is int ? cur : int.tryParse(cur?.toString() ?? '');
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('ApiException (500): ', '');
        _loading = false;
      });
    }
  }

  DateTime? _parse(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  Future<void> _activate(int id) async {
    try {
      await EvenementService.activate(widget.user.id, id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Événement activé — l’app et les préférences utilisent cet événement.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException (400): ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> ev) async {
    final id = (ev['id'] as num?)?.toInt();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l’événement ?'),
        content: Text('« ${ev['nom'] ?? ''} » sera supprimé définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await EvenementService.delete(widget.user.id, id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Événement supprimé')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException (400): ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nomCtrl = TextEditingController(text: existing?['nom']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description']?.toString() ?? '');
    final anneeCtrl = TextEditingController(text: existing?['annee']?.toString() ?? '${DateTime.now().year}');
    final deb = _parse(existing?['dateDebut']) ?? DateTime.now();
    final fin = _parse(existing?['dateFin']) ?? DateTime.now().add(const Duration(days: 1));
    DateTime dateDebut = deb;
    DateTime dateFin = fin;
    final rawNotes = existing?['notes'];
    final notesLines = <String>[];
    if (rawNotes is List) {
      for (final n in rawNotes) {
        notesLines.add(n.toString());
      }
    }
    final notesCtrl = TextEditingController(text: notesLines.join('\n'));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(isEdit ? 'Modifier l’événement' : 'Nouvel événement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: anneeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date de début'),
                  subtitle: Text(_fmtDate(dateDebut)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: dateDebut,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setLocal(() => dateDebut = DateTime(d.year, d.month, d.day, dateDebut.hour, dateDebut.minute));
                  },
                ),
                ListTile(
                  title: const Text('Date de fin'),
                  subtitle: Text(_fmtDate(dateFin)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: dateFin,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setLocal(() => dateFin = DateTime(d.year, d.month, d.day, dateFin.hour, dateFin.minute));
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Notes / à faire (une ligne par point)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;

    final nom = nomCtrl.text.trim();
    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom est requis'), backgroundColor: Colors.red),
      );
      return;
    }
    final annee = int.tryParse(anneeCtrl.text.trim());
    final filteredNotes = notesCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      if (isEdit) {
        final id = (existing['id'] as num).toInt();
        await EvenementService.update(
          widget.user.id,
          id,
          nom: nom,
          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          dateDebut: dateDebut,
          dateFin: dateFin,
          annee: annee,
          notes: filteredNotes,
        );
      } else {
        await EvenementService.create(
          widget.user.id,
          nom: nom,
          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          dateDebut: dateDebut,
          dateFin: dateFin,
          annee: annee,
          notes: filteredNotes,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Événement mis à jour' : 'Événement créé')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException (400): ', '')), backgroundColor: Colors.red),
      );
    }
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  int? _avancementPct(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.round().clamp(0, 100);
    return int.tryParse(v.toString())?.clamp(0, 100);
  }

  void _openRetroplanning(Map<String, dynamic> ev) {
    final id = (ev['id'] as num).toInt();
    final raw = ev['retroplanning'];
    final list = raw is List
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RetroplanningEditor(
          userId: widget.user.id,
          eventId: id,
          eventName: ev['nom']?.toString() ?? '',
          initialItems: list,
          onSaved: _load,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Événements'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel événement'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _evenements.length,
                  itemBuilder: (context, i) {
                    final ev = _evenements[i];
                    final id = (ev['id'] as num?)?.toInt();
                    final isCurrent = id != null && id == _currentId;
                    final avancementPct = _avancementPct(ev['avancementPct']);
                    final notes = (ev['notes'] as List?) ?? [];
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
                                  child: Text(
                                    ev['nom']?.toString() ?? '',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (avancementPct != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Chip(
                                          label: Text(
                                            '$avancementPct %',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          width: 72,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: avancementPct / 100.0,
                                              minHeight: 6,
                                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (isCurrent)
                                  Chip(
                                    label: const Text('En cours'),
                                    backgroundColor: theme.colorScheme.primaryContainer,
                                  ),
                              ],
                            ),
                            if ((ev['description'] as String?)?.trim().isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(ev['description'].toString(), style: theme.textTheme.bodyMedium),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Du ${_fmtDate(_parse(ev['dateDebut']) ?? DateTime.now())} au ${_fmtDate(_parse(ev['dateFin']) ?? DateTime.now())} — année ${ev['annee'] ?? ''}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text('À faire', style: theme.textTheme.titleSmall),
                              const SizedBox(height: 4),
                              ...notes.map(
                                (n) => Padding(
                                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• '),
                                      Expanded(child: Text(n.toString())),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (!isCurrent && id != null)
                                  FilledButton.tonal(
                                    onPressed: () => _activate(id),
                                    child: const Text('Activer'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => _openRetroplanning(ev),
                                  icon: const Icon(Icons.calendar_view_month, size: 18),
                                  label: const Text('Rétroplanning'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _openEditor(existing: ev),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Modifier'),
                                ),
                                if (id != null && !isCurrent)
                                  TextButton.icon(
                                    onPressed: () => _delete(ev),
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    label: const Text('Supprimer'),
                                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
