import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../services/game_folder_service.dart';
import '../providers/editor_provider.dart';
import 'package:grimoire_studio/features/ai_generator/presentation/widgets/ai_prompt_dialog.dart';
import 'package:grimoire_studio/features/ai_generator/presentation/widgets/comfy_ui_connection_dialog.dart';
import '../dialogs/sprite_sheet_splitter_dialog.dart';
import '../dialogs/background_removal_dialog.dart';
import '../dialogs/asset_folder_dialogs.dart';

class GameAssetsCollapsiblePanel extends ConsumerStatefulWidget {
  const GameAssetsCollapsiblePanel({super.key});

  @override
  ConsumerState<GameAssetsCollapsiblePanel> createState() => _GameAssetsCollapsiblePanelState();
}

class _GameAssetsCollapsiblePanelState extends ConsumerState<GameAssetsCollapsiblePanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';
  String? _selectedFolder; // null = all, '' = root only, or folder name
  bool _isDraggingOver = false;

  Future<void> _handleSplitSpriteSheet(String gameName, [File? initialFile]) async {
    final success = await SpriteSheetSplitterDialog.show(
      context,
      gameName: gameName,
      initialFile: initialFile,
    );
    if (success == true && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importFiles(String gameName, List<String> paths) async {
    if (paths.isEmpty) return;
    final targetSub = (_selectedFolder != null && _selectedFolder!.isNotEmpty) ? _selectedFolder : null;
    final results = await ref.read(editorProvider.notifier).uploadMultipleImagesToGameAssets(
          paths,
          targetSubfolder: targetSub,
        );
    if (mounted) {
      setState(() {});
      if (results.isNotEmpty) {
        final count = results.length;
        final folderMsg = targetSub != null ? ' ($targetSub)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GrimoireTheme.accentEmerald,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    count == 1
                        ? 'Imagen guardada con éxito en Assets$folderMsg: ${results.first} (lista para arrastrar o asignar)'
                        : '$count imágenes guardadas con éxito en Assets$folderMsg (listas para arrastrar o asignar)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleUpload(String gameName) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'svg', 'gif', 'bmp'],
      );

      if (files.isNotEmpty) {
        final paths = files.map((f) => f.path).whereType<String>().toList();
        if (paths.isNotEmpty) {
          await _importFiles(gameName, paths);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Text('Error al subir imágenes: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleAiGenerate(String gameName) async {
    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => AiPromptDialog(
        gameName: gameName,
        layerId: ref.read(editorProvider).selectedLayerId,
      ),
    );

    if (success == true && mounted) {
      setState(() {});
    }
  }

  void _confirmDeleteAsset(String gameName, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text(ref.tr('delete_asset_confirm'), style: const TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
        content: Text(
          ref.tr('delete_asset_desc'),
          style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final deleted = GameFolderService.deleteGameAsset(gameName, fileName);
              if (deleted && mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: GrimoireTheme.accentEmerald,
                    content: Text('Asset "$fileName" eliminado.'),
                  ),
                );
              }
            },
            child: Text(ref.tr('delete')),
          ),
        ],
      ),
    );
  }

  void _showEnlargedPreview(File file, String fileName, String gameName, [String? relativeUrl]) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: GrimoireTheme.surfacePanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      fileName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, size: 48, color: GrimoireTheme.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GrimoireTheme.accentPurple,
                      side: const BorderSide(color: GrimoireTheme.accentPurple),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.drive_file_move_outlined, size: 14),
                    label: const Text('Mover a carpeta...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await AssetFolderDialogs.showMoveAssetDialog(
                        context: context,
                        ref: ref,
                        gameName: gameName,
                        assetFile: file,
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                  if (relativeUrl != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GrimoireTheme.accentPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.tune, size: 14),
                      label: const Text('Abrir en el Inspector', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(editorProvider.notifier).selectAsset(relativeUrl);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 2),
                            backgroundColor: const Color(0xFF16182E),
                            content: Text('Asset "$fileName" abierto en el Inspector'),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final activeRow = editorState.project.rows.isNotEmpty ? editorState.project.activeRow : <String, dynamic>{};
    final gameName = (activeRow['game'] ?? 'Magic').toString();
    final currentArtUrl = (activeRow['art_url'] ?? '').toString();

    final allAssets = GameFolderService.listGameAssetImages(gameName, recursive: true);
    final folders = GameFolderService.listAssetFolders(gameName);

    // Filter by selected folder: null = Todos, '' = Raíz, otherwise specific subfolder
    List<File> currentFolderAssets;
    if (_selectedFolder == null) {
      currentFolderAssets = allAssets;
    } else if (_selectedFolder!.isEmpty) {
      currentFolderAssets = GameFolderService.listGameAssetImages(gameName, subfolder: null, recursive: false);
    } else {
      currentFolderAssets = GameFolderService.listGameAssetImages(gameName, subfolder: _selectedFolder, recursive: false);
    }

    final filteredAssets = _searchFilter.isEmpty
        ? currentFolderAssets
        : currentFolderAssets.where((f) => f.uri.pathSegments.last.toLowerCase().contains(_searchFilter.toLowerCase())).toList();

    final Widget panelWidget;
    // If collapsed, display a sleek vertical interactive rail
    if (!editorState.showAssetsPanel) {
      panelWidget = InkWell(
        onTap: () => ref.read(editorProvider.notifier).setAssetsPanelOpen(true),
        child: Container(
          width: 36,
          decoration: const BoxDecoration(
            color: Color(0xFF0F111D),
            border: Border(
              left: BorderSide(color: GrimoireTheme.borderSubtle),
              right: BorderSide(color: GrimoireTheme.borderSubtle),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.chevron_left, size: 18, color: GrimoireTheme.accentPurple),
                tooltip: ref.tr('expand_assets_panel'),
                onPressed: () => ref.read(editorProvider.notifier).setAssetsPanelOpen(true),
              ),
              const SizedBox(height: 12),
              const Icon(Icons.photo_library_outlined, size: 16, color: GrimoireTheme.accentPurple),
              const SizedBox(height: 12),
              RotatedBox(
                quarterTurns: 3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ref.tr('game_assets').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${allAssets.length}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFE9D5FF)),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.file_upload_outlined, size: 16, color: GrimoireTheme.accentEmerald),
                tooltip: ref.tr('upload_asset'),
                onPressed: () => _handleUpload(gameName),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.auto_awesome, size: 16, color: GrimoireTheme.accentPurple),
                tooltip: ref.tr('generate_ai_asset'),
                onPressed: () => _handleAiGenerate(gameName),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.grid_goldenratio, size: 16, color: Color(0xFFC084FC)),
                tooltip: 'Dividir Sprite Sheet...',
                onPressed: () => _handleSplitSpriteSheet(gameName),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    } else {
      // Expanded Assets Panel
      panelWidget = Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF0F111D),
        border: Border(
          left: BorderSide(color: GrimoireTheme.borderSubtle),
          right: BorderSide(color: GrimoireTheme.borderSubtle),
        ),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF131627),
              border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.photo_library_outlined, size: 15, color: GrimoireTheme.accentPurple),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ref.tr('game_assets'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${allAssets.length}',
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFE9D5FF)),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        gameName,
                        style: const TextStyle(fontSize: 10, color: GrimoireTheme.accentEmerald, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(Icons.refresh, size: 15, color: GrimoireTheme.textMuted),
                  tooltip: ref.tr('reload'),
                  onPressed: () => setState(() {}),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(Icons.folder_open, size: 15, color: GrimoireTheme.accentEmerald),
                  tooltip: ref.tr('open_assets_folder'),
                  onPressed: () async {
                    final opened = await GameFolderService.openGameAssetsFolderInExplorer(gameName);
                    if (context.mounted && opened) {
                      final p = GameFolderService.getGameAssetsDir(gameName).absolute.path.replaceAll('/', '\\');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Carpeta abierta: $p'),
                          duration: const Duration(seconds: 3),
                          backgroundColor: const Color(0xFF16182E),
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(Icons.bolt, size: 16, color: GrimoireTheme.accentPurple),
                  tooltip: 'Conectar Motor IA (ComfyUI / NVIDIA NIM / Gemini)',
                  onPressed: () => ComfyUiConnectionDialog.show(context),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(Icons.chevron_right, size: 18, color: GrimoireTheme.textMuted),
                  tooltip: ref.tr('collapse_assets_panel'),
                  onPressed: () => ref.read(editorProvider.notifier).setAssetsPanelOpen(false),
                ),
              ],
            ),
          ),

          // Action Buttons Bar: Subir Imagen, Generar con IA & Cortador de Sprites
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.file_upload_outlined, size: 13),
                    label: Text(
                      ref.tr('upload_asset'),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _handleUpload(gameName),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 13),
                    label: Text(
                      ref.tr('generate_ai_asset'),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _handleAiGenerate(gameName),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Dividir imagen en varios sprites...',
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1B4B),
                      foregroundColor: const Color(0xFFC084FC),
                      padding: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: const Color(0xFFC084FC).withValues(alpha: 0.4)),
                      ),
                    ),
                    icon: const Icon(Icons.grid_goldenratio, size: 16),
                    onPressed: () => _handleSplitSpriteSheet(gameName),
                  ),
                ),
              ],
            ),
          ),

          // Folder Navigation Bar
          _buildFolderBar(context, gameName, folders, allAssets),

          // Search Field (if more than 3 assets)
          if (allAssets.length >= 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: SizedBox(
                height: 30,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: ref.tr('search_assets'),
                    prefixIcon: const Icon(Icons.search, size: 14, color: GrimoireTheme.textMuted),
                    suffixIcon: _searchFilter.isNotEmpty
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.clear, size: 12, color: GrimoireTheme.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchFilter = '');
                            },
                          )
                        : null,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF141728),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: GrimoireTheme.borderSubtle),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchFilter = val),
                ),
              ),
            ),

          const SizedBox(height: 4),

          // Main Content: Grid or Empty State
          Expanded(
            child: filteredAssets.isEmpty
                ? _buildEmptyState(context, gameName)
                : _buildAssetsGrid(context, gameName, filteredAssets, currentArtUrl),
          ),
        ],
      ),
    );
  }

    return DropTarget(
      onDragEntered: (details) {
        setState(() => _isDraggingOver = true);
        if (!editorState.showAssetsPanel) {
          ref.read(editorProvider.notifier).setAssetsPanelOpen(true);
        }
      },
      onDragExited: (details) {
        setState(() => _isDraggingOver = false);
      },
      onDragDone: (details) async {
        setState(() => _isDraggingOver = false);
        if (!editorState.showAssetsPanel) {
          ref.read(editorProvider.notifier).setAssetsPanelOpen(true);
        }
        final paths = details.files.map((e) => e.path).toList();
        await _importFiles(gameName, paths);
      },
      child: Stack(
        children: [
          panelWidget,
          if (_isDraggingOver)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xF2090B16),
                  border: Border.all(color: GrimoireTheme.accentEmerald, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: GrimoireTheme.accentEmerald.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: GrimoireTheme.accentEmerald.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: GrimoireTheme.accentEmerald, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.file_download_outlined,
                            size: 36,
                            color: GrimoireTheme.accentEmerald,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '¡Suelta tus imágenes aquí!',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedFolder != null && _selectedFolder!.isNotEmpty
                              ? 'Se guardarán en la carpeta: "$_selectedFolder"'
                              : 'Se guardarán en los assets del juego ($gameName)',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFFA7F3D0),
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFolderBar(BuildContext context, String gameName, List<String> folders, List<File> allAssets) {
    final rootCount = GameFolderService.listGameAssetImages(gameName, subfolder: null, recursive: false).length;

    return Container(
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFolderChip(
                  label: ref.tr('all_assets'),
                  count: allAssets.length,
                  isSelected: _selectedFolder == null,
                  icon: Icons.grid_view,
                  onTap: () => setState(() => _selectedFolder = null),
                ),
                const SizedBox(width: 5),
                _buildFolderChip(
                  label: ref.tr('root_assets'),
                  count: rootCount,
                  isSelected: _selectedFolder == '',
                  icon: Icons.folder_special_outlined,
                  onTap: () => setState(() => _selectedFolder = ''),
                  isDropTarget: true,
                  gameName: gameName,
                ),
                const SizedBox(width: 5),
                for (final folder in folders) ...[
                  _buildCustomFolderChip(context, gameName, folder),
                  const SizedBox(width: 5),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          _buildNewFolderButton(gameName),
        ],
      ),
    );
  }

  Widget _buildFolderChip({
    required String label,
    required int count,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    bool isDropTarget = false,
    String? gameName,
  }) {
    Widget buildChip(bool isHovered) {
      final effectiveBorderColor = isHovered
          ? GrimoireTheme.accentEmerald
          : (isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle);
      final effectiveBgColor = isHovered
          ? GrimoireTheme.accentEmerald.withValues(alpha: 0.35)
          : (isSelected ? GrimoireTheme.accentPurple.withValues(alpha: 0.25) : const Color(0xFF141728));

      return Tooltip(
        message: isHovered
            ? 'Soltar aquí para mover a la Raíz'
            : (isSelected ? 'Carpeta seleccionada' : 'Filtrar por $label'),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: effectiveBgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: effectiveBorderColor,
                width: (isSelected || isHovered) ? 1.5 : 1.0,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: GrimoireTheme.accentEmerald.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isHovered ? Icons.file_download : icon,
                  size: 12,
                  color: isHovered
                      ? GrimoireTheme.accentEmerald
                      : (isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted),
                ),
                const SizedBox(width: 4),
                Text(
                  isHovered ? 'Soltar en Raíz' : label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: (isSelected || isHovered) ? FontWeight.bold : FontWeight.normal,
                    color: isHovered ? Colors.white : (isSelected ? Colors.white : GrimoireTheme.textSecondary),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? GrimoireTheme.accentEmerald.withValues(alpha: 0.45)
                        : (isSelected ? GrimoireTheme.accentPurple.withValues(alpha: 0.35) : Colors.black38),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: (isSelected || isHovered) ? const Color(0xFFE9D5FF) : GrimoireTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isDropTarget || gameName == null) {
      return buildChip(false);
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final assetPath = details.data;
        if (assetPath.isEmpty) return false;
        final file = GameFolderService.resolveCardImageFile(gameName, assetPath);
        if (file == null) return false;
        final currentSub = GameFolderService.getAssetSubfolder(gameName, file);
        return currentSub != null; // It's currently in a subfolder, so it can be moved to root
      },
      onAcceptWithDetails: (details) {
        final assetPath = details.data;
        final file = GameFolderService.resolveCardImageFile(gameName, assetPath);
        final fileName = file?.uri.pathSegments.last ?? assetPath.split('/').last;
        final ok = ref.read(editorProvider.notifier).moveAsset(
              gameName: gameName,
              relativeOrFileName: assetPath,
              targetSubfolder: null,
            );
        if (ok && mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GrimoireTheme.accentEmerald,
              content: Text('Asset "$fileName" movido a la Raíz.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return buildChip(isHovered);
      },
    );
  }

  Widget _buildCustomFolderChip(BuildContext context, String gameName, String folder) {
    final isSelected = _selectedFolder == folder;
    final folderCount = GameFolderService.listGameAssetImages(gameName, subfolder: folder, recursive: false).length;

    Widget buildChip(bool isHovered) {
      final effectiveBorderColor = isHovered
          ? GrimoireTheme.accentPurple
          : (isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle);
      final effectiveBgColor = isHovered
          ? GrimoireTheme.accentPurple.withValues(alpha: 0.5)
          : (isSelected ? GrimoireTheme.accentPurple.withValues(alpha: 0.25) : const Color(0xFF141728));

      return Tooltip(
        message: isHovered
            ? 'Soltar aquí para mover a "$folder"'
            : (isSelected ? 'Carpeta seleccionada' : 'Filtrar por "$folder"'),
        child: InkWell(
          onTap: () => setState(() => _selectedFolder = folder),
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: effectiveBgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: effectiveBorderColor,
                width: (isSelected || isHovered) ? 1.5 : 1.0,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: GrimoireTheme.accentPurple.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isHovered ? Icons.drive_file_move : (isSelected ? Icons.folder_open : Icons.folder),
                  size: 12,
                  color: isHovered || isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    isHovered ? 'Mover a $folder' : folder,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: (isSelected || isHovered) ? FontWeight.bold : FontWeight.normal,
                      color: (isSelected || isHovered) ? Colors.white : GrimoireTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: (isSelected || isHovered) ? GrimoireTheme.accentPurple.withValues(alpha: 0.35) : Colors.black38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$folderCount',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: (isSelected || isHovered) ? const Color(0xFFE9D5FF) : GrimoireTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 12,
                    color: (isSelected || isHovered) ? Colors.white70 : GrimoireTheme.textMuted,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  color: GrimoireTheme.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: GrimoireTheme.borderSubtle),
                  ),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          const Icon(Icons.drive_file_rename_outline, size: 14, color: Color(0xFF93C5FD)),
                          const SizedBox(width: 8),
                          Text(ref.tr('rename_folder'), style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open, size: 14, color: GrimoireTheme.accentEmerald),
                          const SizedBox(width: 8),
                          Text(ref.tr('open_assets_folder'), style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Text(ref.tr('delete'), style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (action) async {
                    if (action == 'rename') {
                      final newName = await AssetFolderDialogs.showRenameFolderDialog(context, gameName, folder);
                      if (newName != null && mounted) {
                        if (_selectedFolder == folder) {
                          setState(() => _selectedFolder = newName);
                        } else {
                          setState(() {});
                        }
                      }
                    } else if (action == 'open') {
                      GameFolderService.openGameAssetsFolderInExplorer(gameName, subfolder: folder);
                    } else if (action == 'delete') {
                      final deleted = await AssetFolderDialogs.showDeleteFolderConfirm(context, gameName, folder);
                      if (deleted && mounted) {
                        if (_selectedFolder == folder) {
                          setState(() => _selectedFolder = null);
                        } else {
                          setState(() {});
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final assetPath = details.data;
        if (assetPath.isEmpty) return false;
        final file = GameFolderService.resolveCardImageFile(gameName, assetPath);
        if (file == null) return false;
        final currentSub = GameFolderService.getAssetSubfolder(gameName, file);
        return currentSub != folder; // Can be accepted if not already in this folder
      },
      onAcceptWithDetails: (details) {
        final assetPath = details.data;
        final file = GameFolderService.resolveCardImageFile(gameName, assetPath);
        final fileName = file?.uri.pathSegments.last ?? assetPath.split('/').last;
        final ok = ref.read(editorProvider.notifier).moveAsset(
              gameName: gameName,
              relativeOrFileName: assetPath,
              targetSubfolder: folder,
            );
        if (ok && mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GrimoireTheme.accentEmerald,
              content: Text('Asset "$fileName" movido a "$folder".'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return buildChip(isHovered);
      },
    );
  }

  Widget _buildNewFolderButton(String gameName) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
      onAcceptWithDetails: (details) async {
        final assetPath = details.data;
        final newFolder = await AssetFolderDialogs.showCreateFolderDialog(context, gameName);
        if (newFolder != null && mounted) {
          final file = GameFolderService.resolveCardImageFile(gameName, assetPath);
          final fileName = file?.uri.pathSegments.last ?? assetPath.split('/').last;
          final ok = ref.read(editorProvider.notifier).moveAsset(
                gameName: gameName,
                relativeOrFileName: assetPath,
                targetSubfolder: newFolder,
              );
          if (ok && mounted) {
            setState(() => _selectedFolder = newFolder);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: GrimoireTheme.accentEmerald,
                content: Text('Asset "$fileName" movido a nueva carpeta "$newFolder".'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Tooltip(
          message: isHovered ? 'Soltar para crear carpeta y mover aquí' : ref.tr('new_folder_btn'),
          child: InkWell(
            onTap: () async {
              final newFolder = await AssetFolderDialogs.showCreateFolderDialog(this.context, gameName);
              if (newFolder != null && mounted) {
                setState(() => _selectedFolder = newFolder);
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: isHovered ? GrimoireTheme.accentPurple.withValues(alpha: 0.35) : const Color(0xFF16192E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isHovered ? GrimoireTheme.accentPurple : GrimoireTheme.accentPurple.withValues(alpha: 0.5),
                  width: isHovered ? 1.5 : 1.0,
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.5),
                          blurRadius: 6,
                        )
                      ]
                    : null,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.create_new_folder_outlined, size: 13, color: GrimoireTheme.accentPurple),
                  SizedBox(width: 2),
                  Icon(Icons.add, size: 10, color: GrimoireTheme.accentPurple),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String gameName) {
    final hasFolderFilter = _selectedFolder != null;
    final isCustomFolder = _selectedFolder != null && _selectedFolder!.isNotEmpty;
    final isRootFolder = _selectedFolder == '';
    final targetFolder = isCustomFolder ? _selectedFolder : null;

    final folderTitle = isCustomFolder
        ? 'No hay assets en "$_selectedFolder"'
        : (isRootFolder ? 'No hay assets en la Raíz' : ref.tr('no_assets_in_game'));
    final folderHint = hasFolderFilter
        ? 'Arrastra un asset aquí o usa el botón para subir una imagen.'
        : ref.tr('no_assets_hint');

    Widget buildContent(bool isHovered) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: isHovered
                ? BoxDecoration(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GrimoireTheme.accentPurple, width: 2.0),
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? GrimoireTheme.accentPurple.withValues(alpha: 0.3)
                        : GrimoireTheme.accentPurple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHovered ? Icons.drive_file_move : Icons.image_not_supported_outlined,
                    size: 32,
                    color: isHovered ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isHovered
                      ? (isCustomFolder ? '¡Suelta para mover a "$_selectedFolder"!' : '¡Suelta para mover a la Raíz!')
                      : folderTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isHovered ? GrimoireTheme.accentPurple : Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  folderHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GrimoireTheme.accentEmerald,
                          side: const BorderSide(color: GrimoireTheme.accentEmerald),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.upload_file, size: 14),
                        label: Text(
                          ref.tr('upload_asset'),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => _handleUpload(gameName),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GrimoireTheme.accentPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 14),
                        label: Text(
                          ref.tr('generate_ai_asset'),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => _handleAiGenerate(gameName),
                      ),
                    ),
                  ],
                ),
                if (hasFolderFilter) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    icon: const Icon(Icons.grid_view, size: 13, color: GrimoireTheme.accentPurple),
                    label: Text(ref.tr('all_assets'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.accentPurple)),
                    onPressed: () => setState(() => _selectedFolder = null),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!hasFolderFilter) {
      return buildContent(false);
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final assetPath = details.data;
        if (assetPath.isEmpty) return false;
        final file = GameFolderService.resolveCardImageFile(gameName, assetPath);
        if (file == null) return false;
        final currentSub = GameFolderService.getAssetSubfolder(gameName, file);
        return currentSub != targetFolder;
      },
      onAcceptWithDetails: (details) {
        final assetPath = details.data;
        final file = GameFolderService.resolveCardImageFile(gameName, assetPath);
        final fileName = file?.uri.pathSegments.last ?? assetPath.split('/').last;
        final ok = ref.read(editorProvider.notifier).moveAsset(
              gameName: gameName,
              relativeOrFileName: assetPath,
              targetSubfolder: targetFolder,
            );
        if (ok && mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GrimoireTheme.accentEmerald,
              content: Text(
                targetFolder == null
                    ? 'Asset "$fileName" movido a la Raíz.'
                    : 'Asset "$fileName" movido a "$targetFolder".',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return buildContent(isHovered);
      },
    );
  }

  Widget _buildAssetsGrid(
    BuildContext context,
    String gameName,
    List<File> assets,
    String currentArtUrl,
  ) {
    final selectedAssetPath = ref.watch(editorProvider.select((s) => s.selectedAssetPath));

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final file = assets[index];
        final fileName = file.uri.pathSegments.last;
        final relativeUrl = GameFolderService.getRelativeAssetPath(gameName, file);
        final assetSubfolder = GameFolderService.getAssetSubfolder(gameName, file);
        final isCurrentlyAssigned = currentArtUrl.isNotEmpty &&
            (currentArtUrl == relativeUrl || currentArtUrl.endsWith(fileName));
        final isSelectedAsset = selectedAssetPath == relativeUrl ||
            selectedAssetPath == fileName;

        final assetCard = InkWell(
          onTap: () {
            // Selecting the asset reveals its specifications (rename, slice sprites, remove background) in the inspector panel!
            // Clicking does NOT assign the asset to any layer. (Assigning is done only by dragging onto a layer).
            if (isSelectedAsset) {
              ref.read(editorProvider.notifier).selectAsset(null);
            } else {
              ref.read(editorProvider.notifier).selectAsset(relativeUrl);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151829),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelectedAsset
                    ? GrimoireTheme.accentPurple
                    : (isCurrentlyAssigned ? GrimoireTheme.accentEmerald : GrimoireTheme.borderSubtle),
                width: isSelectedAsset ? 2.5 : (isCurrentlyAssigned ? 2.0 : 1.0),
              ),
              boxShadow: isSelectedAsset
                  ? [
                      BoxShadow(
                        color: GrimoireTheme.accentPurple.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                      )
                    ]
                  : (isCurrentlyAssigned
                      ? [
                          BoxShadow(
                            color: GrimoireTheme.accentEmerald.withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image
                Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, size: 28, color: GrimoireTheme.textMuted),
                  ),
                ),

                // In use badge
                if (isCurrentlyAssigned)
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 4),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'ACTIVA',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Subfolder badge when viewing "Todos"
                if (_selectedFolder == null && assetSubfolder != null)
                  Positioned(
                    bottom: 22,
                    left: 5,
                    child: Tooltip(
                      message: 'Ver solo la carpeta "$assetSubfolder"',
                      child: InkWell(
                        onTap: () => setState(() => _selectedFolder = assetSubfolder),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.7), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder, size: 9, color: Color(0xFFC084FC)),
                              const SizedBox(width: 3),
                              Text(
                                assetSubfolder,
                                style: const TextStyle(fontSize: 8, color: Color(0xFFE9D5FF), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Drag indicator hint
                Positioned(
                  top: 5,
                  left: isCurrentlyAssigned ? null : 5,
                  right: isCurrentlyAssigned ? 26 : null,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.drag_indicator, size: 10, color: Colors.white70),
                  ),
                ),

                // More Options Menu Button
                Positioned(
                  top: 2,
                  right: 2,
                  child: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert, size: 13, color: Colors.white),
                    ),
                    color: GrimoireTheme.surfaceElevated,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: GrimoireTheme.borderSubtle),
                    ),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'open_inspector',
                        child: const Row(
                          children: [
                            Icon(Icons.tune, size: 14, color: Color(0xFFC084FC)),
                            SizedBox(width: 8),
                            Text('Abrir en el Inspector', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'preview',
                        child: const Row(
                          children: [
                            Icon(Icons.fullscreen, size: 14, color: Color(0xFF93C5FD)),
                            SizedBox(width: 8),
                            Text('Ver en Grande', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'move',
                        child: const Row(
                          children: [
                            Icon(Icons.drive_file_move_outlined, size: 14, color: GrimoireTheme.accentPurple),
                            SizedBox(width: 8),
                            Text('Mover a carpeta...', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'slice_sprites',
                        child: const Row(
                          children: [
                            Icon(Icons.grid_goldenratio, size: 14, color: Color(0xFFC084FC)),
                            SizedBox(width: 8),
                            Text('Dividir en Sprites...', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove_bg',
                        child: const Row(
                          children: [
                            Icon(Icons.auto_fix_high, size: 14, color: GrimoireTheme.accentEmerald),
                            SizedBox(width: 8),
                            Text('Quitar Fondo...', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Text(ref.tr('delete'), style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (action) async {
                      if (action == 'open_inspector' || action == 'specs') {
                        ref.read(editorProvider.notifier).selectAsset(relativeUrl);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 2),
                            backgroundColor: const Color(0xFF16182E),
                            content: Text('Asset "$fileName" abierto en el Inspector'),
                          ),
                        );
                      } else if (action == 'preview') {
                        _showEnlargedPreview(file, fileName, gameName, relativeUrl);
                      } else if (action == 'move') {
                        await AssetFolderDialogs.showMoveAssetDialog(
                          context: context,
                          ref: ref,
                          gameName: gameName,
                          assetFile: file,
                        );
                        if (mounted) setState(() {});
                      } else if (action == 'slice_sprites') {
                        _handleSplitSpriteSheet(gameName, file);
                      } else if (action == 'remove_bg') {
                        BackgroundRemovalDialog.show(context, sourceImageFile: file, gameName: gameName);
                      } else if (action == 'delete') {
                        _confirmDeleteAsset(gameName, fileName);
                      }
                    },
                  ),
                ),

                // Bottom Filename Bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black,
                        ],
                      ),
                    ),
                    child: Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        return Draggable<String>(
          data: relativeUrl,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(10),
            color: Colors.transparent,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GrimoireTheme.accentEmerald, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 14, spreadRadius: 2)],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: Text(
                        fileName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: assetCard,
          ),
          child: Tooltip(
            message: isSelectedAsset
                ? 'Asset activo en el Inspector (clic para deseleccionar)'
                : 'Clic para abrir en el Inspector • Arrastra para mover a carpetas o asignar',
            waitDuration: const Duration(milliseconds: 600),
            child: assetCard,
          ),
        );
      },
    );
  }
}
