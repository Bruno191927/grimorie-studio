import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/layer_item.dart';
import '../../models/card_template.dart';
import '../providers/editor_provider.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../dialogs/layer_delete_dialog.dart';

class LayerTreePanel extends ConsumerStatefulWidget {
  const LayerTreePanel({super.key});

  @override
  ConsumerState<LayerTreePanel> createState() => _LayerTreePanelState();
}

class _LayerTreePanelState extends ConsumerState<LayerTreePanel> {
  String? _editingLayerId;
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _startEditing(LayerItem layer) {
    setState(() {
      _editingLayerId = layer.id;
      _nameController.text = layer.name;
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: layer.name.length,
      );
    });
    _nameFocusNode.requestFocus();
  }

  void _saveLayerName(String layerId) {
    if (_editingLayerId != layerId) return;
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      final editor = ref.read(editorProvider);
      final layers = editor.project.activeTemplate.getLayers(editor.currentSide);
      final idx = layers.indexWhere((l) => l.id == layerId);
      if (idx != -1) {
        ref.read(editorProvider.notifier).updateLayer(
          layers[idx].copyWith(name: newName),
        );
      }
    }
    setState(() {
      _editingLayerId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final layers = editorState.project.activeTemplate.getLayers(editorState.currentSide);
    final selectedId = editorState.selectedLayerId;

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: GrimoireTheme.surfacePanel,
        border: Border(
          right: BorderSide(color: GrimoireTheme.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          ref.tr('layers_and_hierarchy'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (editorState.selectedLayerIds.length > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: GrimoireTheme.accentPurple),
                          ),
                          child: Text(
                            '${editorState.selectedLayerIds.length}',
                            style: const TextStyle(fontSize: 10, color: GrimoireTheme.accentPurple, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (editorState.hasClipboardLayers) ...[
                  Tooltip(
                    message: '${ref.tr('paste_layer')} (Ctrl+V)',
                    child: InkWell(
                      key: const Key('layer_tree_paste_button'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => ref.read(editorProvider.notifier).pasteLayers(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.accentIndigo.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.content_paste, size: 16, color: GrimoireTheme.accentIndigo),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                PopupMenuButton<LayerType>(
                  tooltip: ref.tr('add_layer'),
                  color: GrimoireTheme.surfaceElevated,
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.add, size: 16, color: GrimoireTheme.accentPurple),
                  ),
                  onSelected: (type) => _addNewLayer(type),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: LayerType.background,
                      child: Row(
                        children: [
                          const Icon(Icons.wallpaper_outlined, size: 16, color: GrimoireTheme.accentPink),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              ref.tr('background_layer'),
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: LayerType.shape,
                      child: Row(
                        children: [
                          const Icon(Icons.category_outlined, size: 16, color: GrimoireTheme.accentAmber),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              ref.tr('shape_layer'),
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: LayerType.text,
                      child: Row(
                        children: [
                          const Icon(Icons.text_fields, size: 16, color: GrimoireTheme.accentIndigo),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              ref.tr('text_layer'),
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: LayerType.image,
                      child: Row(
                        children: [
                          const Icon(Icons.image, size: 16, color: GrimoireTheme.accentEmerald),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              ref.tr('image_layer'),
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Face Switcher Tabs (Anverso / Reverso)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF0F111D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => ref.read(editorProvider.notifier).switchSide(CardSide.front),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: editorState.currentSide == CardSide.front
                            ? GrimoireTheme.accentPurple
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flip_to_front,
                            size: 13,
                            color: editorState.currentSide == CardSide.front
                                ? Colors.white
                                : GrimoireTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              ref.tr('card_side_front'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: editorState.currentSide == CardSide.front
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: editorState.currentSide == CardSide.front
                                    ? Colors.white
                                    : GrimoireTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => ref.read(editorProvider.notifier).switchSide(CardSide.back),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: editorState.currentSide == CardSide.back
                            ? GrimoireTheme.accentIndigo
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flip_to_back,
                            size: 13,
                            color: editorState.currentSide == CardSide.back
                                ? Colors.white
                                : GrimoireTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              ref.tr('card_side_back'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: editorState.currentSide == CardSide.back
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: editorState.currentSide == CardSide.back
                                    ? Colors.white
                                    : GrimoireTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Layer List (Reorderable)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_editingLayerId != null) {
                  _saveLayerName(_editingLayerId!);
                }
                ref.read(editorProvider.notifier).selectLayer(null);
              },
              child: layers.isEmpty
                  ? Center(
                      child: Text(
                        ref.tr('no_layers_yet'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: GrimoireTheme.textMuted, fontSize: 12),
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: layers.length,
                      onReorderItem: (oldIdx, newIdx) {
                        ref.read(editorProvider.notifier).reorderLayersDirect(oldIdx, newIdx);
                      },
                      itemBuilder: (context, index) {
                        final layer = layers[index];
                        final isSelected = layer.id == selectedId || editorState.selectedLayerIds.contains(layer.id);
                        final isEditingThisLayer = _editingLayerId == layer.id;

                        final tileContainer = Container(
                          key: ValueKey(layer.id),
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? GrimoireTheme.accentPurple.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? GrimoireTheme.accentPurple
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onDoubleTap: () => _startEditing(layer),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                hoverColor: GrimoireTheme.surfaceElevated.withValues(alpha: 0.6),
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.drag_indicator,
                                      size: 13,
                                      color: GrimoireTheme.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _getLayerIcon(layer.type),
                                      size: 16,
                                      color: isSelected
                                          ? GrimoireTheme.accentPurple
                                          : GrimoireTheme.textSecondary,
                                    ),
                                  ],
                                ),
                                title: isEditingThisLayer
                                    ? TextField(
                                        controller: _nameController,
                                        focusNode: _nameFocusNode,
                                        autofocus: true,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        cursorColor: GrimoireTheme.accentPurple,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          filled: true,
                                          fillColor: GrimoireTheme.surfaceElevated,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: const BorderSide(color: GrimoireTheme.accentPurple, width: 1.5),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide: const BorderSide(color: GrimoireTheme.accentPurple, width: 1.5),
                                          ),
                                        ),
                                        onSubmitted: (_) => _saveLayerName(layer.id),
                                        onTapOutside: (_) => _saveLayerName(layer.id),
                                      )
                                    : GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onDoubleTap: () => _startEditing(layer),
                                        child: Text(
                                          layer.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                subtitle: layer.bindingKey.isNotEmpty
                                    ? Text(
                                        '{{${layer.bindingKey}}}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          color: GrimoireTheme.accentIndigo,
                                        ),
                                      )
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Visibility Toggle with Tooltip
                                    Tooltip(
                                      message: layer.isVisible ? 'Ocultar capa' : 'Mostrar capa',
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                        icon: Icon(
                                          layer.isVisible
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 15,
                                          color: layer.isVisible
                                              ? GrimoireTheme.textSecondary
                                              : GrimoireTheme.textMuted,
                                        ),
                                        onPressed: () {
                                          ref.read(editorProvider.notifier).toggleLayerVisibility(layer.id);
                                        },
                                      ),
                                    ),
                                    // Lock Toggle with Tooltip
                                    Tooltip(
                                      message: layer.isLocked ? 'Desbloquear capa' : 'Bloquear capa',
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                        icon: Icon(
                                          layer.isLocked
                                              ? Icons.lock_outline
                                              : Icons.lock_open_outlined,
                                          size: 15,
                                          color: layer.isLocked
                                              ? GrimoireTheme.accentAmber
                                              : GrimoireTheme.textMuted,
                                        ),
                                        onPressed: () {
                                          ref.read(editorProvider.notifier).toggleLayerLock(layer.id);
                                        },
                                      ),
                                    ),
                                    // More Actions Popup (Rename / Duplicate / Delete)
                                    PopupMenuButton<String>(
                                      tooltip: 'Más acciones de capa',
                                      padding: EdgeInsets.zero,
                                      color: GrimoireTheme.surfaceElevated,
                                      constraints: const BoxConstraints(minWidth: 140),
                                      icon: const Icon(
                                        Icons.more_vert,
                                        size: 15,
                                        color: GrimoireTheme.textMuted,
                                      ),
                                      onSelected: (action) {
                                        if (action == 'rename') {
                                          _startEditing(layer);
                                        } else if (action == 'duplicate') {
                                          ref.read(editorProvider.notifier).duplicateLayer(layer.id);
                                        } else if (action == 'delete') {
                                          LayerDeleteDialog.show(context: context, ref: ref, layer: layer);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'rename',
                                          height: 32,
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 14, color: GrimoireTheme.accentPurple),
                                              SizedBox(width: 8),
                                              Text('Renombrar capa', style: TextStyle(fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'duplicate',
                                          height: 32,
                                          child: Row(
                                            children: [
                                              Icon(Icons.copy, size: 14, color: GrimoireTheme.accentIndigo),
                                              SizedBox(width: 8),
                                              Text('Duplicar capa', style: TextStyle(fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        if (layer.type != LayerType.background)
                                          const PopupMenuItem(
                                            value: 'delete',
                                            height: 32,
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                                SizedBox(width: 8),
                                                Text('Eliminar capa', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  final isMulti = HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed;
                                  ref.read(editorProvider.notifier).selectLayer(layer.id, multiSelect: isMulti);
                                },
                              ),
                            ),
                          ),
                        );

                      if (layer.type == LayerType.image || layer.type == LayerType.background) {
                        return DragTarget<String>(
                          key: ValueKey(layer.id),
                          onWillAcceptWithDetails: (details) => true,
                          onAcceptWithDetails: (details) {
                            final assetRelativePath = details.data;
                            ref.read(editorProvider.notifier).assignAssetToLayer(layer.id, assetRelativePath);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: GrimoireTheme.accentEmerald,
                                duration: const Duration(milliseconds: 1400),
                                content: Text('Asset asignado a "${layer.name}": ${assetRelativePath.split('/').last}'),
                              ),
                            );
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isHovered = candidateData.isNotEmpty;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: isHovered
                                  ? BoxDecoration(
                                      color: GrimoireTheme.accentEmerald.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: GrimoireTheme.accentEmerald, width: 2),
                                    )
                                  : null,
                              child: tileContainer,
                            );
                          },
                        );
                      }
                      return tileContainer;
                    },
                  ),
            ),
          ),

          // Bottom quick project summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: GrimoireTheme.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${layers.length} ${ref.tr('layers_count')}',
                    style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${editorState.project.widthMm.toStringAsFixed(1)} x ${editorState.project.heightMm.toStringAsFixed(1)} mm',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: GrimoireTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLayerIcon(LayerType type) {
    switch (type) {
      case LayerType.background:
        return Icons.wallpaper_outlined;
      case LayerType.text:
        return Icons.text_fields;
      case LayerType.image:
        return Icons.image_outlined;
      case LayerType.shape:
        return Icons.category_outlined;
    }
  }

  void _addNewLayer(LayerType type) {
    const uuid = Uuid();
    final newId = uuid.v4();

    LayerItem newLayer;
    switch (type) {
      case LayerType.background:
        newLayer = LayerItem(
          id: newId,
          name: 'Card Background',
          type: LayerType.background,
          x: 0,
          y: 0,
          width: 254,
          height: 355.6,
          fillMode: LayerFillMode.gradient,
          gradientType: LayerGradientType.linear,
          shapeColor: const Color(0xFF0F172A),
          gradientEndColor: const Color(0xFF4C1D95),
          gradientAngle: 135.0,
          borderColor: Colors.transparent,
          borderWidth: 0,
          borderRadius: 16,
          isLocked: true,
        );
        break;
      case LayerType.text:
        newLayer = LayerItem(
          id: newId,
          name: 'Text Layer',
          type: LayerType.text,
          x: 20,
          y: 60,
          width: 160,
          height: 30,
          text: 'New Card Label',
          fontSize: 14,
          fontFamily: 'Inter',
        );
        break;
      case LayerType.image:
        newLayer = LayerItem(
          id: newId,
          name: 'Image Frame',
          type: LayerType.image,
          x: 20,
          y: 40,
          width: 200,
          height: 140,
        );
        break;
      case LayerType.shape:
        newLayer = LayerItem(
          id: newId,
          name: 'Shape Element',
          type: LayerType.shape,
          x: 37,
          y: 100,
          width: 180,
          height: 90,
          shapePreset: ShapePreset.rectangle,
          fillMode: LayerFillMode.solid,
          shapeColor: const Color(0xFF1E2337),
          gradientEndColor: const Color(0xFF4C1D95),
          borderColor: GrimoireTheme.accentPurple,
          borderWidth: 1.5,
          borderRadius: 10,
        );
        break;
    }

    ref.read(editorProvider.notifier).addLayer(newLayer);
  }
}
