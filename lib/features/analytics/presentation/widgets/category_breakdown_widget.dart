import 'package:flutter/material.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../domain/models/game_balance_metrics.dart';

class CategoryBreakdownWidget extends StatelessWidget {
  final List<CategoryMetric> categoryMetrics;
  final List<RarityMetric> rarityMetrics;
  final List<TypeMetric> typeMetrics;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  const CategoryBreakdownWidget({
    super.key,
    required this.categoryMetrics,
    required this.rarityMetrics,
    required this.typeMetrics,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
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
                      color: GrimoireTheme.accentIndigo.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.category_outlined, size: 16, color: GrimoireTheme.accentIndigo),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Distribución de Categorías y Arquetipos',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              if (selectedCategory != null && selectedCategory != 'all')
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: GrimoireTheme.accentCyan,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.clear, size: 14),
                  label: Text('Limpiar filtro ($selectedCategory)', style: const TextStyle(fontSize: 11)),
                  onPressed: () => onCategorySelected(null),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Categories List
          if (categoryMetrics.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No hay categorías registradas en el juego.', style: TextStyle(color: GrimoireTheme.textMuted, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categoryMetrics.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final cat = categoryMetrics[idx];
                final isSelected = selectedCategory?.toLowerCase() == cat.name.toLowerCase();
                final catColor = Color(cat.color);

                return InkWell(
                  onTap: () {
                    if (isSelected) {
                      onCategorySelected(null);
                    } else {
                      onCategorySelected(cat.name);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? GrimoireTheme.accentIndigo.withValues(alpha: 0.2)
                          : const Color(0xFF161928),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? GrimoireTheme.accentIndigo
                            : GrimoireTheme.borderSubtle.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(cat.icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            if (cat.avgCost > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Coste Prom: ${cat.avgCost.toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 10, color: GrimoireTheme.textSecondary),
                                ),
                              ),
                            Text(
                              '${cat.count} (${cat.percentage.toStringAsFixed(0)}%)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? GrimoireTheme.accentIndigo : GrimoireTheme.accentCyan,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Proportion Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: cat.percentage / 100.0,
                            minHeight: 4,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(catColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          if (rarityMetrics.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: GrimoireTheme.borderSubtle, height: 1),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.workspace_premium_outlined, size: 15, color: GrimoireTheme.accentAmber),
                SizedBox(width: 8),
                Text(
                  'Distribución de Rarezas',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in rarityMetrics)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: r.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: r.color.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: r.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${r.rarity}: ${r.count} (${r.percentage.toStringAsFixed(0)}%)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: r.color),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
