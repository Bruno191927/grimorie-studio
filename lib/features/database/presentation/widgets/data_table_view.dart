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
  String? _sortColumn;
  bool _sortAscending = true;

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
    final rows = editorState.project.rows;
    final activeRowIndex = editorState.project.activeRowIndex;

    // Collect available games for game filtering
    final availableGames = <String>{};
    for (final r in rows) {
      final g = (r['game'] ?? '').toString().trim();
      if (g.isNotEmpty) availableGames.add(g);
    }
    final sortedGames = availableGames.toList()..sort();

    // Collect all unique keys from all rows, ensuring card_name, game, category, qty come first
    const internalKeys = {'template_id', 'is_category_default', 'is_game_default', 'rules'};
    final List<String> primaryKeys = [
      'card_name',
      'game',
      'category',
      'qty',
      'cost',
      'type',
      'rarity',
      'attack',
      'defense',
      'rules_text',
      'art_url',
    ];
    final Set<String> extraKeys = {};
    for (final r in rows) {
      for (final k in r.keys) {
        if (!primaryKeys.contains(k) && !internalKeys.contains(k)) {
          extraKeys.add(k);
        }
      }
    }
    final columns = [...primaryKeys, ...extraKeys];

    final filteredIndices = <int>[];
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (_selectedGame != 'all') {
        final rowGame = (row['game'] ?? '').toString().trim();
        if (rowGame.toLowerCase() != _selectedGame.toLowerCase()) {
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
        title: Row(
          children: [
            const Icon(Icons.table_chart_outlined, color: GrimoireTheme.accentPurple, size: 20),
            const SizedBox(width: 8),
            Text(ref.tr('db_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        actions: [
          // Manage custom columns button
          if (extraKeys.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: GrimoireTheme.accentIndigo),
              icon: const Icon(Icons.tune, size: 15),
              label: Text('${ref.tr('columns')} (${extraKeys.length})', style: const TextStyle(fontSize: 12)),
              onPressed: () => _showManageColumnsDialog(context, ref, extraKeys.toList()),
            ),
          // Add custom column button
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: GrimoireTheme.accentAmber),
            icon: const Icon(Icons.view_column_outlined, size: 15),
            label: Text(ref.tr('new_column'), style: const TextStyle(fontSize: 12)),
            onPressed: () => _showAddColumnDialog(context, ref),
          ),
          const SizedBox(width: 4),
          // Export CSV button
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: GrimoireTheme.accentEmerald),
            tooltip: _selectedGame == 'all' ? ref.tr('export_current_csv') : '${ref.tr('export_csv')} ($_selectedGame)',
            onPressed: () => _exportCsvFile(context, ref),
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
                            child: Text(
                              col == 'qty' ? 'QTY (Copias)' : col,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: col == 'qty' ? GrimoireTheme.accentPink : GrimoireTheme.accentPurple,
                              ),
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
                              Text('', style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                            ),
                            for (final col in columns)
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
        return 160.0;
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

  Future<void> _exportCsvFile(BuildContext context, WidgetRef ref) async {
    final allRows = ref.read(editorProvider).project.rows;
    if (allRows.isEmpty) return;

    final targetRows = _selectedGame == 'all'
        ? allRows
        : allRows.where((r) => (r['game'] ?? '').toString().toLowerCase() == _selectedGame.toLowerCase()).toList();

    if (targetRows.isEmpty) return;

    const internalKeys = {'template_id', 'is_category_default', 'is_game_default', 'rules'};
    final List<String> standardHeaders = [
      'card_name',
      'game',
      'category',
      'qty',
      'cost',
      'type',
      'rarity',
      'attack',
      'defense',
      'rules_text',
      'prompt',
      'art_url',
      'icon',
      'art_color',
      'creator',
    ];

    final Set<String> extraHeaders = {};
    for (final r in targetRows) {
      for (final k in r.keys) {
        if (!standardHeaders.contains(k) && !internalKeys.contains(k)) {
          extraHeaders.add(k);
        }
      }
    }

    final headers = [...standardHeaders, ...extraHeaders];
    final csvRows = <List<dynamic>>[headers];
    for (final raw in targetRows) {
      final r = GameFolderService.normalizeCardRow(raw, defaultGame: raw['game']?.toString());
      csvRows.add(headers.map((h) => r[h]?.toString() ?? '').toList());
    }

    final csvContent = csv.encode(csvRows);
    final outputDir = await ExportService.getExportDirectory();
    final fileName = _selectedGame == 'all'
        ? 'Grimoire_Database_Export.csv'
        : 'Grimoire_${GameFolderService.sanitizeFolderName(_selectedGame)}_data.csv';
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        title: Text('${ref.tr('edit_cell')} ($key) - #${rowIndex + 1}', style: const TextStyle(fontSize: 14)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: InputDecoration(labelText: key),
          maxLines: key == 'rules_text' ? 4 : 1,
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

  void _showManageColumnsDialog(BuildContext context, WidgetRef ref, List<String> customCols) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        title: const Row(
          children: [
            Icon(Icons.tune, color: GrimoireTheme.accentIndigo, size: 20),
            SizedBox(width: 8),
            Text('Gestionar Columnas Personalizadas', style: TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: customCols.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No hay columnas personalizadas creadas.', style: TextStyle(color: GrimoireTheme.textMuted, fontSize: 12)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: customCols.length,
                  separatorBuilder: (_, _) => const Divider(color: GrimoireTheme.borderSubtle, height: 1),
                  itemBuilder: (context, idx) {
                    final col = customCols[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(col, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      trailing: Row(
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
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('close')),
          ),
        ],
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
