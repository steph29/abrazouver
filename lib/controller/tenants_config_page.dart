import 'package:flutter/material.dart';

import '../api/tenants_service.dart';
import '../theme/app_theme.dart';

/// Page de configuration des clients - accessible uniquement via app.admin.xxx
class TenantsConfigPage extends StatefulWidget {
  final void Function(ThemeData theme)? onThemeReady;

  const TenantsConfigPage({super.key, this.onThemeReady});

  @override
  State<TenantsConfigPage> createState() => _TenantsConfigPageState();
}

class _TenantsConfigPageState extends State<TenantsConfigPage> {
  final _secretController = TextEditingController();
  final _subdomainController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _dbHostController = TextEditingController();
  final _dbPortController = TextEditingController(text: '3306');
  final _dbUserController = TextEditingController();
  final _dbPasswordController = TextEditingController();
  final _dbNameController = TextEditingController();

  String? _secret;
  List<Map<String, dynamic>> _tenants = [];
  bool _loading = false;
  String? _error;
  bool _testing = false;
  bool _provisioning = false;

  @override
  void dispose() {
    _secretController.dispose();
    _subdomainController.dispose();
    _clientNameController.dispose();
    _dbHostController.dispose();
    _dbPortController.dispose();
    _dbUserController.dispose();
    _dbPasswordController.dispose();
    _dbNameController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final secret = _secretController.text.trim();
    if (secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Secret requis'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await TenantsService.getTenants(secret);
      if (!mounted) return;
      setState(() {
        _secret = secret;
        _tenants = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('ApiException (401): ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadTenants() async {
    if (_secret == null) return;
    setState(() => _loading = true);
    try {
      final list = await TenantsService.getTenants(_secret!);
      if (!mounted) return;
      setState(() {
        _tenants = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _testConnection() async {
    if (_secret == null) return;
    setState(() => _testing = true);
    try {
      await TenantsService.testConnection(
        _secret!,
        dbHost: _dbHostController.text.trim(),
        dbPort: int.tryParse(_dbPortController.text) ?? 3306,
        dbUser: _dbUserController.text.trim(),
        dbPassword: _dbPasswordController.text,
        dbName: _dbNameController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion réussie'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException (400): ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _addTenant() async {
    if (_secret == null) return;
    final subdomain = _subdomainController.text.trim().toLowerCase();
    final clientName = _clientNameController.text.trim();
    final dbHost = _dbHostController.text.trim();
    final dbUser = _dbUserController.text.trim();
    final dbName = _dbNameController.text.trim();
    if (subdomain.isEmpty || dbHost.isEmpty || dbUser.isEmpty || dbName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sous-domaine, Host, User et Base requis'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await TenantsService.addTenant(
        _secret!,
        subdomain: subdomain,
        clientName: clientName.isNotEmpty ? clientName : subdomain,
        dbHost: dbHost,
        dbPort: int.tryParse(_dbPortController.text) ?? 3306,
        dbUser: dbUser,
        dbPassword: _dbPasswordController.text,
        dbName: dbName,
      );
      if (!mounted) return;
      _subdomainController.clear();
      _clientNameController.clear();
      _dbHostController.clear();
      _dbPortController.text = '3306';
      _dbUserController.clear();
      _dbPasswordController.clear();
      _dbNameController.clear();
      _loadTenants();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client ajouté'), backgroundColor: AppColors.primary),
      );
      _runProvision();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException (400): ', '').replaceAll('ApiException (500): ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runProvision() async {
    if (_secret == null) return;
    setState(() => _provisioning = true);
    try {
      final result = await TenantsService.provision(_secret!);
      if (!mounted) return;
      final success = result['success'] == true;
      final message = result['message'] as String? ?? '';
      final details = result['details'] as String?;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(success ? 'Provisionnement réussi' : 'Erreur de provisionnement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(color: success ? Colors.green : Colors.red)),
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Détails :', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(details, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Erreur'),
          content: SelectableText(e.toString()),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _provisioning = false);
    }
  }

  Future<void> _editTenant(Map<String, dynamic> t) async {
    if (_secret == null) return;
    final id = (t['id'] as num?)?.toInt() ?? 0;
    final subC = TextEditingController(text: t['subdomain']?.toString() ?? '');
    final nameC = TextEditingController(text: t['clientName']?.toString() ?? '');
    final hostC = TextEditingController(text: t['dbHost']?.toString() ?? '');
    final portC = TextEditingController(text: (t['dbPort'] ?? 3306).toString());
    final userC = TextEditingController(text: t['dbUser']?.toString() ?? '');
    final passC = TextEditingController();
    final dbC = TextEditingController(text: t['dbName']?.toString() ?? '');
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier le client'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: subC, decoration: const InputDecoration(labelText: 'Sous-domaine *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nom du client', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: hostC, decoration: const InputDecoration(labelText: 'DB Host *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: portC, decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: userC, decoration: const InputDecoration(labelText: 'DB User *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: passC, decoration: const InputDecoration(labelText: 'DB Password (vide = conserver)', border: OutlineInputBorder()), obscureText: true),
                const SizedBox(height: 12),
                TextField(controller: dbC, decoration: const InputDecoration(labelText: 'DB Name *', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final sub = subC.text.trim().toLowerCase();
                final host = hostC.text.trim();
                final user = userC.text.trim();
                final db = dbC.text.trim();
                if (sub.isEmpty || host.isEmpty || user.isEmpty || db.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sous-domaine, Host, User et Base requis')));
                  return;
                }
                try {
                  final result = await TenantsService.updateTenant(
                    _secret!,
                    id,
                    subdomain: sub,
                    clientName: nameC.text.trim(),
                    dbHost: host,
                    dbPort: int.tryParse(portC.text) ?? 3306,
                    dbUser: user,
                    dbPassword: passC.text.isEmpty ? null : passC.text,
                    dbName: db,
                  );
                  if (context.mounted) Navigator.pop(ctx, result);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (updated != null && mounted) {
      _loadTenants();
      final schemaOk = updated['schemaApplied'] != false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            schemaOk
                ? 'Client mis à jour. Schéma DB appliqué.'
                : 'Client mis à jour mais le schéma n\'a pas pu être appliqué sur la DB.',
          ),
          backgroundColor: schemaOk ? null : Colors.orange,
        ),
      );
    }
    subC.dispose();
    nameC.dispose();
    hostC.dispose();
    portC.dispose();
    userC.dispose();
    passC.dispose();
    dbC.dispose();
  }

  Future<void> _deleteTenant(int id) async {
    if (_secret == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce client ?'),
        content: const Text('La configuration sera supprimée. Les données dans la Cloud DB ne sont pas affectées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await TenantsService.deleteTenant(_secret!, id);
      if (!mounted) return;
      _loadTenants();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_secret == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuration clients')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Accès réservé',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Entrez le secret super-admin pour gérer les clients.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _secretController,
                  decoration: const InputDecoration(
                    labelText: 'Secret super-admin',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _unlock(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _unlock,
                  child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Accéder'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration clients')),
      body: SafeArea(
        child: _loading && _tenants.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nouveau client (DB Cloud)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Renseignez les éléments de la nouvelle DB Cloud. L\'app créera les tables automatiquement au premier accès.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _subdomainController,
                      decoration: const InputDecoration(
                        labelText: 'Sous-domaine *',
                        hintText: 'ex: ecole-saint-martin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _clientNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du client',
                        hintText: 'École Saint-Martin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _dbHostController,
                            decoration: const InputDecoration(
                              labelText: 'DB Host *',
                              hintText: 'xxx.mysql.db',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _dbPortController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dbUserController,
                      decoration: const InputDecoration(
                        labelText: 'DB User *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dbPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'DB Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dbNameController,
                      decoration: const InputDecoration(
                        labelText: 'DB Name *',
                        hintText: 'abrazouver_apel',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _testing ? null : _testConnection,
                          icon: _testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link),
                          label: const Text('Tester la connexion'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _loading ? null : _addTenant,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter le client'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _provisioning ? null : _runProvision,
                      icon: _provisioning
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.security),
                      label: const Text('Mise à jour SSL (certificats + nginx)'),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Clients configurés (${_tenants.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_tenants.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Aucun client. Ajoutez-en un ci-dessus.', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    else
                      ..._tenants.map((t) => Card(
                            child: ListTile(
                              title: Text(t['clientName'] ?? t['subdomain'] ?? ''),
                              subtitle: Text('${t['subdomain']} → ${t['dbHost']}:${t['dbName']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editTenant(Map<String, dynamic>.from(t)),
                                    tooltip: 'Modifier',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteTenant((t['id'] as num?)?.toInt() ?? 0),
                                    tooltip: 'Supprimer',
                                  ),
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
              ),
      ),
    );
  }
}
