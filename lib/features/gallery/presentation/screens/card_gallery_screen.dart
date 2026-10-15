import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';

class CardGalleryScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenEditor;

  const CardGalleryScreen({super.key, required this.onOpenEditor});

  @override
  ConsumerState<CardGalleryScreen> createState() => _CardGalleryScreenState();
}

class _CardGalleryScreenState extends ConsumerState<CardGalleryScreen> {
  String _searchQuery = '';
  String _selectedGame = 'All';
  bool _groupByGame = true;
  final Map<String, String?> _gameCategoryFilter = {};
  final Set<String> _selectedFileTypes = {'type_300dpi'};
  final Map<String, bool> _showDefaultModelsForGame = {};

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
    if (!editorState.deletedGames.contains('Magic') && !allGamesSet.contains('Magic')) {
      allGamesSet.add('Magic');
    }
    if (!editorState.deletedGames.contains('Unstable Unicorns') && !allGamesSet.contains('Unstable Unicorns')) {
      allGamesSet.add('Unstable Unicorns');
    }
    final allGames = allGamesSet.toList();

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

    return Scaffold(
      backgroundColor: GrimoireTheme.bgCanvas,
      body: Column(
        children: [
          // Sub-Header: Board Game / Deck Switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: const BoxDecoration(
              color: GrimoireTheme.surfacePanel,
              border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // All Games Pill Tab
                  _buildGamePill(
                    title: ref.tr('all_games'),
                    icon: Icons.auto_awesome_motion,
                    isSelected: _selectedGame == 'All',
                    count: allRows.length,
                    onTap: () => setState(() => _selectedGame = 'All'),
                  ),
                  const SizedBox(width: 8),

                  // Pill for each board game
                  for (final game in allGames) ...[
                    _buildGamePill(
                      title: game,
                      icon: _getGameIcon(game),
                      isSelected: _selectedGame == game,
                      count: allRows.where((r) => (r['game'] ?? '').toString() == game).length,
                      onTap: () => setState(() => _selectedGame = game),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Action: Create New Board Game
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                      backgroundColor: GrimoireTheme.accentPurple.withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFFE9D5FF),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 14, color: GrimoireTheme.accentPurple),
                    label: Text(
                      ref.tr('new_game_btn'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _showNewGameDialog,
                  ),
                ],
              ),
            ),
          ),

          // Main Content: Filter Sidebar + Card Showcase
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Filter Sidebar
                _buildFilterSidebar(),

                // Right Card Showcase
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Controls Bar: Count, Grouping Switcher, Sort
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${filteredRows.length} ${ref.tr('items_count')}',
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
                                const SizedBox(width: 12),

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
                        const SizedBox(height: 16),

