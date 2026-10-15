import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../providers/editor_provider.dart';
import '../widgets/card_canvas.dart';
import '../widgets/layer_tree_panel.dart';
import '../widgets/inspector_panel.dart';
import '../../../export/services/export_service.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final GlobalKey repaintBoundaryKey;

  const EditorScreen({super.key, required this.repaintBoundaryKey});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _isExporting = false;

  Future<void> _handleQuickExport() async {
    setState(() => _isExporting = true);

    final imageBytes = await ExportService.captureBoundaryToImage(widget.repaintBoundaryKey);
    if (!mounted) return;

    setState(() => _isExporting = false);

    if (imageBytes != null) {
      final activeRow = ref.read(editorProvider).project.activeRow;
      final cardName = activeRow['card_name']?.toString() ?? 'grimoire_card';

      final pdfFile = await ExportService.exportCardsToPdf(
        cardImages: [imageBytes],
        fileName: cardName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GrimoireTheme.accentEmerald,
            content: Text('Card exported at 300 DPI to: ${pdfFile.path}'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GrimoireTheme.accentPink,
            content: Text('Failed to render 300 DPI image.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final rows = editorState.project.rows;
    final activeRowIndex = editorState.project.activeRowIndex;

    return Scaffold(
      backgroundColor: GrimoireTheme.bgCanvas,
      body: Column(
        children: [
          // Editor Sub-Toolbar
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: GrimoireTheme.surfacePanel,
              border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                // Active Card Selector from Database Rows
                Text(ref.tr('active_card'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: activeRowIndex,
                  dropdownColor: GrimoireTheme.surfaceElevated,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  underline: const SizedBox.shrink(),
                  items: [
                    for (int i = 0; i < rows.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          '#${i + 1} - ${rows[i]['card_name'] ?? "Card"} (${rows[i]['cost'] ?? "?"} Mana)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(editorProvider.notifier).setActiveRow(val);
                    }
                  },
                ),
                const SizedBox(width: 16),
                const VerticalDivider(width: 1),
                const SizedBox(width: 16),

                // Snapping & Grid Toggles
                IconButton(
                  icon: Icon(
                    Icons.grid_on,
                    size: 16,
                    color: editorState.showGrid ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                  ),
                  tooltip: ref.tr('toggle_grid'),
                  onPressed: () => ref.read(editorProvider.notifier).toggleGrid(),
                ),
                IconButton(
                  icon: Icon(
                    Icons.straighten,
                    size: 16,
                    color: editorState.showSnapping ? GrimoireTheme.accentPink : GrimoireTheme.textMuted,
                  ),
                  tooltip: ref.tr('toggle_snapping'),
                  onPressed: () => ref.read(editorProvider.notifier).toggleSnapping(),
                ),
                const SizedBox(width: 8),
                // Zoom Controls
                IconButton(
                  icon: const Icon(Icons.remove, size: 16, color: GrimoireTheme.textSecondary),
                  tooltip: ref.tr('zoom_out'),
                  onPressed: () => ref.read(editorProvider.notifier).setZoom(editorState.zoom - 0.1),
                ),
                Text(
                  '${(editorState.zoom * 100).toInt()}%',
                  style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary, fontFamily: 'monospace'),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16, color: GrimoireTheme.textSecondary),
                  tooltip: ref.tr('zoom_in'),
                  onPressed: () => ref.read(editorProvider.notifier).setZoom(editorState.zoom + 0.1),
                ),

                const Spacer(),

                // 300 DPI Export Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GrimoireTheme.accentIndigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print_outlined, size: 14),
                  label: Text(_isExporting ? ref.tr('rendering_300dpi') : ref.tr('render_300dpi_card')),
                  onPressed: _isExporting ? null : _handleQuickExport,
                ),
              ],
            ),
          ),

          // Three-Panel Area
          Expanded(
            child: Row(
              children: [
                // Left: Layers Tree Panel
                const LayerTreePanel(),

                // Center: Interactive Canvas
                Expanded(
                  child: Container(
                    color: const Color(0xFF090C12),
                    child: CardCanvas(repaintBoundaryKey: widget.repaintBoundaryKey),
                  ),
                ),

                // Right: Inspector Panel
                const InspectorPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
