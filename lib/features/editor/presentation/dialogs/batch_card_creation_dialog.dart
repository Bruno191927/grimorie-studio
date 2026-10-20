import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../models/game_category.dart';
import '../providers/editor_provider.dart';

class BatchCardCreationDialog extends ConsumerStatefulWidget {
  final String initialGame;
  final GameCategory? initialCategory;

  const BatchCardCreationDialog({
    super.key,
    required this.initialGame,
    this.initialCategory,
  });

  @override
  ConsumerState<BatchCardCreationDialog> createState() => _BatchCardCreationDialogState();
}

class _BatchCardCreationDialogState extends ConsumerState<BatchCardCreationDialog> {
  late String _selectedGame;
  GameCategory? _selectedCategory;
  int _modeIndex = 0; // 0: By Names List, 1: By Count

  final TextEditingController _namesController = TextEditingController();
  final TextEditingController _prefixController = TextEditingController(text: 'Carta');
  int _countToGenerate = 5;

  @override
  void initState() {
    super.initState();
    _selectedGame = widget.initialGame;
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _namesController.dispose();
    _prefixController.dispose();
    super.dispose();
  }

  List<String> _extractNames() {
    if (_modeIndex == 0) {
      return _namesController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      final prefix = _prefixController.text.trim();
      final effectivePrefix = prefix.isEmpty ? 'Carta' : prefix;
      return List.generate(_countToGenerate, (i) => '$effectivePrefix #${i + 1}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final categories = ref.read(editorProvider.notifier).getCategoriesForGame(_selectedGame);

    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }

    final cardNames = _extractNames();
    final count = cardNames.length;

    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.copy_all, color: GrimoireTheme.accentPurple, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.tr('batch_card_creator'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ref.tr('batch_card_creator_desc'),
                        style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: GrimoireTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Game & Category selectors
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Juego', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GrimoireTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGame,
                            isExpanded: true,
                            dropdownColor: GrimoireTheme.surfaceElevated,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                            items: [
                              for (final g in editorState.gameCategories.keys)
                                DropdownMenuItem(value: g, child: Text(g)),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedGame = val;
                                  final newCats = ref.read(editorProvider.notifier).getCategoriesForGame(val);
                                  _selectedCategory = newCats.isNotEmpty ? newCats.first : null;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ref.tr('category_label'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GrimoireTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<GameCategory>(
                            value: categories.contains(_selectedCategory) ? _selectedCategory : (categories.isNotEmpty ? categories.first : null),
                            isExpanded: true,
                            dropdownColor: GrimoireTheme.surfaceElevated,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                            items: [
                              for (final cat in categories)
                                DropdownMenuItem(
                                  value: cat,
                                  child: Row(
                                    children: [
                                      Text(cat.icon, style: const TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Text(cat.name),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Mode Selector Tabs
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _buildModeTab(0, ref.tr('generate_by_names'), Icons.list_alt),
                _buildModeTab(1, ref.tr('generate_by_count'), Icons.format_list_numbered),
              ],
            ),
            const SizedBox(height: 14),

            // Mode Body
            if (_modeIndex == 0) ...[
              TextField(
                controller: _namesController,
                maxLines: 6,
                style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: ref.tr('names_list_hint'),
                  hintStyle: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                  filled: true,
                  fillColor: GrimoireTheme.surfaceCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrimoireTheme.accentPurple)),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ref.tr('name_prefix_label'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _prefixController,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: ref.tr('name_prefix_hint'),
                            filled: true,
                            fillColor: GrimoireTheme.surfaceCard,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ref.tr('quantity_to_create'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              style: IconButton.styleFrom(backgroundColor: GrimoireTheme.surfaceCard),
                              onPressed: () {
                                if (_countToGenerate > 1) {
                                  setState(() => _countToGenerate--);
                                }
                              },
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '$_countToGenerate',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              style: IconButton.styleFrom(backgroundColor: GrimoireTheme.surfaceCard),
                              onPressed: () {
                                if (_countToGenerate < 100) {
                                  setState(() => _countToGenerate++);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Footer info & actions
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${ref.tr('total_to_create')}: $count ${ref.tr('cards_unit')}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrimoireTheme.accentPurple),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GrimoireTheme.accentPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: Text(ref.tr('generate_cards_btn')),
                      onPressed: count == 0 || _selectedCategory == null
                          ? null
                          : () {
                              ref.read(editorProvider.notifier).batchCreateCards(
                                    gameName: _selectedGame,
                                    category: _selectedCategory!,
                                    cardNames: cardNames,
                                  );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: GrimoireTheme.accentEmerald,
                                  content: Text('${ref.tr('batch_created_success_1')} $count ${ref.tr('batch_created_success_2')} "$_selectedGame"'),
                                ),
                              );
                            },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(int index, String title, IconData icon) {
    final isSelected = _modeIndex == index;
    return InkWell(
      onTap: () => setState(() => _modeIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? GrimoireTheme.accentPurple.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? GrimoireTheme.accentPurple : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : GrimoireTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
