import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/screens/editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Flexible Category Models & Canvas Editor Integration', () {
    test('GameCategory supports selective mechanics (cost, combat, rarity, custom fields)', () {
      const partyCategory = GameCategory(
        id: 'cat-party',
        name: 'Cartas de Desafío',
        icon: '🎲',
        defaultType: 'Desafío',
        defaultColor: 0xFF10B981,
        hasCost: false,
        hasCombatStats: false,
        hasRarity: true,
        defaultRarity: 'Especial',
        hasRules: true,
        defaultRules: 'Realiza el reto antes de que termine el temporizador.',
        customFields: {
          'dificultad': 'Media',
          'tiempo_seg': '30',
        },
      );

      final json = partyCategory.toJson();
      expect(json['hasCost'], isFalse);
      expect(json['hasCombatStats'], isFalse);
      expect(json['hasRarity'], isTrue);
      expect(json['customFields']['dificultad'], equals('Media'));

      final fromJson = GameCategory.fromJson(json);
      expect(fromJson.hasCost, isFalse);
      expect(fromJson.hasCombatStats, isFalse);
      expect(fromJson.customFields['tiempo_seg'], equals('30'));
    });

    test('createCardFromCategory respects enabled/disabled flags and custom fields', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      const customCat = GameCategory(
        id: 'cat-neigh-custom',
        name: 'Relincho Avanzado',
        icon: '🛑',
        hasCost: false,
        hasCombatStats: false,
        hasRarity: false,
        hasRules: true,
        defaultRules: 'Cancela una jugada sin costo alguno.',
        customFields: {'inmune': 'true', 'elemento': 'Caos'},
      );

      notifier.createCardFromCategory('Unstable Unicorns', customCat, cardName: 'Súper Relincho');

      final cards = container.read(editorProvider).project.rows;
      final created = cards.firstWhere((c) => c['card_name'] == 'Súper Relincho');

      expect(created['cost'], equals(''));
      expect(created['attack'], equals(''));
      expect(created['defense'], equals(''));
      expect(created['rarity'], equals(''));
      expect(created['rules_text'], equals('Cancela una jugada sin costo alguno.'));
      expect(created['inmune'], equals('true'));
      expect(created['elemento'], equals('Caos'));
    });

    test('setCategoryForActiveCard and applyCategoryModelToActiveCard update active card', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      expect(container.read(editorProvider).project.rows.isNotEmpty, isTrue);

      // Change category of active card to 'Instantáneos' (active card is Magic)
      notifier.setCategoryForActiveCard('Instantáneos');
      expect(container.read(editorProvider).project.activeRow['category'], equals('Instantáneos'));
      expect(container.read(editorProvider).project.activeRow['icon'], equals('⚡'));

      // Apply category model
      final instantCat = notifier.getCategoriesForGame('Magic').firstWhere((c) => c.name == 'Instantáneos');
      notifier.applyCategoryModelToActiveCard(instantCat);

      final active = container.read(editorProvider).project.activeRow;
      expect(active['category'], equals('Instantáneos'));
      expect(active['type'], equals('Instantáneo'));
    });

    testWidgets('EditorScreen displays active card and category in subtoolbar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: EditorScreen(repaintBoundaryKey: GlobalKey()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check category label exists in toolbar
      expect(find.text('Categoría:'), findsOneWidget);

      // Verify active card dropdown is present
      expect(find.text('Carta Activa:'), findsOneWidget);
    });
  });
}
