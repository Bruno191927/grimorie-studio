import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/main.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';

void main() {
  testWidgets('Grimoire Studio smoke test and language selector test', (WidgetTester tester) async {
    // Set desktop screen resolution
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const GrimoireApp();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Grimoire Studio header is present
    expect(find.text('Grimoire '), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);

    // Initial language is Spanish
    expect(find.text('Galería de Cartas'), findsOneWidget);

    // App starts empty with No Games Empty State
    expect(find.text('No tienes juegos creados'), findsOneWidget);
    expect(find.text('Crear mi Primer Juego'), findsOneWidget);
    expect(find.text('Restaurar Juegos de Ejemplo'), findsOneWidget);

    // Tap Restaurar Juegos de Ejemplo to populate sample games
    await tester.tap(find.text('Restaurar Juegos de Ejemplo'));
    await tester.pumpAndSettle();

    // Verify Board Game groups are present in Spanish
    expect(find.text('Todos los Juegos'), findsOneWidget);
    expect(find.text('Magic'), findsWidgets);
    expect(find.text('Unstable Unicorns'), findsWidgets);

    // Test Interactive Archetype Pill: tap category 'Criaturas' in Magic
    final categoryPill = find.text('Criaturas');
    expect(categoryPill, findsWidgets);
    await tester.tap(categoryPill.first);
    await tester.pumpAndSettle();

    // Switch to English via provider
    container.read(localeProvider.notifier).setLanguage(AppLanguage.en);
    await tester.pumpAndSettle();

    // Verify UI switched to English
    expect(find.text('Card Gallery'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Text && (w.data == 'Connect AI Engine' || (w.data?.startsWith('NVIDIA:') ?? false))),
      findsOneWidget,
    );
    expect(find.text('All Games'), findsOneWidget);
    expect(find.text('Board Game'), findsWidgets);
  });

  testWidgets('Card tile three-dots menu contains Eliminar option and deletes card', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: GrimoireApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Restore sample games to test card deletion
    if (find.text('Restaurar Juegos de Ejemplo').evaluate().isNotEmpty) {
      await tester.tap(find.text('Restaurar Juegos de Ejemplo'));
      await tester.pumpAndSettle();
    }

    // Verify card Lightning Bolt exists initially
    expect(find.text('"Lightning Bolt"'), findsOneWidget);

    // Find the three dots button on card Lightning Bolt and tap it
    final moreVertButton = find.byKey(const ValueKey('card_menu_Lightning Bolt'));
    await tester.tap(moreVertButton);
    await tester.pumpAndSettle();

    // Verify popup menu displays Eliminar Carta
    final deleteOption = find.text('Eliminar Carta');
    expect(deleteOption, findsOneWidget);

    // Tap Eliminar Carta
    await tester.tap(deleteOption);
    await tester.pumpAndSettle();

    // Verify Confirmation Dialog appears
    expect(find.text('¿Eliminar Carta?'), findsOneWidget);

    // Tap confirm delete in dialog
    final confirmDeleteBtn = find.widgetWithText(ElevatedButton, 'Eliminar Carta');
    await tester.tap(confirmDeleteBtn);
    await tester.pumpAndSettle();

    // Verify Lightning Bolt is deleted from gallery
    expect(find.text('"Lightning Bolt"'), findsNothing);
  });

  testWidgets('Delete game button confirms and removes board game and its cards', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: GrimoireApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Restore sample games to test game deletion
    if (find.text('Restaurar Juegos de Ejemplo').evaluate().isNotEmpty) {
      await tester.tap(find.text('Restaurar Juegos de Ejemplo'));
      await tester.pumpAndSettle();
    }

    // Verify Magic header and cards exist
    expect(find.text('Magic'), findsWidgets);
    expect(find.text('"Black Lotus"'), findsOneWidget);

    // Find the Eliminar Juego button for Magic
    final deleteGameButtons = find.widgetWithText(OutlinedButton, 'Eliminar Juego');
    expect(deleteGameButtons, findsWidgets);

    // Tap the delete game button for Magic
    await tester.tap(deleteGameButtons.first);
    await tester.pumpAndSettle();

    // Verify Confirmation Dialog appears
    expect(find.text('¿Eliminar Juego de Mesa?'), findsOneWidget);
    expect(find.textContaining('Magic'), findsWidgets);

    // Tap confirm delete in dialog
    final confirmDeleteBtn = find.widgetWithText(ElevatedButton, 'Eliminar Juego');
    await tester.tap(confirmDeleteBtn);
    await tester.pumpAndSettle();

    // Verify Magic and Black Lotus are removed
    expect(find.text('"Black Lotus"'), findsNothing);
  });

  testWidgets('App starts with "No tienes juegos creados" empty state and restores sample games', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: GrimoireApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify No Games Empty State appears initially on start
    expect(find.text('No tienes juegos creados'), findsOneWidget);
    expect(find.text('Crear mi Primer Juego'), findsOneWidget);
    expect(find.text('Restaurar Juegos de Ejemplo'), findsOneWidget);

    // 2. Tap Restaurar Juegos de Ejemplo
    await tester.tap(find.text('Restaurar Juegos de Ejemplo'));
    await tester.pumpAndSettle();

    // 3. Verify games are restored
    expect(find.text('Magic'), findsWidgets);
    expect(find.text('Unstable Unicorns'), findsWidgets);
    expect(find.text('"Black Lotus"'), findsOneWidget);
  });
}

