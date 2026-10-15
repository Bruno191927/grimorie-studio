import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/layer_item.dart';
import '../providers/editor_provider.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';

class LayerTreePanel extends ConsumerWidget {
  const LayerTreePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final layers = editorState.project.activeTemplate.layers;
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ref.tr('layers_and_hierarchy'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
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
                  onSelected: (type) => _addNewLayer(ref, type),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: LayerType.text,
                      child: Row(
                        children: [
                          const Icon(Icons.text_fields, size: 16, color: GrimoireTheme.accentIndigo),
                          const SizedBox(width: 8),
                          Text(ref.tr('text_layer'), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: LayerType.image,
                      child: Row(
                        children: [
                          const Icon(Icons.image, size: 16, color: GrimoireTheme.accentEmerald),
                          const SizedBox(width: 8),
                          Text(ref.tr('image_layer'), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: LayerType.shape,
                      child: Row(
                        children: [
                          const Icon(Icons.crop_square, size: 16, color: GrimoireTheme.accentAmber),
                          const SizedBox(width: 8),
                          Text(ref.tr('shape_layer'), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Layer List (Reorderable)
          Expanded(
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
                      final isSelected = layer.id == selectedId;

                      return Container(
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
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            leading: Icon(
                              _getLayerIcon(layer.type),
                              size: 16,
                              color: isSelected
                                  ? GrimoireTheme.accentPurple
                                  : GrimoireTheme.textSecondary,
                            ),
                            title: Text(
                              layer.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                              ),
                            ),
                            subtitle: layer.bindingKey.isNotEmpty
                                ? Text(
                                    '{{${layer.bindingKey}}}',
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
                                // Visibility
                                IconButton(
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
                                // Lock
                                IconButton(
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
                              ],
                            ),
                            onTap: () {
                              ref.read(editorProvider.notifier).selectLayer(layer.id);
                            },
                          ),
                        ),
                      );
                    },
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
                Text(
                  '${layers.length} ${ref.tr('layers_count')}',
                  style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                ),
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
      case LayerType.text:
        return Icons.text_fields;
      case LayerType.image:
        return Icons.image_outlined;
      case LayerType.shape:
        return Icons.crop_square_outlined;
    }
  }

  void _addNewLayer(WidgetRef ref, LayerType type) {
    const uuid = Uuid();
    final newId = uuid.v4();

    LayerItem newLayer;
    switch (type) {
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
          x: 20,
          y: 100,
          width: 100,
          height: 40,
          shapeColor: const Color(0xFF1E2337),
          borderColor: GrimoireTheme.accentPurple,
          borderWidth: 1,
        );
        break;
    }

    ref.read(editorProvider.notifier).addLayer(newLayer);
  }
}
