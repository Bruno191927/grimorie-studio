import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/analytics/domain/services/deck_analytics_service.dart';
import 'package:grimoire_studio/features/analytics/presentation/screens/game_balance_dashboard.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';

void main() {
  final sampleCards = [
      {
        'card_name': 'Duende Rápido',
        'game': 'Fantasy',
        'category': 'Criatura',
        'cost': '1',
        'attack': '2',
        'defense': '1',
        'qty': '3',
        'card_status': 'Definitiva',
        'rules_text': 'Ataque rápido.',
      },
      {
        'card_name': 'Muro de Piedra',
        'game': 'Fantasy',
        'category': 'Defensa',
        'cost': '2',
        'attack': '0',
        'defense': '5',
        'qty': '2',
        'card_status': 'Definitiva',
        'rules_text': 'Defensor.',
      },
      {
        'card_name': 'Dragón Titánico',
        'game': 'Fantasy',
        'category': 'Criatura',
        'cost': '6',
        'attack': '7',
        'defense': '7',
        'qty': '1',
        'card_status': 'Definitiva',
        'rules_text': 'Vuela y arrolla.',
      },
      {
        'card_name': 'Gólem Prohibido (OP)',
        'game': 'Fantasy',
        'category': 'Criatura',
        'cost': '1',
        'attack': '5',
        'defense': '4',
        'qty': '1',
        'card_status': 'Definitiva',
        'rules_text': 'Poder desmedido.',
      },
      {
        'card_name': 'Carta de Prueba Plantilla',
        'game': 'Fantasy',
        'category': 'Muestra',
        'cost': '0',
        'qty': '1',
        'card_status': 'Muestra',
        'rules_text': 'Demo.',
      },
    ];

  group('DeckAnalyticsService Tests', () {
    test('Computes totals respecting quantity multiplier', () {
      final metrics = DeckAnalyticsService.calculateMetrics(
        rows: sampleCards,
        selectedGame: 'Fantasy',
        selectedStatus: 'Definitiva',
        respectQuantity: true,
      );

      // Duende: 3, Muro: 2, Dragón: 1, Gólem: 1 = 7 total cards, 4 unique
      expect(metrics.totalCards, 7);
      expect(metrics.uniqueCards, 4);
    });

    test('Computes Mana Curve and Cost Buckets correctly', () {
      final metrics = DeckAnalyticsService.calculateMetrics(
        rows: sampleCards,
        selectedGame: 'Fantasy',
        selectedStatus: 'Definitiva',
        respectQuantity: true,
      );

      expect(metrics.hasNumericCost, isTrue);
      // Cost 1: 3 Duendes + 1 Golem = 4 cards
      final cost1 = metrics.costBuckets.firstWhere((b) => b.label == '1');
      expect(cost1.count, 4);

      // Cost 2: 2 Muros = 2 cards
      final cost2 = metrics.costBuckets.firstWhere((b) => b.label == '2');
      expect(cost2.count, 2);

      // Peak cost should be 1
      expect(metrics.diagnosis.peakCost, '1');
      expect(metrics.diagnosis.archetype, contains('Agresivo'));
    });

    test('Computes Combat Balance correctly', () {
      final metrics = DeckAnalyticsService.calculateMetrics(
        rows: sampleCards,
        selectedGame: 'Fantasy',
        selectedStatus: 'Definitiva',
        respectQuantity: true,
      );

      expect(metrics.combat.hasCombat, isTrue);
      expect(metrics.combat.maxAttack, 7);
      expect(metrics.combat.maxDefense, 7);
      // Duende (2 > 1): 3 offensive, Golem (5 > 4): 1 offensive = 4 offensive
      expect(metrics.combat.offensiveCount, 4);
      // Muro (0 < 5): 2 defensive
      expect(metrics.combat.defensiveCount, 2);
      // Dragon (7 == 7): 1 balanced
      expect(metrics.combat.balancedCount, 1);
    });

    test('Detects balance anomalies properly', () {
      final metrics = DeckAnalyticsService.calculateMetrics(
        rows: sampleCards,
        selectedGame: 'Fantasy',
        selectedStatus: 'Definitiva',
      );

      // Golem Prohibido costs 1 with 5 ATK + 4 DEF (sum = 9 >= 8) -> Overpowered
      final opAnomalies = metrics.anomalies.where((a) => a.title.contains('Overpowered')).toList();
      expect(opAnomalies, isNotEmpty);
      expect(opAnomalies.first.card['card_name'], 'Gólem Prohibido (OP)');
    });
  });

  testWidgets('GameBalanceDashboard renders properly and displays KPI cards', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    for (final card in sampleCards) {
      container.read(editorProvider.notifier).addRow(card);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GameBalanceDashboard(
            onOpenEditor: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify main header and KPIs are rendered
    expect(find.text('Analítica y Balance del Mazo'), findsOneWidget);
    expect(find.text('Total en Mazo'), findsOneWidget);
    expect(find.text('Coste Promedio'), findsOneWidget);
    expect(find.text('Balance de Combate'), findsWidgets);
    expect(find.text('Curva de Coste de Maná / Recursos'), findsOneWidget);
  });
}
