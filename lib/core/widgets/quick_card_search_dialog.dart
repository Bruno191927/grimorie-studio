import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/grimoire_theme.dart';
import '../../features/editor/presentation/providers/editor_provider.dart';
import '../../features/editor/services/game_folder_service.dart';

/// Fast spotlight search modal (`Ctrl+K`) to jump directly to any card across any game.
class QuickCardSearchDialog extends ConsumerStatefulWidget {
  final VoidCallback onCardSelected;

  const QuickCardSearchDialog({super.key, required this.onCardSelected});

  static Future<void> show(BuildContext context, {required VoidCallback onCardSelected}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => QuickCardSearchDialog(onCardSelected: onCardSelected),
    );
  }

  @override
  ConsumerState<QuickCardSearchDialog> createState() => _QuickCardSearchDialogState();
}

class _QuickCardSearchDialogState extends ConsumerState<QuickCardSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final allRows = editorState.project.rows;
    final query = _controller.text.trim().toLowerCase();

    final filtered = <Map<String, dynamic>>[];
    for (int i = 0; i < allRows.length; i++) {
      final r = allRows[i];
      final name = (r['card_name'] ?? '').toString().toLowerCase();
      final game = (r['game'] ?? '').toString().toLowerCase();
      final cat = (r['category'] ?? '').toString().toLowerCase();
      final type = (r['type'] ?? '').toString().toLowerCase();

      if (query.isEmpty ||
          name.contains(query) ||
          game.contains(query) ||
          cat.contains(query) ||
          type.contains(query)) {
        filtered.add({'row': r, 'index': i});
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Center(
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 520),
          decoration: BoxDecoration(
            color: GrimoireTheme.surfacePanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GrimoireTheme.borderStrong, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Input Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 20, color: GrimoireTheme.accentPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Buscar carta por nombre, juego, tipo o categoría...',
                          hintStyle: TextStyle(fontSize: 13, color: GrimoireTheme.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          fillColor: Colors.transparent,
                        ),
                        onChanged: (_) => setState(() => _selectedIndex = 0),
                        onSubmitted: (_) {
                          if (filtered.isNotEmpty) {
                            final sel = filtered[_selectedIndex.clamp(0, filtered.length - 1)];
                            final realIndex = sel['index'] as int;
                            ref.read(editorProvider.notifier).setActiveRow(realIndex);
                            Navigator.pop(context);
                            widget.onCardSelected();
                          }
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2235),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF2E3550)),
                      ),
                      child: const Text('ESC', style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted, fontFamily: 'monospace')),
                    ),
                  ],
                ),
              ),

              // Search Results List
              Flexible(
                child: filtered.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off, size: 36, color: GrimoireTheme.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              query.isEmpty ? 'No hay cartas en el proyecto.' : 'No se encontraron cartas que coincidan con "$query"',
                              style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, idx) {
                          final item = filtered[idx];
                          final row = item['row'] as Map<String, dynamic>;
                          final realIdx = item['index'] as int;
                          final isSelected = idx == _selectedIndex;

                          final name = (row['card_name'] ?? 'Carta').toString();
                          final game = (row['game'] ?? 'General').toString();
                          final category = (row['category'] ?? '').toString();
                          final type = (row['type'] ?? '').toString();
                          final icon = (row['icon'] ?? '🃏').toString();
                          final artFile = GameFolderService.resolveCardImageFile(game, row['art_url']?.toString());

                          return InkWell(
                            onTap: () {
                              ref.read(editorProvider.notifier).setActiveRow(realIdx);
                              Navigator.pop(context);
                              widget.onCardSelected();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? GrimoireTheme.accentPurple.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected ? GrimoireTheme.accentPurple : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Card mini thumbnail or icon
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF161928),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: GrimoireTheme.borderSubtle),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: artFile != null && artFile.existsSync()
                                        ? Image.file(artFile, fit: BoxFit.cover)
                                        : Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
                                  ),
                                  const SizedBox(width: 12),

                                  // Name and Type
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          type.isNotEmpty ? type : (category.isNotEmpty ? category : 'Carta'),
                                          style: const TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Game Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: GrimoireTheme.surfaceElevated,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: GrimoireTheme.borderSubtle),
                                    ),
                                    child: Text(
                                      game,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFFC7D2FE), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Footer with navigation tips
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF0C0F18),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: GrimoireTheme.borderSubtle)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Presiona Enter para editar la carta seleccionada',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Esc para cerrar',
                      style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
