import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../models/layer_item.dart';
import '../providers/editor_provider.dart';

/// Centralized confirmation dialog for layer deletion.
class LayerDeleteDialog {
  /// Displays a confirmation dialog asking the user if they are sure they want to delete the layer.
  /// If [layer] is omitted, targets the currently selected layer(s) from [editorProvider].
  /// Returns `true` if the layer was deleted, or `false` if cancelled.
  static Future<bool> show({
    required BuildContext context,
    required WidgetRef ref,
    LayerItem? layer,
  }) async {
    final editorState = ref.read(editorProvider);
    final currentSide = editorState.currentSide;
    final layers = editorState.project.activeTemplate.getLayers(currentSide);

    // Determine target layers
    List<LayerItem> targetLayers = [];
    if (layer != null) {
      targetLayers = [layer];
    } else {
      final selectedIds = editorState.selectedLayerIds.isNotEmpty
          ? editorState.selectedLayerIds
          : (editorState.selectedLayerId != null ? {editorState.selectedLayerId!} : <String>{});
      targetLayers = layers.where((l) => selectedIds.contains(l.id)).toList();
    }

    if (targetLayers.isEmpty) return false;

    // Check if the only target is a background layer
    if (targetLayers.length == 1 && targetLayers.first.type == LayerType.background) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1E1B4B),
          content: Text('La capa de fondo no se puede eliminar (solo editar).'),
        ),
      );
      return false;
    }

    // Filter out background layers from multi-selection
    final deletableLayers = targetLayers.where((l) => l.type != LayerType.background).toList();
    if (deletableLayers.isEmpty) return false;

    final isSingle = deletableLayers.length == 1;
    final layerName = deletableLayers.first.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isSingle ? '¿Eliminar capa?' : '¿Eliminar ${deletableLayers.length} capas?',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Text(
          isSingle
              ? '¿Estás seguro de que deseas borrar la capa "$layerName"?\n\nEsta acción quitará la capa de la plantilla activa.'
              : '¿Estás seguro de que deseas borrar las ${deletableLayers.length} capas seleccionadas?\n\nEsta acción quitará las capas de la plantilla activa.',
          style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(ref.tr('delete')),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      if (layer != null) {
        ref.read(editorProvider.notifier).removeLayer(layer.id);
      } else {
        ref.read(editorProvider.notifier).removeSelectedLayers();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GrimoireTheme.accentEmerald,
          content: Text(
            isSingle
                ? 'Capa "$layerName" eliminada.'
                : '${deletableLayers.length} capas eliminadas.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return true;
    }

    return false;
  }
}
