import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/analyse_service.dart';
import '../model/user.dart';
import '../theme/app_theme.dart';

class RappelsTab extends StatefulWidget {
  final User user;

  const RappelsTab({super.key, required this.user});

  @override
  State<RappelsTab> createState() => _RappelsTabState();
}

class _RappelsTabState extends State<RappelsTab> {
  List<Map<String, dynamic>> _benevoles = [];
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  String _search = '';
  Set<int> _selectedIds = {};
  bool _sendToAll = false;
  String? _selectedTemplateId;
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _attachmentName;
  String? _attachmentBase64;

  void _clearAttachment() {
    setState(() {
      _attachmentName = null;
      _attachmentBase64 = null;
    });
  }
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final [benevoles, templates] = await Future.wait([
        AnalyseService.getRappelsBenevoles(widget.user.id),
        AnalyseService.getRappelsTemplates(widget.user.id),
      ]);
      if (mounted) {
        setState(() {
          _benevoles = benevoles;
          _templates = templates;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _benevoles = [];
          _templates = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString().replaceAll('ApiException ', '')}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBenevoles {
    if (_search.trim().isEmpty) return _benevoles;
    final words = _search.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return _benevoles.where((b) {
      final nom = ((b['nom'] as String?) ?? '').toLowerCase();
      final prenom = ((b['prenom'] as String?) ?? '').toLowerCase();
      for (final w in words) {
        if (nom.contains(w) || prenom.contains(w)) continue;
        return false;
      }
      return true;
    }).toList();
  }

  void _applyTemplate(String? id) {
    if (id == null) return;
    try {
      final t = _templates.firstWhere((x) => (x['id'] as String?) == id);
      _subjectController.text = t['subject'] as String? ?? '';
      _bodyController.text = t['bodyTemplate'] as String? ?? '';
    } catch (_) {}
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false, type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    setState(() {
      _attachmentName = file.name;
      _attachmentBase64 = base64Encode(file.bytes!);
    });
  }

  Future<void> _send() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Objet requis'), backgroundColor: Colors.red),
      );
      return;
    }
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corps du mail requis'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!_sendToAll && _selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez des destinataires ou « Envoyer à tous »'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await AnalyseService.sendRappels(
        widget.user.id,
        subject: subject,
        body: body,
        recipientIds: _sendToAll ? null : _selectedIds.toList(),
        sendToAll: _sendToAll,
        templateId: _selectedTemplateId,
        attachmentName: _attachmentName,
        attachmentBase64: _attachmentBase64,
      );
      if (!mounted) return;
      final msg = result['message'] as String? ?? '${result['sent']} email(s) envoyé(s)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryColor = theme.colorScheme.primaryContainer;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Destinataires', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _sendToAll,
                    onChanged: (v) => setState(() => _sendToAll = v ?? false),
                    title: const Text('Envoyer à tous'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (!_sendToAll) ...[
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom ou prénom...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => setState(() => _search = v.trim()),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _filteredBenevoles.length,
                        itemBuilder: (_, i) {
                          final b = _filteredBenevoles[i];
                          final id = (b['id'] as num?)?.toInt() ?? 0;
                          final selected = _selectedIds.contains(id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) _selectedIds.add(id);
                                else _selectedIds.remove(id);
                              });
                            },
                            title: Text('${b['prenom'] ?? ''} ${b['nom'] ?? ''}'.trim()),
                            subtitle: Text(b['email']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                    if (_filteredBenevoles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _search.isEmpty ? 'Aucun bénévole' : 'Aucun résultat',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Template', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedTemplateId,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Choisir un template'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Aucun (personnalisé)')),
                      ..._templates.map((t) => DropdownMenuItem(
                            value: t['id'] as String?,
                            child: Text(t['nom'] as String? ?? ''),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedTemplateId = v;
                        _applyTemplate(v);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Objet',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bodyController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Corps du mail',
                      hintText: 'Placeholders: {{prenom}}, {{nom}}, {{creneaux}}',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickAttachment,
                        icon: const Icon(Icons.attach_file),
                        label: Text(_attachmentName ?? 'Pièce jointe'),
                      ),
                      if (_attachmentName != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _clearAttachment,
                          icon: const Icon(Icons.close),
                          tooltip: 'Supprimer la pièce jointe',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(_sending ? 'Envoi...' : 'Envoyer'),
            style: FilledButton.styleFrom(
              backgroundColor: secondaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
