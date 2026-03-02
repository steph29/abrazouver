import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../api/analyse_service.dart';
import '../theme/theme_provider.dart';
import '../utils/download_helper.dart';
import '../model/user.dart';
import '../theme/app_theme.dart';

class AnalysePage extends StatefulWidget {
  final User user;

  const AnalysePage({super.key, required this.user});

  @override
  State<AnalysePage> createState() => _AnalysePageState();
}

class _AnalysePageState extends State<AnalysePage> {
  bool _loading = true;
  String? _error;
  int _nbPlacesPrises = 0;
  int _nbBenevoles = 0;
  List<Map<String, dynamic>> _tauxParPoste = [];
  List<Map<String, dynamic>> _benevoles = [];
  DateTime? _selectedDay;
  int _heureDebut = 0;
  int _heureFin = 24;
  bool _exporting = false;
  String _benevoleSearch = '';
  List<Map<String, dynamic>> _benevolesManuels = [];
  final TextEditingController _manuelNomController = TextEditingController();
  final TextEditingController _manuelPrenomController = TextEditingController();

  int get _anneeExport =>
      _selectedDay?.year ?? DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadBenevolesManuels();
  }

  @override
  void dispose() {
    _manuelNomController.dispose();
    _manuelPrenomController.dispose();
    super.dispose();
  }

  Future<void> _loadBenevolesManuels() async {
    try {
      final list = await AnalyseService.getBenevolesManuels(widget.user.id, _anneeExport);
      if (mounted) setState(() => _benevolesManuels = list);
    } catch (_) {
      if (mounted) setState(() => _benevolesManuels = []);
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String? dateFrom;
      String? dateTo;
      if (_selectedDay != null) {
        final d = _selectedDay!;
        final dayStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        dateFrom = '${dayStr}T${_heureDebut.toString().padLeft(2, '0')}:00:00';
        dateTo = _heureFin >= 24
            ? '${dayStr}T23:59:59'
            : '${dayStr}T${_heureFin.toString().padLeft(2, '0')}:00:00';
      }
      final data = await AnalyseService.getStats(
        widget.user.id,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (!mounted) return;
      setState(() {
        _nbPlacesPrises = (data['nbPlacesPrises'] as num?)?.toInt() ?? 0;
        _nbBenevoles = (data['nbBenevoles'] as num?)?.toInt() ?? 0;
        _tauxParPoste = List<Map<String, dynamic>>.from(
          (data['tauxRemplissageParPoste'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _benevoles = List<Map<String, dynamic>>.from(
          (data['benevoles'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('ApiException (500): ', '').replaceAll('ApiException (403): ', '');
          _loading = false;
        });
      }
    }
  }

  void _showExportChoice() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Télécharger la liste en',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('PDF'),
                subtitle: const Text('Document lisible'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadExportPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('XLSX'),
                subtitle: const Text('Tableur Excel'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadExportXlsx();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadExportPdf() async {
    setState(() => _exporting = true);
    try {
      final logoBytes = _getLogoBytes();
      final pdf = pw.Document();
      final appBenevoles = _filteredBenevoles.map((b) => {'nom': b['nom']?.toString() ?? '', 'prenom': b['prenom']?.toString() ?? ''}).toList();
      final manuels = _benevolesManuels.map((b) => {'nom': b['nom']?.toString() ?? '', 'prenom': b['prenom']?.toString() ?? ''}).toList();
      final benevoles = [...appBenevoles, ...manuels]
        ..sort((a, b) => '${a['nom']} ${a['prenom']}'.compareTo('${b['nom']} ${b['prenom']}'));

      pdf.addPage(
        pw.MultiPage(
          header: (ctx) => pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logoBytes != null)
                pw.SizedBox(
                  width: 80,
                  height: 40,
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox.shrink(),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Text(
                    'Liste des bénévoles inscrits',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.end,
                  ),
                ),
              ),
            ],
          ),
          build: (ctx) => [
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell('Nom', bold: true),
                    _cell('Prénom', bold: true),
                  ],
                ),
                ...benevoles.map((b) => pw.TableRow(
                      children: [
                        _cell(b['nom'] ?? ''),
                        _cell(b['prenom'] ?? ''),
                      ],
                    )),
              ],
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      const filename = 'benevoles_inscrits.pdf';
      if (kIsWeb) {
        final ok = await downloadFile(bytes, filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok ? 'Téléchargement démarré' : 'Erreur lors du téléchargement'),
              backgroundColor: ok ? Theme.of(context).colorScheme.primaryContainer : Colors.red,
            ),
          );
        }
      } else {
        final file = XFile.fromData(
          Uint8List.fromList(bytes),
          name: filename,
          mimeType: 'application/pdf',
        );
        await Share.shareXFiles([file], subject: 'Bénévoles inscrits', text: 'Liste des bénévoles inscrits');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Fichier prêt à partager'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Extrait les bytes du logo depuis le data URI (AppThemeScope)
  Uint8List? _getLogoBytes() {
    final scope = AppThemeScope.maybeOf(context);
    final uri = scope?.logoDataUri;
    if (uri == null || uri.isEmpty) return null;
    final match = RegExp(r'data:image/\w+;base64,(.+)').firstMatch(uri);
    if (match == null) return null;
    try {
      return base64Decode(match.group(1)!.replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return null;
    }
  }

  pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      );

  Future<void> _downloadExportXlsx() async {
    setState(() => _exporting = true);
    try {
      final bytes = await AnalyseService.downloadExport(widget.user.id, annee: _anneeExport);
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du téléchargement'), backgroundColor: Colors.red),
        );
        return;
      }
      const filename = 'benevoles_inscrits.xlsx';
      if (kIsWeb) {
        final ok = await downloadFile(bytes, filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok ? 'Téléchargement démarré' : 'Erreur lors du téléchargement'),
              backgroundColor: ok ? Theme.of(context).colorScheme.primaryContainer : Colors.red,
            ),
          );
        }
      } else {
        final file = XFile.fromData(
          bytes,
          name: filename,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        await Share.shareXFiles(
          [file],
          subject: 'Bénévoles inscrits',
          text: 'Liste des bénévoles inscrits à l\'événement',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Fichier prêt à partager'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (day == null || !mounted) return;
    setState(() {
      _selectedDay = day;
      _heureDebut = 0;
      _heureFin = 24;
    });
    _loadData();
    _loadBenevolesManuels();
  }

  void _clearDayFilter() {
    setState(() {
      _selectedDay = null;
      _heureDebut = 0;
      _heureFin = 24;
    });
    _loadData();
    _loadBenevolesManuels();
  }

  String _formatDateShort(DateTime d) {
    const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const mois = ['janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
    return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';
  }

  /// Filtre les bénévoles selon la recherche (nom, prénom, email, postes)
  List<Map<String, dynamic>> get _filteredBenevoles {
    if (_benevoleSearch.isEmpty) return _benevoles;
    final words = _benevoleSearch.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 0).toList();
    if (words.isEmpty) return _benevoles;
    return _benevoles.where((b) {
      final prenom = ((b['prenom'] as String?) ?? '').toLowerCase();
      final nom = ((b['nom'] as String?) ?? '').toLowerCase();
      final email = ((b['email'] as String?) ?? '').toLowerCase();
      final fullName = '$prenom $nom'.trim();
      final postes = (b['postes'] as List?) ?? [];
      final posteTitres = postes.map((p) => ((p as Map)['posteTitre']?.toString() ?? '').toLowerCase()).join(' ');
      for (final w in words) {
        if (prenom.contains(w) || nom.contains(w) || email.contains(w) ||
            fullName.contains(w) || posteTitres.contains(w)) continue;
        return false;
      }
      return true;
    }).toList();
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
              FilledButton(onPressed: _loadData, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final secondaryColor = theme.colorScheme.primaryContainer;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: secondaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDay == null
                                  ? 'Toutes les données'
                                  : _formatDateShort(_selectedDay!),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickDay,
                            icon: const Icon(Icons.edit_calendar),
                            label: Text(_selectedDay == null ? 'Choisir un jour' : 'Modifier'),
                          ),
                          if (_selectedDay != null)
                            IconButton(
                              onPressed: _clearDayFilter,
                              icon: const Icon(Icons.clear),
                              tooltip: 'Réinitialiser',
                            ),
                        ],
                      ),
                      if (_selectedDay != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Horaire : ${_heureDebut.toString().padLeft(2, '0')}h - ${_heureFin >= 24 ? '24h' : '${_heureFin}h'}',
                          style: theme.textTheme.bodySmall,
                        ),
                        RangeSlider(
                          values: RangeValues(_heureDebut.toDouble(), _heureFin.toDouble()),
                          min: 0,
                          max: 24,
                          divisions: 24,
                          labels: RangeLabels(
                            '${_heureDebut}h',
                            _heureFin >= 24 ? '24h' : '${_heureFin}h',
                          ),
                          onChanged: (v) {
                            setState(() {
                              _heureDebut = v.start.round();
                              _heureFin = v.end.round();
                              if (_heureDebut >= _heureFin) _heureFin = (_heureDebut + 1).clamp(0, 24);
                            });
                          },
                          onChangeEnd: (_) => _loadData(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPlacesLibresCard(secondaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      'Bénévoles',
                      _nbBenevoles.toString(),
                      Icons.people,
                      secondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Taux de remplissage par poste', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_tauxParPoste.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Aucun poste pour le moment')),
                  ),
                )
              else if (_tauxParPoste.length < 3)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Au moins 3 postes requis pour le graphique radar (${_tauxParPoste.length} actuellement)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 280,
                      child: RadarChart(
                        RadarChartData(
                          dataSets: [
                            RadarDataSet(
                              fillColor: secondaryColor.withOpacity(0.3),
                              borderColor: secondaryColor,
                              borderWidth: 2,
                              dataEntries: _tauxParPoste
                                  .map((p) => RadarEntry(value: ((p['tauxRemplissage'] as num?) ?? 0).toDouble()))
                                  .toList(),
                            ),
                          ],
                          getTitle: (i, _) => RadarChartTitle(
                            text: _tauxParPoste[i]['titre']?.toString().split(' ').take(2).join(' ') ?? 'Poste',
                          ),
                          titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 11),
                          tickCount: 5,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bénévoles inscrits', style: theme.textTheme.titleMedium),
                  FilledButton.icon(
                    onPressed: _exporting ? null : _showExportChoice,
                    icon: _exporting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: Text(_exporting ? 'Téléchargement...' : 'Télécharger'),
                    style: FilledButton.styleFrom(
                      backgroundColor: secondaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_benevoles.isEmpty) ...[
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un bénévole (nom, prénom, email, poste…)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _benevoleSearch = v.trim()),
                ),
                const SizedBox(height: 12),
              ],
              if (_filteredBenevoles.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        _benevoleSearch.isEmpty ? 'Aucun bénévole inscrit' : 'Aucun résultat pour « $_benevoleSearch »',
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: _filteredBenevoles.map((b) => _buildBenevoleTile(b, theme)).toList(),
                  ),
                ),
              const SizedBox(height: 24),
              _buildBenevolesManuelsSection(theme, secondaryColor),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenevolesManuelsSection(ThemeData theme, Color secondaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Bénévoles inscrits à la main',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Ajoutez des bénévoles qui ne souhaitent pas créer de compte. Ils figureront dans les exports PDF et Excel. Année : $_anneeExport.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _manuelNomController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _manuelPrenomController,
                decoration: const InputDecoration(
                  labelText: 'Prénom',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _addBenevoleManuel,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
              style: FilledButton.styleFrom(backgroundColor: secondaryColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_benevolesManuels.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Aucun bénévole inscrit à la main pour $_anneeExport.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: _benevolesManuels.map((b) => ListTile(
                title: Text('${b['prenom'] ?? ''} ${b['nom'] ?? ''}'.trim()),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteBenevoleManuel((b['id'] as num?)?.toInt() ?? 0),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _addBenevoleManuel() async {
    final nom = _manuelNomController.text.trim();
    final prenom = _manuelPrenomController.text.trim();
    if (nom.isEmpty || prenom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom et prénom requis'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      await AnalyseService.addBenevoleManuel(widget.user.id, nom: nom, prenom: prenom, annee: _anneeExport);
      _manuelNomController.clear();
      _manuelPrenomController.clear();
      if (!mounted) return;
      _loadBenevolesManuels();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bénévole ajouté'), backgroundColor: AppColors.primary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException (400): ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteBenevoleManuel(int id) async {
    try {
      await AnalyseService.deleteBenevoleManuel(widget.user.id, id);
      if (!mounted) return;
      _loadBenevolesManuels();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bénévole supprimé'), backgroundColor: AppColors.primary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException (404): ', '')), backgroundColor: Colors.red),
      );
    }
  }

  /// Encart Places occupées : X / Y (Z %) dans la page Analyse
  Widget _buildPlacesLibresCard(Color color) {
    final totalPlaces = _tauxParPoste.fold<int>(
      0,
      (s, p) => s + ((p['totalPlaces'] as num?)?.toInt() ?? 0),
    );
    final pct = totalPlaces > 0 ? ((_nbPlacesPrises / totalPlaces) * 100).round() : 0;
    final value = totalPlaces > 0 ? '$_nbPlacesPrises / $totalPlaces ($pct %)' : '0';
    return _buildKpiCard('Places occupées', value, Icons.event_seat, color);
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenevoleTile(Map<String, dynamic> benevole, ThemeData theme) {
    final postes = (benevole['postes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
        child: Text(
          ((benevole['prenom'] as String?) ?? '?')[0].toUpperCase(),
          style: TextStyle(color: theme.colorScheme.primaryContainer),
        ),
      ),
      title: Text(
        '${benevole['prenom'] ?? ''} ${benevole['nom'] ?? ''}'.trim(),
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      subtitle: postes.isNotEmpty
          ? Text('${postes.length} créneau${postes.length > 1 ? 'x' : ''}', style: const TextStyle(fontSize: 12))
          : null,
      children: [
        ...postes.map(
          (p) => ListTile(
            dense: true,
            leading: const Icon(Icons.work_outline, size: 20),
            title: Text(p['posteTitre'] ?? ''),
            subtitle: Text(
              _formatCreneau(p['dateDebut'], p['dateFin']),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCreneau(dynamic deb, dynamic fin) {
    if (deb == null && fin == null) return '';
    final d = deb != null ? DateTime.tryParse(deb.toString()) : null;
    final f = fin != null ? DateTime.tryParse(fin.toString()) : null;
    if (d == null) return fin.toString();
    if (f == null) return d.toString();
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} - '
        '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
  }
}
