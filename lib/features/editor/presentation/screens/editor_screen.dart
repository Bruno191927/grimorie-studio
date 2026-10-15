import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../models/card_template.dart';
import '../providers/editor_provider.dart';
import '../widgets/card_canvas.dart';
import '../widgets/layer_tree_panel.dart';
import '../widgets/inspector_panel.dart';
import '../../../export/presentation/dialogs/export_options_dialog.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final GlobalKey repaintBoundaryKey;

  const EditorScreen({super.key, required this.repaintBoundaryKey});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  Future<void> _handleQuickExport() async {
    await ExportOptionsDialog.show(
      context,
      repaintBoundaryKey: widget.repaintBoundaryKey,
    );
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: DropdownButton<int>(
                    value: activeRowIndex,
                    isExpanded: true,
                    dropdownColor: GrimoireTheme.surfaceElevated,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    underline: const SizedBox.shrink(),
                    items: [
                      for (int i = 0; i < rows.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '#${i + 1} - ${rows[i]['card_name'] ?? "Card"} (${rows[i]['cost'] ?? "?"} ${ref.tr('mana')})',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(editorProvider.notifier).setActiveRow(val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 14),
                const VerticalDivider(width: 1),
                const SizedBox(width: 14),

                // Active Template Selector
                Text(ref.tr('active_template'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: DropdownButton<int>(
                    value: editorState.project.activeTemplateIndex.clamp(0, editorState.project.templates.length - 1),
                    isExpanded: true,
                    dropdownColor: GrimoireTheme.surfaceElevated,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    underline: const SizedBox.shrink(),
                    items: [
                      for (int i = 0; i < editorState.project.templates.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            editorState.project.templates[i].name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(editorProvider.notifier).setActiveTemplate(val);
                      }
                    },
                  ),
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

                const SizedBox(width: 14),
                const VerticalDivider(width: 1),
                const SizedBox(width: 14),

                // Front / Back Side Switcher Pill
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => ref.read(editorProvider.notifier).toggleSide(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: editorState.currentSide == CardSide.front
                          ? GrimoireTheme.accentPurple.withValues(alpha: 0.15)
                          : GrimoireTheme.accentIndigo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: editorState.currentSide == CardSide.front
                            ? GrimoireTheme.accentPurple.withValues(alpha: 0.5)
                            : GrimoireTheme.accentIndigo.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          editorState.currentSide == CardSide.front ? Icons.flip_to_front : Icons.flip_to_back,
                          size: 15,
                          color: editorState.currentSide == CardSide.front ? GrimoireTheme.accentPurple : GrimoireTheme.accentIndigo,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          editorState.currentSide == CardSide.front ? ref.tr('card_side_front') : ref.tr('card_side_back'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: editorState.currentSide == CardSide.front ? const Color(0xFFE9D5FF) : const Color(0xFFC7D2FE),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.sync, size: 12, color: GrimoireTheme.textMuted),
                      ],
                    ),
                  ),
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
                  icon: const Icon(Icons.print_outlined, size: 14),
                  label: Text(ref.tr('render_300dpi_card')),
                  onPressed: _handleQuickExport,
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
