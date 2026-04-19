import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/auth_service.dart';
import '../model/family_member.dart';
import '../model/user.dart';
import '../theme/app_theme.dart';

class ComptePage extends StatefulWidget {
  final User user;
  final void Function(User) onUserUpdated;

  const ComptePage({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<ComptePage> createState() => _ComptePageState();
}

class _ComptePageState extends State<ComptePage> {
  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _emailController;
  late TextEditingController _telephoneController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _twoFactorEnabled = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  List<FamilyMember> _famille = [];
  bool _loadingFamille = false;
  final _famPrenomController = TextEditingController();
  final _famNomController = TextEditingController();
  final _famEmailController = TextEditingController();
  final _famPasswordController = TextEditingController();
  final _famFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.user.nom);
    _prenomController = TextEditingController(text: widget.user.prenom);
    _emailController = TextEditingController(text: widget.user.email);
    _telephoneController = TextEditingController(text: widget.user.telephone ?? '');
    _twoFactorEnabled = widget.user.twoFactorEnabled;
    if (widget.user.isFamilyHead) {
      _loadFamille();
    }
  }

  @override
  void dispose() {
    _famPrenomController.dispose();
    _famNomController.dispose();
    _famEmailController.dispose();
    _famPasswordController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadFamille() async {
    setState(() => _loadingFamille = true);
    try {
      final raw = await AuthService.getFamilyMembers(widget.user.id);
      if (!mounted) return;
      setState(() {
        _famille = raw.map((e) => FamilyMember.fromJson(e)).toList();
        _loadingFamille = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFamille = false);
    }
  }

  Future<void> _addFamilyMember() async {
    if (!_famFormKey.currentState!.validate()) return;
    final email = _famEmailController.text.trim();
    final pwd = _famPasswordController.text;
    if (email.isNotEmpty && pwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Si un email est renseigné, le mot de passe doit faire au moins 6 caractères.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (email.isEmpty && pwd.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indiquez un email pour un compte avec mot de passe, ou laissez email et mot de passe vides.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.addFamilyMember(
        widget.user.id,
        email: email.isEmpty ? null : email,
        password: email.isEmpty ? null : pwd,
        nom: _famNomController.text.trim(),
        prenom: _famPrenomController.text.trim(),
      );
      if (!mounted) return;
      _famPrenomController.clear();
      _famNomController.clear();
      _famEmailController.clear();
      _famPasswordController.clear();
      await _loadFamille();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            email.isEmpty
                ? 'Membre ajouté. Il n’a pas de compte séparé : vous gérez ses inscriptions depuis votre compte.'
                : 'Membre ajouté. Il peut se connecter avec son email et son mot de passe.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('ApiException (400): ', '').replaceAll('ApiException (409): ', ''),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFamilyMember(FamilyMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer ce membre'),
        content: Text(
          'Retirer ${m.displayName} du foyer ? Ses inscriptions aux créneaux seront supprimées.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.removeFamilyMember(widget.user.id, m.id);
      if (!mounted) return;
      await _loadFamille();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membre retiré'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildFamilySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.family_restroom_rounded, color: AppColors.primaryDark, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Foyer / bénévoles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des membres (conjoint, enfant…). Email et mot de passe sont facultatifs : sans eux, seul le titulaire gère les inscriptions (ex. couple sur une seule adresse).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_loadingFamille)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            ..._famille.where((m) => !m.isHead).map(
                  (m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(m.displayName),
                    subtitle: Text(
                      m.canLogin && (m.email?.isNotEmpty ?? false)
                          ? m.email!
                          : 'Compte géré par le titulaire (pas de connexion séparée)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                      tooltip: 'Retirer',
                      onPressed: _isLoading ? null : () => _removeFamilyMember(m),
                    ),
                  ),
                ),
          const SizedBox(height: 16),
          Text(
            'Nouveau membre',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Form(
            key: _famFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _famPrenomController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Prénom',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Prénom requis' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _famNomController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _famEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email (facultatif)',
                    hintText: 'Laisser vide si pas de compte séparé',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _famPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe (facultatif, min. 6 caractères si email)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (v.length < 6) return 'Au moins 6 caractères si renseigné';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _addFamilyMember,
                  icon: const Icon(Icons.person_add_rounded, size: 20),
                  label: const Text('Ajouter le membre'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await AuthService.updateProfile(
        widget.user.id,
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        email: _emailController.text.trim(),
        telephone: _telephoneController.text.trim().isEmpty
            ? null
            : _telephoneController.text.trim(),
      );
      if (!mounted) return;
      final updatedUser = User.fromJson(response);
      widget.onUserUpdated(updatedUser);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil mis à jour'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('ApiException (400): ', '')
                .replaceAll('ApiException (409): ', ''),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.updatePassword(
        widget.user.id,
        _currentPasswordController.text,
        _newPasswordController.text,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe modifié'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('ApiException (401): ', '').replaceAll('ApiException (400): ', ''),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPasswordSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
      ),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_rounded, color: AppColors.primaryDark, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Modifier le mot de passe',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Mot de passe actuel',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mot de passe actuel requis';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nouveau mot de passe requis';
                if (v.length < 6) return 'Au moins 6 caractères';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirmer le nouveau mot de passe',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirmation requise';
                if (v != _newPasswordController.text) return 'Les mots de passe ne correspondent pas';
                return null;
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isLoading ? null : _updatePassword,
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('Modifier le mot de passe'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSetup2FADialog() async {
    setState(() => _isLoading = true);
    try {
      final response = await AuthService.setup2FA(widget.user.id);
      if (!mounted) return;
      final qrCodeDataUrl = response['qrCodeDataUrl'] as String? ?? '';
      final manualKey = response['manualEntryKey'] as String? ?? '';

      final codeCtrl = TextEditingController();
      final activated = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded),
              SizedBox(width: 8),
              Flexible(child: Text('Configurer Microsoft Authenticator')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '1. Scannez ce QR code avec Microsoft Authenticator',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (qrCodeDataUrl.contains(','))
                  Center(
                    child: Image.memory(
                      base64Decode(qrCodeDataUrl.split(',').last),
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  '2. Ou saisissez cette clé manuellement :',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    manualKey,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '3. Entrez le code à 6 chiffres affiché :',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: '000000',
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final code = codeCtrl.text.trim();
                if (code.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code à 6 chiffres requis')),
                  );
                  return;
                }
                try {
                  await AuthService.confirm2FA(widget.user.id, code);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceAll('ApiException (401): ', ''),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );

      if (activated == true && mounted) {
        setState(() => _twoFactorEnabled = true);
        widget.onUserUpdated(widget.user.copyWith(twoFactorEnabled: true));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('2FA activée avec succès'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('ApiException ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showDisable2FADialog() async {
    final codeCtrl = TextEditingController();
    final disabled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Désactiver la 2FA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entrez le code à 6 chiffres de votre authentificator pour confirmer.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Code',
                hintText: '000000',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code à 6 chiffres requis')),
                );
                return;
              }
              try {
                await AuthService.disable2FA(widget.user.id, code);
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceAll('ApiException (401): ', ''),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (disabled == true && mounted) {
      setState(() => _twoFactorEnabled = false);
      widget.onUserUpdated(widget.user.copyWith(twoFactorEnabled: false));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('2FA désactivée'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Mon compte',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Modifiez vos informations personnelles',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nomController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nom requis';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _prenomController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Prénom',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Prénom requis';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'votre@email.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email requis';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(v.trim())) {
                    return 'Email invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telephoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  hintText: '06 12 34 56 78',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              if (widget.user.isFamilyHead) ...[
                const SizedBox(height: 32),
                _buildFamilySection(),
              ],
              const SizedBox(height: 24),
              _buildPasswordSection(),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security_rounded,
                          color: AppColors.primaryDark,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Authentification à deux facteurs (2FA)',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _twoFactorEnabled
                                    ? 'Activée - Code requis à chaque connexion'
                                    : 'Sécurisez votre compte avec Microsoft Authenticator.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _twoFactorEnabled
                        ? OutlinedButton.icon(
                            onPressed: _isLoading ? null : _showDisable2FADialog,
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: const Text('Désactiver la 2FA'),
                          )
                        : FilledButton.icon(
                            onPressed: _isLoading ? null : _showSetup2FADialog,
                            icon: const Icon(Icons.security_rounded, size: 18),
                            label: const Text('Activer avec Microsoft Authenticator'),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer les modifications'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
