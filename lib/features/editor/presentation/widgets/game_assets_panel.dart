import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../services/game_folder_service.dart';
import '../providers/editor_provider.dart';
import 'package:grimoire_studio/features/ai_generator/presentation/widgets/ai_prompt_dialog.dart';

class GameAssetsCollapsiblePanel extends ConsumerStatefulWidget {
  const GameAssetsCollapsiblePanel({super.key});

  @override
  ConsumerState<GameAssetsCollapsiblePanel> createState() => _GameAssetsCollapsiblePanelState();
}

class _GameAssetsCollapsiblePanelState extends ConsumerState<GameAssetsCollapsiblePanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleUpload(String gameName) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final filePath = files.first.path!;
        final relativeUrl = await ref.read(editorProvider.notifier).uploadImageForActiveCard(filePath);
        if (mounted && relativeUrl != null) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GrimoireTheme.accentEmerald,
              content: Text('Imagen guardada y vinculada a la carta: $relativeUrl'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error al subir imagen: $e'),
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

  void _showEnlargedPreview(File file, String fileName) {
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

    final allAssets = GameFolderService.listGameAssetImages(gameName);
    final filteredAssets = _searchFilter.isEmpty
        ? allAssets
        : allAssets.where((f) => f.uri.pathSegments.last.toLowerCase().contains(_searchFilter.toLowerCase())).toList();

    // If collapsed, display a sleek vertical interactive rail
    if (!editorState.showAssetsPanel) {
      return InkWell(
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
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }

    // Expanded Assets Panel
    return Container(
      width: 280,
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
                  onPressed: () => GameFolderService.openGameFolderInExplorer(gameName),
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

          // Action Buttons Bar: Subir Imagen & Generar con IA
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.file_upload_outlined, size: 14),
                    label: Text(
                      ref.tr('upload_asset'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: Text(
                      ref.tr('generate_ai_asset'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _handleAiGenerate(gameName),
                  ),
                ),
              ],
            ),
          ),

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

  Widget _buildEmptyState(BuildContext context, String gameName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.image_not_supported_outlined, size: 32, color: GrimoireTheme.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              ref.tr('no_assets_in_game'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              ref.tr('no_assets_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GrimoireTheme.accentEmerald,
                    side: const BorderSide(color: GrimoireTheme.accentEmerald),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.upload_file, size: 14),
                  label: Text(ref.tr('upload_asset'), style: const TextStyle(fontSize: 11)),
                  onPressed: () => _handleUpload(gameName),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GrimoireTheme.accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: Text(ref.tr('generate_ai_asset'), style: const TextStyle(fontSize: 11)),
                  onPressed: () => _handleAiGenerate(gameName),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetsGrid(
    BuildContext context,
    String gameName,
    List<File> assets,
    String currentArtUrl,
  ) {
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
        final relativeUrl = 'assets/$fileName';
        final isCurrentlyAssigned = currentArtUrl.isNotEmpty &&
            (currentArtUrl == relativeUrl || currentArtUrl.endsWith(fileName));

        return InkWell(
          onTap: () {
            ref.read(editorProvider.notifier).assignAssetToActiveCard(relativeUrl);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: GrimoireTheme.accentEmerald,
                duration: const Duration(milliseconds: 1400),
                content: Text('${ref.tr('asset_assigned_toast')}: $fileName'),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151829),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCurrentlyAssigned ? GrimoireTheme.accentEmerald : GrimoireTheme.borderSubtle,
                width: isCurrentlyAssigned ? 2.0 : 1.0,
              ),
              boxShadow: isCurrentlyAssigned
                  ? [
                      BoxShadow(
                        color: GrimoireTheme.accentEmerald.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
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
                        value: 'assign',
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: GrimoireTheme.accentEmerald),
                            const SizedBox(width: 8),
                            Text(ref.tr('click_to_assign'), style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'preview',
                        child: Row(
                          children: [
                            const Icon(Icons.fullscreen, size: 14, color: Color(0xFF93C5FD)),
                            const SizedBox(width: 8),
                            const Text('Ver en Grande', style: TextStyle(fontSize: 11)),
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
                    onSelected: (action) {
                      if (action == 'assign') {
                        ref.read(editorProvider.notifier).assignAssetToActiveCard(relativeUrl);
                      } else if (action == 'preview') {
                        _showEnlargedPreview(file, fileName);
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
      },
    );
  }
}
