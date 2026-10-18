import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/main.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GameCategory unit test: Unstable Unicorns base categories and card creation', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(editorProvider.notifier);
    notifier.restoreSampleGames();
    final unicornCategories = notifier.getCategoriesForGame('Unstable Unicorns');

    // 1. Verify Unstable Unicorns has requested categories
    final initialCount = unicornCategories.length;
    final catNames = unicornCategories.map((c) => c.name).toList();
    expect(catNames, contains('Unicornios'));
    expect(catNames, contains('Cartas de Mejora'));
    expect(catNames, contains('Cartas de Degradación'));
    expect(catNames, contains('Cartas de Magia'));
    expect(catNames, contains('Cartas de ¡Neigh! (Relincho)'));

    // 2. Generate a new card from the "Unicornios" category
    final unicornCat = unicornCategories.firstWhere((c) => c.name == 'Unicornios');
    notifier.createCardFromCategory('Unstable Unicorns', unicornCat, cardName: 'Unicornio Estelar');

    final rows = container.read(editorProvider).project.rows;
    final createdCard = rows.firstWhere((r) => r['card_name'] == 'Unicornio Estelar');
    expect(createdCard['game'], equals('Unstable Unicorns'));
    expect(createdCard['category'], equals('Unicornios'));
    expect(createdCard['icon'], equals('🦄'));
    expect(createdCard['type'], equals('Unicornio Mágico'));

    // 3. Add a new custom category to Unstable Unicorns
    final newCat = GameCategory(
      id: 'cat_dragons',
      name: 'Unicornios Dragón',
      icon: '🐉',
      defaultType: 'Unicornio Dragón Legendario',
      defaultColor: 0xFFEF4444,
      defaultRules: 'Inmune a cartas de Degradación.',
    );
    notifier.addCategoryToGame('Unstable Unicorns', newCat);

    final updatedCats = notifier.getCategoriesForGame('Unstable Unicorns');
    expect(updatedCats.length, equals(initialCount + 1));
    expect(updatedCats.any((c) => c.name == 'Unicornios Dragón'), isTrue);

    // 4. Generate card from new custom category
    notifier.createCardFromCategory('Unstable Unicorns', newCat, cardName: 'Dragón Brillante');
    final rowsAfter = container.read(editorProvider).project.rows;
    final dragonCard = rowsAfter.firstWhere((r) => r['card_name'] == 'Dragón Brillante');
    expect(dragonCard['icon'], equals('🐉'));
    expect(dragonCard['category'], equals('Unicornios Dragón'));
    expect(dragonCard['rules'], equals('Inmune a cartas de Degradación.'));

    // 5. Delete card and category from game
    final dragonIdx = container.read(editorProvider).project.rows.indexWhere((r) => r['card_name'] == 'Dragón Brillante');
    if (dragonIdx != -1) {
      notifier.removeRow(dragonIdx);
    }
    notifier.deleteCategoryFromGame('Unstable Unicorns', 'Unicornios Dragón');
    expect(notifier.getCategoriesForGame('Unstable Unicorns').length, equals(initialCount));
  });

  testWidgets('Unstable Unicorns game exists with cards, custom template, and playtest integration', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: GrimoireApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Initial state is empty; restore sample games to test
    if (find.text('Restaurar Juegos de Ejemplo').evaluate().isNotEmpty) {
      await tester.tap(find.text('Restaurar Juegos de Ejemplo'));
      await tester.pumpAndSettle();
    }

    // 1. Verify Unstable Unicorns Game Pill is present in Gallery sub-header
    final unicornGamePill = find.text('Unstable Unicorns');
    expect(unicornGamePill, findsWidgets);

    // Tap on the Unstable Unicorns filter pill
    await tester.tap(unicornGamePill.first);
    await tester.pumpAndSettle();

    // 2. Verify key Unstable Unicorns cards are displayed in the gallery
    expect(find.text('"Unicornio Bebé Arcoíris"'), findsOneWidget);
    expect(find.text('"Unicornio Seductor"'), findsOneWidget);
    expect(find.text('"¡Relincho! (Neigh!)"'), findsOneWidget);
    expect(find.text('"Bomba de Purpurina"'), findsOneWidget);
    expect(find.text('"Melena Arcoíris Protectora"'), findsOneWidget);

    // Verify categories for Unstable Unicorns are shown in sidebar
    expect(find.text('Unicornios'), findsWidgets);
    expect(find.text('Cartas de Mejora'), findsWidgets);
    expect(find.text('Cartas de Degradación'), findsWidgets);
    expect(find.text('Cartas de Magia'), findsWidgets);
    expect(find.text('Cartas de ¡Neigh! (Relincho)'), findsWidgets);

    // 3. Tap on "Unicornio Seductor" to open Canvas Editor
    await tester.ensureVisible(find.text('"Unicornio Seductor"'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('"Unicornio Seductor"'));
    await tester.pumpAndSettle();

    // Verify Canvas Editor is open and Unicorn Stable Frame template is auto-activated
    expect(find.text('Plantilla Activa'), findsWidgets);
    expect(find.text('Unicorn Stable Frame (Kawaii Chaos)'), findsWidgets);

    // Verify rules text is bound in canvas
    expect(find.textContaining('Al entrar a tu establo, roba 1 carta de Unicornio'), findsWidgets);

    // 4. Navigate to Playtest Screen
    final playtestNavTab = find.text('Mesa de Playtest');
    expect(playtestNavTab, findsOneWidget);
    await tester.tap(playtestNavTab);
    await tester.pumpAndSettle();

    // Verify Playtest screen loads Unstable Unicorns deck
    expect(find.text('Unstable Unicorns'), findsWidgets);
    expect(find.text('Tapete de Juego Tabletop'), findsOneWidget);

    // Verify player has cards in hand
    expect(find.byType(Draggable<Map<String, dynamic>>), findsWidgets);

    // Tap on "Robar Carta" to draw another unicorn card
    final drawDeckButton = find.text('Robar');
    expect(drawDeckButton, findsOneWidget);
    await tester.tap(drawDeckButton);
    await tester.pumpAndSettle();

    // Tap on Next Turn
    final nextTurnButton = find.textContaining('Siguiente Turno');
    expect(nextTurnButton, findsOneWidget);
    await tester.tap(nextTurnButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('(2)'), findsOneWidget);
  });
}