                        // Card Area: Grouped or Continuous Grid
                        Expanded(
                          child: filteredRows.isEmpty
                              ? Center(
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
                                )
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
          ),
        ],
      ),
    );
  }

  // --- Grouped View by Board Game ---
  Widget _buildGroupedByGameView(List<Map<String, dynamic>> filteredRows, List<Map<String, dynamic>> allRows) {
    // Partition filtered cards by game
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final row in filteredRows) {
      final game = (row['game'] ?? 'General').toString();
      groups.putIfAbsent(game, () => []).add(row);
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                    Row(
                      children: [
                        PopupMenuButton<String>(
                          tooltip: 'Añadir carta por categoría',
                          color: GrimoireTheme.surfaceElevated,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: GrimoireTheme.borderSubtle),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 14, color: GrimoireTheme.accentPurple),
                                const SizedBox(width: 4),
                                Text(
                                  '+ ${ref.tr('add_row')}',
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
                              ref.read(editorProvider.notifier).addCardToGame(entry.key);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: GrimoireTheme.accentEmerald,
                                  content: Text('Nueva carta estándar añadida a "${entry.key}".'),
                                ),
                              );
                            } else {
                              final cats = ref.read(editorProvider.notifier).getCategoriesForGame(entry.key);
                              final cat = cats.firstWhere((c) => c.name == val, orElse: () => cats.first);
                              ref.read(editorProvider.notifier).createCardFromCategory(entry.key, cat);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: GrimoireTheme.accentEmerald,
                                  content: Text('Nueva carta "${cat.name}" creada para "${entry.key}".'),
                                ),
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
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFC7D2FE),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          ),
                          icon: const Icon(Icons.settings_outlined, size: 14, color: GrimoireTheme.accentIndigo),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.file_download_outlined, size: 14, color: GrimoireTheme.accentIndigo),
                          label: Text(
                            ref.tr('export_game'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            widget.onOpenEditor();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: GrimoireTheme.accentIndigo,
                                content: Text('Abriendo editor para exportar "${entry.key}"...'),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: GrimoireTheme.accentPink.withValues(alpha: 0.5)),
                            backgroundColor: const Color(0xFF1E1420),
                            foregroundColor: const Color(0xFFFECDD3),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 14, color: GrimoireTheme.accentPink),
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
                              label: const Text('+ Crear Carta'),
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
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.70,
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
          child: filteredRows.isEmpty
              ? Center(
                  child: Text(
                    ref.tr('no_cards_found'),
                    style: const TextStyle(color: GrimoireTheme.textMuted, fontSize: 13),
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.70,
                  ),
                  itemCount: filteredRows.length,
                  itemBuilder: (context, index) {
                    final row = filteredRows[index];
                    final originalIndex = allRows.indexOf(row);
                    return _buildGalleryCardTile(row, originalIndex);
                  },
                ),
        ),
      ],
    );
  }

  // --- Board Game Pill Tab ---
  Widget _buildGamePill({
    required String title,
    required IconData icon,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? GrimoireTheme.accentPurple.withValues(alpha: 0.22) : GrimoireTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSidebar() {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: GrimoireTheme.surfacePanel,
        border: Border(right: BorderSide(color: GrimoireTheme.borderSubtle)),
      ),
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ref.tr('filter_title'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedGame = 'All';
                    _gameCategoryFilter.clear();
                    _selectedFileTypes.clear();
                    _selectedFileTypes.add('type_300dpi');
                  });
                },
                child: Text(ref.tr('filter_reset'), style: const TextStyle(fontSize: 12, color: GrimoireTheme.accentPurple)),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Search Field
          TextField(
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: ref.tr('filter_search_hint'),
              prefixIcon: const Icon(Icons.search, size: 16, color: GrimoireTheme.textMuted),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 16),

          // File Types Checklist (Fully Interactive)
          _buildFilterSectionTitle(ref.tr('filter_file_types')),
          _buildInteractiveCheckbox(
            label: ref.tr('type_300dpi'),
            isSelected: _selectedFileTypes.contains('type_300dpi'),
            onToggle: (val) => _toggleFileType('type_300dpi', val),
          ),
          _buildInteractiveCheckbox(
            label: ref.tr('type_pdf_print'),
            isSelected: _selectedFileTypes.contains('type_pdf_print'),
            onToggle: (val) => _toggleFileType('type_pdf_print', val),
          ),
          _buildInteractiveCheckbox(
            label: ref.tr('type_vector'),
            isSelected: _selectedFileTypes.contains('type_vector'),
            onToggle: (val) => _toggleFileType('type_vector', val),
          ),

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

  Widget _buildFilterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  // Interactive Checkbox row where clicking anywhere on the label or box toggles state
  Widget _buildInteractiveCheckbox({
    required String label,
    required bool isSelected,
    required ValueChanged<bool?> onToggle,
  }) {
    return InkWell(
      onTap: () => onToggle(!isSelected),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: isSelected,
                activeColor: GrimoireTheme.accentPurple,
                checkColor: Colors.white,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: onToggle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Game Categories & Predefined Archetypes Bar (Inside each Game) ---
  Widget _buildGameCategoriesBar(String gameName, List<Map<String, dynamic>> allGameCards) {
    final editorState = ref.watch(editorProvider);
    final categories = editorState.gameCategories[gameName] ?? [];
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
                              '${categories.length} ${ref.tr('cards_in_game')}',
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
                  // Button: Toggle Default Card Models Blueprint Section
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                      backgroundColor: showDefaultModels ? GrimoireTheme.accentPurple.withValues(alpha: 0.18) : const Color(0xFF131522),
                      foregroundColor: const Color(0xFFE9D5FF),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(
                      showDefaultModels ? Icons.visibility_off_outlined : Icons.auto_awesome,
                      size: 14,
                      color: GrimoireTheme.accentPurple,
                    ),
                    label: Text(
                      showDefaultModels ? ref.tr('hide_default_models') : ref.tr('view_default_models'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => setState(() => _showDefaultModelsForGame[gameName] = !showDefaultModels),
                  ),

                  // Button: Carpeta del Juego (data.csv & assets/)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.5)),
                      backgroundColor: GrimoireTheme.accentEmerald.withValues(alpha: 0.12),
                      foregroundColor: const Color(0xFFA7F3D0),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.folder_open_outlined, size: 14, color: GrimoireTheme.accentEmerald),
                    label: Text(ref.tr('game_folder'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _showGameFolderDialog(gameName, allGameCards),
                  ),

                  // Button: + Nueva Categoría
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: Text(ref.tr('new_category_btn'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _showCategoryModelDialog(gameName),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable Category Archetype Chips (Enlarged & Visual)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "Todas" chip
                _buildArchetypePill(
                  title: ref.tr('all_cards_in_game'),
                  icon: '✨',
                  count: allGameCards.length,
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
                    count: allGameCards.where((c) => (c['category'] ?? '').toString().toLowerCase() == cat.name.toLowerCase()).length,
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

          // Dedicated Section: Default Card Models Blueprint Carousel
          if (showDefaultModels) ...[
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
                    children: [
                      const Icon(Icons.dashboard_customize_outlined, size: 16, color: GrimoireTheme.accentPurple),
                      const SizedBox(width: 8),
                      Text(
                        ref.tr('default_card_models'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${categories.length} plantillas configuradas)',
                        style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final cat in categories) ...[
                          _buildCategoryBlueprintCard(gameName, cat, allGameCards),
                          const SizedBox(width: 12),
                        ],
                        _buildAddCategoryBlueprintCard(gameName),
                      ],
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
              padding: const EdgeInsets.only(left: 14, right: 8, top: 7, bottom: 7),
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
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: catColor.withValues(alpha: 0.7)),
                ),
                icon: const Icon(Icons.flash_on, size: 12, color: Colors.white),
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

  // Visual Blueprint Card for a Category Default Model
  Widget _buildCategoryBlueprintCard(String gameName, GameCategory cat, List<Map<String, dynamic>> allGameCards) {
    final catColor = Color(cat.defaultColor);
    final cardCount = allGameCards.where((c) => (c['category'] ?? '').toString().toLowerCase() == cat.name.toLowerCase()).length;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111422),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: catColor.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Icon & Name
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: catColor),
                ),
                alignment: Alignment.center,
                child: Text(cat.icon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      '$cardCount ${ref.tr('cards_in_game')}',
                      style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: GrimoireTheme.borderSubtle),
          const SizedBox(height: 8),

          // Default Card Specs
          Row(
            children: [
              const Icon(Icons.style_outlined, size: 12, color: GrimoireTheme.accentPurple),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Tipo: ${cat.defaultType}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC7D2FE)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('⚡ ', style: TextStyle(fontSize: 10)),
              Text('Coste: ${cat.defaultCost}', style: const TextStyle(fontSize: 10, color: Colors.white)),
              const Spacer(),
              const Text('⚔️ ', style: TextStyle(fontSize: 10)),
              Text('${cat.defaultAttack}/${cat.defaultDefense}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: _getRarityColor(cat.defaultRarity), shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(cat.defaultRarity, style: TextStyle(fontSize: 10, color: _getRarityColor(cat.defaultRarity), fontWeight: FontWeight.w600)),
            ],
          ),
          if (cat.defaultRules.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"${cat.defaultRules}"',
              style: const TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: GrimoireTheme.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),

          // Action Buttons: Use Blueprint to generate card & Edit Blueprint
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GrimoireTheme.accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.flash_on, size: 12),
                  label: const Text('+ Usar Modelo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _generateCardFromModel(gameName, cat),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Icons.tune, size: 15, color: GrimoireTheme.accentIndigo),
                tooltip: 'Editar Modelo',
                onPressed: () => _showCategoryModelDialog(gameName, existingCategory: cat),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Icons.delete_outline, size: 15, color: GrimoireTheme.accentPink),
                tooltip: 'Eliminar Categoría',
                onPressed: () => _confirmDeleteCategory(gameName, cat.name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Button Blueprint card to add a new category model
  Widget _buildAddCategoryBlueprintCard(String gameName) {
    return InkWell(
      onTap: () => _showCategoryModelDialog(gameName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        height: 175,
        decoration: BoxDecoration(
          color: const Color(0xFF10121E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_circle_outline, size: 24, color: GrimoireTheme.accentPurple),
            ),
            const SizedBox(height: 10),
            Text(
              '+ Nueva\nPlantilla',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE9D5FF)),
            ),
          ],
        ),
      ),
    );
  }


  void _generateCardFromModel(String gameName, GameCategory category) {
    ref.read(editorProvider.notifier).createCardFromCategory(gameName, category);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GrimoireTheme.accentEmerald,
        content: Text('¡Carta creada con el modelo predefinido "${category.name}"!'),
        action: SnackBarAction(
          label: 'Ver en Editor',
          textColor: Colors.white,
          onPressed: () {
            final rows = ref.read(editorProvider).project.rows;
            ref.read(editorProvider.notifier).setActiveRow(rows.length - 1);
            final g = gameName.toLowerCase();
            if (g.contains('unicorn') || g.contains('unstable')) {
              ref.read(editorProvider.notifier).setActiveTemplate(1);
            } else {
              ref.read(editorProvider.notifier).setActiveTemplate(0);
            }
            widget.onOpenEditor();
          },
        ),
      ),
    );
  }

  // --- Card Tile ---
  Widget _buildGalleryCardTile(Map<String, dynamic> row, int index) {
    final name = row['card_name']?.toString() ?? 'Card';
    final icon = row['icon']?.toString() ?? '🃏';
    final artColor = Color(row['art_color'] is int ? row['art_color'] as int : 0xFFF59E0B);
    final game = row['game']?.toString() ?? 'General';
    final cost = row['cost']?.toString() ?? '0';
    final category = row['category']?.toString() ?? '';
    final type = row['type']?.toString() ?? '';
    final rarity = row['rarity']?.toString() ?? 'Común';
    final attack = row['attack']?.toString() ?? '0';
    final defense = row['defense']?.toString() ?? '0';
    final hasCombatStats = (attack != '0' || defense != '0') ||
        type.toLowerCase().contains('criatura') ||
        type.toLowerCase().contains('creature') ||
        type.toLowerCase().contains('unicorn');
    final rarityColor = _getRarityColor(rarity);
    final artFile = GameFolderService.resolveCardImageFile(game, row['art_url']?.toString());

    return InkWell(
      onTap: () {
        ref.read(editorProvider.notifier).setActiveRow(index);
        final cardGame = (row['game'] ?? '').toString().toLowerCase();
        if (cardGame.contains('unicorn') || cardGame.contains('unstable')) {
          ref.read(editorProvider.notifier).setActiveTemplate(1);
        } else {
          ref.read(editorProvider.notifier).setActiveTemplate(0);
        }
        widget.onOpenEditor();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: GrimoireTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GrimoireTheme.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
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
                        color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              type.isNotEmpty ? type : (category.isNotEmpty ? category : game),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE9D5FF),
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

                // Card Context Menu (Move to Game, Edit, Delete)
                PopupMenuButton<String>(
                  key: ValueKey('card_menu_$name'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert, size: 16, color: GrimoireTheme.textMuted),
                  color: GrimoireTheme.surfaceElevated,
                  onSelected: (val) {
                    if (val == 'edit') {
                      ref.read(editorProvider.notifier).setActiveRow(index);
                      final cardGame = (row['game'] ?? '').toString().toLowerCase();
                      if (cardGame.contains('unicorn') || cardGame.contains('unstable')) {
                        ref.read(editorProvider.notifier).setActiveTemplate(1);
                      } else {
                        ref.read(editorProvider.notifier).setActiveTemplate(0);
                      }
                      widget.onOpenEditor();
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
            const SizedBox(height: 8),

            // Artwork Area (Clean, no countdown timers)
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: artColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: artFile != null
                    ? Image.file(
                        artFile,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Center(
                          child: Text(icon, style: const TextStyle(fontSize: 50)),
                        ),
                      )
                    : Center(
                        child: Text(icon, style: const TextStyle(fontSize: 50)),
                      ),
              ),
            ),
            const SizedBox(height: 8),

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
                ),
                const SizedBox(width: 6),

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
                        const Text('⚔️ ', style: TextStyle(fontSize: 8.5)),
                        Text(
                          attack,
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Text('  🛡️ ', style: TextStyle(fontSize: 8.5)),
                        Text(
                          defense,
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr('new_game_hint'),
              style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted),
            ),
            const SizedBox(height: 12),
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
          ],
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
                ref.read(editorProvider.notifier).addCardToGame(gameName);
                setState(() {
                  _selectedGame = gameName;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: GrimoireTheme.accentEmerald,
                    content: Text('¡Juego de mesa "$gameName" creado con su primera carta!'),
                  ),
                );
              }
            },
            child: Text(ref.tr('create')),
          ),
        ],
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: GrimoireTheme.accentEmerald,
                      content: Text('Carta reasignada al juego "$g".'),
                    ),
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

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: GrimoireTheme.accentPink,
                  content: Text('${ref.tr('card_deleted')}: "$cardName"'),
                ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: GrimoireTheme.accentPink,
                  content: Text('${ref.tr('game_deleted')}: "$gameName"'),
                ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: GrimoireTheme.accentPink,
                  content: Text('Categoría "$categoryName" eliminada de "$gameName".'),
                ),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.add, size: 12),
                                label: const Text('+ Carta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _generateCardFromModel(gameName, cat);
                                },
                              ),
                              const SizedBox(width: 4),
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
  void _showCategoryModelDialog(String defaultGame, {GameCategory? existingCategory}) {
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

    final isEditing = existingCategory != null;
    final nameController = TextEditingController(text: existingCategory?.name ?? '');
    final iconController = TextEditingController(text: existingCategory?.icon ?? '🦄');
    final typeController = TextEditingController(text: existingCategory?.defaultType ?? '');
    final costController = TextEditingController(text: existingCategory?.defaultCost ?? '3');
    final attackController = TextEditingController(text: existingCategory?.defaultAttack ?? '0');
    final defenseController = TextEditingController(text: existingCategory?.defaultDefense ?? '0');
    final rarityController = TextEditingController(text: existingCategory?.defaultRarity ?? 'Común');
    final rulesController = TextEditingController(text: existingCategory?.defaultRules ?? '');

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

    final emojiPresets = ['🦄', '🌟', '✨', '💣', '🚫', '⚔️', '🛡️', '🤖', '🔮', '⚡', '👑', '📜', '🐼', '🚀', '🦌'];

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
                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  isEditing ? Icons.tune : Icons.category_outlined,
                  color: GrimoireTheme.accentPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? ref.tr('edit_category_model') : ref.tr('new_category_title'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Juego: $chosenGame',
                      style: const TextStyle(fontSize: 11, color: GrimoireTheme.accentPurple),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.tr('new_category_desc'),
                    style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.3),
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
                          if (val != null) setDialogState(() => chosenGame = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Category Name
                  Text(ref.tr('category_name'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'ej. Unicornios (Básicos y Mágicos), Cartas de Mejora',
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

                  // Emoji / Icon
                  Text(ref.tr('category_icon'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 55,
                        child: TextField(
                          controller: iconController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: emojiPresets.map((emoji) => InkWell(
                              onTap: () => setDialogState(() => iconController.text = emoji),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(emoji, style: const TextStyle(fontSize: 18)),
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Default Card Type & Cost Row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ref.tr('category_default_type'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: typeController,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'ej. Unicornio Mágico, Instantánea',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ref.tr('default_cost'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: costController,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '2',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Attack, Defense & Rarity Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ataque Base', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: attackController,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '2',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Defensa Base', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: defenseController,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '2',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ref.tr('default_rarity'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: rarityController,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Común',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

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
                  const SizedBox(height: 12),

                  // Default Rules Template
                  Text(ref.tr('category_rules_template'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: rulesController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'ej. Al entrar a tu Establo, puedes activar un efecto...',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GrimoireTheme.accentPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final catName = nameController.text.trim();
                if (catName.isNotEmpty) {
                  final cat = GameCategory(
                    id: existingCategory?.id ?? 'cat_${DateTime.now().millisecondsSinceEpoch}',
                    name: catName,
                    icon: iconController.text.trim().isEmpty ? '🦄' : iconController.text.trim(),
                    defaultType: typeController.text.trim().isEmpty ? catName : typeController.text.trim(),
                    defaultColor: selectedColor,
                    defaultRules: rulesController.text.trim(),
                    defaultCost: costController.text.trim().isEmpty ? '3' : costController.text.trim(),
                    defaultAttack: attackController.text.trim().isEmpty ? '0' : attackController.text.trim(),
                    defaultDefense: defenseController.text.trim().isEmpty ? '0' : defenseController.text.trim(),
                    defaultRarity: rarityController.text.trim().isEmpty ? 'Común' : rarityController.text.trim(),
                  );
                  ref.read(editorProvider.notifier).addCategoryToGame(chosenGame, cat);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: GrimoireTheme.accentEmerald,
                      content: Text('Modelo predefinido "$catName" guardado para "$chosenGame".'),
                    ),
                  );
                }
              },
              child: Text(isEditing ? ref.tr('save_model') : ref.tr('create')),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewCategoryDialog(String defaultGame) {
    _showCategoryModelDialog(defaultGame);
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: GrimoireTheme.accentEmerald,
                            content: Text('${ref.tr('csv_saved_toast')} "$gameName" (${gameCards.length} cartas).'),
                          ),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: ok ? GrimoireTheme.accentEmerald : GrimoireTheme.accentPink,
                            content: Text(ok
                                ? '${ref.tr('csv_loaded_toast')} "$gameName".'
                                : 'No se encontró data.csv para "$gameName". Primero guárdalo.'),
                          ),
                        );
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
