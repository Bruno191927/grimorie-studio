import 'package:flutter/material.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../domain/models/game_balance_metrics.dart';

class CombatBalanceWidget extends StatelessWidget {
  final CombatDistribution combat;

  const CombatBalanceWidget({
    super.key,
    required this.combat,
  });

  @override
  Widget build(BuildContext context) {
    if (!combat.hasCombat) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111422),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GrimoireTheme.borderSubtle.withValues(alpha: 0.8)),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, size: 24, color: GrimoireTheme.textMuted),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estadísticas de Combate', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                  SizedBox(height: 2),
                  Text('Este juego no utiliza valores de combate (Ataque y Defensa) en sus cartas.', style: TextStyle(color: GrimoireTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final totalCombatCards = combat.offensiveCount + combat.defensiveCount + combat.balancedCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GrimoireTheme.borderSubtle.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GrimoireTheme.accentPink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GrimoireTheme.accentPink.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.sports_kabaddi, size: 16, color: GrimoireTheme.accentPink),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance de Combate (Ataque vs Defensa)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Relación ofensiva y defensiva de las cartas del mazo',
                    style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Main Stats Row
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Ataque Promedio',
                  value: combat.avgAttack.toStringAsFixed(1),
                  subtitle: 'Máximo: ${combat.maxAttack}',
                  color: const Color(0xFFF43F5E),
                  icon: Icons.flash_on,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'Defensa Promedio',
                  value: combat.avgDefense.toStringAsFixed(1),
                  subtitle: 'Máxima: ${combat.maxDefense}',
                  color: const Color(0xFF06B6D4),
                  icon: Icons.shield,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Combat Roles Bar
          const Text('Orientación Táctica de las Cartas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),

          Row(
            children: [
              if (totalCombatCards > 0 && combat.offensiveCount > 0)
                Expanded(
                  flex: combat.offensiveCount,
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF43F5E),
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                    ),
                  ),
                ),
              if (totalCombatCards > 0 && combat.balancedCount > 0)
                Expanded(
                  flex: combat.balancedCount,
                  child: Container(
                    height: 12,
                    color: const Color(0xFF10B981),
                  ),
                ),
              if (totalCombatCards > 0 && combat.defensiveCount > 0)
                Expanded(
                  flex: combat.defensiveCount,
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF06B6D4),
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                label: 'Ofensivas (ATK > DEF)',
                count: combat.offensiveCount,
                color: const Color(0xFFF43F5E),
              ),
              _buildLegendItem(
                label: 'Equilibradas (ATK = DEF)',
                count: combat.balancedCount,
                color: const Color(0xFF10B981),
              ),
              _buildLegendItem(
                label: 'Defensivas (DEF > ATK)',
                count: combat.defensiveCount,
                color: const Color(0xFF06B6D4),
              ),
              if (combat.nonCombatCount > 0)
                _buildLegendItem(
                  label: 'Sin Combate (Efectos / Leyes)',
                  count: combat.nonCombatCount,
                  color: const Color(0xFF64748B),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(width: 8),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required String label, required int count, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary)),
        Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
