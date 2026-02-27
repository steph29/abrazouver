import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/preferences_service.dart';
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
    _loadPreferences();
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
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
    final ext = file.extension?.toLowerCase() ?? 'png';
    final mime = ext == 'jpg' || ext == 'jpeg' ? 'jpeg' : 'png';
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
