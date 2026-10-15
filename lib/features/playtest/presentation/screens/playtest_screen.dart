import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';

class PlaytestCard {
  final String id;
  final Map<String, dynamic> data;
  Offset position;
  bool isTapped;

  PlaytestCard({
    required this.id,
    required this.data,
    required this.position,
    this.isTapped = false,
  });
}

class PlaytestScreen extends ConsumerStatefulWidget {
  const PlaytestScreen({super.key});

  @override
  ConsumerState<PlaytestScreen> createState() => _PlaytestScreenState();
}

class _PlaytestScreenState extends ConsumerState<PlaytestScreen> {
  final List<PlaytestCard> _battlefield = [];
  final List<Map<String, dynamic>> _hand = [];
  int _playerLife = 20;
  int _turn = 1;

  @override
  void initState() {
    super.initState();
    // Initialize hand from project rows
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rows = ref.read(editorProvider).project.rows;
      if (rows.isNotEmpty) {
        setState(() {
          _hand.addAll(rows.take(5));
        });
      }
    });
  }

  void _drawCard() {
    final rows = ref.read(editorProvider).project.rows;
    if (rows.isNotEmpty) {
      final nextIndex = (_hand.length + _battlefield.length) % rows.length;
      setState(() {
        _hand.add(rows[nextIndex]);
      });
    }
  }

  void _playCardToBattlefield(Map<String, dynamic> cardData, Offset position) {
    setState(() {
      _hand.remove(cardData);
      _battlefield.add(
        PlaytestCard(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          data: cardData,
          position: position,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D111A),
      appBar: AppBar(
        backgroundColor: GrimoireTheme.surfacePanel,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.casino_outlined, color: GrimoireTheme.accentPurple, size: 22),
            const SizedBox(width: 8),
            const Text('Tabletop Playtest Mat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            // Life counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: GrimoireTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GrimoireTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  const Text('❤️ Life: ', style: TextStyle(fontSize: 12, color: GrimoireTheme.textMuted)),
                  IconButton(
                    icon: const Icon(Icons.remove, size: 14, color: GrimoireTheme.accentPink),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _playerLife--),
                  ),
                  const SizedBox(width: 6),
                  Text('$_playerLife', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.add, size: 14, color: GrimoireTheme.accentEmerald),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _playerLife++),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Turn counter
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GrimoireTheme.surfaceElevated,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.refresh, size: 14, color: GrimoireTheme.accentIndigo),
              label: Text('Next Turn ($_turn)'),
              onPressed: () {
                setState(() {
                  _turn++;
                  // Untap all
                  for (final c in _battlefield) {
                    c.isTapped = false;
                  }
                });
                _drawCard();
              },
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tabletop Battlefield Area
          Expanded(
            child: DragTarget<Map<String, dynamic>>(
              onAcceptWithDetails: (details) {
                final renderBox = context.findRenderObject() as RenderBox?;
                final localPos = renderBox?.globalToLocal(details.offset) ?? details.offset;
                _playCardToBattlefield(details.data, localPos);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F131D),
                    border: Border.all(
                      color: candidateData.isNotEmpty ? GrimoireTheme.accentPurple : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Mat subtle grid pattern
                      const Center(
                        child: Text(
                          'BATTLEFIELD ZONE\nDrag cards from your hand onto the play mat',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2438),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                      // Placed battlefield cards
                      for (final card in _battlefield)
                        Positioned(
                          left: card.position.dx,
                          top: card.position.dy,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                card.position += details.delta;
                              });
                            },
                            onDoubleTap: () {
                              setState(() {
                                card.isTapped = !card.isTapped;
                              });
                            },
                            child: Transform.rotate(
                              angle: card.isTapped ? 1.5708 : 0, // 90 degrees
                              child: _buildMiniCard(card.data, isTapped: card.isTapped),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Hand Zone
          Container(
            height: 150,
            decoration: const BoxDecoration(
              color: GrimoireTheme.surfacePanel,
              border: Border(top: BorderSide(color: GrimoireTheme.borderSubtle)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Draw Deck Button
                InkWell(
                  onTap: _drawCard,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 75,
                    height: 110,
                    decoration: BoxDecoration(
                      color: GrimoireTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GrimoireTheme.accentPurple),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.layers, color: GrimoireTheme.accentPurple, size: 24),
                        SizedBox(height: 4),
                        Text('DECK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Draw', style: TextStyle(fontSize: 9, color: GrimoireTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const VerticalDivider(width: 1),
                const SizedBox(width: 16),

                // Player Hand Cards
                Expanded(
                  child: _hand.isEmpty
                      ? const Center(
                          child: Text('Hand is empty. Tap the Deck to draw cards.',
                              style: TextStyle(fontSize: 12, color: GrimoireTheme.textMuted)),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _hand.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final cardData = _hand[index];
                            return Draggable<Map<String, dynamic>>(
                              data: cardData,
                              feedback: Material(
                                color: Colors.transparent,
                                child: _buildMiniCard(cardData, elevation: 12),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: _buildMiniCard(cardData),
                              ),
                              child: _buildMiniCard(cardData),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(Map<String, dynamic> data, {bool isTapped = false, double elevation = 2}) {
    final name = data['card_name']?.toString() ?? 'Card';
    final cost = data['cost']?.toString() ?? '1';
    final atk = data['attack']?.toString() ?? '1';
    final def = data['defense']?.toString() ?? '1';
    final icon = data['icon']?.toString() ?? '🃏';

    return Container(
      width: 85,
      height: 120,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: GrimoireTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTapped ? GrimoireTheme.accentAmber : GrimoireTheme.borderStrong,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🔥$cost', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: GrimoireTheme.accentAmber)),
              Text(atk.isNotEmpty ? '$atk/$def' : '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const Spacer(),
          Center(
            child: Text(icon, style: const TextStyle(fontSize: 26)),
          ),
          const Spacer(),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
