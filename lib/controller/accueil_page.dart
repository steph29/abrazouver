import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../api/preferences_service.dart';
import '../theme/app_theme.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  bool _loading = true;
  String? _error;
  String _titre = '';
  String _description = '';

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await PreferencesService.get();
      setState(() {
        _titre = (prefs['accueilTitre'] as String?)?.trim() ?? '';
        _description = (prefs['accueilDescription'] as String?) ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
                onPressed: _loadContent,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final hasContent = _titre.isNotEmpty || _description.trim().isNotEmpty;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadContent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasContent) ...[
                if (_titre.isNotEmpty)
                  Text(
                    _titre,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (_titre.isNotEmpty && _description.trim().isNotEmpty)
                  const SizedBox(height: 16),
                if (_description.trim().isNotEmpty)
                  Html(
                    data: _description.trim(),
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(16),
                        color: theme.colorScheme.onSurface,
                      ),
                      'p': Style(
                        margin: Margins.only(bottom: 12),
                      ),
                    },
                  ),
              ] else
                Text(
                  'Accueil',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
