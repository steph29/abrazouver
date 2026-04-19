import 'dart:math' show Random;

import 'package:flutter/material.dart';

import '../api/evenement_service.dart';
import '../theme/app_theme.dart';

const Map<String, String> kRetroStatutLabels = {
  'a_faire': 'À faire',
  'en_cours': 'En cours',
  'en_attente': 'En attente',
  'retarde': 'Retardé',
  'termine': 'Terminé',
};

Color retroStatutColor(String status, BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case 'termine':
      return scheme.tertiaryContainer;
    case 'en_cours':
      // Fond plus clair pour que le texte en primaryContainer reste lisible
      return Color.alphaBlend(
        scheme.primaryContainer.withValues(alpha: 0.22),
        scheme.surface,
      );
    case 'retarde':
      return const Color(0xFFFFE0B2);
    case 'en_attente':
      return const Color(0xFFE1BEE7);
    case 'a_faire':
    default:
      return scheme.surfaceContainerHighest;
  }
}

Color retroStatutOnColor(String status, BuildContext context) {
  switch (status) {
    case 'termine':
      return Theme.of(context).colorScheme.onTertiaryContainer;
    case 'en_cours':
      // Même couleur que la teinte « carte » (primaryContainer), pas le blanc onPrimary
      return Theme.of(context).colorScheme.primaryContainer;
    case 'retarde':
      return const Color(0xFFE65100);
    case 'en_attente':
      return const Color(0xFF6A1B9A);
    case 'a_faire':
    default:
      return AppColors.textPrimary;
  }
}

class RetroplanningEditor extends StatefulWidget {
  final int userId;
  final int eventId;
  final String eventName;
  final List<Map<String, dynamic>> initialItems;
  final VoidCallback onSaved;

  const RetroplanningEditor({
    super.key,
    required this.userId,
    required this.eventId,
    required this.eventName,
    required this.initialItems,
    required this.onSaved,
  });

  @override
  State<RetroplanningEditor> createState() => _RetroplanningEditorState();
}

class _RetroplanningEditorState extends State<RetroplanningEditor> {
  late List<Map<String, dynamic>> _items;
  final Map<String, TextEditingController> _labelCtrls = {};
  bool _saving = false;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems.map((e) => Map<String, dynamic>.from(e)).toList();
    if (_items.isEmpty) {
      _items.add(_blankItem());
    }
    for (final it in _items) {
      it['id'] ??= _newId();
      it['id'] = it['id'].toString();
      it['label'] = it['label']?.toString() ?? '';
      it['status'] = it['status']?.toString() ?? 'a_faire';
      it['done'] = it['done'] == true || it['status'] == 'termine';
      if (it['done'] == true) it['status'] = 'termine';
      final id = it['id'] as String;
      _labelCtrls[id] = TextEditingController(text: it['label'] as String);
    }
  }

  @override
  void dispose() {
    for (final c in _labelCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _newId() => 'rp_${DateTime.now().microsecondsSinceEpoch}_${_rnd.nextInt(99999)}';

  Map<String, dynamic> _blankItem() => {
        'id': _newId(),
        'label': '',
        'dueDate': null,
        'done': false,
        'status': 'a_faire',
      };

  void _addItem() {
    final it = _blankItem();
    final id = it['id']!.toString();
    setState(() {
      _items.add(it);
      _labelCtrls[id] = TextEditingController();
    });
  }

  void _removeAt(int index) {
    final id = _items[index]['id'].toString();
    setState(() {
      _labelCtrls[id]?.dispose();
      _labelCtrls.remove(id);
      _items.removeAt(index);
    });
  }

  Future<void> _pickDate(int index) async {
    final cur = _items[index]['dueDate'];
    DateTime initial = DateTime.now();
    if (cur != null && cur.toString().isNotEmpty) {
      initial = DateTime.tryParse(cur.toString()) ?? initial;
    }
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _items[index]['dueDate'] = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    final payload = <Map<String, dynamic>>[];
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      final id = it['id'] as String;
      final label = (_labelCtrls[id]?.text ?? '').trim();
      if (label.isEmpty) continue;
      payload.add({
        'id': id,
        'label': label,
        'dueDate': it['dueDate'],
        'done': it['done'] == true,
        'status': it['status'] ?? 'a_faire',
      });
    }
    setState(() => _saving = true);
    try {
      await EvenementService.update(
        widget.userId,
        widget.eventId,
        retroplanning: payload,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rétroplanning enregistré'), backgroundColor: AppColors.primary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException (400): ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Rétroplanning — ${widget.eventName}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enregistrer'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Date cible, statut coloré, case à cocher pour terminé.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final it = _items[i];
                final id = it['id'].toString();
                final status = (it['status'] ?? 'a_faire').toString();
                final bg = retroStatutColor(status, context);
                final fg = retroStatutOnColor(status, context);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: bg,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: it['done'] == true,
                              onChanged: (v) {
                                setState(() {
                                  it['done'] = v ?? false;
                                  if (it['done'] == true) {
                                    it['status'] = 'termine';
                                  } else if (it['status'] == 'termine') {
                                    it['status'] = 'a_faire';
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: TextField(
                                controller: _labelCtrls[id],
                                decoration: const InputDecoration(
                                  hintText: 'Libellé de l’action',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: TextStyle(color: fg, fontWeight: FontWeight.w500),
                                maxLines: 2,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: fg.withValues(alpha: 0.7)),
                              onPressed: () => _removeAt(i),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => _pickDate(i),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.event, size: 18, color: fg),
                                    const SizedBox(width: 6),
                                    Text(
                                      it['dueDate'] != null && it['dueDate'].toString().isNotEmpty
                                          ? _fmtDateFr(it['dueDate'].toString())
                                          : 'Date cible',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: fg,
                                        decoration: it['dueDate'] == null ? TextDecoration.underline : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DropdownButton<String>(
                              value: kRetroStatutLabels.containsKey(status) ? status : 'a_faire',
                              dropdownColor: theme.colorScheme.surface,
                              style: TextStyle(color: fg, fontSize: 13),
                              underline: const SizedBox.shrink(),
                              items: kRetroStatutLabels.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  it['status'] = v;
                                  it['done'] = v == 'termine';
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une action'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDateFr(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
