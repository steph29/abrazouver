import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/preferences_service.dart';
import '../utils/logo_picker.dart';
import '../model/user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

class PreferencesPage extends StatefulWidget {
  final User user;

  const PreferencesPage({super.key, required this.user});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  late TextEditingController _primaryController;
  late TextEditingController _secondaryController;
  late TextEditingController _contactEmailController;
  late TextEditingController _accueilTitreController;
  late TextEditingController _accueilDescriptionController;
  String? _logoDataUri;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  static const int _maxLogoBytes = 2 * 1024 * 1024; // 2 Mo

  @override
  void initState() {
    super.initState();
    _primaryController = TextEditingController(text: '#4CAF50');
    _secondaryController = TextEditingController(text: '#2b5a72');
    _contactEmailController = TextEditingController();
    _accueilTitreController = TextEditingController();
    _accueilDescriptionController = TextEditingController();
    _loadPreferences();
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await PreferencesService.get();
      setState(() {
        _primaryController.text = (prefs['primaryColor'] as String?) ?? '#4CAF50';
        _secondaryController.text = (prefs['secondaryColor'] as String?) ?? '#2b5a72';
        _contactEmailController.text = (prefs['contactEmail'] as String?) ?? '';
        _accueilTitreController.text = (prefs['accueilTitre'] as String?) ?? '';
        _accueilDescriptionController.text = (prefs['accueilDescription'] as String?) ?? '';
        _logoDataUri = prefs['logo'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('ApiException (500): ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    final bytes = await pickImageBytes(maxBytes: _maxLogoBytes);
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire le fichier. Essayez un autre format.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (bytes.length > _maxLogoBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fichier trop volumineux (${(bytes.length / 1024).round()} Ko). Max : 2 Mo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final mime = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8 ? 'jpeg' : 'png';
    final base64 = base64Encode(bytes);
    setState(() => _logoDataUri = 'data:image/$mime;base64,$base64');
  }

  void _removeLogo() {
    setState(() => _logoDataUri = null);
  }

  bool _isValidHex(String? s) {
    if (s == null || s.isEmpty) return false;
    return RegExp(r'^#?[0-9A-Fa-f]{6}$').hasMatch(s.trim());
  }

  Future<void> _save() async {
    final primary = _primaryController.text.trim();
    final secondary = _secondaryController.text.trim();
    if (!_isValidHex(primary)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couleur principale invalide (format: #RRGGBB)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_isValidHex(secondary)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couleur secondaire invalide (format: #RRGGBB)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final prefs = await PreferencesService.update(
        widget.user.id,
        primaryColor: primary.startsWith('#') ? primary : '#$primary',
        secondaryColor: secondary.startsWith('#') ? secondary : '#$secondary',
        logo: _logoDataUri,
        removeLogo: _logoDataUri == null,
        contactEmail: _contactEmailController.text.trim(),
        accueilTitre: _accueilTitreController.text.trim(),
        accueilDescription: _accueilDescriptionController.text,
      );
      if (!mounted) return;

      final primaryColor = colorFromHex(prefs['primaryColor'] as String? ?? primary);
      final secondaryColor = colorFromHex(prefs['secondaryColor'] as String? ?? secondary);
      final newTheme = AppTheme.buildTheme(primaryColor, secondaryColor);

      final scope = AppThemeScope.maybeOf(context);
      scope?.updateTheme(newTheme);
      scope?.updateLogo(prefs['logo'] as String?);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Préférences enregistrées'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('ApiException (403): ', '').replaceAll('ApiException (400): ', ''),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logo de l\'association',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Format : JPG ou PNG uniquement. Taille max : 2 Mo. Affiché en haut à gauche dans l\'application.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_logoDataUri != null) ...[
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageFromDataUri(_logoDataUri, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
            ],
            FilledButton.tonalIcon(
              onPressed: _pickLogo,
              icon: Icon(_logoDataUri != null ? Icons.refresh_rounded : Icons.upload_file_rounded),
              label: Text(_logoDataUri != null ? 'Remplacer le logo' : 'Choisir un logo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            if (_logoDataUri != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: _removeLogo,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Supprimer le logo',
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ],
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
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadPreferences,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Personnalisation du thème',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Ces couleurs s\'appliquent à toute l\'application pour tous les utilisateurs.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildColorField(
              label: 'Couleur principale',
              controller: _primaryController,
              hint: '#4CAF50',
            ),
            const SizedBox(height: 16),
            _buildColorField(
              label: 'Couleur secondaire',
              controller: _secondaryController,
              hint: '#2b5a72',
            ),
            const SizedBox(height: 24),
            _buildLogoSection(),
            const SizedBox(height: 24),
            _buildContactEmailSection(),
            const SizedBox(height: 24),
            _buildAccueilSection(),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _wrapSelection(String openTag, String closeTag) {
    final c = _accueilDescriptionController;
    final sel = c.selection;
    if (!sel.isValid || sel.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez du texte à formater')),
      );
      return;
    }
    final start = sel.start;
    final end = sel.end;
    final selected = c.text.substring(start, end);
    final wrapped = '$openTag$selected$closeTag';
    c.text = c.text.substring(0, start) + wrapped + c.text.substring(end);
    c.selection = TextSelection(baseOffset: start, extentOffset: start + wrapped.length);
    setState(() {});
  }

  /// Retire les balises <span style="color:..."> existantes pour éviter l'imbrication
  String _stripColorSpans(String text) {
    String s = text;
    while (true) {
      final m = RegExp(r'^<span\s+style="color:\s*[^"]*">([\s\S]*?)</span>$')
          .firstMatch(s);
      if (m == null) break;
      s = m.group(1)!;
    }
    return s;
  }

  void _wrapSelectionWithColor(Color color) {
    final c = _accueilDescriptionController;
    final sel = c.selection;
    if (!sel.isValid || sel.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez du texte à formater')),
      );
      return;
    }
    final start = sel.start;
    final end = sel.end;
    final selected = c.text.substring(start, end);
    final stripped = _stripColorSpans(selected);
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    final wrapped = '<span style="color:$hex">$stripped</span>';
    c.text = c.text.substring(0, start) + wrapped + c.text.substring(end);
    c.selection = TextSelection(baseOffset: start, extentOffset: start + wrapped.length);
    setState(() {});
  }

  static const _presetColors = [
    (Colors.black, 'Noir'),
    (Color(0xFFE53935), 'Rouge'),
    (Color(0xFF1E88E5), 'Bleu'),
    (Color(0xFF43A047), 'Vert'),
    (Color(0xFFFB8C00), 'Orange'),
  ];

  Widget _buildAccueilSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Modifier la page Accueil',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Titre et description affichés sur la page d\'accueil. Utilisez les boutons pour formater la description (gras, italique, couleurs, alignement).',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _accueilTitreController,
          decoration: const InputDecoration(
            labelText: 'Titre',
            hintText: 'Bienvenue',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Description (texte formaté)',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                  IconButton.filledTonal(
                    onPressed: () => _wrapSelection('<b>', '</b>'),
                    icon: const Icon(Icons.format_bold_rounded),
                    tooltip: 'Gras',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _wrapSelection('<i>', '</i>'),
                    icon: const Icon(Icons.format_italic_rounded),
                    tooltip: 'Italique',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _wrapSelection('<u>', '</u>'),
                    icon: const Icon(Icons.format_underlined_rounded),
                    tooltip: 'Souligné',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _wrapSelection('<div style="text-align: left">', '</div>'),
                    icon: const Icon(Icons.format_align_left_rounded),
                    tooltip: 'Aligner à gauche',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _wrapSelection('<div style="text-align: center">', '</div>'),
                    icon: const Icon(Icons.format_align_center_rounded),
                    tooltip: 'Centrer',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _wrapSelection('<div style="text-align: right">', '</div>'),
                    icon: const Icon(Icons.format_align_right_rounded),
                    tooltip: 'Aligner à droite',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  ..._presetColors.map((e) => Tooltip(
                    message: e.$2,
                    child: InkWell(
                      onTap: () => _wrapSelectionWithColor(e.$1),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: e.$1,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  )),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              TextFormField(
                controller: _accueilDescriptionController,
                decoration: const InputDecoration(
                  hintText: 'Saisissez la description, sélectionnez du texte puis utilisez les boutons ci-dessus pour le formater.',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
                maxLines: 6,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactEmailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email de contact (destinataire des messages)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Les messages envoyés depuis la page Contact seront adressés à cette adresse.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _contactEmailController,
          decoration: const InputDecoration(
            hintText: 'admin@exemple.org',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildColorField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: () {
                  try {
                    return colorFromHex(controller.text);
                  } catch (_) {
                    return Colors.grey;
                  }
                }(),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
