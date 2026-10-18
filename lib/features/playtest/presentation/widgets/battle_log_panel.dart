import 'package:flutter/material.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';
import '../../models/playtest_models.dart';

class BattleLogPanel extends StatefulWidget {
  final List<BattleLogEntry> logs;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const BattleLogPanel({
    super.key,
    required this.logs,
    required this.onClear,
    required this.onClose,
  });

  @override
  State<BattleLogPanel> createState() => _BattleLogPanelState();
}

class _BattleLogPanelState extends State<BattleLogPanel> {
  BattleLogType? _selectedFilter;

  IconData _getIconForType(BattleLogType type) {
    switch (type) {
      case BattleLogType.turn:
        return Icons.refresh;
      case BattleLogType.draw:
        return Icons.pan_tool_alt;
      case BattleLogType.play:
        return Icons.style;
      case BattleLogType.combat:
        return Icons.sports_martial_arts;
      case BattleLogType.dice:
        return Icons.casino;
      case BattleLogType.life:
        return Icons.favorite;
      case BattleLogType.token:
        return Icons.toll;
      case BattleLogType.general:
        return Icons.history;
    }
  }

  Color _getColorForType(BattleLogType type) {
    switch (type) {
      case BattleLogType.turn:
        return GrimoireTheme.accentPurple;
      case BattleLogType.draw:
        return const Color(0xFF38BDF8);
      case BattleLogType.play:
        return const Color(0xFFF59E0B);
      case BattleLogType.combat:
        return const Color(0xFFDC2626);
      case BattleLogType.dice:
        return GrimoireTheme.accentEmerald;
      case BattleLogType.life:
        return GrimoireTheme.accentPink;
      case BattleLogType.token:
        return const Color(0xFFEAB308);
      case BattleLogType.general:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _selectedFilter == null
        ? widget.logs
        : widget.logs.where((l) => l.type == _selectedFilter).toList();

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF10121C),
        border: Border(left: BorderSide(color: GrimoireTheme.borderSubtle)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: GrimoireTheme.surfacePanel,
              border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_edu, color: GrimoireTheme.accentPurple, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Registro de Partida',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: GrimoireTheme.textMuted),
                      tooltip: 'Limpiar Registro',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onClear,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: GrimoireTheme.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters Row
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF0C0E17),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('Todos', null),
                _buildFilterChip('Turnos', BattleLogType.turn),
                _buildFilterChip('Dados', BattleLogType.dice),
                _buildFilterChip('Jugadas', BattleLogType.play),
                _buildFilterChip('Vida', BattleLogType.life),
                _buildFilterChip('Fichas', BattleLogType.token),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: filteredLogs.isEmpty
                ? const Center(
                    child: Text('Sin acciones registradas aún.',
                        style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                  )
                : ListView.builder(
                    reverse: true, // Show newest at the bottom or top
                    padding: const EdgeInsets.all(10),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final item = filteredLogs[filteredLogs.length - 1 - index];
                      final color = _getColorForType(item.type);
                      final icon = _getIconForType(item.type);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF171926),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, size: 11, color: color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (item.player != 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: item.player == 1
                                                ? GrimoireTheme.accentPurple.withValues(alpha: 0.3)
                                                : const Color(0xFF06B6D4).withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'J${item.player}',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              color: item.player == 1 ? const Color(0xFFE9D5FF) : const Color(0xFFCFFAFE),
                                            ),
                                          ),
                                        ),
                                      Text(item.formattedTime,
                                          style: const TextStyle(fontSize: 9, color: GrimoireTheme.textMuted)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.message,
                                    style: const TextStyle(fontSize: 11, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, BattleLogType? type) {
    final isSelected = _selectedFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 10)),
        selected: isSelected,
        selectedColor: GrimoireTheme.accentPurple.withValues(alpha: 0.4),
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        onSelected: (_) => setState(() => _selectedFilter = type),
      ),
    );
  }
}
