import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../models/card_template.dart';
import '../../models/game_category.dart';
import '../providers/editor_provider.dart';
import '../widgets/card_canvas.dart';
import '../widgets/layer_tree_panel.dart';
import '../widgets/inspector_panel.dart';
import '../widgets/game_assets_panel.dart';
import '../widgets/card_renderer_widget.dart';
import '../dialogs/layer_delete_dialog.dart';
import '../../../export/presentation/dialogs/export_options_dialog.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';
import '../../../../core/widgets/grimoire_toast.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final GlobalKey repaintBoundaryKey;

  const EditorScreen({super.key, required this.repaintBoundaryKey});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _showCardsFilmstrip = false;

  Future<void> _handleQuickExport() async {
    await ExportOptionsDialog.show(
      context,
      repaintBoundaryKey: widget.repaintBoundaryKey,
    );
  }

  bool _isEditingText() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    if (focus.debugLabel == 'EditableText') return true;
    final ctx = focus.context;
    if (ctx != null) {
      if (ctx.widget is EditableText ||
          ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
        return true;
      }
    }
    return false;
  }

  void _handleDeleteSelectedLayer() {
    if (_isEditingText()) return;
    final editorState = ref.read(editorProvider);
    if (editorState.selectedLayerId == null && editorState.selectedLayerIds.isEmpty) {
      return;
    }
    LayerDeleteDialog.show(context: context, ref: ref);
  }

  void _handleCopyLayers() {
    if (_isEditingText()) return;
    final count = ref.read(editorProvider.notifier).copySelectedLayers();
    if (count > 0 && mounted) {
      GrimoireToast.info(
        context,
        '$count ${ref.tr('selected_layers_count')} copiadas',
      );
    }
  }

  void _handlePasteLayers() {
    if (_isEditingText()) return;
    ref.read(editorProvider.notifier).pasteLayers();
  }

  void _handleDuplicateLayers() {
    if (_isEditingText()) return;
    ref.read(editorProvider.notifier).duplicateSelectedLayers();
  }

  void _handleDuplicateActiveCard() {
    if (_isEditingText()) return;
    final state = ref.read(editorProvider);
    if (state.project.rows.isNotEmpty) {
      ref.read(editorProvider.notifier).duplicateRow(state.project.activeRowIndex);
      if (mounted) {
        GrimoireToast.success(
          context,
          ref.tr('card_duplicated_toast'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final rows = editorState.project.rows;
    final activeRowIndex = editorState.project.activeRowIndex;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        // When typing in any text field or inline editor, let text keys (backspace, delete, arrows, ctrl+c/v) pass freely
        if (_isEditingText()) {
          return KeyEventResult.ignored;
        }

        final isCtrl = HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        if (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace) {
          _handleDeleteSelectedLayer();
          return KeyEventResult.handled;
        }

        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
          _handleCopyLayers();
          return KeyEventResult.handled;
        }

        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyV) {
          _handlePasteLayers();
          return KeyEventResult.handled;
        }

        if (isCtrl && !isShift && event.logicalKey == LogicalKeyboardKey.keyD) {
          _handleDuplicateLayers();
          return KeyEventResult.handled;
        }

        if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyD) {
          _handleDuplicateActiveCard();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Scaffold(
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
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Active Card Selector from Database Rows
                        Text(ref.tr('active_card'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                        const SizedBox(width: 4),

                        // Quick Previous Card Button
                        IconButton(
                          key: const Key('editor_prev_card_button'),
                          tooltip: 'Carta anterior',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          icon: Icon(
                            Icons.chevron_left,
                            size: 18,
                            color: activeRowIndex > 0 ? Colors.white : GrimoireTheme.textMuted.withValues(alpha: 0.3),
                          ),
                          onPressed: activeRowIndex > 0
                              ? () => ref.read(editorProvider.notifier).setActiveRow(activeRowIndex - 1)
                              : null,
                        ),

                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: DropdownButton<int>(
                            value: (rows.isEmpty || activeRowIndex < 0 || activeRowIndex >= rows.length)
                                ? null
                                : activeRowIndex,
                            hint: Text(
                              rows.isEmpty ? 'Sin cartas' : 'Seleccionar carta',
                              style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
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

                        // Quick Next Card Button
                        IconButton(
                          key: const Key('editor_next_card_button'),
                          tooltip: 'Siguiente carta',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          icon: Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: activeRowIndex < rows.length - 1 ? Colors.white : GrimoireTheme.textMuted.withValues(alpha: 0.3),
                          ),
                          onPressed: activeRowIndex < rows.length - 1
                              ? () => ref.read(editorProvider.notifier).setActiveRow(activeRowIndex + 1)
                              : null,
                        ),
                        const SizedBox(width: 4),
                        // Duplicate Card Button
                        IconButton(
                          key: const Key('editor_duplicate_card_button'),
                          tooltip: '${ref.tr('duplicate_card')} (Ctrl+Shift+D)',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          icon: const Icon(Icons.copy_all_rounded, size: 16, color: GrimoireTheme.accentPurple),
                          onPressed: rows.isNotEmpty
                              ? () {
                                  ref.read(editorProvider.notifier).duplicateRow(activeRowIndex);
                                  GrimoireToast.success(
                                    context,
                                    ref.tr('card_duplicated_toast'),
                                  );
                                }
                              : null,
                        ),
                        const SizedBox(width: 4),
                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
                const SizedBox(width: 8),

                // Active Card Category Selector
                _buildActiveCardCategorySelector(context, ref, editorState),
                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
                const SizedBox(width: 8),

                // Active Template Selector + Manage Template Menu
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
                        final tpl = editorState.project.templates[val];
                        ref.read(editorProvider.notifier).updateActiveRowData('template_id', tpl.id);
                      }
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  key: const Key('template_actions_menu'),
                  tooltip: 'Gestionar Plantillas y Tamaño',
                  color: GrimoireTheme.surfaceElevated,
                  icon: const Icon(Icons.more_vert, size: 16, color: GrimoireTheme.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onSelected: (action) => _handleTemplateMenuAction(context, action, editorState),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'new_template',
                      child: Row(
                        children: [
                          Icon(Icons.add_box_outlined, size: 15, color: GrimoireTheme.accentPurple),
                          SizedBox(width: 8),
                          Text('Nueva Plantilla', style: TextStyle(fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate_template',
                      child: Row(
                        children: [
                          Icon(Icons.copy_outlined, size: 15, color: GrimoireTheme.accentIndigo),
                          SizedBox(width: 8),
                          Text('Duplicar Plantilla Activa', style: TextStyle(fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename_template',
                      child: Row(
                        children: [
                          Icon(Icons.drive_file_rename_outline, size: 15, color: GrimoireTheme.accentAmber),
                          SizedBox(width: 8),
                          Text('Renombrar Plantilla', style: TextStyle(fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                    if (editorState.project.templates.length > 1)
                      const PopupMenuItem(
                        value: 'delete_template',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 15, color: GrimoireTheme.accentPink),
                            SizedBox(width: 8),
                            Text('Eliminar Plantilla', style: TextStyle(fontSize: 12, color: GrimoireTheme.accentPink)),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      enabled: false,
                      height: 24,
                      child: Text(
                        'PLANTILLAS PREDEFINIDAS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textMuted),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'preset_tcg_fantasy',
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 15, color: GrimoireTheme.accentPurple),
                          SizedBox(width: 8),
                          Text('TCG Fantasía / Criatura', style: TextStyle(fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'preset_boardgame_action',
                      child: Row(
                        children: [
                          Icon(Icons.flash_on, size: 15, color: GrimoireTheme.accentAmber),
                          SizedBox(width: 8),
                          Text('Juego de Mesa / Acción', style: TextStyle(fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'preset_tarot_hero',
                      child: Row(
                        children: [
                          Icon(Icons.shield, size: 15, color: GrimoireTheme.accentEmerald),
                          SizedBox(width: 8),
                          Text('Tarot / Héroe Legendario', style: TextStyle(fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      enabled: false,
                      height: 24,
                      child: Text(
                        'TAMAÑO FÍSICO DE CARTA',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textMuted),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'size_poker',
                      child: Text('Poker Estándar (63.5 × 88.9 mm)', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                    const PopupMenuItem(
                      value: 'size_japanese',
                      child: Text('Japonés / Yu-Gi-Oh (59 × 86 mm)', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                    const PopupMenuItem(
                      value: 'size_tarot',
                      child: Text('Tarot Grande (70 × 120 mm)', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                    const PopupMenuItem(
                      value: 'size_minieuro',
                      child: Text('Mini Euro (44 × 68 mm)', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const VerticalDivider(width: 1),
                const SizedBox(width: 6),

                // Undo / Redo Buttons
                IconButton(
                  key: const Key('editor_undo_btn'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    Icons.undo,
                    size: 16,
                    color: editorState.canUndo ? Colors.white : GrimoireTheme.textMuted.withValues(alpha: 0.4),
                  ),
                  tooltip: 'Deshacer (Ctrl+Z)',
                  onPressed: editorState.canUndo ? () => ref.read(editorProvider.notifier).undo() : null,
                ),
                IconButton(
                  key: const Key('editor_redo_btn'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    Icons.redo,
                    size: 16,
                    color: editorState.canRedo ? Colors.white : GrimoireTheme.textMuted.withValues(alpha: 0.4),
                  ),
                  tooltip: 'Rehacer (Ctrl+Y)',
                  onPressed: editorState.canRedo ? () => ref.read(editorProvider.notifier).redo() : null,
                ),
                const SizedBox(width: 6),
                const VerticalDivider(width: 1),
                const SizedBox(width: 6),

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
                IconButton(
                  key: const Key('toolbar_toggle_bleed_guides'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    Icons.crop_free,
                    size: 16,
                    color: editorState.showBleedGuides ? const Color(0xFF06B6D4) : GrimoireTheme.textMuted,
                  ),
                  tooltip: 'Guías de sangrado y corte seguro (3mm)',
                  onPressed: () => ref.read(editorProvider.notifier).toggleBleedGuides(),
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
                Tooltip(
                  message: 'Clic para restablecer a 100%',
                  child: InkWell(
                    onTap: () => ref.read(editorProvider.notifier).setZoom(1.0),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141724),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: GrimoireTheme.borderSubtle),
                      ),
                      child: Text(
                        '${(editorState.zoom * 100).toInt()}%',
                        style: const TextStyle(fontSize: 10.5, color: GrimoireTheme.textSecondary, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
                const SizedBox(width: 8),

                // Collapsible Assets Panel Toggle Pill
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => ref.read(editorProvider.notifier).toggleAssetsPanel(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: editorState.showAssetsPanel
                          ? GrimoireTheme.accentPurple.withValues(alpha: 0.2)
                          : const Color(0xFF161928),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: editorState.showAssetsPanel
                            ? GrimoireTheme.accentPurple
                            : GrimoireTheme.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          editorState.showAssetsPanel ? Icons.photo_library : Icons.photo_library_outlined,
                          size: 15,
                          color: editorState.showAssetsPanel ? const Color(0xFFE9D5FF) : GrimoireTheme.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          ref.tr('game_assets'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: editorState.showAssetsPanel ? Colors.white : GrimoireTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                const VerticalDivider(width: 1),
                const SizedBox(width: 8),

                // Collapsible Cards Filmstrip Toggle Pill
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _showCardsFilmstrip = !_showCardsFilmstrip),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _showCardsFilmstrip
                          ? GrimoireTheme.accentPurple.withValues(alpha: 0.2)
                          : const Color(0xFF161928),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _showCardsFilmstrip
                            ? GrimoireTheme.accentPurple
                            : GrimoireTheme.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showCardsFilmstrip ? Icons.style : Icons.style_outlined,
                          size: 15,
                          color: _showCardsFilmstrip ? const Color(0xFFE9D5FF) : GrimoireTheme.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Cartas (${rows.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _showCardsFilmstrip ? Colors.white : GrimoireTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Multi-Panel Area: Tree | Canvas | Collapsible Assets | Inspector
          Expanded(
            child: Row(
              children: [
                // Left: Layers Tree Panel
                const LayerTreePanel(),

                // Center: Interactive Canvas + Optional Bottom Cards Strip
                Expanded(
                  child: Container(
                    color: const Color(0xFF090C12),
                    child: Column(
                      children: [
                        Expanded(
                          child: CardCanvas(repaintBoundaryKey: widget.repaintBoundaryKey),
                        ),
                        if (_showCardsFilmstrip)
                          _buildCardsFilmstrip(context, ref, editorState),
                      ],
                    ),
                  ),
                ),

                // Center-Right: Collapsible Assets Panel
                const GameAssetsCollapsiblePanel(),

                // Right: Inspector Panel with Pinned Bottom 300 DPI Export Action
                InspectorPanel(
                  bottomAction: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D101C),
                      border: Border(
                        top: BorderSide(color: GrimoireTheme.borderSubtle),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton.icon(
                        key: const Key('editor_render_300dpi_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GrimoireTheme.accentIndigo,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: Text(
                          ref.tr('render_300dpi_card'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _handleQuickExport,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
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
              GrimoireToast.info(
                context,
                chosenCategory.isEmpty
                    ? ref.tr('no_category')
                    : '${ref.tr('category_label')}: $chosenCategory',
                actionLabel: chosenCategory.isNotEmpty ? ref.tr('apply_category_model') : null,
                onAction: chosenCategory.isNotEmpty
                    ? () {
                        final cat = gameCategories.firstWhere((c) => c.name == chosenCategory);
                        ref.read(editorProvider.notifier).applyCategoryModelToActiveCard(cat);
                      }
                    : null,
              );
            }
          },
        ),
      ],
    );
  }

  void _handleTemplateMenuAction(BuildContext context, String action, EditorState state) {
    final notifier = ref.read(editorProvider.notifier);
    switch (action) {
      case 'new_template':
        _showTemplateNameDialog(
          context,
          title: 'Nueva Plantilla de Carta',
          initialValue: 'Plantilla #${state.project.templates.length + 1}',
          onConfirm: (name) => notifier.createNewTemplate(name),
        );
        break;
      case 'duplicate_template':
        notifier.duplicateActiveTemplate();
        break;
      case 'rename_template':
        _showTemplateNameDialog(
          context,
          title: 'Renombrar Plantilla',
          initialValue: state.project.activeTemplate.name,
          onConfirm: (name) => notifier.renameActiveTemplate(name),
        );
        break;
      case 'delete_template':
        notifier.deleteActiveTemplate();
        break;
      case 'preset_tcg_fantasy':
        notifier.applyPresetTemplate('tcgFantasy');
        GrimoireToast.info(
          context,
          'Plantilla "TCG Fantasía / Criatura" aplicada.',
        );
        break;
      case 'preset_boardgame_action':
        notifier.applyPresetTemplate('boardgameAction');
        GrimoireToast.warning(
          context,
          'Plantilla "Juego de Mesa / Acción" aplicada.',
        );
        break;
      case 'preset_tarot_hero':
        notifier.applyPresetTemplate('tarotHero');
        GrimoireToast.success(
          context,
          'Plantilla "Tarot / Héroe Legendario" aplicada.',
        );
        break;
      case 'size_poker':
        notifier.updateCardDimensions(63.5, 88.9);
        break;
      case 'size_japanese':
        notifier.updateCardDimensions(59.0, 86.0);
        break;
      case 'size_tarot':
        notifier.updateCardDimensions(70.0, 120.0);
        break;
      case 'size_minieuro':
        notifier.updateCardDimensions(44.0, 68.0);
        break;
    }
  }

  void _showTemplateNameDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    required ValueChanged<String> onConfirm,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        title: Text(title, style: const TextStyle(fontSize: 15, color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: Colors.white),
          decoration: const InputDecoration(labelText: 'Nombre de la plantilla'),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              onConfirm(val.trim());
              Navigator.pop(ctx);
            }
          },
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
                onConfirm(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(ref.tr('save')),
          ),
        ],
      ),
    );
  }

  // --- Bottom Cards Filmstrip (Visual Card Reel for Quick Switching) ---
  Widget _buildCardsFilmstrip(BuildContext context, WidgetRef ref, EditorState editorState) {
    final rows = editorState.project.rows;
    final activeIndex = editorState.project.activeRowIndex;

    return Container(
      height: 125,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E1A),
        border: Border(top: BorderSide(color: GrimoireTheme.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.style_outlined, size: 14, color: GrimoireTheme.accentPurple),
              const SizedBox(width: 6),
              Text(
                'Cartas del Juego (${rows.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  final currentGame = editorState.project.rows.isNotEmpty
                      ? (editorState.project.activeRow['game'] ?? 'General').toString()
                      : 'General';
                  ref.read(editorProvider.notifier).addRow({
                    'card_name': 'Nueva Carta',
                    'game': currentGame,
                    'type': 'Creature',
                    'cost': '1',
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 11, color: GrimoireTheme.accentPurple),
                      SizedBox(width: 2),
                      Text('Nueva Carta', style: TextStyle(fontSize: 10, color: Color(0xFFE9D5FF), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                icon: const Icon(Icons.close, size: 14, color: GrimoireTheme.textMuted),
                tooltip: 'Ocultar cinta de cartas',
                onPressed: () => setState(() => _showCardsFilmstrip = false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rows.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final row = rows[index];
                final isSelected = index == activeIndex;
                final tpl = ref.read(editorProvider.notifier).resolveTemplateForRow(row);
                final cardName = (row['card_name'] ?? 'Carta').toString();

                return Tooltip(
                  message: '#${index + 1} - $cardName',
                  child: InkWell(
                    onTap: () {
                      ref.read(editorProvider.notifier).setActiveRow(index);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 58,
                      decoration: BoxDecoration(
                        color: GrimoireTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: CardRendererWidget(
                                template: tpl,
                                cardData: row,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                              color: Colors.black87,
                              child: Text(
                                cardName,
                                style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
