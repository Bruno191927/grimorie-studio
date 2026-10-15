import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';

class DataTableView extends ConsumerWidget {
  const DataTableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final rows = editorState.project.rows;
    final activeRowIndex = editorState.project.activeRowIndex;

    // Collect all unique keys from all rows
    final Set<String> allKeys = {'card_name', 'cost', 'type', 'rarity', 'attack', 'defense', 'rules_text'};
    for (final r in rows) {
      allKeys.addAll(r.keys);
    }
    final columns = allKeys.toList();

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
                '${rows.length} ${ref.tr('total_cards')}',
                style: const TextStyle(fontSize: 11, color: GrimoireTheme.accentPurple, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: GrimoireTheme.accentIndigo),
            tooltip: ref.tr('import_file'),
            onPressed: () => _importFile(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: GrimoireTheme.accentEmerald),
            tooltip: ref.tr('add_row'),
            onPressed: () {
              ref.read(editorProvider.notifier).addRow({
                'card_name': 'New Card ${rows.length + 1}',
                'cost': '1',
                'type': 'Creature',
                'rarity': 'Common',
                'attack': '1',
                'defense': '1',
                'rules_text': 'Card rules text goes here.',
              });
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
          : Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(GrimoireTheme.surfaceElevated),
                    dataRowColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return GrimoireTheme.accentPurple.withValues(alpha: 0.15);
                      }
                      return Colors.transparent;
                    }),
                    columns: [
                      const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      for (final col in columns)
                        DataColumn(
                          label: Text(
                            col,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: GrimoireTheme.accentPurple,
                            ),
                          ),
                        ),
                      DataColumn(label: Text(ref.tr('actions'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                    rows: [
                      for (int i = 0; i < rows.length; i++)
                        DataRow(
                          selected: i == activeRowIndex,
                          onSelectChanged: (_) {
                            ref.read(editorProvider.notifier).setActiveRow(i);
                          },
                          cells: [
                            DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted))),
                            for (final col in columns)
                              DataCell(
                                Text(
                                  rows[i][col]?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: i == activeRowIndex ? Colors.white : GrimoireTheme.textSecondary,
                                  ),
                                ),
                                onTap: () => _editCellDialog(context, ref, i, col, rows[i][col]?.toString() ?? ''),
                              ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: GrimoireTheme.accentPink),
                                onPressed: () {
                                  ref.read(editorProvider.notifier).removeRow(i);
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
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
              newRows.add(map);
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
                ref.read(editorProvider.notifier).addRow(Map<String, dynamic>.from(item));
              }
            }
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: GrimoireTheme.accentEmerald,
              content: Text('Cards imported successfully!'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GrimoireTheme.accentPink,
            content: Text('Error importing file: $e'),
          ),
        );
      }
    }
  }
}
