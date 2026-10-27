import 'package:flutter/material.dart';

enum AnomalyType {
  overpowered,
  underpowered,
  missingRules,
  statAnomaly,
}

enum AnomalySeverity {
  info,
  warning,
  alert,
}

class CostBucket {
  final String label;
  final int count;
  final double percentage;
  final List<Map<String, dynamic>> cards;
  final Map<String, int> categoryCounts;

  const CostBucket({
    required this.label,
    required this.count,
    required this.percentage,
    required this.cards,
    this.categoryCounts = const {},
  });
}

class CategoryMetric {
  final String name;
  final int count;
  final double percentage;
  final int color;
  final double avgCost;
  final String icon;

  const CategoryMetric({
    required this.name,
    required this.count,
    required this.percentage,
    required this.color,
    required this.avgCost,
    this.icon = '🃏',
  });
}

class RarityMetric {
  final String rarity;
  final int count;
  final double percentage;
  final Color color;

  const RarityMetric({
    required this.rarity,
    required this.count,
    required this.percentage,
    required this.color,
  });
}

class TypeMetric {
  final String type;
  final int count;
  final double percentage;

  const TypeMetric({
    required this.type,
    required this.count,
    required this.percentage,
  });
}

class CombatDistribution {
  final bool hasCombat;
  final double avgAttack;
  final double avgDefense;
  final int maxAttack;
  final int maxDefense;
  final int offensiveCount;
  final int defensiveCount;
  final int balancedCount;
  final int nonCombatCount;

  const CombatDistribution({
    required this.hasCombat,
    required this.avgAttack,
    required this.avgDefense,
    required this.maxAttack,
    required this.maxDefense,
    required this.offensiveCount,
    required this.defensiveCount,
    required this.balancedCount,
    required this.nonCombatCount,
  });

  static const empty = CombatDistribution(
    hasCombat: false,
    avgAttack: 0,
    avgDefense: 0,
    maxAttack: 0,
    maxDefense: 0,
    offensiveCount: 0,
    defensiveCount: 0,
    balancedCount: 0,
    nonCombatCount: 0,
  );
}

class CardAnomaly {
  final Map<String, dynamic> card;
  final AnomalyType type;
  final String title;
  final String description;
  final AnomalySeverity severity;

  const CardAnomaly({
    required this.card,
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
  });
}

class CurveDiagnosis {
  final String archetype;
  final String peakCost;
  final String summary;
  final List<String> recommendations;

  const CurveDiagnosis({
    required this.archetype,
    required this.peakCost,
    required this.summary,
    required this.recommendations,
  });

  static const empty = CurveDiagnosis(
    archetype: 'Indefinido',
    peakCost: '-',
    summary: 'No hay suficientes cartas para calcular el ritmo de la curva.',
    recommendations: [],
  );
}

class GameBalanceMetrics {
  final int totalCards;
  final int uniqueCards;
  final double avgCost;
  final bool hasNumericCost;
  final List<CostBucket> costBuckets;
  final List<CategoryMetric> categoryMetrics;
  final List<RarityMetric> rarityMetrics;
  final List<TypeMetric> typeMetrics;
  final CombatDistribution combat;
  final CurveDiagnosis diagnosis;
  final List<CardAnomaly> anomalies;

  const GameBalanceMetrics({
    required this.totalCards,
    required this.uniqueCards,
    required this.avgCost,
    required this.hasNumericCost,
    required this.costBuckets,
    required this.categoryMetrics,
    required this.rarityMetrics,
    required this.typeMetrics,
    required this.combat,
    required this.diagnosis,
    required this.anomalies,
  });

  static const empty = GameBalanceMetrics(
    totalCards: 0,
    uniqueCards: 0,
    avgCost: 0,
    hasNumericCost: false,
    costBuckets: [],
    categoryMetrics: [],
    rarityMetrics: [],
    typeMetrics: [],
    combat: CombatDistribution.empty,
    diagnosis: CurveDiagnosis.empty,
    anomalies: [],
  );
}
