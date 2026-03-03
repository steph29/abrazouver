import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../api/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  final String token;
  final void Function(ThemeData theme) onThemeReady;

  const ResetPasswordPage({super.key, required this.token, required this.onThemeReady});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _success = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.resetPassword(widget.token, _passwordController.text);
      if (!mounted) return;
      setState(() {
        _success = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException (400): ', '').replaceAll('ApiException (500): ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted && !_success) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _success ? _buildSuccessContent() : _buildFormContent(),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          Icon(Icons.lock_reset_rounded, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            'Nouveau mot de passe',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Choisissez un nouveau mot de passe (au moins 6 caractères)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Mot de passe requis';
              if (v.length < 6) return 'Au moins 6 caractères';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirmation requise';
              if (v != _passwordController.text) return 'Les mots de passe ne correspondent pas';
              return null;
            },
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Modifier le mot de passe'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48),
        Icon(Icons.check_circle_rounded, size: 64, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Mot de passe modifié',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () {
            if (kIsWeb) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginPage(onThemeReady: widget.onThemeReady)),
                (_) => false,
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LoginPage(onThemeReady: widget.onThemeReady)),
              );
            }
          },
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Se connecter'),
        ),
      ],
    );
  }
}
