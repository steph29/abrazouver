import 'package:flutter/material.dart';
import '../api/auth_service.dart';
import '../theme/app_theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  final void Function(ThemeData theme) onThemeReady;

  const ForgotPasswordPage({super.key, required this.onThemeReady});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.forgotPassword(
        _emailController.text.trim(),
        appBaseUrl: Uri.base.origin,
      );
      if (!mounted) return;
      setState(() {
        _emailSent = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException (503): ', '').replaceAll('ApiException (500): ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted && !_emailSent) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _emailSent ? _buildSuccessContent() : _buildFormContent(),
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
          const SizedBox(height: 24),
          Icon(Icons.lock_reset_rounded, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            'Mot de passe perdu',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Entrez votre adresse email. Nous vous enverrons un lien pour réinitialiser votre mot de passe.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'votre@email.com',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email requis';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                return 'Email invalide';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Envoyer le lien'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Icon(Icons.mark_email_read_rounded, size: 64, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Email envoyé',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Si un compte existe avec cette adresse, vous recevrez un lien pour réinitialiser votre mot de passe. Vérifiez également votre dossier spam.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Retour à la connexion'),
        ),
      ],
    );
  }
}
