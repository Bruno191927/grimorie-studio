import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../domain/models/game_balance_metrics.dart';

class CostCurveChart extends StatelessWidget {
  final List<CostBucket> buckets;
  final String? selectedCostLabel;
  final ValueChanged<String?> onCostSelected;

  const CostCurveChart({
    super.key,
    required this.buckets,
    required this.selectedCostLabel,
    required this.onCostSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Text('No hay datos de coste suficientes para graficar la curva.', style: TextStyle(color: GrimoireTheme.textMuted)),
      );
    }

    final maxCount = buckets.map((b) => b.count).fold<int>(0, math.max);
    final effectiveMax = maxCount > 0 ? maxCount : 1;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, size: 16, color: GrimoireTheme.accentPurple),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Curva de Coste de Maná / Recursos',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Distribución de cartas según su coste (Toca una barra para filtrar)',
                        style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              if (selectedCostLabel != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: GrimoireTheme.accentCyan,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.clear, size: 14),
                  label: Text('Limpiar filtro ($selectedCostLabel)', style: const TextStyle(fontSize: 11)),
                  onPressed: () => onCostSelected(null),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bucket in buckets)
                  Expanded(
                    child: _buildBar(context, bucket, effectiveMax),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, CostBucket bucket, int maxCount) {
    final isSelected = selectedCostLabel == bucket.label;
    final ratio = maxCount > 0 ? (bucket.count / maxCount).clamp(0.0, 1.0) : 0.0;
    final barHeight = 110.0 * ratio;

    return InkWell(
      onTap: () {
        if (isSelected) {
          onCostSelected(null);
        } else {
          onCostSelected(bucket.label);
        }
      },
      borderRadius: BorderRadius.circular(8),
      hoverColor: Colors.white.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Top count & percent badge
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: bucket.count > 0 ? 1.0 : 0.4,
              child: Text(
                '${bucket.count}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? GrimoireTheme.accentCyan : Colors.white,
                ),
              ),
            ),
            Text(
              '${bucket.percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? GrimoireTheme.accentCyan : GrimoireTheme.textMuted,
              ),
            ),
            const SizedBox(height: 6),

            // Bar Container with glow on selected
            Container(
              height: math.max(barHeight, bucket.count > 0 ? 8.0 : 2.0),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isSelected
                      ? [GrimoireTheme.accentCyan, const Color(0xFF67E8F9)]
                      : (bucket.count > 0
                          ? [GrimoireTheme.accentIndigo, GrimoireTheme.accentPurple]
                          : [Colors.white12, Colors.white10]),
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: GrimoireTheme.accentCyan.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ]
                    : (bucket.count > 0
                        ? [
                            BoxShadow(
                              color: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ]
                        : null),
              ),
            ),
            const SizedBox(height: 8),

            // Bottom Label (e.g. 0, 1, 2, ..., 7+)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? GrimoireTheme.accentCyan.withValues(alpha: 0.2)
                    : (bucket.label == 'Otro' ? Colors.white10 : const Color(0xFF1E2235)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? GrimoireTheme.accentCyan
                      : (bucket.count > 0 ? GrimoireTheme.borderSubtle : Colors.transparent),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bucket.label != 'Otro')
                    const Icon(Icons.diamond_outlined, size: 9, color: GrimoireTheme.accentAmber),
                  if (bucket.label != 'Otro') const SizedBox(width: 2),
                  Text(
                    bucket.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? GrimoireTheme.accentCyan : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
