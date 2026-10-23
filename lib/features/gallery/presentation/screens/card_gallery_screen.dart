import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';
import 'package:grimoire_studio/core/widgets/grimoire_emoji_picker.dart';
import 'package:grimoire_studio/features/ai_generator/presentation/widgets/batch_ai_dialog.dart';
import 'package:grimoire_studio/features/editor/presentation/widgets/card_renderer_widget.dart';
import 'package:grimoire_studio/features/editor/models/card_template.dart';
import 'package:grimoire_studio/features/editor/presentation/dialogs/predefined_templates_dialog.dart';
import 'package:grimoire_studio/features/editor/presentation/dialogs/batch_card_creation_dialog.dart';
import 'package:grimoire_studio/features/editor/presentation/dialogs/card_3d_viewer_dialog.dart';
import 'package:grimoire_studio/core/widgets/grimoire_toast.dart';

class CardGalleryScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenEditor;
  final VoidCallback? onBatchExport;

  const CardGalleryScreen({
    super.key,
    required this.onOpenEditor,
    this.onBatchExport,
  });

  @override
  ConsumerState<CardGalleryScreen> createState() => _CardGalleryScreenState();
}

class _CardGalleryScreenState extends ConsumerState<CardGalleryScreen> {
  String _searchQuery = '';
  String _selectedGame = 'All';
  bool _groupByGame = true;
  bool _compactGrid = false;
  final Map<String, String?> _gameCategoryFilter = {};
  final Set<String> _selectedFileTypes = {'type_300dpi'};
  final Map<String, bool> _showDefaultModelsForGame = {};
  final Map<String, ScrollController> _categoryScrollControllers = {};
  final Map<String, ScrollController> _modelsScrollControllers = {};

  ScrollController _getCategoryScrollController(String gameName) =>
      _categoryScrollControllers.putIfAbsent(gameName, () => ScrollController());

  ScrollController _getModelsScrollController(String gameName) =>
      _modelsScrollControllers.putIfAbsent(gameName, () => ScrollController());

  void _scrollHorizontally(ScrollController controller, double delta) {
    if (!controller.hasClients) return;
    final target = (controller.offset + delta).clamp(0.0, controller.position.maxScrollExtent);
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildScrollArrowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: GrimoireTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: Icon(icon, size: 16, color: GrimoireTheme.textSecondary),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _categoryScrollControllers.values) {
      c.dispose();
    }
    for (final c in _modelsScrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleImportGrimoire() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['grimoire', 'zip'],
        dialogTitle: 'Seleccionar paquete de juego Grimoire Studio (.grimoire / .zip)',
      );

      if (files.isEmpty || files.first.path == null) {
        return;
      }

      final file = File(files.first.path!);
      final result = await ref.read(editorProvider.notifier).importGrimoirePackage(file);
      if (!mounted) return;

