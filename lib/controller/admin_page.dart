import 'package:flutter/material.dart';

import '../api/poste_service.dart';
import '../model/poste.dart';
import '../theme/app_theme.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _titreController = TextEditingController();
  final _descController = TextEditingController();

  List<_CreneauForm> _creneaux = [];
  List<Poste> _postes = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  int? _editingPosteId;

  @override
  void initState() {
    super.initState();
    _loadPostes();
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descController.dispose();
    super.dispose();
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

  void _startEdit(Poste p) {
    _editingPosteId = p.id;
    _titreController.text = p.titre;
    _descController.text = p.description ?? '';
    setState(() {
      _creneaux = p.creneaux
          .map((c) => _CreneauForm(
                debut: c.dateDebut,
                fin: c.dateFin,
                nbBenevoles: c.nbBenevolesRequis,
              ))
          .toList();
    });
  }

  void _cancelEdit() {
    _editingPosteId = null;
    _titreController.clear();
    _descController.clear();
    setState(() => _creneaux = []);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_creneaux.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez au moins un créneau'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    for (final c in _creneaux) {
      if (c.debut == null || c.fin == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Renseignez tous les créneaux'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (c.fin!.isBefore(c.debut!) || c.fin!.isAtSameMomentAs(c.debut!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Créneau : la fin doit être après le début (${_creneaux.indexOf(c) + 1})'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (c.nbBenevoles < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Au moins 1 bénévole par créneau'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'titre': _titreController.text.trim(),
        'description': _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        'creneaux': _creneaux
            .map((c) => {
                  'dateDebut': _formatDateTimeForApi(c.debut!),
                  'dateFin': _formatDateTimeForApi(c.fin!),
                  'nbBenevolesRequis': c.nbBenevoles,
                })
            .toList(),
      };
      if (_editingPosteId != null) {
        await PosteService.updatePoste(_editingPosteId!, payload);
      } else {
        await PosteService.createPoste(payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingPosteId != null
              ? 'Poste mis à jour'
              : 'Poste créé avec succès'),
          backgroundColor: AppColors.primary,
        ),
      );
      _cancelEdit();
      setState(() => _saving = false);
      _loadPostes();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Erreur : ${e.toString().replaceAll('ApiException (400): ', '').replaceAll('ApiException (500): ', '')}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _deletePoste(Poste p) async {
    if (p.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce poste ?'),
        content: Text(
            '« ${p.titre } » et ses ${p.creneaux.length} créneau(x) seront supprimés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PosteService.deletePoste(p.id!);
      if (!mounted) return;
      _loadPostes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Poste supprimé'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _pickDateTime(
    BuildContext ctx,
    DateTime? initial,
    void Function(DateTime) onSelected,
  ) async {
    final date = await showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !ctx.mounted) return;
    final time = await showTimePicker(
      context: ctx,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : const TimeOfDay(hour: 12, minute: 0),
    );
    if (time == null || !ctx.mounted) return;
    onSelected(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Postes de bénévolat',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _editingPosteId != null
                                ? 'Modifier le poste'
                                : 'Créer un poste',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (_editingPosteId != null)
                            TextButton.icon(
                              onPressed: _saving ? null : _cancelEdit,
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Annuler'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titreController,
                        decoration: const InputDecoration(
                          labelText: 'Titre',
                          hintText: 'Ex: Buvette',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Titre requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Description du poste...',
                          prefixIcon: Icon(Icons.description_rounded),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Créneaux',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _creneaux.add(_CreneauForm(
                                  debut: null,
                                  fin: null,
                                  nbBenevoles: 1,
                                ));
                              });
                            },
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_creneaux.length, (i) {
                        final c = _creneaux[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: AppColors.background,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Créneau ${i + 1}',
                                      style:
                                          Theme.of(context).textTheme.titleSmall,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () {
                                        setState(() => _creneaux.removeAt(i));
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ListTile(
                                        title: Text(
                                          c.debut == null
                                              ? 'Début'
                                              : _formatDateTime(c.debut!),
                                          style: TextStyle(
                                            color: c.debut == null
                                                ? AppColors.textSecondary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        leading: const Icon(Icons.schedule),
                                        onTap: () => _pickDateTime(
                                          context,
                                          c.debut,
                                          (d) {
                                            setState(() {
                                              _creneaux[i] = c.copyWith(
                                                debut: d,
                                                fin: c.fin != null &&
                                                        c.fin!.isBefore(d)
                                                    ? d.add(const Duration(
                                                        hours: 1))
                                                    : c.fin,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListTile(
                                        title: Text(
                                          c.fin == null
                                              ? 'Fin'
                                              : _formatDateTime(c.fin!),
                                          style: TextStyle(
                                            color: c.fin == null
                                                ? AppColors.textSecondary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        leading: const Icon(Icons.schedule),
                                        onTap: () => _pickDateTime(
                                          context,
                                          c.fin ?? c.debut,
                                          (d) {
                                            setState(() {
                                              _creneaux[i] =
                                                  c.copyWith(fin: d);
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.people_outline),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Bénévoles : ',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: DropdownButtonFormField<int>(
                                          value: c.nbBenevoles.clamp(1, 20),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets
                                                .symmetric(
                                                    horizontal: 8,
                                                    vertical: 8),
                                          ),
                                          items: List.generate(
                                            20,
                                            (j) => DropdownMenuItem(
                                              value: j + 1,
                                              child: Text('${j + 1}'),
                                            ),
                                          ),
                                          onChanged: (n) {
                                            if (n != null) {
                                              setState(() {
                                                _creneaux[i] =
                                                    c.copyWith(nbBenevoles: n);
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (_creneaux.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Ajoutez un créneau pour définir les horaires.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_editingPosteId != null
                                ? 'Mettre à jour'
                                : 'Créer le poste'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Postes existants',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                ),
              )
            else if (_postes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucun poste pour le moment.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ..._postes.map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        p.titre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        p.description?.isNotEmpty == true
                            ? p.description!
                            : '${p.creneaux.length} créneau(x)',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _startEdit(p),
                            tooltip: 'Modifier',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deletePoste(p),
                            tooltip: 'Supprimer',
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  /// Format pour l'API MySQL : YYYY-MM-DD HH:mm:ss (évite tout problème de locale)
  String _formatDateTimeForApi(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _CreneauForm {
  final DateTime? debut;
  final DateTime? fin;
  final int nbBenevoles;

  _CreneauForm({
    this.debut,
    this.fin,
    this.nbBenevoles = 1,
  });

  _CreneauForm copyWith({
    DateTime? debut,
    DateTime? fin,
    int? nbBenevoles,
  }) =>
      _CreneauForm(
        debut: debut ?? this.debut,
        fin: fin ?? this.fin,
        nbBenevoles: nbBenevoles ?? this.nbBenevoles,
      );
}
