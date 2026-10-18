import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/widgets/inspector_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Game & Category Default Model Tests', () {
    test('markActiveCardAsGameDefault sets default card and new cards inherit its template and styling', () {
      final container = ProviderContainer();
      final notifier = container.read(editorProvider.notifier);

      // Add a game card
      notifier.addCardToGame('policritics', cardName: 'Carta Base Policritics', type: 'Guardián', artColor: 0xFFFF5722);
      final rows1 = container.read(editorProvider).project.rows;
      final cardIndex = rows1.length - 1;
      notifier.setActiveRow(cardIndex);

      // Mark as game default
      notifier.markActiveCardAsGameDefault();

      final updatedRows = container.read(editorProvider).project.rows;
      expect(notifier.isRowGameDefault(updatedRows[cardIndex]), isTrue);

      // Create a second card in policritics
      notifier.addCardToGame('policritics', cardName: 'Segunda Carta');
      final rows2 = container.read(editorProvider).project.rows;
      final secondCard = rows2.last;

      expect(secondCard['card_name'], equals('Segunda Carta'));
      expect(secondCard['game'], equals('policritics'));
      // Inherits art_color and type from the game default model
      expect(secondCard['art_color'], equals(0xFFFF5722));
      expect(secondCard['type'], equals('Guardián'));
    });

    test('markActiveCardAsCategoryDefault sets default card and new category cards inherit it', () {
      final container = ProviderContainer();
      final notifier = container.read(editorProvider.notifier);

      // Create category
      const testCat = GameCategory(
        id: 'cat_armas',
        name: 'Armas',
        icon: '⚔️',
        defaultType: 'Arma',
        defaultColor: 0xFF10B981,
      );
      notifier.addCategoryToGame('policritics', testCat, createDefaultCard: true);

      // Check that category default card was automatically created
      final rows = container.read(editorProvider).project.rows;
      final catModel = rows.firstWhere((r) => r['game'] == 'policritics' && r['category'] == 'Armas');
      expect(catModel, isNotNull);
      expect(notifier.isRowCategoryDefault(catModel), isTrue);

      // Add a card of category Armas
      notifier.addCardToGame('policritics', cardName: 'Espada de Fuego', category: 'Armas');
      final rowsAfter = container.read(editorProvider).project.rows;
      final espada = rowsAfter.last;

      expect(espada['card_name'], equals('Espada de Fuego'));
      expect(espada['category'], equals('Armas'));
      expect(espada['type'], equals('Arma'));
      expect(espada['icon'], equals('⚔️'));
    });

    testWidgets('InspectorPanel displays default model buttons and allows marking as default', (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(editorProvider.notifier);

      notifier.addCardToGame('policritics', cardName: 'Mi Carta Especial', category: 'Criaturas');
      final rows = container.read(editorProvider).project.rows;
      notifier.setActiveRow(rows.length - 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: InspectorPanel(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Modelos Predefinidos'), findsOneWidget);
      expect(find.byKey(const Key('btn_mark_game_default')), findsOneWidget);
      expect(find.byKey(const Key('btn_mark_category_default')), findsOneWidget);

      // Tap mark as game default
      await tester.tap(find.byKey(const Key('btn_mark_game_default')));
      await tester.pumpAndSettle();

      expect(find.text('Predefinida para policritics'), findsOneWidget);
    });
  });
}
