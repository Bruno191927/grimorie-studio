import 'package:flutter/material.dart';
import '../models/game_balance_metrics.dart';
import '../../../editor/models/game_category.dart';

class DeckAnalyticsService {
  /// Calculates full game balance metrics and analytics for a set of card rows
  static GameBalanceMetrics calculateMetrics({
    required List<Map<String, dynamic>> rows,
    Map<String, List<GameCategory>> gameCategories = const {},
    bool respectQuantity = true,
    String selectedGame = 'all',
    String selectedStatus = 'all', // 'all', 'Definitiva', 'Muestra'
    String selectedCategory = 'all',
  }) {
    if (rows.isEmpty) {
      return GameBalanceMetrics.empty;
    }

    // 1. Filter rows according to scope
    final filteredRows = rows.where((r) {
      if (selectedGame != 'all') {
        final g = (r['game'] ?? '').toString().trim().toLowerCase();
        if (g != selectedGame.toLowerCase()) return false;
      }
      if (selectedStatus != 'all') {
        final s = (r['card_status'] ?? 'Definitiva').toString().trim().toLowerCase();
        if (s != selectedStatus.toLowerCase()) return false;
      }
      if (selectedCategory != 'all') {
        final c = (r['category'] ?? '').toString().trim().toLowerCase();
        if (c != selectedCategory.toLowerCase()) return false;
      }
      return true;
    }).toList();

    if (filteredRows.isEmpty) {
      return GameBalanceMetrics.empty;
    }

    // 2. Count weights and totals
    int totalCards = 0;
    final rowWeights = <Map<String, dynamic>, int>{};

    for (final r in filteredRows) {
      final qty = respectQuantity ? (int.tryParse(r['qty']?.toString() ?? '1') ?? 1).clamp(1, 999) : 1;
      rowWeights[r] = qty;
      totalCards += qty;
    }

    final uniqueCards = filteredRows.length;

    // 3. Cost buckets & Mana Curve
    final bucketCards = <String, List<Map<String, dynamic>>>{
      '0': [],
      '1': [],
      '2': [],
      '3': [],
      '4': [],
      '5': [],
      '6': [],
      '7+': [],
      'Otro': [],
    };
    final bucketCounts = <String, int>{
      '0': 0,
      '1': 0,
      '2': 0,
      '3': 0,
      '4': 0,
      '5': 0,
      '6': 0,
      '7+': 0,
      'Otro': 0,
    };
    final bucketCatCounts = <String, Map<String, int>>{
      for (final k in bucketCards.keys) k: {},
    };

    double totalCostSum = 0;
    int numericCostCards = 0;

    for (final r in filteredRows) {
      final weight = rowWeights[r]!;
      final rawCost = (r['cost'] ?? '').toString().trim();
      final numCost = num.tryParse(rawCost);
      final cat = (r['category'] ?? 'General').toString().trim();

      String bucketKey;
      if (numCost != null) {
        totalCostSum += numCost * weight;
        numericCostCards += weight;
        final intCost = numCost.toInt();
        if (intCost <= 0) {
          bucketKey = '0';
        } else if (intCost >= 7) {
          bucketKey = '7+';
        } else {
          bucketKey = '$intCost';
        }
      } else {
        bucketKey = 'Otro';
      }

      bucketCards[bucketKey]!.add(r);
      bucketCounts[bucketKey] = (bucketCounts[bucketKey] ?? 0) + weight;
      bucketCatCounts[bucketKey]![cat] = (bucketCatCounts[bucketKey]![cat] ?? 0) + weight;
    }

    final hasNumericCost = numericCostCards > 0;
    final avgCost = hasNumericCost ? totalCostSum / numericCostCards : 0.0;

    final costBuckets = <CostBucket>[];
    for (final entry in bucketCounts.entries) {
      final count = entry.value;
      if (count > 0 || (hasNumericCost && entry.key != 'Otro')) {
        costBuckets.add(CostBucket(
          label: entry.key,
          count: count,
          percentage: totalCards > 0 ? (count / totalCards) * 100 : 0.0,
          cards: bucketCards[entry.key] ?? [],
          categoryCounts: bucketCatCounts[entry.key] ?? {},
        ));
      }
    }

    // 4. Category Metrics
    final categoryTotals = <String, int>{};
    final categoryCostSums = <String, double>{};
    final categoryNumericCounts = <String, int>{};
    final categoryColors = <String, int>{};
    final categoryIcons = <String, String>{};

    // Pre-seed known categories from models
    for (final catList in gameCategories.values) {
      for (final cat in catList) {
        categoryColors[cat.name.toLowerCase()] = cat.defaultColor;
        categoryIcons[cat.name.toLowerCase()] = cat.icon;
      }
    }

    for (final r in filteredRows) {
      final weight = rowWeights[r]!;
      final cat = (r['category'] ?? 'General').toString().trim();
      final catLower = cat.toLowerCase();
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + weight;

      final numCost = num.tryParse((r['cost'] ?? '').toString().trim());
      if (numCost != null) {
        categoryCostSums[cat] = (categoryCostSums[cat] ?? 0) + (numCost * weight);
        categoryNumericCounts[cat] = (categoryNumericCounts[cat] ?? 0) + weight;
      }

      if (!categoryColors.containsKey(catLower) && r['art_color'] is int) {
        categoryColors[catLower] = r['art_color'] as int;
      }
      if (!categoryIcons.containsKey(catLower) && r['icon'] != null) {
        categoryIcons[catLower] = r['icon'].toString();
      }
    }

    final categoryMetrics = categoryTotals.entries.map((entry) {
      final cat = entry.key;
      final count = entry.value;
      final numCount = categoryNumericCounts[cat] ?? 0;
      final avgC = numCount > 0 ? (categoryCostSums[cat] ?? 0) / numCount : 0.0;
      final color = categoryColors[cat.toLowerCase()] ?? 0xFF7C3AED;
      final icon = categoryIcons[cat.toLowerCase()] ?? '🃏';

      return CategoryMetric(
        name: cat,
        count: count,
        percentage: totalCards > 0 ? (count / totalCards) * 100 : 0.0,
        color: color,
        avgCost: avgC,
        icon: icon,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // 5. Rarity Metrics
    final rarityTotals = <String, int>{};
    for (final r in filteredRows) {
      final weight = rowWeights[r]!;
      final rarity = (r['rarity'] ?? 'Común').toString().trim();
      if (rarity.isNotEmpty) {
        rarityTotals[rarity] = (rarityTotals[rarity] ?? 0) + weight;
      }
    }

    Color resolveRarityColor(String r) {
      final s = r.toLowerCase();
      if (s.contains('mít') || s.contains('mit') || s.contains('legend')) return const Color(0xFFEC4899);
      if (s.contains('épic') || s.contains('epic')) return const Color(0xFFF59E0B);
      if (s.contains('rar')) return const Color(0xFF8B5CF6);
      if (s.contains('poco') || s.contains('uncommon')) return const Color(0xFF3B82F6);
      return const Color(0xFF64748B);
    }

    final rarityMetrics = rarityTotals.entries.map((e) {
      return RarityMetric(
        rarity: e.key,
        count: e.value,
        percentage: totalCards > 0 ? (e.value / totalCards) * 100 : 0.0,
        color: resolveRarityColor(e.key),
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // 6. Type Metrics
    final typeTotals = <String, int>{};
    for (final r in filteredRows) {
      final weight = rowWeights[r]!;
      final type = (r['type'] ?? 'Carta Normal').toString().trim();
      if (type.isNotEmpty) {
        typeTotals[type] = (typeTotals[type] ?? 0) + weight;
      }
    }

    final typeMetrics = typeTotals.entries.map((e) {
      return TypeMetric(
        type: e.key,
        count: e.value,
        percentage: totalCards > 0 ? (e.value / totalCards) * 100 : 0.0,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // 7. Combat Balance (Attack & Defense)
    bool hasCombat = false;
    double totalAttack = 0;
    double totalDefense = 0;
    int combatCardsCount = 0;
    int maxAtk = 0;
    int maxDef = 0;
    int offensiveCount = 0;
    int defensiveCount = 0;
    int balancedCount = 0;
    int nonCombatCount = 0;

    for (final r in filteredRows) {
      final weight = rowWeights[r]!;
      final atkRaw = (r['attack'] ?? '').toString().trim();
      final defRaw = (r['defense'] ?? '').toString().trim();
      final atk = int.tryParse(atkRaw);
      final def = int.tryParse(defRaw);

      if (atk != null || def != null) {
        hasCombat = true;
        final a = atk ?? 0;
        final d = def ?? 0;
        totalAttack += a * weight;
        totalDefense += d * weight;
        combatCardsCount += weight;
        if (a > maxAtk) maxAtk = a;
        if (d > maxDef) maxDef = d;

        if (a > d) {
          offensiveCount += weight;
        } else if (d > a) {
          defensiveCount += weight;
        } else {
          balancedCount += weight;
        }
      } else {
        nonCombatCount += weight;
      }
    }

    final combat = CombatDistribution(
      hasCombat: hasCombat,
      avgAttack: combatCardsCount > 0 ? totalAttack / combatCardsCount : 0.0,
      avgDefense: combatCardsCount > 0 ? totalDefense / combatCardsCount : 0.0,
      maxAttack: maxAtk,
      maxDefense: maxDef,
      offensiveCount: offensiveCount,
      defensiveCount: defensiveCount,
      balancedCount: balancedCount,
      nonCombatCount: nonCombatCount,
    );

    // 8. Curve Diagnosis & Tempo Archetype
    String peakCost = '-';
    int maxBucketCount = -1;
    for (final b in costBuckets) {
      if (b.label != 'Otro' && b.count > maxBucketCount) {
        maxBucketCount = b.count;
        peakCost = b.label;
      }
    }

    String archetype = 'Personalizado';
    String summary = 'Distribución sin curva estándar.';
    final recommendations = <String>[];

    if (hasNumericCost) {
      final peakNum = int.tryParse(peakCost) ?? 2;
      final lowCostCount = (bucketCounts['0'] ?? 0) + (bucketCounts['1'] ?? 0) + (bucketCounts['2'] ?? 0);
      final highCostCount = (bucketCounts['5'] ?? 0) + (bucketCounts['6'] ?? 0) + (bucketCounts['7+'] ?? 0);
      final lowCostRatio = totalCards > 0 ? lowCostCount / totalCards : 0.0;
      final highCostRatio = totalCards > 0 ? highCostCount / totalCards : 0.0;

      if (peakNum <= 2 && avgCost < 2.6) {
        archetype = 'Agresivo / Rápido (Aggro)';
        summary = 'Curva muy baja enfocada en jugadas tempranas rápidas y saturación del tablero.';
      } else if (avgCost >= 2.6 && avgCost <= 3.7 && (peakNum == 2 || peakNum == 3)) {
        archetype = 'Equilibrado / Midrange';
        summary = 'Curva en campana ideal con desarrollo progresivo de juego inicial a medio.';
      } else {
        archetype = 'Control / Tardío (Late Game)';
        summary = 'Curva pesada orientada a cartas de alto impacto y juego tardío.';
      }

      if (lowCostRatio < 0.25) {
        recommendations.add('⚠️ Pocos costes iniciales (solo ${(lowCostRatio * 100).toStringAsFixed(0)}% cuestan ≤2). Podrías quedarte sin jugadas en los primeros turnos.');
      } else if (lowCostRatio >= 0.40) {
        recommendations.add('⚡ Excelente consistencia de apertura: ${(lowCostRatio * 100).toStringAsFixed(0)}% de cartas de coste temprano.');
      }

      if (highCostRatio > 0.30) {
        recommendations.add('⚠️ Posible atasco de mano: ${(highCostRatio * 100).toStringAsFixed(0)}% del mazo cuesta 5 o más.');
      }

      if (hasCombat && combat.offensiveCount > (combat.defensiveCount * 2)) {
        recommendations.add('⚔️ Mazo altamente ofensivo: Más del doble de cartas con Ataque > Defensa.');
      } else if (hasCombat && combat.defensiveCount > (combat.offensiveCount * 2)) {
        recommendations.add('🛡️ Mazo defensivo / Muralla: Predominan cartas con mayor Defensa.');
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add(' Balance general óptimo según la cantidad de cartas analizadas.');
    }

    final diagnosis = CurveDiagnosis(
      archetype: archetype,
      peakCost: peakCost,
      summary: summary,
      recommendations: recommendations,
    );

    // 9. Anomalies and Outliers Detection
    final anomalies = <CardAnomaly>[];

    for (final r in filteredRows) {
      final name = (r['card_name'] ?? 'Sin nombre').toString();
      final numCost = num.tryParse((r['cost'] ?? '').toString().trim());
      final atk = int.tryParse((r['attack'] ?? '').toString().trim());
      final def = int.tryParse((r['defense'] ?? '').toString().trim());
      final rules = (r['rules_text'] ?? r['rules'] ?? '').toString().trim();

      // Check for OP stats at low cost
      if (numCost != null && numCost <= 2 && atk != null && def != null) {
        if ((atk + def) >= 8) {
          anomalies.add(CardAnomaly(
            card: r,
            type: AnomalyType.overpowered,
            title: 'Potencialmente Muy Fuerte (Overpowered)',
            description: '"$name" tiene coste bajo ($numCost) pero suma ${atk + def} de estadísticas ($atk ATK / $def DEF).',
            severity: AnomalySeverity.alert,
          ));
        }
      }

      // Check for underpowered high cost cards
      if (numCost != null && numCost >= 5 && atk != null && def != null) {
        if ((atk + def) <= 3 && rules.length < 15) {
          anomalies.add(CardAnomaly(
            card: r,
            type: AnomalyType.underpowered,
            title: 'Posiblemente Infrabalanceada (Muy Débil)',
            description: '"$name" cuesta $numCost pero solo ofrece ${atk + def} de stats ($atk ATK / $def DEF) y poco o ningún efecto.',
            severity: AnomalySeverity.warning,
          ));
        }
      }

      // Check for cards with 0 rules
      if (rules.isEmpty && (numCost == null || numCost > 2) && atk == null && def == null) {
        anomalies.add(CardAnomaly(
          card: r,
          type: AnomalyType.missingRules,
          title: 'Carta Sin Efecto o Reglas',
          description: '"$name" no cuenta con texto de reglas ni estadísticas de combate.',
          severity: AnomalySeverity.info,
        ));
      }
    }

    return GameBalanceMetrics(
      totalCards: totalCards,
      uniqueCards: uniqueCards,
      avgCost: avgCost,
      hasNumericCost: hasNumericCost,
      costBuckets: costBuckets,
      categoryMetrics: categoryMetrics,
      rarityMetrics: rarityMetrics,
      typeMetrics: typeMetrics,
      combat: combat,
      diagnosis: diagnosis,
      anomalies: anomalies,
    );
  }
}
