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

    // Verify Board Game groups are present in Spanish
    expect(find.text('Todos los Juegos'), findsOneWidget);
    expect(find.text('Cyber Arena TCG'), findsWidgets);
    expect(find.text('Reino Arcano (Fantasy)'), findsWidgets);

    // Test Interactive Checkbox: tap dynamic game category 'Hechizos Arcanos'
    final categoryCheckbox = find.text('Hechizos Arcanos');
    expect(categoryCheckbox, findsWidgets);
    await tester.tap(categoryCheckbox.first);
    await tester.pumpAndSettle();

    // Switch to English via provider
    container.read(localeProvider.notifier).setLanguage(AppLanguage.en);
    await tester.pumpAndSettle();

    // Verify UI switched to English
    expect(find.text('Card Gallery'), findsOneWidget);
    expect(find.text('Connect AI Engine'), findsOneWidget);
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

    // Verify card Flame Dress exists initially
    expect(find.text('"Flame Dress"'), findsOneWidget);

    // Find the first three dots button and tap it
    final moreVertButton = find.byIcon(Icons.more_vert).first;
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

    // Verify Flame Dress is deleted from gallery
    expect(find.text('"Flame Dress"'), findsNothing);
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

    // Verify Reino Arcano (Fantasy) header and cards exist initially
    expect(find.text('Reino Arcano (Fantasy)'), findsWidgets);
    expect(find.text('"Celestial Kitsune"'), findsOneWidget);

    // Find the Eliminar Juego button for Reino Arcano
    final deleteGameButtons = find.widgetWithText(OutlinedButton, 'Eliminar Juego');
    expect(deleteGameButtons, findsWidgets);

    // Tap the second delete game button (corresponding to Reino Arcano)
    await tester.tap(deleteGameButtons.at(1));
    await tester.pumpAndSettle();

    // Verify Confirmation Dialog appears
    expect(find.text('¿Eliminar Juego de Mesa?'), findsOneWidget);
    expect(find.textContaining('Reino Arcano (Fantasy)'), findsWidgets);

    // Tap confirm delete in dialog
    final confirmDeleteBtn = find.widgetWithText(ElevatedButton, 'Eliminar Juego');
    await tester.tap(confirmDeleteBtn);
    await tester.pumpAndSettle();

    // Verify Reino Arcano (Fantasy) and Celestial Kitsune are removed
    expect(find.text('"Celestial Kitsune"'), findsNothing);
    expect(find.text('Juego de mesa eliminado con éxito: "Reino Arcano (Fantasy)"'), findsOneWidget);
  });
}

