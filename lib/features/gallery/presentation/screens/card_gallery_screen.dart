import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';

class CardGalleryScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenEditor;

  const CardGalleryScreen({super.key, required this.onOpenEditor});

  @override
  ConsumerState<CardGalleryScreen> createState() => _CardGalleryScreenState();
}

class _CardGalleryScreenState extends ConsumerState<CardGalleryScreen> {
  double _maxMana = 10;
  String _searchQuery = '';
  String _selectedGame = 'All';
  bool _groupByGame = true;
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedFileTypes = {'type_300dpi'};

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final allRows = editorState.project.rows;

    // Extract unique board games
    final allGamesSet = <String>{};
    for (final r in allRows) {
      final g = r['game']?.toString().trim();
      if (g != null && g.isNotEmpty) allGamesSet.add(g);
    }
    if (!allGamesSet.contains('Cyber Arena TCG')) allGamesSet.add('Cyber Arena TCG');
    if (!allGamesSet.contains('Reino Arcano (Fantasy)')) allGamesSet.add('Reino Arcano (Fantasy)');
    final allGames = allGamesSet.toList();

    // Filter rows based on search, mana, board game, and category
    final filteredRows = allRows.where((row) {
      final name = (row['card_name'] ?? '').toString().toLowerCase();
      final type = (row['type'] ?? '').toString().toLowerCase();
      final game = (row['game'] ?? '').toString().toLowerCase();
      final cost = double.tryParse((row['cost'] ?? '0').toString()) ?? 0;
      final cat = (row['category'] ?? '').toString();

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          type.contains(_searchQuery.toLowerCase()) ||
          game.contains(_searchQuery.toLowerCase());
      final matchesMana = cost <= _maxMana;
      final matchesGame = _selectedGame == 'All' ||
          (row['game'] ?? '').toString().toLowerCase() == _selectedGame.toLowerCase();
      final matchesCategory = _selectedCategories.isEmpty ||
          _selectedCategories.contains(cat);

      return matchesQuery && matchesMana && matchesGame && matchesCategory;
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
                                            _selectedCategories.clear();
                                            _maxMana = 10;
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
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: GrimoireTheme.accentPurple,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            '+ ${ref.tr('add_row')}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            ref.read(editorProvider.notifier).addCardToGame(entry.key);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: GrimoireTheme.accentEmerald,
                                content: Text('Nueva carta añadida a "${entry.key}".'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Responsive Grid for cards in this board game
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
    return GridView.builder(
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

  // --- Left Filter Sidebar with FULLY Interactive Checkboxes ---
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
                    _maxMana = 10;
                    _searchQuery = '';
                    _selectedGame = 'All';
                    _selectedCategories.clear();
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

          // Categories Checklist (Fully Interactive)
          _buildFilterSectionTitle(ref.tr('filter_categories')),
          _buildInteractiveCheckbox(
            label: ref.tr('cat_art_creature'),
            isSelected: _selectedCategories.contains('cat_art_creature'),
            onToggle: (val) => _toggleCategory('cat_art_creature', val),
          ),
          _buildInteractiveCheckbox(
            label: ref.tr('cat_spell_magic'),
            isSelected: _selectedCategories.contains('cat_spell_magic'),
            onToggle: (val) => _toggleCategory('cat_spell_magic', val),
          ),
          _buildInteractiveCheckbox(
            label: ref.tr('cat_relic_artifact'),
            isSelected: _selectedCategories.contains('cat_relic_artifact'),
            onToggle: (val) => _toggleCategory('cat_relic_artifact', val),
          ),
          _buildInteractiveCheckbox(
            label: ref.tr('cat_virtual_lands'),
            isSelected: _selectedCategories.contains('cat_virtual_lands'),
            onToggle: (val) => _toggleCategory('cat_virtual_lands', val),
          ),
          _buildInteractiveCheckbox(
            label: ref.tr('cat_trading_cards'),
            isSelected: _selectedCategories.contains('cat_trading_cards'),
            onToggle: (val) => _toggleCategory('cat_trading_cards', val),
          ),
          _buildInteractiveCheckbox(
            label: ref.tr('cat_utility_rules'),
            isSelected: _selectedCategories.contains('cat_utility_rules'),
            onToggle: (val) => _toggleCategory('cat_utility_rules', val),
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

          const SizedBox(height: 16),
          // Mana Cost Slider
          _buildFilterSectionTitle('${ref.tr('filter_mana_cost')} (≤ ${_maxMana.toInt()})'),
          Slider(
            value: _maxMana,
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: GrimoireTheme.accentPurple,
            onChanged: (val) => setState(() => _maxMana = val),
          ),
        ],
      ),
    );
  }

  void _toggleCategory(String key, bool? isChecked) {
    setState(() {
      if (isChecked == true) {
        _selectedCategories.add(key);
      } else {
        _selectedCategories.remove(key);
      }
    });
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

  // --- Card Tile ---
  Widget _buildGalleryCardTile(Map<String, dynamic> row, int index) {
    final name = row['card_name']?.toString() ?? 'Card';
    final creator = row['creator']?.toString() ?? 'Tyler Covington';
    final bid = row['bid']?.toString() ?? '4.89 ETH';
    final chain = row['chain']?.toString() ?? 'BSC';
    final icon = row['icon']?.toString() ?? '🤖';
    final artColor = Color(row['art_color'] is int ? row['art_color'] as int : 0xFFF59E0B);
    final game = row['game']?.toString() ?? 'General';
    final cost = row['cost']?.toString() ?? '0';

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
            // Creator info header with Board Game Tag & Menu
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                  child: Text(
                    creator.isNotEmpty ? creator.substring(0, 1) : 'C',
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ref.tr('creator_label'), style: const TextStyle(fontSize: 8, color: GrimoireTheme.textMuted)),
                      Text(
                        creator,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Card Context Menu (Move to Game, Edit)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert, size: 16, color: GrimoireTheme.textMuted),
                  color: GrimoireTheme.surfaceElevated,
                  onSelected: (val) {
                    if (val == 'edit') {
                      ref.read(editorProvider.notifier).setActiveRow(index);
                      widget.onOpenEditor();
                    } else if (val == 'move') {
                      _showMoveCardDialog(index, name, game);
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
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Artwork Area with Timer Pill
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: artColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(icon, style: const TextStyle(fontSize: 50)),
                    ),
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131622).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department, size: 12, color: GrimoireTheme.accentPurple),
                            SizedBox(width: 4),
                            Text(
                              '5 : 23 : 26 : 22',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
            const SizedBox(height: 8),

            // Title & Board Game Badge
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

            // Board Game Tag Pill
            Container(
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
            const SizedBox(height: 6),

            // Current Bid & Chain Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ref.tr('current_bid'), style: const TextStyle(fontSize: 8, color: GrimoireTheme.textMuted)),
                      Text(bid, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.tagBsc,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(chain, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
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

  IconData _getGameIcon(String game) {
    final g = game.toLowerCase();
    if (g.contains('cyber') || g.contains('arena') || g.contains('mech')) {
      return Icons.smart_toy_outlined;
    } else if (g.contains('arcano') || g.contains('fantasy') || g.contains('magic') || g.contains('reino')) {
      return Icons.castle_outlined;
    } else if (g.contains('star') || g.contains('odyssey') || g.contains('sci-fi') || g.contains('space')) {
      return Icons.rocket_launch_outlined;
    }
    return Icons.casino_outlined;
  }
}
