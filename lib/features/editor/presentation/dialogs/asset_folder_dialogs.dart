import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../services/game_folder_service.dart';
import '../providers/editor_provider.dart';

class AssetFolderDialogs {
  /// Dialog to create a new subfolder in `games/<gameName>/assets/`
  static Future<String?> showCreateFolderDialog(BuildContext context, String gameName) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          return AlertDialog(
            backgroundColor: GrimoireTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: GrimoireTheme.borderSubtle),
            ),
            title: Row(
              children: [
                const Icon(Icons.create_new_folder_outlined, color: GrimoireTheme.accentPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  ref.tr('new_folder_dialog_title'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.tr('new_folder_dialog_hint'),
                    style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'ej. Personajes, Fondos, Íconos...',
                      hintStyle: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                      prefixIcon: const Icon(Icons.folder, size: 16, color: GrimoireTheme.accentPurple),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFF141728),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: GrimoireTheme.borderSubtle),
                      ),
                    ),
                    validator: (val) {
                      final name = val?.trim() ?? '';
                      if (name.isEmpty) return 'El nombre no puede estar vacío';
                      final existing = GameFolderService.listAssetFolders(gameName);
                      if (existing.any((f) => f.toLowerCase() == name.toLowerCase())) {
                        return 'Ya existe una carpeta con este nombre';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (formKey.currentState?.validate() ?? false) {
                        final created = GameFolderService.createAssetFolder(gameName, controller.text.trim());
                        Navigator.pop(ctx, created?.uri.pathSegments.reversed.skip(1).first);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GrimoireTheme.accentPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    final created = GameFolderService.createAssetFolder(gameName, controller.text.trim());
                    final folderName = created?.path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;
                    Navigator.pop(ctx, folderName);
                  }
                },
                child: Text(ref.tr('create_folder')),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog to rename an existing subfolder
  static Future<String?> showRenameFolderDialog(BuildContext context, String gameName, String oldFolderName) async {
    final controller = TextEditingController(text: oldFolderName);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          return AlertDialog(
            backgroundColor: GrimoireTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: GrimoireTheme.borderSubtle),
            ),
            title: Row(
              children: [
                const Icon(Icons.drive_file_rename_outline, color: Color(0xFF93C5FD), size: 20),
                const SizedBox(width: 8),
                Text(
                  '${ref.tr('rename_folder')}: $oldFolderName',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.folder, size: 16, color: GrimoireTheme.accentPurple),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFF141728),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: GrimoireTheme.borderSubtle),
                  ),
                ),
                validator: (val) {
                  final name = val?.trim() ?? '';
                  if (name.isEmpty) return 'El nombre no puede estar vacío';
                  if (name == oldFolderName) return null;
                  final existing = GameFolderService.listAssetFolders(gameName);
                  if (existing.any((f) => f.toLowerCase() == name.toLowerCase())) {
                    return 'Ya existe una carpeta con este nombre';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GrimoireTheme.accentPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    final newName = controller.text.trim();
                    if (newName != oldFolderName) {
                      GameFolderService.renameAssetFolder(gameName, oldFolderName, newName);
                    }
                    Navigator.pop(ctx, newName);
                  }
                },
                child: Text(ref.tr('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog to confirm folder deletion
  static Future<bool> showDeleteFolderConfirm(BuildContext context, String gameName, String folderName) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Consumer(
            builder: (context, ref, _) {
              return AlertDialog(
                backgroundColor: GrimoireTheme.surfaceElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: GrimoireTheme.borderSubtle),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${ref.tr('delete_folder_title')}: $folderName',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                content: Text(
                  ref.tr('delete_folder_desc'),
                  style: const TextStyle(fontSize: 11.5, color: GrimoireTheme.textSecondary, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final ok = GameFolderService.deleteAssetFolder(gameName, folderName, moveFilesToRoot: true);
                      Navigator.pop(ctx, ok);
                    },
                    child: Text(ref.tr('delete')),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;
  }

  /// Dialog to move an asset to another folder or back to root
  static Future<bool> showMoveAssetDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String gameName,
    required File assetFile,
  }) async {
    final currentSubfolder = GameFolderService.getAssetSubfolder(gameName, assetFile);
    final fileName = assetFile.uri.pathSegments.last;
    final folders = GameFolderService.listAssetFolders(gameName);

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: GrimoireTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: GrimoireTheme.borderSubtle),
            ),
            title: Row(
              children: [
                const Icon(Icons.drive_file_move_outlined, color: GrimoireTheme.accentPurple, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ref.tr('move_to_folder'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        fileName,
                        style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona la carpeta de destino:',
                    style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131627),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GrimoireTheme.borderSubtle),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        // Option: Raíz (root assets folder)
                        ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: Icon(
                            Icons.folder_special_outlined,
                            size: 18,
                            color: currentSubfolder == null ? GrimoireTheme.accentEmerald : GrimoireTheme.textMuted,
                          ),
                          title: Text(
                            'Raíz (assets/)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: currentSubfolder == null ? FontWeight.bold : FontWeight.normal,
                              color: currentSubfolder == null ? GrimoireTheme.accentEmerald : Colors.white,
                            ),
                          ),
                          trailing: currentSubfolder == null
                              ? const Icon(Icons.check, size: 14, color: GrimoireTheme.accentEmerald)
                              : null,
                          onTap: currentSubfolder == null
                              ? null
                              : () {
                                  Navigator.pop(ctx, true);
                                  final ok = ref.read(editorProvider.notifier).moveAsset(
                                        gameName: gameName,
                                        relativeOrFileName: assetFile.path,
                                        targetSubfolder: null,
                                      );
                                  if (ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: GrimoireTheme.accentEmerald,
                                        content: Text('Asset movido a la carpeta Raíz'),
                                      ),
                                    );
                                  }
                                },
                        ),
                        const Divider(height: 1, color: GrimoireTheme.borderSubtle),
                        // List subfolders
                        if (folders.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: Text(
                                'No hay subcarpetas creadas aún.',
                                style: TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
                              ),
                            ),
                          ),
                        for (final folder in folders)
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Icon(
                              Icons.folder_outlined,
                              size: 18,
                              color: currentSubfolder == folder
                                  ? GrimoireTheme.accentPurple
                                  : GrimoireTheme.textSecondary,
                            ),
                            title: Text(
                              folder,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: currentSubfolder == folder ? FontWeight.bold : FontWeight.normal,
                                color: currentSubfolder == folder ? GrimoireTheme.accentPurple : Colors.white,
                              ),
                            ),
                            trailing: currentSubfolder == folder
                                ? const Icon(Icons.check, size: 14, color: GrimoireTheme.accentPurple)
                                : null,
                            onTap: currentSubfolder == folder
                                ? null
                                : () {
                                    Navigator.pop(ctx, true);
                                    final ok = ref.read(editorProvider.notifier).moveAsset(
                                          gameName: gameName,
                                          relativeOrFileName: assetFile.path,
                                          targetSubfolder: folder,
                                        );
                                    if (ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: GrimoireTheme.accentEmerald,
                                          content: Text('Asset movido a "$folder"'),
                                        ),
                                      );
                                    }
                                  },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Button to create a new folder directly from the move dialog
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GrimoireTheme.accentPurple,
                      side: const BorderSide(color: GrimoireTheme.accentPurple),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size.fromHeight(32),
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: Text(ref.tr('new_folder_btn'), style: const TextStyle(fontSize: 11)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final createdFolder = await showCreateFolderDialog(context, gameName);
                      if (createdFolder != null && context.mounted) {
                        final ok = ref.read(editorProvider.notifier).moveAsset(
                              gameName: gameName,
                              relativeOrFileName: assetFile.path,
                              targetSubfolder: createdFolder,
                            );
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: GrimoireTheme.accentEmerald,
                              content: Text('Asset movido a nueva carpeta "$createdFolder"'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
              ),
            ],
          ),
        ) ??
        false;
  }
}
