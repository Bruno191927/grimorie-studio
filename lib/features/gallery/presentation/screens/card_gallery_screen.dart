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
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final allRows = editorState.project.rows;

    // Filter rows based on search and mana
    final filteredRows = allRows.where((row) {
      final name = (row['card_name'] ?? '').toString().toLowerCase();
      final type = (row['type'] ?? '').toString().toLowerCase();
      final cost = double.tryParse((row['cost'] ?? '0').toString()) ?? 0;

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          type.contains(_searchQuery.toLowerCase());
      final matchesMana = cost <= _maxMana;
      final matchesCategory = _selectedCategory == 'All' ||
          type.toLowerCase() == _selectedCategory.toLowerCase();

      return matchesQuery && matchesMana && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: GrimoireTheme.bgCanvas,
      body: Column(
        children: [
          // Sub-Header Navigation Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: const BoxDecoration(
              color: GrimoireTheme.surfacePanel,
              border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                _buildSubNavTab(ref.tr('tab_live_projects'), isSelected: true),
                const SizedBox(width: 24),
                _buildSubNavTab(ref.tr('tab_today_ai')),
                const SizedBox(width: 24),
                _buildSubNavTab(ref.tr('tab_tabletop_lands')),
                const SizedBox(width: 24),
                _buildSubNavTab(ref.tr('tab_card_vault')),
              ],
            ),
          ),

          // Main Content: Filter Sidebar + Card Grid
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Filter Sidebar
                _buildFilterSidebar(),

                // Right Card Grid Showcase
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Grid Header / Controls
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
                              ],
                            ),

                            // View Switchers & Sorter
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: GrimoireTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: GrimoireTheme.borderSubtle),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.grid_view, size: 16, color: GrimoireTheme.accentPurple),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        constraints: const BoxConstraints(),
                                        onPressed: () {},
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.view_list, size: 18, color: GrimoireTheme.textMuted),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        constraints: const BoxConstraints(),
                                        onPressed: () {},
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
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

                        // Card Grid
                        Expanded(
                          child: filteredRows.isEmpty
                              ? const Center(
                                  child: Text('No cards match your filter criteria.',
                                      style: TextStyle(color: GrimoireTheme.textMuted)),
                                )
                              : GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 260,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.72,
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

  Widget _buildSubNavTab(String title, {bool isSelected = false}) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(bottom: BorderSide(color: GrimoireTheme.accentPurple, width: 2))
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
          ),
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
                    _maxMana = 10;
                    _searchQuery = '';
                    _selectedCategory = 'All';
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

          // Categories Checklist
          _buildFilterSectionTitle(ref.tr('filter_categories')),
          _buildCheckbox(ref.tr('cat_art_creature'), true),
          _buildCheckbox(ref.tr('cat_spell_magic'), false),
          _buildCheckbox(ref.tr('cat_relic_artifact'), false),
          _buildCheckbox(ref.tr('cat_virtual_lands'), false),
          _buildCheckbox(ref.tr('cat_trading_cards'), true),
          _buildCheckbox(ref.tr('cat_utility_rules'), true),

          const SizedBox(height: 16),
          _buildFilterSectionTitle(ref.tr('filter_file_types')),
          _buildCheckbox(ref.tr('type_300dpi'), true),
          _buildCheckbox(ref.tr('type_pdf_print'), false),
          _buildCheckbox(ref.tr('type_vector'), false),

          const SizedBox(height: 16),
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

  Widget _buildFilterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              activeColor: GrimoireTheme.accentPurple,
              onChanged: (_) {},
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryCardTile(Map<String, dynamic> row, int index) {
    final name = row['card_name']?.toString() ?? 'Card';
    final creator = row['creator']?.toString() ?? 'Tyler Covington';
    final bid = row['bid']?.toString() ?? '4.89 ETH';
    final chain = row['chain']?.toString() ?? 'BSC';
    final icon = row['icon']?.toString() ?? '🤖';
    final artColor = Color(row['art_color'] is int ? row['art_color'] as int : 0xFFF59E0B);

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
            // Creator info header
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                  child: Text(creator.substring(0, 1), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ref.tr('creator_label'), style: const TextStyle(fontSize: 8, color: GrimoireTheme.textMuted)),
                      Text(creator, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border, size: 11, color: GrimoireTheme.accentPink),
                      SizedBox(width: 3),
                      Text('100', style: TextStyle(fontSize: 10, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

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
                      child: Text(icon, style: const TextStyle(fontSize: 54)),
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
            const SizedBox(height: 10),

            // Title
            Text(
              '"$name"',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Current Bid & Tag
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
}
