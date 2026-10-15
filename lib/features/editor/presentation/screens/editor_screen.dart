import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../models/card_template.dart';
import '../../models/game_category.dart';
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
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: DropdownButton<int>(
                    value: rows.isEmpty ? null : activeRowIndex.clamp(0, rows.length - 1),
                    isExpanded: true,
                    dropdownColor: GrimoireTheme.surfaceElevated,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    underline: const SizedBox.shrink(),
                    items: [
                      for (int i = 0; i < rows.length; i++) ...[
                        DropdownMenuItem(
                          value: i,
                          child: Builder(
                            builder: (context) {
                              final r = rows[i];
                              final cardName = (r['card_name'] ?? 'Card').toString();
                              final costStr = (r['cost'] ?? '').toString().trim();
                              final catStr = (r['category'] ?? '').toString().trim();
                              final badge = costStr.isNotEmpty
                                  ? '($costStr ${ref.tr('mana')})'
                                  : (catStr.isNotEmpty ? '[$catStr]' : '');
                              return Text(
                                '#${i + 1} - $cardName $badge',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(editorProvider.notifier).setActiveRow(val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
                const SizedBox(width: 8),

                // Active Card Category Selector
                _buildActiveCardCategorySelector(context, ref, editorState),
                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
                const SizedBox(width: 8),

                // Active Template Selector
                Text(ref.tr('active_template'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
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
                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
                const SizedBox(width: 8),

                // Snapping & Grid Toggles
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    Icons.grid_on,
                    size: 16,
                    color: editorState.showGrid ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                  ),
                  tooltip: ref.tr('toggle_grid'),
                  onPressed: () => ref.read(editorProvider.notifier).toggleGrid(),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    Icons.straighten,
                    size: 16,
                    color: editorState.showSnapping ? GrimoireTheme.accentPink : GrimoireTheme.textMuted,
                  ),
                  tooltip: ref.tr('toggle_snapping'),
                  onPressed: () => ref.read(editorProvider.notifier).toggleSnapping(),
                ),
                const SizedBox(width: 6),
                // Zoom Controls
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(Icons.remove, size: 16, color: GrimoireTheme.textSecondary),
                  tooltip: ref.tr('zoom_out'),
                  onPressed: () => ref.read(editorProvider.notifier).setZoom(editorState.zoom - 0.1),
                ),
                Text(
                  '${(editorState.zoom * 100).toInt()}%',
                  style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary, fontFamily: 'monospace'),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(Icons.add, size: 16, color: GrimoireTheme.textSecondary),
                  tooltip: ref.tr('zoom_in'),
                  onPressed: () => ref.read(editorProvider.notifier).setZoom(editorState.zoom + 0.1),
                ),

                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
                const SizedBox(width: 8),

                // Front / Back Side Switcher Pill
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => ref.read(editorProvider.notifier).toggleSide(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                        const SizedBox(width: 5),
                        Text(
                          editorState.currentSide == CardSide.front ? ref.tr('card_side_front') : ref.tr('card_side_back'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: editorState.currentSide == CardSide.front ? const Color(0xFFE9D5FF) : const Color(0xFFC7D2FE),
                          ),
                        ),
                        const SizedBox(width: 4),
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

  Widget _buildActiveCardCategorySelector(
    BuildContext context,
    WidgetRef ref,
    EditorState editorState,
  ) {
    if (editorState.project.rows.isEmpty) return const SizedBox.shrink();

    final activeRow = editorState.project.activeRow;
    final activeGame = (activeRow['game'] ?? 'Magic').toString();
    final activeCategory = (activeRow['category'] ?? '').toString();
    final gameCategories = ref.read(editorProvider.notifier).getCategoriesForGame(activeGame);

    final matchingCategory = gameCategories.firstWhere(
      (c) => c.name.toLowerCase() == activeCategory.toLowerCase(),
      orElse: () => GameCategory(
        id: '',
        name: activeCategory.isNotEmpty ? activeCategory : ref.tr('no_category'),
        icon: '🏷️',
      ),
    );

    final catColor = matchingCategory.defaultColor != 0
        ? Color(matchingCategory.defaultColor)
        : GrimoireTheme.accentPurple;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(ref.tr('category_label'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: ref.tr('select_category'),
          color: GrimoireTheme.surfaceElevated,
          offset: const Offset(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: GrimoireTheme.borderSubtle),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: catColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  matchingCategory.icon.isNotEmpty ? matchingCategory.icon : '🏷️',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 95),
                  child: Text(
                    activeCategory.isNotEmpty ? activeCategory : ref.tr('no_category'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: catColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 16, color: GrimoireTheme.textMuted),
              ],
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              height: 28,
              child: Text(
                '${ref.tr('game')}: $activeGame',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.accentPurple),
              ),
            ),
            const PopupMenuDivider(height: 4),
            for (final cat in gameCategories)
              PopupMenuItem<String>(
                value: cat.name,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(cat.defaultColor),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(cat.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: cat.name == activeCategory ? FontWeight.bold : FontWeight.normal,
                          color: cat.name == activeCategory ? GrimoireTheme.accentPurple : Colors.white,
                        ),
                      ),
                    ),
                    if (cat.name == activeCategory)
                      const Icon(Icons.check, size: 14, color: GrimoireTheme.accentPurple),
                  ],
                ),
              ),
            const PopupMenuDivider(height: 4),
            PopupMenuItem<String>(
              value: '',
              child: Row(
                children: [
                  const Icon(Icons.block, size: 14, color: GrimoireTheme.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    ref.tr('no_category'),
                    style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (chosenCategory) {
            if (chosenCategory != activeCategory) {
              ref.read(editorProvider.notifier).setCategoryForActiveCard(chosenCategory);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: GrimoireTheme.surfaceElevated,
                  duration: const Duration(seconds: 4),
                  content: Text(
                    chosenCategory.isEmpty
                        ? ref.tr('no_category')
                        : '${ref.tr('category_label')}: $chosenCategory',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  action: chosenCategory.isNotEmpty
                      ? SnackBarAction(
                          label: ref.tr('apply_category_model'),
                          textColor: GrimoireTheme.accentPurple,
                          onPressed: () {
                            final cat = gameCategories.firstWhere((c) => c.name == chosenCategory);
                            ref.read(editorProvider.notifier).applyCategoryModelToActiveCard(cat);
                          },
                        )
                      : null,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
