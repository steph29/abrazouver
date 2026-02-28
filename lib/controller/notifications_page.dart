import 'package:flutter/material.dart';

import '../api/contact_admin_service.dart';
import '../model/user.dart';
import '../theme/app_theme.dart';
import '../utils/download_helper.dart';

class NotificationsPage extends StatefulWidget {
  final User user;
  final void Function(int count)? onViewed;

  const NotificationsPage({super.key, required this.user, this.onViewed});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  final Map<int, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ContactAdminService.getMessages(widget.user.id);
      if (mounted) {
        setState(() {
          _messages = list;
          _loading = false;
        });
        widget.onViewed?.call(list.length);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('ApiException ', '');
          _loading = false;
        });
        widget.onViewed?.call(0);
      }
    }
  }

  String _formatDate(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    if (s.length >= 16) return s.substring(0, 16).replaceFirst('T', ' ');
    return s;
  }

  Future<void> _downloadAttachment(int messageId) async {
    final result = await ContactAdminService.downloadAttachment(
      widget.user.id,
      messageId,
    );
    if (result == null || !mounted) return;
    final ok = await downloadFile(result.bytes, result.name);
    if (mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de télécharger la pièce jointe')),
      );
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
                onPressed: _loadMessages,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline_rounded, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'Aucun message reçu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Les messages envoyés depuis la page Contact apparaîtront ici.',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadMessages,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length,
          itemBuilder: (context, i) {
            final m = _messages[i];
            final id = (m['id'] as num?)?.toInt() ?? 0;
            final expanded = _expanded[id] ?? false;
            final hasAttachment = m['attachment_name'] != null && (m['attachment_name'] as String).isNotEmpty;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() => _expanded[id] = !expanded);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m['subject'] as String? ?? '(sans objet)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasAttachment)
                            Icon(Icons.attach_file_rounded, size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'De : ${m['email']} • ${_formatDate(m['created_at'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (expanded) ...[
                        const Divider(height: 24),
                        SelectableText(
                          m['body'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        if (hasAttachment) ...[
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: () => _downloadAttachment(id),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text('Télécharger ${m['attachment_name']}'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
