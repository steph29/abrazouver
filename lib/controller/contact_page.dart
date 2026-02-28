import 'package:flutter/material.dart';

import '../api/contact_service.dart';
import '../model/user.dart';
import '../theme/app_theme.dart';
import '../utils/logo_picker.dart';

class ContactPage extends StatefulWidget {
  final User user;

  const ContactPage({super.key, required this.user});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  ({List<int> bytes, String name})? _attachment;
  bool _sending = false;

  static const int _maxAttachmentBytes = 5 * 1024 * 1024; // 5 Mo

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.user.email);
    _subjectController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await pickFileBytes(maxBytes: _maxAttachmentBytes);
    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fichier non sélectionné ou trop volumineux (max ${_maxAttachmentBytes ~/ 1024 ~/ 1024} Mo).',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    setState(() => _attachment = (bytes: result.bytes, name: result.name));
  }

  void _removeAttachment() {
    setState(() => _attachment = null);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      await ContactService.sendMessage(
        userId: widget.user.id,
        email: _emailController.text.trim(),
        subject: _subjectController.text.trim(),
        body: _bodyController.text.trim(),
        attachment: _attachment,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message envoyé. L\'administrateur vous répondra à votre adresse email.'),
          backgroundColor: AppColors.primary,
        ),
      );
      _subjectController.clear();
      _bodyController.clear();
      setState(() {
        _attachment = null;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      setState(() => _sending = false);
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
                'Contacter l\'administration',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Utilisez ce formulaire pour envoyer un message à l\'équipe responsable. Votre email sera utilisé pour vous répondre.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Votre email',
                  hintText: 'votre@email.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email obligatoire';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Objet',
                  hintText: 'Objet de votre message',
                  prefixIcon: Icon(Icons.subject_rounded),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Objet obligatoire';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Décrivez votre demande...',
                  prefixIcon: Icon(Icons.message_rounded),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 6,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Message obligatoire';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildAttachmentSection(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Envoi...' : 'Envoyer'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pièce jointe (optionnelle, max 5 Mo)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _pickAttachment,
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(_attachment == null ? 'Joindre un fichier' : 'Remplacer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            if (_attachment != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _attachment!.name,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                onPressed: _removeAttachment,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Retirer la pièce jointe',
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
}