      if (result.success) {
        GrimoireToast.success(context, result.message);
      } else {
        GrimoireToast.error(context, result.message);
      }
    } catch (e) {
      if (mounted) {
        GrimoireToast.error(context, 'Error al importar paquete: $e');
      }
    }
  }

  Future<void> _handleExportGrimoireGame(String gameName) async {
    try {
      final safeName = gameName.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      final defaultFileName = '$safeName.grimoire';

      // First generate the temporary package
      final exportedFile = await ref.read(editorProvider.notifier).exportGrimoirePackage(
        gameName: gameName,
      );
      final fileBytes = await exportedFile.readAsBytes();

      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Exportar Paquete .grimoire de "$gameName"',
        fileName: defaultFileName,
        bytes: fileBytes,
        type: FileType.custom,
        allowedExtensions: ['grimoire'],
      );

      // If user cancelled save file dialog, exit gracefully
      if (savedUri == null) {
        return;
      }

      String savedPath;
      try {
        savedPath = savedUri.toFilePath();
      } catch (_) {
        savedPath = savedUri.path;
      }

      if (!mounted) return;

      GrimoireToast.success(
        context,
        '¡Paquete de "$gameName" exportado con éxito como archivo .grimoire!',
        actionLabel: 'Abrir Carpeta',
        onAction: () {
          final finalFile = File(savedPath);
          GameFolderService.openDirectoryInExplorer(finalFile.parent);
        },
      );
    } catch (e) {
      if (mounted) {
        GrimoireToast.error(context, 'Error al exportar paquete .grimoire: $e');
      }
    }
  }

  bool _isModelCard(Map<String, dynamic> row) {
    return ref.read(editorProvider.notifier).isRowCategoryDefault(row) ||
           ref.read(editorProvider.notifier).isRowGameDefault(row);
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final allRows = editorState.project.rows;

    // Extract unique board games
    final allGamesSet = <String>{};
    for (final r in allRows) {
      final g = r['game']?.toString().trim();
      if (g != null && g.isNotEmpty && !editorState.deletedGames.contains(g)) {
        allGamesSet.add(g);
      }
    }
    for (final g in editorState.gameCategories.keys) {
      final trimmed = g.trim();
      if (trimmed.isNotEmpty && !editorState.deletedGames.contains(trimmed)) {
        allGamesSet.add(trimmed);
      }
    }
    final allGames = allGamesSet.toList();
    if (allGames.isEmpty && _selectedGame != 'All') {
      _selectedGame = 'All';
    }

    // Filter rows based on search, board game, and game-scoped category
    final filteredRows = allRows.where((row) {
      final name = (row['card_name'] ?? '').toString().toLowerCase();
      final type = (row['type'] ?? '').toString().toLowerCase();
      final game = (row['game'] ?? '').toString();
      final cat = (row['category'] ?? '').toString();

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          type.contains(_searchQuery.toLowerCase()) ||
          game.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesGame = _selectedGame == 'All' ||
          game.toLowerCase() == _selectedGame.toLowerCase();
      
      final activeCatForGame = _gameCategoryFilter[game];
      final matchesCategory = activeCatForGame == null ||
          activeCatForGame == 'All' ||
          cat.toLowerCase() == activeCatForGame.toLowerCase();

      return matchesQuery && matchesGame && matchesCategory;
    }).toList();

    // Models always appear at the top ("arriba")
    filteredRows.sort((a, b) {
      final aIsModel = _isModelCard(a);
      final bIsModel = _isModelCard(b);
      if (aIsModel && !bIsModel) return -1;
      if (!aIsModel && bIsModel) return 1;
      return 0;
    });

    final playableCardsCount = filteredRows.where((r) => !_isModelCard(r)).length;

    return Scaffold(
      backgroundColor: GrimoireTheme.bgCanvas,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Games / Projects Sidebar
          _buildGamesSidebar(allRows, allGames),

          // Right Card Showcase
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Controls Bar: Count, Filter Search, File Types, Grouping Switcher, Sort
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                      Row(
                        children: [
                          Text(
                            '$playableCardsCount ${ref.tr('items_count')}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              ref.tr('deck_sync_ok'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: GrimoireTheme.accentPurple,
                              ),
                            ),
                          ),
                          if (_selectedGame != 'All') ...[
                            const SizedBox(width: 8),
                            Chip(
                              backgroundColor: GrimoireTheme.surfaceElevated,
                              side: const BorderSide(color: GrimoireTheme.borderSubtle),
                              avatar: Icon(_getGameIcon(_selectedGame), size: 14, color: GrimoireTheme.accentPurple),
                              label: Text(
                                _selectedGame,
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              onDeleted: () => setState(() => _selectedGame = 'All'),
                              deleteIconColor: GrimoireTheme.textMuted,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                          const SizedBox(width: 16),

                          // Inline Search Input (Filter)
                          Container(
                            width: 180,
                            height: 34,
                            decoration: BoxDecoration(
                              color: GrimoireTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GrimoireTheme.borderSubtle),
                            ),
                            child: TextField(
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: ref.tr('filter_search_hint'),
                                hintStyle: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                                prefixIcon: const Icon(Icons.search, size: 14, color: GrimoireTheme.textMuted),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14, color: GrimoireTheme.textMuted),
                                        onPressed: () => setState(() => _searchQuery = ''),
                                      )
                                    : null,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                border: InputBorder.none,
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Filter Popover Button: Tipos de Salida
                          PopupMenuButton<String>(
                            tooltip: ref.tr('filter_file_types'),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            color: GrimoireTheme.surfacePanel,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                enabled: false,
                                child: Text(
                                  ref.tr('filter_file_types'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary),
                                ),
                              ),
                              const PopupMenuDivider(),
                              _buildPopupCheckboxItem('type_300dpi', ref.tr('type_300dpi')),
                              _buildPopupCheckboxItem('type_pdf_print', ref.tr('type_pdf_print')),
                              _buildPopupCheckboxItem('type_vector', ref.tr('type_vector')),
                            ],
                            child: Container(
                              height: 34,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: GrimoireTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GrimoireTheme.borderSubtle),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.tune, size: 14, color: GrimoireTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    ref.tr('filter_title'),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down, size: 16, color: GrimoireTheme.textMuted),
                                ],
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => setState(() => _searchQuery = ''),
                              child: Text(ref.tr('filter_reset'), style: const TextStyle(fontSize: 11.5, color: GrimoireTheme.accentPurple)),
                            ),
                          ],
                        ],
                      ),

                            // Grouping Switcher & Sorter
                            Row(
                              children: [
                                // Group by Game Toggle
                                Tooltip(
                                  message: _groupByGame
                                      ? 'Agrupado por Juego de Mesa (Activo)'
                                      : 'Vista Continua (Activo)',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: GrimoireTheme.surfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: GrimoireTheme.borderSubtle),
                                    ),
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () => setState(() => _groupByGame = true),
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _groupByGame ? GrimoireTheme.accentPurple.withValues(alpha: 0.25) : Colors.transparent,
                                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.folder_special_outlined,
                                                  size: 15,
                                                  color: _groupByGame ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  ref.tr('group_by_game'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: _groupByGame ? FontWeight.bold : FontWeight.normal,
                                                    color: _groupByGame ? Colors.white : GrimoireTheme.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => setState(() => _groupByGame = false),
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: !_groupByGame ? GrimoireTheme.accentPurple.withValues(alpha: 0.25) : Colors.transparent,
                                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.grid_view,
                                                  size: 15,
                                                  color: !_groupByGame ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  ref.tr('group_none'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: !_groupByGame ? FontWeight.bold : FontWeight.normal,
                                                    color: !_groupByGame ? Colors.white : GrimoireTheme.textMuted,
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
                                const SizedBox(width: 8),

                                // Grid Density Switcher (Comfortable vs Compact)
                                Tooltip(
                                  message: _compactGrid ? 'Modo Compacto (Activo)' : 'Modo Cómodo (Activo)',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: GrimoireTheme.surfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: GrimoireTheme.borderSubtle),
                                    ),
                                    child: Row(
                                      children: [
                                        InkWell(
                                          key: const Key('gallery_density_comfortable'),
                                          onTap: () => setState(() => _compactGrid = false),
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: !_compactGrid ? GrimoireTheme.accentPurple.withValues(alpha: 0.25) : Colors.transparent,
                                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                                            ),
                                            child: Icon(
                                              Icons.grid_view_rounded,
                                              size: 15,
                                              color: !_compactGrid ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          key: const Key('gallery_density_compact'),
                                          onTap: () => setState(() => _compactGrid = true),
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _compactGrid ? GrimoireTheme.accentPurple.withValues(alpha: 0.25) : Colors.transparent,
                                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                                            ),
                                            child: Icon(
                                              Icons.apps_rounded,
                                              size: 15,
                                              color: _compactGrid ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Sorter
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: GrimoireTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: GrimoireTheme.borderSubtle),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(ref.tr('sort_low_to_high'), style: const TextStyle(fontSize: 12, color: Colors.white)),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.keyboard_arrow_down, size: 16, color: GrimoireTheme.textMuted),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                        Expanded(
                          child: allGames.isEmpty || filteredRows.isEmpty
                              ? _buildEmptyStateContent(filteredRows, allRows, allGames)
                              : _groupByGame
                                  ? _buildGroupedByGameView(filteredRows, allRows)
                                  : _buildFlatGridView(filteredRows, allRows),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- Grouped View by Board Game ---
  Widget _buildGroupedByGameView(List<Map<String, dynamic>> filteredRows, List<Map<String, dynamic>> allRows) {
    // Partition filtered cards by game, keeping mockups only on top
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final row in filteredRows) {
      final game = (row['game'] ?? 'General').toString();
      groups.putIfAbsent(game, () => []);
      if (!_isModelCard(row)) {
        groups[game]!.add(row);
      }
    }

    return ListView(
      children: [
        for (final entry in groups.entries) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GrimoireTheme.surfacePanel.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Game Header Section
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                          ),
                          child: Icon(_getGameIcon(entry.key), size: 18, color: GrimoireTheme.accentPurple),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              '${entry.value.length} ${ref.tr('cards_in_game')}',
                              style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Game Section Actions
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PopupMenuButton<String>(
                          tooltip: 'Añadir carta por categoría',
                          color: GrimoireTheme.surfaceElevated,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: GrimoireTheme.borderSubtle),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 16, color: GrimoireTheme.accentPurple),
                                const SizedBox(width: 4),
                                Text(
                                  ref.tr('add_row'),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GrimoireTheme.accentPurple),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 16, color: GrimoireTheme.accentPurple),
                              ],
                            ),
                          ),
                          onSelected: (val) {
                            if (val == '__new_category__') {
                              _showNewCategoryDialog(entry.key);
                            } else if (val == '__basic__') {
                              ref.read(editorProvider.notifier).addCardToGame(
                                entry.key,
                                cardName: '${ref.tr('default_card_name')} (${entry.key})',
                                type: ref.tr('default_card_type'),
                                rulesText: ref.tr('default_rules_text').replaceAll('{game}', entry.key),
                              );
                              GrimoireToast.success(
                                context,
                                'Nueva carta estándar añadida a "${entry.key}".',
                              );
                            } else {
                              final cats = ref.read(editorProvider.notifier).getCategoriesForGame(entry.key);
                              final cat = cats.firstWhere((c) => c.name == val, orElse: () => cats.first);
                              ref.read(editorProvider.notifier).createCardFromCategory(entry.key, cat);
                              GrimoireToast.success(
                                context,
                                'Nueva carta "${cat.name}" creada para "${entry.key}".',
                              );
                            }
                          },
                          itemBuilder: (ctx) {
                            final cats = ref.read(editorProvider.notifier).getCategoriesForGame(entry.key);
                            return [
                              PopupMenuItem<String>(
                                value: '__basic__',
                                child: const Row(
                                  children: [
                                    Icon(Icons.note_add_outlined, size: 15, color: GrimoireTheme.textMuted),
                                    SizedBox(width: 8),
                                    Text('Carta Estándar', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (cats.isNotEmpty) const PopupMenuDivider(height: 8),
                              ...cats.map((cat) => PopupMenuItem<String>(
                                value: cat.name,
                                child: Row(
                                  children: [
                                    Text(cat.icon, style: const TextStyle(fontSize: 15)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cat.name,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                              const PopupMenuDivider(height: 8),
                              PopupMenuItem<String>(
                                value: '__new_category__',
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_circle_outline, size: 15, color: GrimoireTheme.accentPurple),
                                    const SizedBox(width: 8),
                                    Text(
                                      ref.tr('new_category_btn'),
                                      style: const TextStyle(fontSize: 12, color: GrimoireTheme.accentPurple, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ];
                          },
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: ref.tr('batch_card_creator'),
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => BatchCardCreationDialog(initialGame: entry.key),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: GrimoireTheme.accentCyan.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GrimoireTheme.accentCyan.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_all, size: 15, color: GrimoireTheme.accentCyan),
                                  const SizedBox(width: 4),
                                  Text(
                                    ref.tr('batch_card_creator'),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GrimoireTheme.accentCyan),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFC7D2FE),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            minimumSize: const Size(0, 36),
                          ),
                          icon: const Icon(Icons.settings_outlined, size: 15, color: GrimoireTheme.accentIndigo),
                          label: Text(
                            ref.tr('manage_categories'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _showManageCategoriesDialog(entry.key),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.5)),
                            backgroundColor: const Color(0xFF16182E),
                            foregroundColor: const Color(0xFFE0E7FF),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.file_download_outlined, size: 15, color: GrimoireTheme.accentIndigo),
                          label: Text(
                            ref.tr('export_game'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            widget.onOpenEditor();
                            GrimoireToast.info(context, 'Abriendo editor para exportar "${entry.key}"...');
                          },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: GrimoireTheme.accentPink.withValues(alpha: 0.5)),
                            backgroundColor: const Color(0xFF1E1420),
                            foregroundColor: const Color(0xFFFECDD3),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 15, color: GrimoireTheme.accentPink),
                          label: Text(
                            ref.tr('delete_game'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _confirmDeleteGame(entry.key, entry.value.length),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Game Categories & Predefined Archetypes Bar (Inside the Game)
                _buildGameCategoriesBar(
                  entry.key,
                  allRows.where((r) => (r['game'] ?? '').toString() == entry.key).toList(),
                ),
                const SizedBox(height: 14),

                // Responsive Grid for cards in this board game
                if (entry.value.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10121E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GrimoireTheme.borderSubtle.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_list_off, size: 32, color: GrimoireTheme.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No hay cartas en este juego con el filtro de categoría activo.',
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Puedes crear una carta con este modelo o restablecer para ver todas.',
                          style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_gameCategoryFilter[entry.key] != null) ...[
                              OutlinedButton(
                                onPressed: () => setState(() => _gameCategoryFilter[entry.key] = null),
                                child: const Text('Ver todas las cartas'),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GrimoireTheme.accentPurple,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Crear Carta'),
                              onPressed: () {
                                final cats = ref.read(editorProvider.notifier).getCategoriesForGame(entry.key);
                                final activeCatName = _gameCategoryFilter[entry.key];
                                final cat = cats.firstWhere((c) => c.name == activeCatName, orElse: () => cats.isNotEmpty ? cats.first : GameCategory(id: 'cat', name: 'General'));
                                _generateCardFromModel(entry.key, cat);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: _compactGrid ? 190 : 260,
                      crossAxisSpacing: _compactGrid ? 10 : 16,
                      mainAxisSpacing: _compactGrid ? 10 : 16,
                      childAspectRatio: _compactGrid ? 0.68 : 0.70,
                    ),
                    itemCount: entry.value.length,
                    itemBuilder: (context, idx) {
                      final row = entry.value[idx];
                      final originalIndex = allRows.indexOf(row);
                      return _buildGalleryCardTile(row, originalIndex);
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Flat Continuous Grid View ---
  Widget _buildFlatGridView(List<Map<String, dynamic>> filteredRows, List<Map<String, dynamic>> allRows) {
    final playableRows = filteredRows.where((r) => !_isModelCard(r)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedGame != 'All') ...[
          _buildGameCategoriesBar(
            _selectedGame,
            allRows.where((r) => (r['game'] ?? '').toString() == _selectedGame).toList(),
          ),
          const SizedBox(height: 14),
        ],
        Expanded(
          child: playableRows.isEmpty
              ? _buildNoFilteredCardsEmptyState()
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: _compactGrid ? 190 : 260,
                    crossAxisSpacing: _compactGrid ? 10 : 16,
                    mainAxisSpacing: _compactGrid ? 10 : 16,
                    childAspectRatio: _compactGrid ? 0.68 : 0.70,
                  ),
                  itemCount: playableRows.length,
                  itemBuilder: (context, index) {
                    final row = playableRows[index];
                    final originalIndex = allRows.indexOf(row);
                    return _buildGalleryCardTile(row, originalIndex);
                  },
                ),
        ),
      ],
    );
  }

  // --- Empty State Controller ---
  Widget _buildEmptyStateContent(
    List<Map<String, dynamic>> filteredRows,
    List<Map<String, dynamic>> allRows,
    List<String> allGames,
  ) {
    if (allGames.isEmpty) {
      return _buildNoGamesEmptyState();
    }
    if (_selectedGame != 'All') {
      final selectedGameCards = allRows
          .where((r) => (r['game'] ?? '').toString().toLowerCase() == _selectedGame.toLowerCase())
          .toList();
      if (selectedGameCards.isEmpty) {
        return _buildEmptyGameView(_selectedGame);
      }
    } else {
      if (allRows.isEmpty) {
        return _buildNoCardsInAnyGameEmptyState(allGames);
      }
    }
    return _buildNoFilteredCardsEmptyState();
  }

  // --- Empty State: No Games in Studio ---
  Widget _buildNoGamesEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: GrimoireTheme.surfacePanel.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Icon Badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                      GrimoireTheme.accentIndigo.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_esports_outlined,
                  size: 36,
                  color: GrimoireTheme.accentPurple,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                ref.tr('no_games_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                ref.tr('no_games_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: GrimoireTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  // Button: Crear mi Primer Juego
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                      shadowColor: GrimoireTheme.accentPurple.withValues(alpha: 0.5),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text(
                      ref.tr('create_first_game_btn'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _showNewGameDialog,
                  ),

                  // Button: Restaurar Juegos de Ejemplo (Magic & Unstable Unicorns)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.5)),
                      backgroundColor: GrimoireTheme.accentIndigo.withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFFC7D2FE),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.restore, size: 17, color: GrimoireTheme.accentIndigo),
                    label: Text(
                      ref.tr('restore_sample_games_btn'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      ref.read(editorProvider.notifier).restoreSampleGames();
                      setState(() {
                        _selectedGame = 'All';
                        _gameCategoryFilter.clear();
                        _searchQuery = '';
                      });
                      GrimoireToast.success(context, ref.tr('sample_games_restored'));
                    },
                  ),

                  // Button: Importar Paquete .grimoire
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.5)),
                      backgroundColor: GrimoireTheme.accentEmerald.withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFFA7F3D0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.file_open_outlined, size: 17, color: GrimoireTheme.accentEmerald),
                    label: const Text(
                      'Importar .grimoire',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _handleImportGrimoire,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Empty State: Games exist, but 0 Cards in Studio ---
  Widget _buildNoCardsInAnyGameEmptyState(List<String> allGames) {
    final targetGame = allGames.isNotEmpty ? allGames.first : 'General';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: GrimoireTheme.surfacePanel.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Icon Badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                      GrimoireTheme.accentIndigo.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.style_outlined,
                  size: 36,
                  color: GrimoireTheme.accentPurple,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                ref.tr('no_cards_in_studio_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                ref.tr('no_cards_in_studio_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: GrimoireTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  // Button: Añadir Primera Carta
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                      shadowColor: GrimoireTheme.accentPurple.withValues(alpha: 0.5),
                    ),
                    icon: const Icon(Icons.add, size: 17),
                    label: Text(
                      '${ref.tr('add_first_card_to')} "$targetGame"',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      ref.read(editorProvider.notifier).addCardToGame(
                        targetGame,
                        cardName: '${ref.tr('default_card_name')} ($targetGame)',
                        type: ref.tr('default_card_type'),
                        rulesText: ref.tr('default_rules_text').replaceAll('{game}', targetGame),
                      );
                      GrimoireToast.success(
                        context,
                        'Primera carta añadida al juego "$targetGame".',
                      );
                    },
                  ),

                  // Button: Crear Modelo Preset
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 17, color: Colors.black),
                    label: Text(
                      ref.tr('create_preset_card_model'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showCreateCardPresetModelDialog(targetGame),
                  ),

                  // Button: Restaurar Juegos de Ejemplo
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GrimoireTheme.borderSubtle.withValues(alpha: 0.8)),
                      backgroundColor: const Color(0xFF131522),
                      foregroundColor: GrimoireTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.restore, size: 17, color: GrimoireTheme.textMuted),
                    label: Text(
                      ref.tr('restore_sample_games_btn'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      ref.read(editorProvider.notifier).restoreSampleGames();
                      setState(() {
                        _selectedGame = 'All';
                        _gameCategoryFilter.clear();
                        _searchQuery = '';
                      });
                      GrimoireToast.success(context, ref.tr('sample_games_restored'));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Empty State: Selected Game has No Cards ---
  Widget _buildEmptyGameView(String gameName) {
    return ListView(
      children: [
        _buildGameCategoriesBar(gameName, []),
        const SizedBox(height: 32),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: GrimoireTheme.surfacePanel.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getGameIcon(gameName), size: 44, color: GrimoireTheme.accentPurple),
                const SizedBox(height: 14),
                Text(
                  ref.tr('game_has_no_cards_title'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  ref.tr('game_has_no_cards_desc'),
                  style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GrimoireTheme.accentPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        '${ref.tr('add_first_card_to')} "$gameName"',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        ref.read(editorProvider.notifier).addCardToGame(
                          gameName,
                          cardName: '${ref.tr('default_card_name')} ($gameName)',
                          type: ref.tr('default_card_type'),
                          rulesText: ref.tr('default_rules_text').replaceAll('{game}', gameName),
                        );
                        GrimoireToast.success(
                          context,
                          'Primera carta añadida al juego "$gameName".',
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      key: const Key('btn_empty_create_preset_model'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.black),
                      label: Text(
                        ref.tr('create_preset_card_model'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showCreateCardPresetModelDialog(gameName),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Empty State: Filter Matched No Cards ---
  Widget _buildNoFilteredCardsEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: GrimoireTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            ref.tr('no_cards_found'),
            style: const TextStyle(color: GrimoireTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedGame = 'All';
                _gameCategoryFilter.clear();
                _searchQuery = '';
              });
            },
            child: Text(ref.tr('filter_reset')),
          ),
        ],
      ),
    );
  }



  Widget _buildGamesSidebar(List<Map<String, dynamic>> allRows, List<String> allGames) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: GrimoireTheme.surfacePanel,
        border: Border(right: BorderSide(color: GrimoireTheme.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.casino_outlined, size: 16, color: GrimoireTheme.accentPurple),
                    const SizedBox(width: 8),
                    Text(
                      ref.tr('board_game').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: GrimoireTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: ref.tr('new_game_btn'),
                  icon: const Icon(Icons.add_circle_outline, size: 18, color: GrimoireTheme.accentPurple),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: _showNewGameDialog,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: GrimoireTheme.borderSubtle),

          // Scrollable Games List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                // "Todos los Juegos" Tile
                _buildSidebarGameTile(
                  title: ref.tr('all_games'),
                  icon: Icons.auto_awesome_motion,
                  count: allRows.where((r) => !_isModelCard(r)).length,
                  isSelected: _selectedGame == 'All',
                  onTap: () => setState(() => _selectedGame = 'All'),
                ),
                const SizedBox(height: 4),

                // Tile for each game
                for (final game in allGames) ...[
                  _buildSidebarGameTile(
                    title: game,
                    icon: _getGameIcon(game),
                    count: allRows.where((r) => (r['game'] ?? '').toString() == game && !_isModelCard(r)).length,
                    isSelected: _selectedGame == game,
                    onTap: () => setState(() => _selectedGame = game),
                    onDelete: () => _confirmDeleteGame(
                      game,
                      allRows.where((r) => (r['game'] ?? '').toString() == game && !_isModelCard(r)).length,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: GrimoireTheme.borderSubtle),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // + Nuevo Juego
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                    backgroundColor: GrimoireTheme.accentPurple.withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFFE9D5FF),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 15, color: GrimoireTheme.accentPurple),
                  label: Text(ref.tr('new_game_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _showNewGameDialog,
                ),
                const SizedBox(height: 6),

                // Importar .grimoire
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.5)),
                    backgroundColor: GrimoireTheme.accentEmerald.withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFFA7F3D0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.file_open_outlined, size: 15, color: GrimoireTheme.accentEmerald),
                  label: const Text('Importar .grimoire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _handleImportGrimoire,
                ),
                const SizedBox(height: 6),

                // Generación IA en Lote
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.amber.shade400.withValues(alpha: 0.5)),
                    backgroundColor: Colors.amber.shade900.withValues(alpha: 0.15),
                    foregroundColor: Colors.amber.shade200,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 15, color: Colors.amber),
                  label: const Text('Generación IA en Lote', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => BatchAiDialog.show(context),
                ),
                const SizedBox(height: 6),

                // Lote 300 DPI Export
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.5)),
                    backgroundColor: GrimoireTheme.accentIndigo.withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFFC7D2FE),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.archive_outlined, size: 15, color: GrimoireTheme.accentIndigo),
                  label: Text(ref.tr('btn_batch_export'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => widget.onBatchExport?.call(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarGameTile({
    required String title,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return _SidebarGameTileItem(
      title: title,
      icon: icon,
      count: count,
      isSelected: isSelected,
      onTap: onTap,
      onDelete: onDelete,
    );
  }

  PopupMenuItem<String> _buildPopupCheckboxItem(String key, String label) {
    final isChecked = _selectedFileTypes.contains(key);
    return PopupMenuItem<String>(
      onTap: () {
        _toggleFileType(key, !isChecked);
      },
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: isChecked ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }

  void _toggleFileType(String key, bool? isChecked) {
    setState(() {
      if (isChecked == true) {
        _selectedFileTypes.add(key);
      } else {
        _selectedFileTypes.remove(key);
      }
    });
  }



  // --- Game Categories & Predefined Archetypes Bar (Inside each Game) ---
  Widget _buildGameCategoriesBar(String gameName, List<Map<String, dynamic>> allGameCards) {
    final editorState = ref.watch(editorProvider);
    final allRows = editorState.project.rows;
    final categories = ref.read(editorProvider.notifier).getCategoriesForGame(gameName);

    final normalizedGame = gameName.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
    final predefinedCards = <Map<String, dynamic>>[];
    for (final row in allRows) {
      final rowGame = (row['game'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
      if (rowGame == normalizedGame) {
        final isCatDefault = ref.read(editorProvider.notifier).isRowCategoryDefault(row);
        final isGameDefault = ref.read(editorProvider.notifier).isRowGameDefault(row);
        if (isCatDefault || isGameDefault) {
          predefinedCards.add(row);
        }
      }
    }
    final totalPredefined = predefinedCards.length;
    final currentCatFilter = _gameCategoryFilter[gameName];
    final showDefaultModels = _showDefaultModelsForGame[gameName] ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GrimoireTheme.borderSubtle.withValues(alpha: 0.9), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title, active filter tag, and action buttons (Responsive Wrap)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.category_outlined, size: 18, color: GrimoireTheme.accentPurple),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ref.tr('categories_and_defaults'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: GrimoireTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: GrimoireTheme.borderSubtle),
                            ),
                            child: Text(
                              '${categories.length} ${categories.length == 1 ? "categoría" : "categorías"}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFC7D2FE)),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        ref.tr('categories_defaults_desc'),
                        style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                  if (currentCatFilter != null && currentCatFilter != 'All') ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Filtrando: $currentCatFilter',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFE9D5FF), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => setState(() => _gameCategoryFilter[gameName] = null),
                            child: const Icon(Icons.close, size: 14, color: Color(0xFFE9D5FF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  // Button: Toggle Default Card Models Blueprint Section (only if predefined models exist)
                  if (totalPredefined > 0)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                        backgroundColor: showDefaultModels ? GrimoireTheme.accentPurple.withValues(alpha: 0.18) : const Color(0xFF131522),
                        foregroundColor: const Color(0xFFE9D5FF),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(
                        showDefaultModels ? Icons.visibility_off_outlined : Icons.auto_awesome,
                        size: 16,
                        color: GrimoireTheme.accentPurple,
                      ),
                      label: Text(
                        showDefaultModels ? ref.tr('hide_default_models') : ref.tr('view_default_models'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => setState(() => _showDefaultModelsForGame[gameName] = !showDefaultModels),
                    ),

                  // Button: + Plantilla Preset
                  OutlinedButton.icon(
                    key: const Key('btn_add_blueprint_model_card'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                      backgroundColor: GrimoireTheme.accentPurple.withValues(alpha: 0.12),
                      foregroundColor: const Color(0xFFE9D5FF),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 16, color: GrimoireTheme.accentPurple),
                    label: const Text('+ Plantilla Preset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showCreateCardPresetModelDialog(gameName),
                  ),

                  // Button: Carpeta del Juego (data.csv & assets/)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.5)),
                      backgroundColor: GrimoireTheme.accentEmerald.withValues(alpha: 0.12),
                      foregroundColor: const Color(0xFFA7F3D0),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.folder_open_outlined, size: 16, color: GrimoireTheme.accentEmerald),
                    label: Text(ref.tr('game_folder'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showGameFolderDialog(gameName, allGameCards),
                  ),

                  // Button: + Nueva Categoría
                  ElevatedButton.icon(
                    key: const Key('btn_add_category_model'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(ref.tr('new_category_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showCategoryModelDialog(gameName),
                  ),

                  // Button: Exportar .grimoire
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GrimoireTheme.accentCyan.withValues(alpha: 0.5)),
                      backgroundColor: GrimoireTheme.accentCyan.withValues(alpha: 0.12),
                      foregroundColor: const Color(0xFFA5F3FC),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.archive_outlined, size: 16, color: GrimoireTheme.accentCyan),
                    label: const Text('Exportar .grimoire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _handleExportGrimoireGame(gameName),
                  ),

                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable Category Archetype Chips (Enlarged & Visual)
          Row(
            children: [
              _buildScrollArrowButton(
                icon: Icons.chevron_left,
                tooltip: 'Desplazar categorías a la izquierda',
                onPressed: () => _scrollHorizontally(_getCategoryScrollController(gameName), -260),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Scrollbar(
                  controller: _getCategoryScrollController(gameName),
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _getCategoryScrollController(gameName),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        // "Todas" chip
                        _buildArchetypePill(
                          title: ref.tr('all_cards_in_game'),
                          icon: '✨',
                          count: allGameCards.where((r) => !_isModelCard(r)).length,
                          color: GrimoireTheme.accentPurple,
                          isSelected: currentCatFilter == null || currentCatFilter == 'All',
                          onTap: () => setState(() => _gameCategoryFilter[gameName] = null),
                        ),
                        const SizedBox(width: 10),

                        // Predefined archetype chips
                        for (final cat in categories) ...[
                          _buildArchetypeCategoryPill(
                            gameName: gameName,
                            category: cat,
                            count: allGameCards.where((c) => (c['category'] ?? '').toString().toLowerCase() == cat.name.toLowerCase() && !_isModelCard(c)).length,
                            isSelected: currentCatFilter?.toLowerCase() == cat.name.toLowerCase(),
                            onTap: () {
                              setState(() {
                                if (currentCatFilter?.toLowerCase() == cat.name.toLowerCase()) {
                                  _gameCategoryFilter[gameName] = null;
                                } else {
                                  _gameCategoryFilter[gameName] = cat.name;
                                }
                              });
                            },
                            onGenerateCard: () => _generateCardFromModel(gameName, cat),
                            onEditModel: () => _showCategoryModelDialog(gameName, existingCategory: cat),
                            onDelete: () => _confirmDeleteCategory(gameName, cat.name),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildScrollArrowButton(
                icon: Icons.chevron_right,
                tooltip: 'Desplazar categorías a la derecha',
                onPressed: () => _scrollHorizontally(_getCategoryScrollController(gameName), 260),
              ),
            ],
          ),

          // Dedicated Section: Default Card Models Blueprint Carousel (Only shown if predefined models exist)
          if (showDefaultModels && totalPredefined > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF090B14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.dashboard_customize_outlined, size: 16, color: GrimoireTheme.accentPurple),
                          const SizedBox(width: 8),
                          Text(
                            ref.tr('default_card_models'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '($totalPredefined ${totalPredefined == 1 ? "plantilla configurada" : "plantillas configuradas"})',
                            style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildScrollArrowButton(
                            icon: Icons.chevron_left,
                            tooltip: 'Desplazar modelos a la izquierda',
                            onPressed: () => _scrollHorizontally(_getModelsScrollController(gameName), -428),
                          ),
                          const SizedBox(width: 6),
                          _buildScrollArrowButton(
                            icon: Icons.chevron_right,
                            tooltip: 'Desplazar modelos a la derecha',
                            onPressed: () => _scrollHorizontally(_getModelsScrollController(gameName), 428),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Scrollbar(
                    controller: _getModelsScrollController(gameName),
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _getModelsScrollController(gameName),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < predefinedCards.length; i++) ...[
                            SizedBox(
                              width: 200,
                              height: 295,
                              child: _buildGalleryCardTile(
                                predefinedCards[i],
                                allRows.indexOf(predefinedCards[i]),
                              ),
                            ),
                            if (i < predefinedCards.length - 1) const SizedBox(width: 14),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArchetypePill({
    required String title,
    required String icon,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.25) : GrimoireTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? color : GrimoireTheme.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.45) : const Color(0xFF131520),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : GrimoireTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchetypeCategoryPill({
    required String gameName,
    required GameCategory category,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onGenerateCard,
    required VoidCallback onEditModel,
    required VoidCallback onDelete,
  }) {
    final catColor = Color(category.defaultColor);
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? catColor.withValues(alpha: 0.22) : GrimoireTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected ? catColor : GrimoireTheme.borderSubtle,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: catColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main clickable filter area
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8, top: 8, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? catColor.withValues(alpha: 0.45) : const Color(0xFF131520),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : GrimoireTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Prominent Quick Action Button: + Generar
          Tooltip(
            message: 'Generar carta con el modelo "${category.name}"',
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: catColor.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: catColor.withValues(alpha: 0.7)),
                ),
                icon: const Icon(Icons.flash_on, size: 13, color: Colors.white),
                label: Text(
                  ref.tr('quick_generate'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: onGenerateCard,
              ),
            ),
          ),

          // Options Menu: Edit Model, Delete
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.more_vert, size: 15, color: GrimoireTheme.textMuted.withValues(alpha: 0.9)),
            color: GrimoireTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: GrimoireTheme.borderSubtle),
            ),
            onSelected: (val) {
              if (val == 'generate') {
                onGenerateCard();
              } else if (val == 'edit') {
                onEditModel();
              } else if (val == 'duplicate') {
                _showCategoryModelDialog(gameName, existingCategory: category, isDuplicate: true);
              } else if (val == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'generate',
                child: Row(
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text('Crear carta "${category.name}"', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 14, color: GrimoireTheme.accentIndigo),
                    const SizedBox(width: 8),
                    Text(ref.tr('edit_category_model'), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: const Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 14, color: GrimoireTheme.accentCyan),
                    SizedBox(width: 8),
                    Text('Duplicar Categoría', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 6),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 14, color: GrimoireTheme.accentPink),
                    const SizedBox(width: 8),
                    Text(ref.tr('delete_category'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.accentPink)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }



  void _generateCardFromModel(String gameName, GameCategory category) {
    ref.read(editorProvider.notifier).createCardFromCategory(gameName, category);
    GrimoireToast.success(
      context,
      '¡Carta creada con el modelo predefinido "${category.name}"!',
      actionLabel: 'Ver en Editor',
      onAction: () {
        final rows = ref.read(editorProvider).project.rows;
        if (rows.isNotEmpty) {
          ref.read(editorProvider.notifier).setActiveRow(rows.length - 1);
        }
        widget.onOpenEditor();
      },
    );
  }

  // --- Card Tile ---
  Widget _buildGalleryCardTile(Map<String, dynamic> row, int index) {
    final name = row['card_name']?.toString() ?? 'Card';
    final icon = row['icon']?.toString() ?? '🃏';
    final game = row['game']?.toString() ?? 'General';
    final cost = (row['cost']?.toString() ?? '').trim();
    final category = (row['category']?.toString() ?? '').trim();
    final type = (row['type']?.toString() ?? '').trim();
    final rarity = (row['rarity']?.toString() ?? '').trim();
    final attack = (row['attack']?.toString() ?? '').trim();
    final defense = (row['defense']?.toString() ?? '').trim();

    final gameCategories = ref.read(editorProvider).gameCategories[game] ?? const <GameCategory>[];
    GameCategory? matchedCat;
    for (final c in gameCategories) {
      if (c.name.toLowerCase() == category.toLowerCase()) {
        matchedCat = c;
        break;
      }
    }

    final bool showCost = cost.isNotEmpty && (matchedCat == null || matchedCat.hasCost);
    final bool showRarity = rarity.isNotEmpty && (matchedCat == null || matchedCat.hasRarity);

    final bool showAttack = matchedCat != null
        ? (matchedCat.hasCombatStats &&
            attack.isNotEmpty &&
            attack != '0')
        : (attack.isNotEmpty && attack != '0');

    final bool showDefense = matchedCat != null
        ? (matchedCat.hasCombatStats &&
            defense.isNotEmpty &&
            defense != '0')
        : (defense.isNotEmpty && defense != '0');

    final hasCombatStats = showAttack || showDefense;
    final rarityColor = _getRarityColor(rarity);
    final isCatDefault = ref.read(editorProvider.notifier).isRowCategoryDefault(row);
    final isGameDefault = ref.read(editorProvider.notifier).isRowGameDefault(row);

    return InkWell(
      onTap: () {
        ref.read(editorProvider.notifier).setActiveRow(index);
        widget.onOpenEditor();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: GrimoireTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: rarityColor != GrimoireTheme.textMuted
                ? rarityColor.withValues(alpha: 0.35)
                : GrimoireTheme.borderSubtle,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (rarityColor != GrimoireTheme.textMuted ? rarityColor : Colors.black)
                  .withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Card Type / Archetype Tag & Menu
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isCatDefault || isGameDefault)
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                            : GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isCatDefault || isGameDefault)
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                              : GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCatDefault || isGameDefault) ...[
                            const Icon(Icons.star, size: 12, color: Color(0xFFFBBF24)),
                            const SizedBox(width: 4),
                          ] else ...[
                            Text(icon, style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              (isCatDefault || isGameDefault)
                                  ? (isCatDefault ? 'Modelo • $category' : 'Modelo • $game')
                                  : ((category.isNotEmpty && category.toLowerCase() != 'general')
                                      ? category
                                      : ((type.isNotEmpty && type.toLowerCase() != 'creature' && type.toLowerCase() != 'criatura')
                                          ? type
                                          : (type.toLowerCase() == 'creature' || type.toLowerCase() == 'criatura'
                                              ? ref.tr('default_card_type')
                                              : game))),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: (isCatDefault || isGameDefault) ? const Color(0xFFFDE68A) : const Color(0xFFE9D5FF),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Card Context Menu (Move to Game, Edit, Delete, Mark as Default)
                PopupMenuButton<String>(
                  key: ValueKey('card_menu_$name'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert, size: 16, color: GrimoireTheme.textMuted),
                  color: GrimoireTheme.surfaceElevated,
                  onSelected: (val) {
                    if (val == 'edit') {
                      ref.read(editorProvider.notifier).setActiveRow(index);
                      final targetTpl = ref.read(editorProvider.notifier).resolveTemplateForRow(row);
                      final allTemplates = ref.read(editorProvider).project.templates;
                      final tplIdx = allTemplates.indexWhere((t) => t.id == targetTpl.id);
                      if (tplIdx != -1) {
                        ref.read(editorProvider.notifier).setActiveTemplate(tplIdx);
                      }
                      widget.onOpenEditor();
                    } else if (val == 'mark_game_default') {
                      ref.read(editorProvider.notifier).setActiveRow(index);
                      ref.read(editorProvider.notifier).markActiveCardAsGameDefault();
                      GrimoireToast.warning(
                        context,
                        '"$name" establecida como modelo predefinido de $game.',
                      );
                    } else if (val == 'unmark_game_default') {
                      ref.read(editorProvider.notifier).setActiveRow(index);
                      ref.read(editorProvider.notifier).unmarkActiveCardAsGameDefault();
                      GrimoireToast.info(
                        context,
                        'Carta desmarcada como modelo de $game.',
                      );
                    } else if (val == 'mark_cat_default') {
                      ref.read(editorProvider.notifier).setActiveRow(index);
                      ref.read(editorProvider.notifier).markActiveCardAsCategoryDefault();
                      GrimoireToast.success(
                        context,
                        '"$name" establecida como modelo predefinido de "$category".',
                      );
                    } else if (val == 'unmark_cat_default') {
                      ref.read(editorProvider.notifier).setActiveRow(index);
                      ref.read(editorProvider.notifier).unmarkActiveCardAsCategoryDefault();
                      GrimoireToast.info(
                        context,
                        'Carta desmarcada como modelo de "$category".',
                      );
                    } else if (val == 'duplicate') {
                      ref.read(editorProvider.notifier).duplicateCard(index);
                      GrimoireToast.success(
                        context,
                        ref.tr('card_duplicated_toast'),
                      );
                    } else if (val == 'inspect_3d') {
                      final targetTpl = ref.read(editorProvider.notifier).resolveTemplateForRow(row);
                      final project = ref.read(editorProvider).project;
                      showDialog(
                        context: context,
                        builder: (_) => Card3DViewerDialog(
                          template: targetTpl,
                          cardData: row,
                          widthMm: project.widthMm,
                          heightMm: project.heightMm,
                        ),
                      );
                    } else if (val == 'move') {
                      _showMoveCardDialog(index, name, game);
                    } else if (val == 'delete') {
                      _confirmDeleteCard(index, name, row);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 14, color: GrimoireTheme.accentPurple),
                          const SizedBox(width: 8),
                          Text(ref.tr('nav_editor'), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'inspect_3d',
                      child: Row(
                        children: [
                          const Icon(Icons.view_in_ar, size: 14, color: GrimoireTheme.accentCyan),
                          const SizedBox(width: 8),
                          Text(ref.tr('inspect_3d'), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          const Icon(Icons.copy_outlined, size: 14, color: GrimoireTheme.accentEmerald),
                          const SizedBox(width: 8),
                          Text(ref.tr('duplicate_card'), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: isGameDefault ? 'unmark_game_default' : 'mark_game_default',
                      child: Row(
                        children: [
                          Icon(
                            isGameDefault ? Icons.star_border : Icons.star,
                            size: 14,
                            color: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isGameDefault ? 'Quitar como modelo de $game' : 'Definir como modelo de $game',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (category.isNotEmpty && category.toLowerCase() != 'general')
                      PopupMenuItem(
                        value: isCatDefault ? 'unmark_cat_default' : 'mark_cat_default',
                        child: Row(
                          children: [
                            Icon(
                              isCatDefault ? Icons.auto_awesome_outlined : Icons.auto_awesome,
                              size: 14,
                              color: GrimoireTheme.accentPurple,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCatDefault ? 'Quitar como modelo de "$category"' : 'Definir como modelo de "$category"',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'move',
                      child: Row(
                        children: [
                          const Icon(Icons.drive_file_move_outlined, size: 14, color: GrimoireTheme.accentIndigo),
                          const SizedBox(width: 8),
                          Text(ref.tr('assign_game'), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 8),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 14, color: GrimoireTheme.accentPink),
                          const SizedBox(width: 8),
                          Text(
                            ref.tr('delete_card'),
                            style: const TextStyle(fontSize: 12, color: GrimoireTheme.accentPink, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 7),

            // Card Preview Area (Real Rendered Card from Template & Layers)
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0E1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                ),
                child: Builder(
                  builder: (context) {
                    final tpl = ref.read(editorProvider.notifier).resolveTemplateForRow(row);
                    return Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        child: CardRendererWidget(
                          template: tpl,
                          cardData: row,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 7),

            // Title & Cost Badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    '"$name"',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showCost) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '$cost ${ref.tr('mana')}',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GrimoireTheme.accentPurple),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // Board Game Tag Pill & Category Pill
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GrimoireTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getGameIcon(game), size: 10, color: GrimoireTheme.accentIndigo),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            game,
                            style: const TextStyle(fontSize: 9, color: Color(0xFFC7D2FE), fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 85),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(fontSize: 8.5, color: Color(0xFFE9D5FF), fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Tabletop Card Stats: Rarity Chip & ATK/DEF / Effect badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Rarity indicator
                if (showRarity)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: rarityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            rarity,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: rarityColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),

                if (showRarity) const SizedBox(width: 6),

                // Combat Stats (⚔️ ATK / 🛡️ DEF) or Card Archetype
                if (hasCombatStats)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2235),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GrimoireTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showAttack) ...[
                          const Text('⚔️ ', style: TextStyle(fontSize: 8.5)),
                          Text(
                            attack,
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                        if (showAttack && showDefense)
                          const SizedBox(width: 6),
                        if (showDefense) ...[
                          const Text('🛡️ ', style: TextStyle(fontSize: 8.5)),
                          Text(
                            defense,
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2235),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: GrimoireTheme.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_stories, size: 9, color: GrimoireTheme.textMuted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              type.isNotEmpty ? type : 'Efecto',
                              style: const TextStyle(fontSize: 8.5, color: GrimoireTheme.textMuted, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialog: Create New Board Game ---
  void _showNewGameDialog() {
    final textController = TextEditingController();
    String selectedPresetId = 'default';
    final presets = CardTemplate.predefinedPresets;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: GrimoireTheme.surfacePanel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.casino_outlined, color: GrimoireTheme.accentPurple),
              const SizedBox(width: 8),
              Text(
                ref.tr('new_game_title'),
                style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.tr('new_game_hint'),
                  style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ej. Dungeon Crawler TCG',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ref.tr('template_style'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: const Size(0, 24),
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 12, color: GrimoireTheme.accentPurple),
                      label: const Text(
                        'Explorar...',
                        style: TextStyle(fontSize: 11, color: GrimoireTheme.accentPurple),
                      ),
                      onPressed: () async {
                        final chosen = await PredefinedTemplatesDialog.show(
                          context,
                          initialSelectedId: selectedPresetId,
                          showModeSelector: false,
                        );
                        if (chosen != null) {
                          setDialogState(() {
                            final match = presets.firstWhere((p) => p.name == chosen.name, orElse: () => presets.first);
                            selectedPresetId = match.id;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presets.map((preset) {
                    final isSelected = preset.id == selectedPresetId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setDialogState(() => selectedPresetId = preset.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? GrimoireTheme.accentPurple.withValues(alpha: 0.2)
                              : const Color(0xFF10121E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              preset.icon,
                              size: 13,
                              color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              preset.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : GrimoireTheme.textMuted,
                              ),
                            ),
                            if (preset.isDefault) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: GrimoireTheme.accentEmerald,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Default',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
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
                final gameName = textController.text.trim();
                if (gameName.isNotEmpty) {
                  final cardNameLocalized = '${ref.tr('default_card_name')} ($gameName)';
                  final cardTypeLocalized = ref.tr('default_card_type');
                  final rulesLocalized = ref.tr('default_rules_text').replaceAll('{game}', gameName);

                  ref.read(editorProvider.notifier).addCardToGame(
                    gameName,
                    cardName: cardNameLocalized,
                    type: cardTypeLocalized,
                    rulesText: rulesLocalized,
                    presetTemplateId: selectedPresetId,
                  );
                  setState(() {
                    _selectedGame = gameName;
                  });
                  Navigator.pop(ctx);
                  final toastMsg = ref.tr('game_created_toast').replaceAll('{game}', gameName);
                  GrimoireToast.success(
                    context,
                    toastMsg,
                  );
                }
              },
              child: Text(ref.tr('create')),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialog: Move Card to another Board Game ---
  void _showMoveCardDialog(int cardIndex, String currentCardName, String currentGame) {
    final allRows = ref.read(editorProvider).project.rows;
    final allGames = allRows.map((r) => (r['game'] ?? 'General').toString()).toSet().toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfacePanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.drive_file_move_outlined, color: GrimoireTheme.accentIndigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${ref.tr('assign_game')}: "$currentCardName"',
                style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona el juego de mesa al que pertenecerá esta carta:',
              style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final g in allGames) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(_getGameIcon(g), size: 16, color: g == currentGame ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted),
                title: Text(
                  g,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: g == currentGame ? FontWeight.bold : FontWeight.normal,
                    color: g == currentGame ? GrimoireTheme.accentPurple : Colors.white,
                  ),
                ),
                trailing: g == currentGame
                    ? const Icon(Icons.check, size: 16, color: GrimoireTheme.accentPurple)
                    : null,
                onTap: () {
                  ref.read(editorProvider.notifier).assignCardToGame(cardIndex, g);
                  Navigator.pop(ctx);
                  GrimoireToast.success(
                    context,
                    'Carta reasignada al juego "$g".',
                  );
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  // --- Dialog: Delete Card Confirmation ---
  void _confirmDeleteCard(int cardIndex, String cardName, Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfacePanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentPink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GrimoireTheme.accentPink.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.delete_outline, color: GrimoireTheme.accentPink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ref.tr('confirm_delete_card_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr('confirm_delete_card_desc'),
              style: const TextStyle(fontSize: 13, color: GrimoireTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10121E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GrimoireTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  Text(row['icon']?.toString() ?? '🃏', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cardName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${row['game'] ?? ''} • ${row['cost'] ?? '0'} ${ref.tr('mana')}',
                          style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GrimoireTheme.accentPink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(ref.tr('delete_card'), style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              final allRows = ref.read(editorProvider).project.rows;
              final targetIndex = allRows.indexOf(row);
              if (targetIndex != -1) {
                ref.read(editorProvider.notifier).removeRow(targetIndex);
              } else if (cardIndex >= 0 && cardIndex < allRows.length) {
                ref.read(editorProvider.notifier).removeRow(cardIndex);
              }

              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              GrimoireToast.error(
                context,
                '${ref.tr('card_deleted')}: "$cardName"',
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Dialog: Delete Board Game Confirmation ---
  void _confirmDeleteGame(String gameName, int cardCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfacePanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentPink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GrimoireTheme.accentPink.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.delete_sweep_outlined, color: GrimoireTheme.accentPink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ref.tr('confirm_delete_game_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr('confirm_delete_game_desc'),
              style: const TextStyle(fontSize: 13, color: GrimoireTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10121E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GrimoireTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(_getGameIcon(gameName), color: GrimoireTheme.accentPink, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gameName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '$cardCount cartas',
                          style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GrimoireTheme.accentPink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: Text(ref.tr('delete_game'), style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(editorProvider.notifier).deleteGame(gameName);
              if (_selectedGame.toLowerCase() == gameName.toLowerCase()) {
                setState(() => _selectedGame = 'All');
              }
              GrimoireToast.error(
                context,
                '${ref.tr('game_deleted')}: "$gameName"',
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Dialog: Delete Category Confirmation ---
  void _confirmDeleteCategory(String gameName, String categoryName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfacePanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentPink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GrimoireTheme.accentPink.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.delete_outline, color: GrimoireTheme.accentPink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ref.tr('confirm_delete_category_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr('confirm_delete_category_desc'),
              style: const TextStyle(fontSize: 13, color: GrimoireTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10121E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GrimoireTheme.borderSubtle),
              ),
              child: Text(
                '$categoryName ($gameName)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GrimoireTheme.accentPink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(ref.tr('delete_category'), style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(editorProvider.notifier).deleteCategoryFromGame(gameName, categoryName);
              if (_gameCategoryFilter[gameName]?.toLowerCase() == categoryName.toLowerCase()) {
                setState(() => _gameCategoryFilter[gameName] = null);
              }
              GrimoireToast.error(
                context,
                'Categoría "$categoryName" eliminada de "$gameName".',
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Dialog: Overview & Management of All Archetype Models for a Game ---
  void _showManageCategoriesDialog(String gameName) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final editorState = ref.watch(editorProvider);
          final categories = editorState.gameCategories[gameName] ?? [];
          final allRows = editorState.project.rows;
          final allGameCards = allRows.where((r) => (r['game'] ?? '').toString() == gameName).toList();

          return AlertDialog(
            backgroundColor: GrimoireTheme.surfacePanel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: GrimoireTheme.borderSubtle),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.style_outlined, color: GrimoireTheme.accentPurple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modelos Predefinidos: $gameName',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '${categories.length} categorías configuradas como plantillas base',
                        style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 420,
              child: categories.isEmpty
                  ? Center(
                      child: Text(ref.tr('no_categories_defined'), style: const TextStyle(color: GrimoireTheme.textMuted)),
                    )
                  : ListView.separated(
                      itemCount: categories.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final cat = categories[idx];
                        final cardCount = allGameCards.where((c) => (c['category'] ?? '').toString().toLowerCase() == cat.name.toLowerCase()).length;
                        final catColor = Color(cat.defaultColor);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10131F),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: GrimoireTheme.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: catColor),
                                ),
                                alignment: Alignment.center,
                                child: Text(cat.icon, style: const TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          cat.name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: GrimoireTheme.surfaceElevated,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: GrimoireTheme.borderSubtle),
                                          ),
                                          child: Text(
                                            '$cardCount cartas',
                                            style: const TextStyle(fontSize: 9, color: GrimoireTheme.textMuted),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tipo: ${cat.defaultType} • Coste: ${cat.defaultCost} • Stats: ${cat.defaultAttack}/${cat.defaultDefense} • ${cat.defaultRarity}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFFC7D2FE)),
                                    ),
                                    if (cat.defaultRules.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        '"${cat.defaultRules}"',
                                        style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted, fontStyle: FontStyle.italic),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Quick Create Card Button
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GrimoireTheme.accentPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  minimumSize: const Size(0, 36),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('Carta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _generateCardFromModel(gameName, cat);
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: GrimoireTheme.accentCyan),
                                tooltip: 'Duplicar Categoría',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showCategoryModelDialog(gameName, existingCategory: cat, isDuplicate: true);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: GrimoireTheme.accentIndigo),
                                tooltip: 'Editar Modelo Predefinido',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showCategoryModelDialog(gameName, existingCategory: cat);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: GrimoireTheme.accentPink),
                                tooltip: 'Eliminar Categoría',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _confirmDeleteCategory(gameName, cat.name);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GrimoireTheme.accentPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(ref.tr('new_category_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCategoryModelDialog(gameName);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Dialog: Create or Edit Predefined Archetype Model for a Category ---
  void _showCategoryModelDialog(String defaultGame, {GameCategory? existingCategory, bool isDuplicate = false}) {
    final editorState = ref.read(editorProvider);
    final allGames = editorState.gameCategories.keys
        .where((g) => !editorState.deletedGames.contains(g))
        .toList();
    if (!allGames.contains(defaultGame) && !editorState.deletedGames.contains(defaultGame)) {
      allGames.add(defaultGame);
    }
    String chosenGame = defaultGame;
    if (chosenGame == 'All' || editorState.deletedGames.contains(chosenGame)) {
      chosenGame = allGames.isNotEmpty ? allGames.first : 'Unstable Unicorns';
    }

    final isEditing = existingCategory != null && !isDuplicate;
    final nameController = TextEditingController(
      text: isDuplicate
          ? 'Copia de ${existingCategory?.name ?? ''}'
          : (existingCategory?.name ?? ''),
    );
    final iconController = TextEditingController(text: existingCategory?.icon ?? '🃏');
    
    // Ensure defaultType never defaults to 'Criatura'
    String initialType = existingCategory?.defaultType ?? '';
    if (initialType.toLowerCase() == 'criatura') {
      initialType = ref.tr('default_card_type');
    }
    final typeController = TextEditingController(text: initialType);
    final costController = TextEditingController(text: existingCategory?.defaultCost ?? '');
    final attackController = TextEditingController(text: existingCategory?.defaultAttack ?? '');
    final defenseController = TextEditingController(text: existingCategory?.defaultDefense ?? '');
    final rarityController = TextEditingController(text: existingCategory?.defaultRarity ?? 'Común');
    final rulesController = TextEditingController(text: existingCategory?.defaultRules ?? '');

    final customKeyCtrl = TextEditingController();
    final customValCtrl = TextEditingController();

    bool hasCost = existingCategory?.hasCost ?? false;
    bool hasCombatStats = existingCategory?.hasCombatStats ?? false;
    bool hasRarity = existingCategory?.hasRarity ?? false;
    bool hasRules = existingCategory?.hasRules ?? false;
    Map<String, String> customFields = Map<String, String>.from(existingCategory?.customFields ?? {});
    bool showAddCustom = false;
    bool createPresetCard = !isEditing;
    Map<String, dynamic>? selectedBaseCard;
    int? selectedBaseCardIndex;

    int selectedColor = existingCategory?.defaultColor ?? 0xFF8B5CF6;
    final colorOptions = [
      0xFF8B5CF6, // Purple
      0xFFEC4899, // Pink
      0xFF3B82F6, // Blue
      0xFF10B981, // Emerald
      0xFFF59E0B, // Amber
      0xFFEF4444, // Red
      0xFF06B6D4, // Cyan
      0xFF6B7280, // Slate / Gray
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: GrimoireTheme.surfacePanel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: GrimoireTheme.borderSubtle),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDuplicate
                      ? GrimoireTheme.accentCyan.withValues(alpha: 0.15)
                      : GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDuplicate
                        ? GrimoireTheme.accentCyan.withValues(alpha: 0.4)
                        : GrimoireTheme.accentPurple.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  isDuplicate
                      ? Icons.copy_rounded
                      : (isEditing ? Icons.tune : Icons.category_outlined),
                  color: isDuplicate ? GrimoireTheme.accentCyan : GrimoireTheme.accentPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDuplicate
                          ? 'Duplicar Categoría'
                          : (isEditing ? ref.tr('edit_category_model') : ref.tr('new_category_title')),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Juego: $chosenGame',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDuplicate ? GrimoireTheme.accentCyan : GrimoireTheme.accentPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDuplicate
                        ? 'Copia los atributos de "${existingCategory?.name}" para crear una nueva categoría con ajustes personalizados.'
                        : ref.tr('new_category_desc'),
                    style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 12),

                  // Preset Card Checkbox Tile
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: createPresetCard
                          ? GrimoireTheme.accentPurple.withValues(alpha: 0.14)
                          : const Color(0xFF10121E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: createPresetCard
                            ? GrimoireTheme.accentPurple.withValues(alpha: 0.45)
                            : GrimoireTheme.borderSubtle,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => setDialogState(() => createPresetCard = !createPresetCard),
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: createPresetCard,
                              activeColor: GrimoireTheme.accentPurple,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) => setDialogState(() => createPresetCard = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.style_outlined, size: 13, color: GrimoireTheme.accentPurple),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        isEditing
                                            ? 'Generar también carta Preset con estos cambios'
                                            : 'Crear carta Preset por defecto de esta categoría',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Crea de inmediato una carta modelo en tu proyecto para alinear y personalizar su diseño en el canvas.',
                                  style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Game selector if there are multiple games and not editing
                  if (!isEditing && allGames.length > 1) ...[
                    const Text('Juego de Mesa:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10121E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GrimoireTheme.borderSubtle),
                      ),
                      child: DropdownButton<String>(
                        value: chosenGame,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: GrimoireTheme.surfaceElevated,
                        items: allGames.map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g, style: const TextStyle(fontSize: 12, color: Colors.white)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              chosenGame = val;
                              if (val.toLowerCase().contains('unicorn')) {
                                hasCost = false;
                                hasCombatStats = false;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Selector de Carta Base (para preestablecer / modificar modelo)
                  if (!isEditing) ...[
                    Builder(
                      builder: (context) {
                        final gameCards = editorState.project.rows
                            .where((r) => (r['game'] ?? '').toString().toLowerCase().trim() == chosenGame.toLowerCase().trim())
                            .toList();
                        if (gameCards.isEmpty) return const SizedBox();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Carta base para este modelo (opcional):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10121E),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GrimoireTheme.borderSubtle),
                              ),
                              child: DropdownButton<int?>(
                                value: selectedBaseCardIndex,
                                isExpanded: true,
                                underline: const SizedBox(),
                                dropdownColor: GrimoireTheme.surfaceElevated,
                                hint: const Text('Ninguna (Plantilla en blanco)', style: TextStyle(fontSize: 12, color: GrimoireTheme.textMuted)),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Ninguna (Plantilla en blanco)', style: TextStyle(fontSize: 12, color: GrimoireTheme.textMuted)),
                                  ),
                                  for (int i = 0; i < gameCards.length; i++)
                                    DropdownMenuItem<int?>(
                                      value: i,
                                      child: Text(
                                        '${gameCards[i]['icon'] ?? '🃏'} ${gameCards[i]['card_name'] ?? 'Carta ${i + 1}'}${gameCards[i]['type'] != null ? ' (${gameCards[i]['type']})' : ''}',
                                        style: const TextStyle(fontSize: 12, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (idx) {
                                  setDialogState(() {
                                    selectedBaseCardIndex = idx;
                                    if (idx != null && idx >= 0 && idx < gameCards.length) {
                                      final pickedCard = gameCards[idx];
                                      selectedBaseCard = pickedCard;
                                      if (nameController.text.isEmpty || nameController.text.startsWith('Nueva')) {
                                        nameController.text = (pickedCard['category'] ?? pickedCard['card_name'] ?? '').toString();
                                      }
                                      iconController.text = (pickedCard['icon'] ?? '🃏').toString();
                                      typeController.text = (pickedCard['type'] ?? nameController.text).toString();
                                      if (pickedCard['cost'] != null && pickedCard['cost'].toString().isNotEmpty) {
                                        hasCost = true;
                                        costController.text = pickedCard['cost'].toString();
                                      } else {
                                        hasCost = false;
                                        costController.text = '';
                                      }
                                      if ((pickedCard['attack'] != null && pickedCard['attack'].toString().isNotEmpty) ||
                                          (pickedCard['defense'] != null && pickedCard['defense'].toString().isNotEmpty)) {
                                        hasCombatStats = true;
                                        attackController.text = (pickedCard['attack'] ?? '').toString();
                                        defenseController.text = (pickedCard['defense'] ?? '').toString();
                                      } else {
                                        hasCombatStats = false;
                                        attackController.text = '';
                                        defenseController.text = '';
                                      }
                                      if (pickedCard['rarity'] != null && pickedCard['rarity'].toString().isNotEmpty) {
                                        hasRarity = true;
                                        rarityController.text = pickedCard['rarity'].toString();
                                      } else {
                                        hasRarity = false;
                                        rarityController.text = '';
                                      }
                                      if ((pickedCard['rules_text'] != null && pickedCard['rules_text'].toString().isNotEmpty) ||
                                          (pickedCard['rules'] != null && pickedCard['rules'].toString().isNotEmpty)) {
                                        hasRules = true;
                                        rulesController.text = (pickedCard['rules_text'] ?? pickedCard['rules'] ?? '').toString();
                                      } else {
                                        hasRules = false;
                                        rulesController.text = '';
                                      }
                                      if (pickedCard['art_color'] is int) {
                                        selectedColor = pickedCard['art_color'] as int;
                                      } else if (pickedCard['art_color'] != null) {
                                        selectedColor = int.tryParse(pickedCard['art_color'].toString()) ?? selectedColor;
                                      }

                                      // Copy any custom fields from base card
                                      const internalKeys = {
                                        'card_name', 'game', 'category', 'qty', 'cost', 'type', 'rarity',
                                        'attack', 'defense', 'rules_text', 'rules', 'prompt', 'art_url',
                                        'icon', 'art_color', 'creator', 'template_id', 'is_game_default', 'is_category_default'
                                      };
                                      customFields.clear();
                                      pickedCard.forEach((k, v) {
                                        if (!internalKeys.contains(k) && v != null && v.toString().trim().isNotEmpty) {
                                          customFields[k] = v.toString().trim();
                                        }
                                      });
                                    } else {
                                      selectedBaseCard = null;
                                      selectedBaseCardIndex = null;
                                      final isUnicorn = chosenGame.toLowerCase().contains('unicorn');
                                      hasCost = !isUnicorn;
                                      hasCombatStats = !isUnicorn;
                                      hasRarity = true;
                                      hasRules = true;
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),
                  ],

                  // Category Name
                  Text(ref.tr('category_name'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'ej. Unicornios Mágicos, Cartas de Mejora, Hechizos',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      if (!isEditing && (typeController.text.isEmpty || typeController.text == nameController.text)) {
                        typeController.text = val;
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Fila unificada: Ícono / Emoji y Tipo de Carta por Defecto
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícono / Emoji Tile Selector
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.tr('category_icon'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Tooltip(
                            message: 'Haz clic para seleccionar cualquier emoji',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                final picked = await GrimoireEmojiPicker.show(context, currentEmoji: iconController.text);
                                if (picked != null && picked.isNotEmpty) {
                                  setDialogState(() => iconController.text = picked);
                                }
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Color(selectedColor).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Color(selectedColor), width: 1.8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  iconController.text.isEmpty ? '🃏' : iconController.text,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Tipo de Carta por Defecto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.tr('category_default_type'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 44,
                              child: TextField(
                                controller: typeController,
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'ej. Unicornio Mágico, Instantánea, Equipamiento',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),



                  // Theme Color
                  Text(ref.tr('category_color'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Row(
                    children: colorOptions.map((c) {
                      final isSelected = selectedColor == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setDialogState(() => selectedColor = c),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (isEditing)
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 14, color: GrimoireTheme.accentCyan),
                label: const Text('Duplicar', style: TextStyle(color: GrimoireTheme.accentCyan, fontSize: 12)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCategoryModelDialog(chosenGame, existingCategory: existingCategory, isDuplicate: true);
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDuplicate ? GrimoireTheme.accentCyan : GrimoireTheme.accentPurple,
                foregroundColor: isDuplicate ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final catName = nameController.text.trim();
                if (catName.isNotEmpty) {
                  final cat = GameCategory(
                    id: isEditing
                        ? existingCategory.id
                        : 'cat_${DateTime.now().millisecondsSinceEpoch}',
                    name: catName,
                    icon: iconController.text.trim().isEmpty ? '🃏' : iconController.text.trim(),
                    defaultType: typeController.text.trim().isEmpty ? catName : typeController.text.trim(),
                    defaultColor: selectedColor,
                    hasCost: hasCost,
                    defaultCost: hasCost ? costController.text.trim() : '',
                    hasCombatStats: hasCombatStats,
                    defaultAttack: hasCombatStats ? attackController.text.trim() : '',
                    defaultDefense: hasCombatStats ? defenseController.text.trim() : '',
                    hasRarity: hasRarity,
                    defaultRarity: hasRarity ? rarityController.text.trim() : '',
                    hasRules: hasRules,
                    defaultRules: hasRules ? rulesController.text.trim() : '',
                    customFields: customFields,
                  );
                  ref.read(editorProvider.notifier).addCategoryToGame(chosenGame, cat);

                  if (createPresetCard) {
                    ref.read(editorProvider.notifier).createCardFromCategory(
                      chosenGame,
                      cat,
                      cardName: '$catName (Modelo)',
                      isCategoryDefault: true,
                      baseCard: selectedBaseCard,
                    );
                    final rows = ref.read(editorProvider).project.rows;
                    if (rows.isNotEmpty) {
                      ref.read(editorProvider.notifier).setActiveRow(rows.length - 1);
                    }
                  }

                  Navigator.pop(ctx);
                  final notificationText = isDuplicate
                      ? 'Categoría duplicada "$catName" guardada${createPresetCard ? ' y carta Preset generada' : ''}.'
                      : (createPresetCard
                          ? 'Categoría "$catName" guardada y carta Preset creada.'
                          : 'Modelo predefinido "$catName" guardado para "$chosenGame".');

                  GrimoireToast.success(
                    context,
                    notificationText,
                    actionLabel: createPresetCard ? 'Ver en Editor' : null,
                    onAction: createPresetCard
                        ? () {
                            final rows = ref.read(editorProvider).project.rows;
                            if (rows.isNotEmpty) {
                              ref.read(editorProvider.notifier).setActiveRow(rows.length - 1);
                            }
                            widget.onOpenEditor();
                          }
                        : null,
                  );
                }
              },
              child: Text(
                isDuplicate
                    ? 'Duplicar y Guardar'
                    : (isEditing ? ref.tr('save_model') : ref.tr('create')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                activeColor: GrimoireTheme.accentPurple,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewCategoryDialog(String defaultGame) {
    _showCategoryModelDialog(defaultGame);
  }

  // --- Dedicated Dialog: Crear Modelo Preset de Carta ---
  void _showCreateCardPresetModelDialog(String defaultGame, {Map<String, dynamic>? fromExistingCard}) {
    final editorState = ref.read(editorProvider);
    final allGames = editorState.gameCategories.keys
        .where((g) => !editorState.deletedGames.contains(g))
        .toList();
    if (!allGames.contains(defaultGame) && !editorState.deletedGames.contains(defaultGame)) {
      allGames.add(defaultGame);
    }
    String chosenGame = defaultGame;
    if (chosenGame == 'All' || editorState.deletedGames.contains(chosenGame)) {
      chosenGame = allGames.isNotEmpty ? allGames.first : 'Unstable Unicorns';
    }

    final isFromCard = fromExistingCard != null;

    final starterArchetypes = [
      _StarterCardArchetype(
        label: ref.tr('archetype_creature_label'),
        icon: '⚔️',
        defaultName: ref.tr('archetype_creature_name'),
        defaultType: ref.tr('archetype_creature_type'),
        defaultColor: 0xFFEF4444,
        hasCost: true,
        defaultCost: '3',
        hasCombatStats: true,
        defaultAttack: '3',
        defaultDefense: '3',
        hasRarity: true,
        defaultRarity: 'Común',
        hasRules: true,
        defaultRules: ref.tr('archetype_creature_rules'),
        layoutPreset: 'tcgFantasy',
      ),
      _StarterCardArchetype(
        label: ref.tr('archetype_spell_label'),
        icon: '⚡',
        defaultName: ref.tr('archetype_spell_name'),
        defaultType: ref.tr('archetype_spell_type'),
        defaultColor: 0xFF3B82F6,
        hasCost: true,
        defaultCost: '2',
        hasCombatStats: false,
        defaultAttack: '',
        defaultDefense: '',
        hasRarity: true,
        defaultRarity: 'Rara',
        hasRules: true,
        defaultRules: ref.tr('archetype_spell_rules'),
        layoutPreset: 'tcgFantasy',
      ),
      _StarterCardArchetype(
        label: ref.tr('archetype_hero_label'),
        icon: '👑',
        defaultName: ref.tr('archetype_hero_name'),
        defaultType: ref.tr('archetype_hero_type'),
        defaultColor: 0xFFF59E0B,
        hasCost: true,
        defaultCost: '5',
        hasCombatStats: true,
        defaultAttack: '4',
        defaultDefense: '6',
        hasRarity: true,
        defaultRarity: 'Legendaria',
        hasRules: true,
        defaultRules: ref.tr('archetype_hero_rules'),
        layoutPreset: 'tarotHero',
      ),
      _StarterCardArchetype(
        label: ref.tr('archetype_event_label'),
        icon: '🎲',
        defaultName: ref.tr('archetype_event_name'),
        defaultType: ref.tr('archetype_event_type'),
        defaultColor: 0xFF10B981,
        hasCost: false,
        defaultCost: '',
        hasCombatStats: false,
        defaultAttack: '',
        defaultDefense: '',
        hasRarity: false,
        defaultRarity: '',
        hasRules: true,
        defaultRules: ref.tr('archetype_event_rules'),
        layoutPreset: 'boardgameAction',
      ),
      _StarterCardArchetype(
        label: ref.tr('archetype_item_label'),
        icon: '🗡️',
        defaultName: ref.tr('archetype_item_name'),
        defaultType: ref.tr('archetype_item_type'),
        defaultColor: 0xFF8B5CF6,
        hasCost: true,
        defaultCost: '2',
        hasCombatStats: true,
        defaultAttack: '+2',
        defaultDefense: '',
        hasRarity: true,
        defaultRarity: 'Poco Común',
        hasRules: true,
        defaultRules: ref.tr('archetype_item_rules'),
        layoutPreset: 'tcgFantasy',
      ),
      _StarterCardArchetype(
        label: ref.tr('archetype_location_label'),
        icon: '🏛️',
        defaultName: ref.tr('archetype_location_name'),
        defaultType: ref.tr('archetype_location_type'),
        defaultColor: 0xFF06B6D4,
        hasCost: false,
        defaultCost: '',
        hasCombatStats: false,
        defaultAttack: '',
        defaultDefense: '',
        hasRarity: true,
        defaultRarity: 'Rara',
        hasRules: true,
        defaultRules: ref.tr('archetype_location_rules'),
        layoutPreset: 'tcgFantasy',
      ),
      _StarterCardArchetype(
        label: ref.tr('archetype_custom_label'),
        icon: '🃏',
        defaultName: ref.tr('archetype_custom_name'),
        defaultType: ref.tr('archetype_custom_type'),
        defaultColor: 0xFF6B7280,
        hasCost: true,
        defaultCost: '1',
        hasCombatStats: false,
        defaultAttack: '',
        defaultDefense: '',
        hasRarity: true,
        defaultRarity: 'Común',
        hasRules: true,
        defaultRules: '',
        layoutPreset: 'tcgFantasy',
      ),
    ];

    int selectedArchetypeIndex = isFromCard ? -1 : 0;
    final initialArchetype = isFromCard ? null : starterArchetypes.first;

    final nameController = TextEditingController(
      text: isFromCard
          ? '${fromExistingCard['card_name'] ?? 'Carta'} (Modelo)'
          : (initialArchetype?.defaultName ?? 'Nuevo Modelo'),
    );
    final iconController = TextEditingController(
      text: isFromCard
          ? (fromExistingCard['icon']?.toString() ?? '🃏')
          : (initialArchetype?.icon ?? '⚔️'),
    );
    final typeController = TextEditingController(
      text: isFromCard
          ? (fromExistingCard['type']?.toString() ?? fromExistingCard['category']?.toString() ?? 'Criatura')
          : (initialArchetype?.defaultType ?? 'Criatura'),
    );
    final costController = TextEditingController(
      text: isFromCard
          ? (fromExistingCard['cost']?.toString() ?? '')
          : (initialArchetype?.defaultCost ?? '3'),
    );
    final attackController = TextEditingController(
      text: isFromCard
          ? (fromExistingCard['attack']?.toString() ?? '')
          : (initialArchetype?.defaultAttack ?? '3'),
    );
    final defenseController = TextEditingController(
      text: isFromCard
          ? (fromExistingCard['defense']?.toString() ?? '')
          : (initialArchetype?.defaultDefense ?? '3'),
    );
    final rarityController = TextEditingController(
      text: isFromCard
          ? (fromExistingCard['rarity']?.toString() ?? 'Común')
          : (initialArchetype?.defaultRarity ?? 'Común'),
    );
    final rulesController = TextEditingController(
      text: isFromCard
          ? (fromExistingCard['rules_text']?.toString() ?? fromExistingCard['rules']?.toString() ?? '')
          : (initialArchetype?.defaultRules ?? ''),
    );

    final customKeyCtrl = TextEditingController();
    final customValCtrl = TextEditingController();

    bool hasCost = isFromCard ? (costController.text.isNotEmpty) : (initialArchetype?.hasCost ?? true);
    bool hasCombatStats = isFromCard
        ? (attackController.text.isNotEmpty || defenseController.text.isNotEmpty)
        : (initialArchetype?.hasCombatStats ?? true);
    bool hasRarity = isFromCard ? (rarityController.text.isNotEmpty) : (initialArchetype?.hasRarity ?? true);
    bool hasRules = isFromCard ? (rulesController.text.isNotEmpty) : (initialArchetype?.hasRules ?? true);

    Map<String, String> customFields = {};
    if (isFromCard) {
      final reservedKeys = {'card_name', 'icon', 'art_color', 'game', 'cost', 'category', 'type', 'rarity', 'attack', 'defense', 'rules_text', 'rules', 'creator', 'art_url'};
      for (final e in fromExistingCard.entries) {
        if (!reservedKeys.contains(e.key) && e.value != null && e.value.toString().isNotEmpty) {
          customFields[e.key] = e.value.toString();
        }
      }
    }

    bool showAddCustom = false;
    bool createPresetCard = true;
    String selectedLayout = initialArchetype?.layoutPreset ?? 'tcgFantasy';

    int selectedColor = isFromCard
        ? (fromExistingCard['art_color'] is int ? fromExistingCard['art_color'] as int : 0xFFF59E0B)
        : (initialArchetype?.defaultColor ?? 0xFFEF4444);

    final colorOptions = [
      0xFFEF4444, // Red
      0xFFF59E0B, // Amber / Gold
      0xFF10B981, // Emerald
      0xFF06B6D4, // Cyan
      0xFF3B82F6, // Blue
      0xFF8B5CF6, // Purple
      0xFFEC4899, // Pink
      0xFF6B7280, // Slate
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: GrimoireTheme.surfacePanel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.tr('create_preset_card_model_title'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      isFromCard
                          ? 'Basado en: "${fromExistingCard['card_name'] ?? 'Carta'}" · Juego: $chosenGame'
                          : 'Juego: $chosenGame',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFFDE68A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.tr('create_preset_card_model_desc'),
                    style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 14),

                  // Starter Archetype Selection Chips
                  if (!isFromCard) ...[
                    Text(
                      ref.tr('starter_archetypes'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFDE68A)),
                    ),
                    const SizedBox(height: 8),
                    Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: starterArchetypes.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final arch = entry.value;
                          final isSel = selectedArchetypeIndex == idx;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedArchetypeIndex = idx;
                                  nameController.text = arch.defaultName;
                                  iconController.text = arch.icon;
                                  typeController.text = arch.defaultType;
                                  selectedColor = arch.defaultColor;
                                  hasCost = arch.hasCost;
                                  costController.text = arch.defaultCost;
                                  hasCombatStats = arch.hasCombatStats;
                                  attackController.text = arch.defaultAttack;
                                  defenseController.text = arch.defaultDefense;
                                  hasRarity = arch.hasRarity;
                                  rarityController.text = arch.defaultRarity;
                                  hasRules = arch.hasRules;
                                  rulesController.text = arch.defaultRules;
                                  selectedLayout = arch.layoutPreset;
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFFF59E0B).withValues(alpha: 0.22) : const Color(0xFF131522),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFFF59E0B) : GrimoireTheme.borderSubtle,
                                    width: isSel ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(arch.icon, style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      arch.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                        color: isSel ? Colors.white : GrimoireTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Target Game Dropdown
                  if (allGames.length > 1) ...[
                    Text(
                      '${ref.tr('game')}:',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10121E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GrimoireTheme.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: chosenGame,
                          isExpanded: true,
                          dropdownColor: GrimoireTheme.surfaceElevated,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          items: allGames.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => chosenGame = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Visual Layout Template Selector
                  Text(
                    ref.tr('card_layout_style'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildPresetLayoutOption(
                        label: ref.tr('preset_tcg_fantasy'),
                        icon: Icons.sports_kabaddi,
                        isSelected: selectedLayout == 'tcgFantasy',
                        onTap: () => setDialogState(() => selectedLayout = 'tcgFantasy'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetLayoutOption(
                        label: ref.tr('preset_boardgame_action'),
                        icon: Icons.dashboard_outlined,
                        isSelected: selectedLayout == 'boardgameAction',
                        onTap: () => setDialogState(() => selectedLayout = 'boardgameAction'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetLayoutOption(
                        label: ref.tr('preset_tarot_hero'),
                        icon: Icons.shield_outlined,
                        isSelected: selectedLayout == 'tarotHero',
                        onTap: () => setDialogState(() => selectedLayout = 'tarotHero'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Name and Emoji Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji button
                      InkWell(
                        onTap: () async {
                          final picked = await GrimoireEmojiPicker.show(context, currentEmoji: iconController.text);
                          if (picked != null) {
                            setDialogState(() => iconController.text = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10121E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: GrimoireTheme.borderSubtle),
                          ),
                          child: Center(
                            child: Text(
                              iconController.text.trim().isEmpty ? '🃏' : iconController.text.trim(),
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Name Field
                      Expanded(
                        child: TextField(
                          key: const Key('input_preset_model_name'),
                          controller: nameController,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Nombre del Modelo Preset *',
                            hintText: 'ej. Criatura Guerrera, Hechizo de Fuego...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Type Field
                      SizedBox(
                        width: 130,
                        child: TextField(
                          controller: typeController,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: InputDecoration(
                            labelText: ref.tr('type'),
                            hintText: 'ej. Criatura',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Mechanics Container
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10121E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GrimoireTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mecánicas y Atributos del Modelo Preset:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),

                        // Toggle Cost
                        _buildDialogToggleRow(
                          title: ref.tr('include_cost'),
                          subtitle: 'Actívalo si las cartas usan coste de maná o recursos',
                          value: hasCost,
                          onChanged: (v) => setDialogState(() => hasCost = v),
                        ),
                        if (hasCost) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 28, bottom: 8),
                            child: SizedBox(
                              width: 150,
                              child: TextField(
                                controller: costController,
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: ref.tr('default_cost'),
                                  hintText: '3 o {2}{R}',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Toggle Combat Stats
                        _buildDialogToggleRow(
                          title: ref.tr('include_combat_stats'),
                          subtitle: 'Ataque y defensa para combatientes o criaturas',
                          value: hasCombatStats,
                          onChanged: (v) => setDialogState(() => hasCombatStats = v),
                        ),
                        if (hasCombatStats) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 28, bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: attackController,
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: 'Ataque (⚔️)',
                                      hintText: '3',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: defenseController,
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: 'Defensa (🛡️)',
                                      hintText: '3',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Toggle Rarity
                        _buildDialogToggleRow(
                          title: ref.tr('include_rarity'),
                          subtitle: 'Nivel de rareza para la carta',
                          value: hasRarity,
                          onChanged: (v) => setDialogState(() => hasRarity = v),
                        ),
                        if (hasRarity) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 28, bottom: 8),
                            child: SizedBox(
                              width: 190,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: ['Común', 'Poco Común', 'Rara', 'Épica', 'Legendaria', 'Especial'].contains(rarityController.text)
                                    ? rarityController.text
                                    : 'Común',
                                dropdownColor: GrimoireTheme.surfaceElevated,
                                decoration: InputDecoration(
                                  labelText: ref.tr('default_rarity'),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                                items: ['Común', 'Poco Común', 'Rara', 'Épica', 'Legendaria', 'Especial']
                                    .map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => rarityController.text = v);
                                },
                              ),
                            ),
                          ),
                        ],

                        // Toggle Rules
                        _buildDialogToggleRow(
                          title: ref.tr('include_rules'),
                          subtitle: 'Habilidad o texto explicativo de reglas',
                          value: hasRules,
                          onChanged: (v) => setDialogState(() => hasRules = v),
                        ),
                        if (hasRules) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 28, bottom: 8),
                            child: TextField(
                              controller: rulesController,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Texto de Reglas / Efecto',
                                hintText: 'Describe el efecto predeterminado de este modelo...',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                        ],

                        // Custom Fields Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Campos Personalizados (Metadata):',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 14, color: GrimoireTheme.accentPurple),
                              label: Text(ref.tr('add_custom_field'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.accentPurple)),
                              onPressed: () => setDialogState(() => showAddCustom = !showAddCustom),
                            ),
                          ],
                        ),
                        if (customFields.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: customFields.entries.map((e) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1D2E),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: GrimoireTheme.borderSubtle),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${e.key}: ', style: const TextStyle(fontSize: 11, color: Color(0xFFC7D2FE), fontWeight: FontWeight.bold)),
                                  Text(e.value, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => setDialogState(() => customFields.remove(e.key)),
                                    child: const Icon(Icons.close, size: 12, color: GrimoireTheme.accentPink),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ],
                        if (showAddCustom) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: customKeyCtrl,
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: ref.tr('field_name'),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: customValCtrl,
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: ref.tr('field_value'),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GrimoireTheme.accentPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: () {
                                  final k = customKeyCtrl.text.trim();
                                  final v = customValCtrl.text.trim();
                                  if (k.isNotEmpty && v.isNotEmpty) {
                                    setDialogState(() {
                                      customFields[k] = v;
                                      customKeyCtrl.clear();
                                      customValCtrl.clear();
                                      showAddCustom = false;
                                    });
                                  }
                                },
                                child: const Text('OK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Color Picker
                  Text(ref.tr('category_color'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Row(
                    children: colorOptions.map((c) {
                      final isSelected = selectedColor == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setDialogState(() => selectedColor = c),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Checkbox: Create sample preset card immediately
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: createPresetCard
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                          : const Color(0xFF10121E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: createPresetCard
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                            : GrimoireTheme.borderSubtle,
                      ),
                    ),
                    child: InkWell(
                      key: const Key('chk_create_sample_preset_card'),
                      onTap: () => setDialogState(() => createPresetCard = !createPresetCard),
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: createPresetCard,
                              activeColor: const Color(0xFFF59E0B),
                              checkColor: Colors.black,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) => setDialogState(() => createPresetCard = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.auto_awesome, size: 13, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        'Generar carta Preset de muestra en "$chosenGame"',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Crea una carta inmediatamente con este diseño y la añade al mazo para empezar a diseñar.',
                                  style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                                ),
                              ],
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
            ),
            ElevatedButton.icon(
              key: const Key('btn_submit_create_preset_model'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
              icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.black),
              label: const Text(
                'Crear Modelo Preset',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                final catName = nameController.text.trim();
                if (catName.isNotEmpty) {
                  final cat = GameCategory(
                    id: 'preset_${DateTime.now().millisecondsSinceEpoch}',
                    name: catName,
                    icon: iconController.text.trim().isEmpty ? '🃏' : iconController.text.trim(),
                    defaultType: typeController.text.trim().isEmpty ? catName : typeController.text.trim(),
                    defaultColor: selectedColor,
                    hasCost: hasCost,
                    defaultCost: hasCost ? costController.text.trim() : '',
                    hasCombatStats: hasCombatStats,
                    defaultAttack: hasCombatStats ? attackController.text.trim() : '',
                    defaultDefense: hasCombatStats ? defenseController.text.trim() : '',
                    hasRarity: hasRarity,
                    defaultRarity: hasRarity ? rarityController.text.trim() : '',
                    hasRules: hasRules,
                    defaultRules: hasRules ? rulesController.text.trim() : '',
                    customFields: customFields,
                  );

                  ref.read(editorProvider.notifier).addCategoryToGame(chosenGame, cat);

                  if (createPresetCard) {
                    ref.read(editorProvider.notifier).createCardFromCategory(
                      chosenGame,
                      cat,
                      cardName: '$catName (Preset)',
                      isCategoryDefault: true,
                      baseCard: fromExistingCard,
                    );
                    final rows = ref.read(editorProvider).project.rows;
                    if (rows.isNotEmpty) {
                      ref.read(editorProvider.notifier).setActiveRow(rows.length - 1);
                    }
                    if (selectedLayout.isNotEmpty) {
                      ref.read(editorProvider.notifier).applyPresetTemplate(selectedLayout);
                    }
                  }

                  setState(() {
                    _showDefaultModelsForGame[chosenGame] = true;
                  });

                  Navigator.pop(ctx);
                  GrimoireToast.warning(
                    context,
                    '¡Modelo Preset "$catName" creado para "$chosenGame"${createPresetCard ? ' y carta de muestra generada' : ''}!',
                    actionLabel: 'Ver en Editor',
                    onAction: () {
                      widget.onOpenEditor();
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetLayoutOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF59E0B).withValues(alpha: 0.18) : const Color(0xFF10121E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFF59E0B) : GrimoireTheme.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? const Color(0xFFF59E0B) : GrimoireTheme.textMuted),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGameFolderDialog(String gameName, List<Map<String, dynamic>> allGameCards) {
    final gameCards = allGameCards
        .where((c) => (c['game'] ?? '').toString().toLowerCase() == gameName.toLowerCase())
        .toList();
    final gameDir = GameFolderService.getGameDir(gameName);
    final assetsCount = GameFolderService.getAssetsCount(gameName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfacePanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentEmerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.folder_special_outlined, color: GrimoireTheme.accentEmerald, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${ref.tr('game_structure_dialog_title')}: "$gameName"',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref.tr('game_structure_dialog_desc'),
                style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),

              // Folder Structure Diagram Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F121E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GrimoireTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder, size: 16, color: GrimoireTheme.accentEmerald),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            gameDir.path,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: GrimoireTheme.borderSubtle, height: 16),
                    Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.description_outlined, size: 14, color: GrimoireTheme.accentIndigo),
                        const SizedBox(width: 8),
                        const Text('data.csv', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: GrimoireTheme.accentIndigo.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${gameCards.length} cartas',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC7D2FE)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.photo_library_outlined, size: 14, color: GrimoireTheme.accentPink),
                        const SizedBox(width: 8),
                        const Text('assets/', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: GrimoireTheme.accentPink.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$assetsCount imágenes',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFBCFE8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.6)),
                        backgroundColor: GrimoireTheme.accentEmerald.withValues(alpha: 0.12),
                        foregroundColor: const Color(0xFFA7F3D0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.save_outlined, size: 15),
                      label: Text(ref.tr('save_csv_btn'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        await ref.read(editorProvider.notifier).syncGameDataCsv(gameName);
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        GrimoireToast.success(
                          context,
                          '${ref.tr('csv_saved_toast')} "$gameName" (${gameCards.length} cartas).',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.6)),
                        backgroundColor: GrimoireTheme.accentIndigo.withValues(alpha: 0.12),
                        foregroundColor: const Color(0xFFC7D2FE),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.sync, size: 15),
                      label: Text(ref.tr('load_csv_btn'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final ok = await ref.read(editorProvider.notifier).reloadGameFromCsv(gameName);
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (ok) {
                          GrimoireToast.success(
                            context,
                            '${ref.tr('csv_loaded_toast')} "$gameName".',
                          );
                        } else {
                          GrimoireToast.error(
                            context,
                            'No se encontró data.csv para "$gameName". Primero guárdalo.',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Button: Abrir en Explorador de Windows
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GrimoireTheme.accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: Text(ref.tr('open_in_explorer'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ref.read(editorProvider.notifier).openGameFolder(gameName);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    final r = rarity.toLowerCase();
    if (r.contains('mítica') || r.contains('mythic')) return const Color(0xFFF59E0B);
    if (r.contains('épica') || r.contains('epic')) return const Color(0xFFEC4899);
    if (r.contains('rara') || r.contains('rare')) return const Color(0xFFA855F7);
    if (r.contains('poco') || r.contains('uncommon')) return const Color(0xFF38BDF8);
    if (r.contains('inicial') || r.contains('starter')) return const Color(0xFF34D399);
    return const Color(0xFF94A3B8);
  }

  IconData _getGameIcon(String game) {
    final g = game.toLowerCase();
    if (g.contains('unicorn') || g.contains('unstable') || g.contains('inestable')) {
      return Icons.pets;
    } else if (g.contains('magic') || g.contains('mtg') || g.contains('arcano')) {
      return Icons.auto_awesome;
    }
    return Icons.casino_outlined;
  }
}

class _StarterCardArchetype {
  final String label;
  final String icon;
  final String defaultName;
  final String defaultType;
  final int defaultColor;
  final bool hasCost;
  final String defaultCost;
  final bool hasCombatStats;
  final String defaultAttack;
  final String defaultDefense;
  final bool hasRarity;
  final String defaultRarity;
  final bool hasRules;
  final String defaultRules;
  final String layoutPreset;

  const _StarterCardArchetype({
    required this.label,
    required this.icon,
    required this.defaultName,
    required this.defaultType,
    required this.defaultColor,
    required this.hasCost,
    required this.defaultCost,
    required this.hasCombatStats,
    required this.defaultAttack,
    required this.defaultDefense,
    required this.hasRarity,
    required this.defaultRarity,
    required this.hasRules,
    required this.defaultRules,
    required this.layoutPreset,
  });
}

class _SidebarGameTileItem extends StatefulWidget {
  final String title;
  final IconData icon;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SidebarGameTileItem({
    required this.title,
    required this.icon,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_SidebarGameTileItem> createState() => _SidebarGameTileItemState();
}

class _SidebarGameTileItemState extends State<_SidebarGameTileItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? GrimoireTheme.accentPurple.withValues(alpha: 0.18)
                : (_isHovered ? Colors.white.withValues(alpha: 0.04) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected ? GrimoireTheme.accentPurple.withValues(alpha: 0.8) : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
                    color: widget.isSelected ? Colors.white : GrimoireTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              // Card count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? GrimoireTheme.accentPurple.withValues(alpha: 0.35)
                      : const Color(0xFF1E2235),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.isSelected ? Colors.white : GrimoireTheme.textMuted,
                  ),
                ),
              ),
              // Delete game icon button on hover or selection (if deletable)
              if (widget.onDelete != null && (_isHovered || widget.isSelected)) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Eliminar juego',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: widget.onDelete,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.delete_outline,
                          size: 15,
                          color: Colors.red.shade400.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
