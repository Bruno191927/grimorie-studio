import 'package:grimoire_studio/features/editor/models/card_template.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';
import 'package:grimoire_studio/core/widgets/grimoire_toast.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';
import 'package:grimoire_studio/features/export/services/export_service.dart';

class DataTableView extends ConsumerStatefulWidget {
  const DataTableView({super.key});

  @override
  ConsumerState<DataTableView> createState() => _DataTableViewState();
}

class _DataTableViewState extends ConsumerState<DataTableView> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';
  String _selectedGame = 'all';
  String _selectedStatus = 'all'; // 'all', 'Definitiva', 'Muestra'
  String? _sortColumn;
  bool _sortAscending = true;
  final Set<String> _hiddenColumns = {};
  final Set<String> _explicitlyShownColumns = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(editorProvider.notifier).syncTemplateVariablesToRows();
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final project = editorState.project;
    final rows = project.rows;
    final activeRowIndex = project.activeRowIndex;

    // Collect available games for game filtering
    final availableGames = <String>{};
    for (final r in rows) {
      final g = (r['game'] ?? '').toString().trim();
      if (g.isNotEmpty) availableGames.add(g);
    }
    final sortedGames = availableGames.toList()..sort();

    // 1. Core permanent columns (always shown first, cannot be hidden)
    const coreKeys = ['card_name', 'game', 'category', 'card_status', 'qty'];
    const internalKeys = GameFolderService.internalKeys;

    // 2. Relevant rows based on game filter
    final currentTargetRows = _selectedGame == 'all'
        ? rows
        : rows.where((r) => (r['game'] ?? '').toString().toLowerCase() == _selectedGame.toLowerCase()).toList();
    final rowsToCheck = currentTargetRows.isNotEmpty ? currentTargetRows : rows;

    // 3. Dynamic template variables extracted from templates of cards being displayed
    final templateVars = <String>{};
    final displayedTemplates = <CardTemplate>{};
    for (final r in rowsToCheck) {
      displayedTemplates.add(ref.read(editorProvider.notifier).resolveTemplateForRow(r));
    }
    if (project.templates.isNotEmpty) {
      displayedTemplates.add(project.activeTemplate);
    }
    for (final t in displayedTemplates) {
      templateVars.addAll(t.getReferencedVariables());
    }
    final templateKeys = <String>[];
    for (final v in templateVars) {
      if (!internalKeys.contains(v) && !coreKeys.contains(v) && !templateKeys.contains(v)) {
        templateKeys.add(v);
      }
    }

    // 4. Standard genre columns
    const standardGenreKeys = [
      'type',
      'rarity',
      'cost',
      'attack',
      'defense',
      'rules_text',
      'art_url',
      'prompt',
      'icon',
      'art_color',
      'creator',
    ];

    // 5. Extra data columns from row data
    final extraDataKeys = <String>[];
    for (final r in rowsToCheck) {
      for (final k in r.keys) {
        if (!coreKeys.contains(k) &&
            !templateKeys.contains(k) &&
            !standardGenreKeys.contains(k) &&
            !internalKeys.contains(k) &&
            !extraDataKeys.contains(k)) {
          extraDataKeys.add(k);
        }
      }
    }

    // 6. Active genre keys:
    // Only include if in template, or explicitly shown, or has non-empty/non-default data
    final activeGenreKeys = <String>[];
    for (final genre in standardGenreKeys) {
      if (templateKeys.contains(genre)) continue;
      if (_hiddenColumns.contains(genre)) continue;
      if (_explicitlyShownColumns.contains(genre)) {
        activeGenreKeys.add(genre);
        continue;
      }
      final hasData = rowsToCheck.any((r) {
        final val = (r[genre]?.toString() ?? '').trim();
        if (genre == 'creator' && val == 'Grimoire Studio') return false;
        if (genre == 'icon' && val == '🃏') return false;
        return val.isNotEmpty;
      });
      if (hasData) {
        activeGenreKeys.add(genre);
      }
    }

    final allCandidateColumns = [
      ...coreKeys,
      ...templateKeys,
      ...extraDataKeys,
      ...activeGenreKeys,
    ];

    final columns = allCandidateColumns.where((col) {
      if (coreKeys.contains(col)) return true;
      return !_hiddenColumns.contains(col);
    }).toList();

    final filteredIndices = <int>[];
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (_selectedGame != 'all') {
        final rowGame = (row['game'] ?? '').toString().trim();
        if (rowGame.toLowerCase() != _selectedGame.toLowerCase()) {
          continue;
        }
      }
      if (_selectedStatus != 'all') {
        final rowStatus = (row['card_status'] ?? 'Definitiva').toString().trim();
        if (rowStatus.toLowerCase() != _selectedStatus.toLowerCase()) {
          continue;
        }
      }
      if (_searchFilter.isEmpty) {
        filteredIndices.add(i);
      } else {
        final query = _searchFilter.toLowerCase();
        final match = row.values.any((v) => v.toString().toLowerCase().contains(query));
        if (match) filteredIndices.add(i);
      }
    }

    if (_sortColumn != null) {
      filteredIndices.sort((a, b) {
        final valA = rows[a][_sortColumn]?.toString() ?? '';
        final valB = rows[b][_sortColumn]?.toString() ?? '';
        final numA = num.tryParse(valA);
        final numB = num.tryParse(valB);
        int comparison;
        if (numA != null && numB != null) {
          comparison = numA.compareTo(numB);
        } else {
          comparison = valA.toLowerCase().compareTo(valB.toLowerCase());
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    return Scaffold(
      backgroundColor: GrimoireTheme.bgCanvas,
      appBar: AppBar(
        backgroundColor: GrimoireTheme.surfacePanel,
        elevation: 0,
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
            const Icon(Icons.table_chart_outlined, color: GrimoireTheme.accentPurple, size: 20),
            const SizedBox(width: 8),
            Text(ref.tr('db_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${filteredIndices.length}/${rows.length} ${ref.tr('total_cards')}',
                style: const TextStyle(fontSize: 11, color: GrimoireTheme.accentPurple, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            // Game filter selector
            if (sortedGames.isNotEmpty) ...[
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: GrimoireTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GrimoireTheme.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGame == 'all' || sortedGames.contains(_selectedGame)
                        ? _selectedGame
                        : 'all',
                    dropdownColor: GrimoireTheme.surfaceElevated,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                    icon: const Icon(Icons.arrow_drop_down, size: 16, color: GrimoireTheme.textMuted),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.apps, size: 13, color: GrimoireTheme.accentPurple),
                            SizedBox(width: 6),
                            Text('Todos los juegos'),
                          ],
                        ),
                      ),
                      for (final g in sortedGames)
                        DropdownMenuItem(
                          value: g,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.style, size: 13, color: GrimoireTheme.accentAmber),
                              SizedBox(width: 6),
                              Text(g),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGame = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            // Status filter selector (Definitivas vs Muestras / Presets)
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: GrimoireTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedStatus == 'Definitiva'
                      ? GrimoireTheme.accentEmerald.withValues(alpha: 0.5)
                      : (_selectedStatus == 'Muestra'
                          ? GrimoireTheme.accentAmber.withValues(alpha: 0.5)
                          : GrimoireTheme.borderSubtle),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  dropdownColor: GrimoireTheme.surfaceElevated,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  icon: const Icon(Icons.arrow_drop_down, size: 16, color: GrimoireTheme.textMuted),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers_outlined, size: 13, color: GrimoireTheme.accentIndigo),
                          SizedBox(width: 6),
                          Text('Todas las cartas'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Definitiva',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 13, color: GrimoireTheme.accentEmerald),
                          SizedBox(width: 6),
                          Text('Solo Definitivas'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Muestra',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_border, size: 13, color: GrimoireTheme.accentAmber),
                          SizedBox(width: 6),
                          Text('Solo Muestras / Presets'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Quick search in table
            SizedBox(
              width: 180,
              height: 32,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 11, color: Colors.white),
                decoration: InputDecoration(
                  hintText: ref.tr('filter_table_hint'),
                  hintStyle: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                  prefixIcon: const Icon(Icons.search, size: 14, color: GrimoireTheme.textMuted),
                  suffixIcon: _searchFilter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 13, color: GrimoireTheme.textMuted),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchFilter = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: GrimoireTheme.surfaceElevated,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: GrimoireTheme.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: GrimoireTheme.borderSubtle),
                  ),
                ),
                onChanged: (val) => setState(() => _searchFilter = val.trim()),
              ),
            ),
          ],
        ),
      ),
      actions: [
          // Manage custom & template columns button (always available)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: GrimoireTheme.accentIndigo),
            icon: const Icon(Icons.tune, size: 15),
            label: Text('${ref.tr('columns')} (${columns.length})', style: const TextStyle(fontSize: 12)),
            onPressed: () => _showManageColumnsDialog(
              context,
              ref,
              allAvailableColumns: [
                ...coreKeys,
                ...templateKeys,
                ...extraDataKeys,
                ...standardGenreKeys.where((k) => !templateKeys.contains(k) && !coreKeys.contains(k)),
              ],
              templateKeys: templateKeys,
              customKeys: extraDataKeys,
              visibleColumns: columns.toSet(),
            ),
          ),
          // Add custom column button
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: GrimoireTheme.accentAmber),
            icon: const Icon(Icons.view_column_outlined, size: 15),
            label: Text(ref.tr('new_column'), style: const TextStyle(fontSize: 12)),
            onPressed: () => _showAddColumnDialog(context, ref),
          ),
          const SizedBox(width: 4),
          // Sync with template variables button
          IconButton(
            icon: const Icon(Icons.sync, color: GrimoireTheme.accentCyan, size: 20),
            tooltip: 'Sincronizar variables con plantilla',
            onPressed: () {
              ref.read(editorProvider.notifier).syncTemplateVariablesToRows();
              GrimoireToast.success(context, 'Variables sincronizadas con las capas de la plantilla.', title: 'Sincronización completada');
            },
          ),
          // Export CSV button
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: GrimoireTheme.accentEmerald),
            tooltip: _selectedGame == 'all' ? ref.tr('export_current_csv') : '${ref.tr('export_csv')} ($_selectedGame)',
            onPressed: () => _exportCsvFile(context, ref, columns, filteredIndices),
          ),
          // Import CSV/JSON
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: GrimoireTheme.accentIndigo),
            tooltip: ref.tr('import_file'),
            onPressed: () => _importFile(context, ref),
          ),
          // Add Card Row
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: GrimoireTheme.accentPurple),
            tooltip: ref.tr('add_row'),
            onPressed: () {
              final activeRow = rows.isNotEmpty && activeRowIndex >= 0 && activeRowIndex < rows.length
                  ? rows[activeRowIndex]
                  : null;
              final targetGame = _selectedGame != 'all'
                  ? _selectedGame
                  : (activeRow?['game']?.toString().isNotEmpty == true
                      ? activeRow!['game'].toString()
                      : (sortedGames.isNotEmpty ? sortedGames.first : 'Magic'));
              ref.read(editorProvider.notifier).addCardToGame(
                targetGame,
                cardName: '${ref.tr('default_card_name')} ($targetGame)',
                type: ref.tr('default_card_type'),
                rulesText: ref.tr('default_rules_text').replaceAll('{game}', targetGame),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: rows.isEmpty
          ? Center(
              child: Text(ref.tr('no_data_rows'),
                  style: const TextStyle(color: GrimoireTheme.textMuted)),
            )
          : GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                ref.read(editorProvider.notifier).setActiveRow(-1);
              },
              child: SizedBox.expand(
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      child: DataTable(
                    sortColumnIndex: _sortColumn == null ? null : (columns.indexOf(_sortColumn!) + 1),
                    sortAscending: _sortAscending,
                    headingRowColor: WidgetStateProperty.all(GrimoireTheme.surfaceElevated),
                    dataRowColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return GrimoireTheme.accentPurple.withValues(alpha: 0.15);
                      }
                      return Colors.transparent;
                    }),
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    clipBehavior: Clip.antiAlias,
                    columns: [
                      const DataColumn(
                        label: Expanded(
                          child: Text(
                            '#',
                            maxLines: 1,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        columnWidth: FixedColumnWidth(60),
                      ),
                      for (final col in columns)
                        DataColumn(
                          onSort: (columnIndex, ascending) {
                            setState(() {
                              if (_sortColumn == col) {
                                _sortAscending = !_sortAscending;
                              } else {
                                _sortColumn = col;
                                _sortAscending = true;
                              }
                            });
                          },
                          label: Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (templateKeys.contains(col)) ...[
                                  const Icon(Icons.link, size: 11, color: GrimoireTheme.accentIndigo),
                                  const SizedBox(width: 3),
                                ],
                                Flexible(
                                  child: Text(
                                    col == 'qty' ? 'QTY (Copias)' : (col == 'card_status' ? 'Estado (Definitiva / Muestra)' : col),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: col == 'qty'
                                          ? GrimoireTheme.accentPink
                                          : (templateKeys.contains(col)
                                              ? GrimoireTheme.accentIndigo
                                              : GrimoireTheme.accentPurple),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          columnWidth: FixedColumnWidth(_getColumnWidth(col)),
                        ),
                      DataColumn(
                        label: Expanded(
                          child: Text(
                            ref.tr('actions'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        columnWidth: const FixedColumnWidth(130),
                      ),
                    ],
                    rows: [
                      for (final i in filteredIndices)
                        DataRow(
                          selected: i == activeRowIndex,
                          onSelectChanged: (selected) {
                            if (selected == true) {
                              ref.read(editorProvider.notifier).setActiveRow(i);
                            } else {
                              ref.read(editorProvider.notifier).setActiveRow(-1);
                            }
                          },
                          cells: [
                            DataCell(
                              Text('${i + 1}', style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                            ),
                            for (final col in columns)
                              if (col == 'card_status')
                                DataCell(
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      final current = (rows[i]['card_status'] ?? 'Definitiva').toString().trim();
                                      final next = current.toLowerCase() == 'muestra' ? 'Definitiva' : 'Muestra';
                                      ref.read(editorProvider.notifier).updateRowData(i, 'card_status', next);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (rows[i]['card_status']?.toString().toLowerCase() == 'muestra')
                                            ? GrimoireTheme.accentAmber.withValues(alpha: 0.18)
                                            : GrimoireTheme.accentEmerald.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: (rows[i]['card_status']?.toString().toLowerCase() == 'muestra')
                                              ? GrimoireTheme.accentAmber.withValues(alpha: 0.6)
                                              : GrimoireTheme.accentEmerald.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            (rows[i]['card_status']?.toString().toLowerCase() == 'muestra')
                                                ? Icons.bookmark_border
                                                : Icons.check_circle_outline,
                                            size: 11,
                                            color: (rows[i]['card_status']?.toString().toLowerCase() == 'muestra')
                                                ? GrimoireTheme.accentAmber
                                                : GrimoireTheme.accentEmerald,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              (rows[i]['card_status']?.toString().toLowerCase() == 'muestra') ? 'Muestra' : 'Definitiva',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: (rows[i]['card_status']?.toString().toLowerCase() == 'muestra')
                                                    ? GrimoireTheme.accentAmber
                                                    : GrimoireTheme.accentEmerald,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                DataCell(
                                  Text(
                                    rows[i][col]?.toString() ?? (col == 'qty' ? '1' : ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: col == 'qty' ? FontWeight.bold : FontWeight.normal,
                                      color: col == 'qty'
                                          ? GrimoireTheme.accentPink
                                          : (i == activeRowIndex ? Colors.white : GrimoireTheme.textSecondary),
                                    ),
                                  ),
                                  onTap: () => _editCellDialog(context, ref, i, col, rows[i][col]?.toString() ?? (col == 'qty' ? '1' : '')),
                                ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy_outlined, size: 16, color: GrimoireTheme.accentIndigo),
                                    tooltip: 'Duplicar carta',
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(28, 28),
                                      padding: const EdgeInsets.all(4),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      ref.read(editorProvider.notifier).duplicateRow(i);
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: GrimoireTheme.accentPink),
                                    tooltip: 'Eliminar carta',
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(28, 28),
                                      padding: const EdgeInsets.all(4),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      ref.read(editorProvider.notifier).removeRow(i);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }

  double _getColumnWidth(String col) {
    switch (col) {
      case 'qty':
        return 110.0;
      case 'card_status':
        return 160.0;
      case 'card_name':
        return 180.0;
      case 'game':
        return 120.0;
      case 'category':
        return 120.0;
      case 'cost':
        return 85.0;
      case 'type':
        return 120.0;
      case 'rarity':
        return 100.0;
      case 'attack':
        return 90.0;
      case 'defense':
        return 90.0;
      case 'rules_text':
        return 260.0;
      case 'art_url':
      case 'card_url':
      case 'category_url':
        return 180.0;
      default:
        return 140.0;
    }
  }

  void _showAddColumnDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        title: Text(ref.tr('add_new_column_title'), style: const TextStyle(fontSize: 14, color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: const InputDecoration(labelText: 'Nombre del campo (ej. qty, illustrator, set_number)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(editorProvider.notifier).addCustomColumnToDatabase(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(ref.tr('add')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsvFile(BuildContext context, WidgetRef ref, List<String> currentColumns, List<int> filteredIndices) async {
    final allRows = ref.read(editorProvider).project.rows;
    if (allRows.isEmpty) return;

    final targetRows = <Map<String, dynamic>>[];
    for (final i in filteredIndices) {
      if (i >= 0 && i < allRows.length) {
        targetRows.add(allRows[i]);
      }
    }

    if (targetRows.isEmpty) {
      if (context.mounted) {
        GrimoireToast.info(context, 'No hay cartas para exportar con los filtros seleccionados.');
      }
      return;
    }

    final headers = currentColumns;
    final csvRows = <List<dynamic>>[headers];
    for (final raw in targetRows) {
      final r = GameFolderService.normalizeCardRow(raw, defaultGame: raw['game']?.toString());
      csvRows.add(headers.map((h) => r[h]?.toString() ?? '').toList());
    }

    final csvContent = csv.encode(csvRows);
    final outputDir = await ExportService.getExportDirectory();
    final statusSuffix = _selectedStatus == 'Definitiva'
        ? '_Definitivas'
        : (_selectedStatus == 'Muestra' ? '_Muestras' : '');
    final fileName = _selectedGame == 'all'
        ? 'Grimoire_Database_Export$statusSuffix.csv'
        : 'Grimoire_${GameFolderService.sanitizeFolderName(_selectedGame)}$statusSuffix.csv';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsString('\uFEFF$csvContent', encoding: utf8);

    if (context.mounted) {
      GrimoireToast.success(
        context,
        file.path,
        title: ref.tr('csv_exported_success'),
      );
    }
  }

  void _editCellDialog(BuildContext context, WidgetRef ref, int rowIndex, String key, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    final isImageField = key.contains('url') || key.contains('art') || key.contains('image');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        title: Text('${ref.tr('edit_cell')} ($key) - #${rowIndex + 1}', style: const TextStyle(fontSize: 14)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  labelText: key,
                  suffixIcon: isImageField
                      ? IconButton(
                          icon: const Icon(Icons.image_search, color: GrimoireTheme.accentPurple, size: 20),
                          tooltip: 'Seleccionar archivo de imagen',
                          onPressed: () async {
                            final res = await FilePicker.pickFiles(type: FileType.image);
                            if (res.isNotEmpty && res.first.path != null) {
                              controller.text = res.first.path!;
                            }
                          },
                        )
                      : null,
                ),
                maxLines: key == 'rules_text' ? 4 : 1,
              ),
              if (isImageField) ...[
                const SizedBox(height: 8),
                const Text(
                  '💡 Puedes ingresar la ruta relativa dentro de assets/ o seleccionar un archivo.',
                  style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
            onPressed: () {
              ref.read(editorProvider.notifier).setActiveRow(rowIndex);
              ref.read(editorProvider.notifier).updateActiveRowData(key, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(ref.tr('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final filePath = files.first.path!;
        final file = File(filePath);
        final content = await file.readAsString();

        if (filePath.endsWith('.csv')) {
          final csvRows = csv.decode(content);
          if (csvRows.isNotEmpty) {
            final headers = csvRows.first.map((e) => e.toString().trim()).toList();
            final List<Map<String, dynamic>> newRows = [];

            for (int i = 1; i < csvRows.length; i++) {
              final row = csvRows[i];
              final map = <String, dynamic>{};
              for (int j = 0; j < headers.length && j < row.length; j++) {
                map[headers[j]] = row[j];
              }
              newRows.add(GameFolderService.normalizeCardRow(map));
            }

            for (final r in newRows) {
              ref.read(editorProvider.notifier).addRow(r);
            }
          }
        } else if (filePath.endsWith('.json')) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map) {
                final normalized = GameFolderService.normalizeCardRow(Map<String, dynamic>.from(item));
                ref.read(editorProvider.notifier).addRow(normalized);
              }
            }
          }
        }

        ref.read(editorProvider.notifier).syncTemplateVariablesToRows();

        if (context.mounted) {
          GrimoireToast.success(
            context,
            'Se han importado y alineado las cartas en el proyecto.',
            title: ref.tr('cards_imported_success'),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        GrimoireToast.error(
          context,
          e.toString(),
          title: 'Error importando archivo',
        );
      }
    }
  }

  void _showManageColumnsDialog(
    BuildContext context,
    WidgetRef ref, {
    required List<String> allAvailableColumns,
    required List<String> templateKeys,
    required List<String> customKeys,
    required Set<String> visibleColumns,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: GrimoireTheme.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.tune, color: GrimoireTheme.accentIndigo, size: 20),
                SizedBox(width: 8),
                Text('Columnas y Variables de Base de Datos', style: TextStyle(fontSize: 14, color: Colors.white)),
              ],
            ),
            content: SizedBox(
              width: 440,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Las variables usadas en tus capas se sincronizan automáticamente. Activa o desactiva columnas a conveniencia.',
                    style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.sync, size: 14, color: GrimoireTheme.accentCyan),
                        label: const Text('Detectar de Plantilla', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          ref.read(editorProvider.notifier).syncTemplateVariablesToRows();
                          setDialogState(() {
                            _hiddenColumns.clear();
                            _explicitlyShownColumns.clear();
                          });
                          setState(() {});
                        },
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _hiddenColumns.clear();
                            for (final c in allAvailableColumns) {
                              _explicitlyShownColumns.add(c);
                            }
                          });
                          setState(() {});
                        },
                        child: const Text('Mostrar Todas', style: TextStyle(fontSize: 11, color: GrimoireTheme.accentIndigo)),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _hiddenColumns.clear();
                            _explicitlyShownColumns.clear();
                          });
                          setState(() {});
                        },
                        child: const Text('Solo Relevantes', style: TextStyle(fontSize: 11, color: GrimoireTheme.accentAmber)),
                      ),
                    ],
                  ),
                  const Divider(color: GrimoireTheme.borderSubtle, height: 16),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: allAvailableColumns.length,
                      separatorBuilder: (_, _) => const Divider(color: GrimoireTheme.borderSubtle, height: 1),
                      itemBuilder: (context, idx) {
                        final col = allAvailableColumns[idx];
                        const coreKeys = ['card_name', 'game', 'category', 'card_status', 'qty'];
                        final isCore = coreKeys.contains(col);
                        final isTemplate = templateKeys.contains(col);
                        final isCustom = customKeys.contains(col);
                        final isVisible = isCore || (!_hiddenColumns.contains(col) && (visibleColumns.contains(col) || _explicitlyShownColumns.contains(col)));

                        return SwitchListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          title: Row(
                            children: [
                              Text(
                                col == 'qty' ? 'QTY (Copias)' : (col == 'card_status' ? 'Estado (Definitiva / Muestra)' : col),
                                style: TextStyle(
                                  color: isCore
                                      ? Colors.white
                                      : (isTemplate ? GrimoireTheme.accentIndigo : Colors.white),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isCore)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Núcleo', style: TextStyle(fontSize: 9, color: GrimoireTheme.textMuted)),
                                )
                              else if (isTemplate)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: GrimoireTheme.accentIndigo.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.5)),
                                  ),
                                  child: const Text('Plantilla', style: TextStyle(fontSize: 9, color: GrimoireTheme.accentIndigo, fontWeight: FontWeight.bold)),
                                )
                              else if (isCustom)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: GrimoireTheme.accentAmber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Personalizada', style: TextStyle(fontSize: 9, color: GrimoireTheme.accentAmber)),
                                ),
                            ],
                          ),
                          value: isVisible,
                          onChanged: isCore
                              ? null
                              : (val) {
                                  setDialogState(() {
                                    if (val) {
                                      _hiddenColumns.remove(col);
                                      _explicitlyShownColumns.add(col);
                                    } else {
                                      _explicitlyShownColumns.remove(col);
                                      _hiddenColumns.add(col);
                                    }
                                  });
                                  setState(() {});
                                },
                          secondary: isCustom
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16, color: GrimoireTheme.accentAmber),
                                      tooltip: ref.tr('rename_column'),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _showRenameColumnDialog(context, ref, col);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: GrimoireTheme.accentPink),
                                      tooltip: ref.tr('delete_column'),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _confirmDeleteColumn(context, ref, col);
                                      },
                                    ),
                                  ],
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ref.tr('close')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRenameColumnDialog(BuildContext context, WidgetRef ref, String oldKey) {
    final controller = TextEditingController(text: oldKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        title: Text('${ref.tr('rename_column')} "$oldKey"', style: const TextStyle(fontSize: 14, color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: InputDecoration(labelText: ref.tr('new_column_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(editorProvider.notifier).renameCustomColumnInDatabase(oldKey, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(ref.tr('save')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteColumn(BuildContext context, WidgetRef ref, String colKey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        title: Text(ref.tr('delete_column_title'), style: const TextStyle(fontSize: 14, color: Colors.white)),
        content: Text(
          '${ref.tr('delete_column_confirm')} ("$colKey")',
          style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentPink),
            onPressed: () {
              ref.read(editorProvider.notifier).removeCustomColumnFromDatabase(colKey);
              Navigator.pop(ctx);
            },
            child: Text(ref.tr('delete')),
          ),
        ],
      ),
    );
  }
}
