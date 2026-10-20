import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/main.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';

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

    // Initial language is English by default
    expect(find.text(AppStrings.get(AppLanguage.en, 'nav_gallery')), findsOneWidget);

    // App starts empty with No Games Empty State
    expect(find.text(AppStrings.get(AppLanguage.en, 'no_games_title')), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.en, 'create_first_game_btn')), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.en, 'restore_sample_games_btn')), findsOneWidget);

    // Tap Restore Sample Games to populate sample games
    await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'restore_sample_games_btn')));
    await tester.pumpAndSettle();

    // Verify Board Game groups are present in English
    expect(find.text(AppStrings.get(AppLanguage.en, 'all_games')), findsOneWidget);
    expect(find.text('Magic'), findsWidgets);
    expect(find.text('Unstable Unicorns'), findsWidgets);

    // Test Interactive Archetype Pill: tap category 'Criaturas' in Magic
    final categoryPill = find.text('Criaturas');
    expect(categoryPill, findsWidgets);
    await tester.tap(categoryPill.first);
    await tester.pumpAndSettle();

    // Switch to Spanish via provider
    container.read(localeProvider.notifier).setLanguage(AppLanguage.es);
    await tester.pumpAndSettle();

    // Verify UI switched to Spanish
    expect(find.text(AppStrings.get(AppLanguage.es, 'nav_gallery')), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.es, 'btn_batch_export')), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.es, 'all_games')), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.es, 'group_by_game')), findsWidgets);
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
    final restoreBtn = find.text(AppStrings.get(AppLanguage.en, 'restore_sample_games_btn'));
    if (restoreBtn.evaluate().isNotEmpty) {
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();
    }

    // Verify card Lightning Bolt exists initially
    expect(find.text('"Lightning Bolt"'), findsOneWidget);

    // Find the three dots button on card Lightning Bolt and tap it
    final moreVertButton = find.byKey(const ValueKey('card_menu_Lightning Bolt'));
    await tester.tap(moreVertButton);
    await tester.pumpAndSettle();

    // Verify popup menu displays Delete Card
    final deleteOption = find.text(AppStrings.get(AppLanguage.en, 'delete_card'));
    expect(deleteOption, findsOneWidget);

    // Tap Delete Card
    await tester.tap(deleteOption);
    await tester.pumpAndSettle();

    // Verify Confirmation Dialog appears
    expect(find.text('${AppStrings.get(AppLanguage.en, 'delete_card')}?'), findsOneWidget);

    // Tap confirm delete in dialog
    final confirmDeleteBtn = find.widgetWithText(ElevatedButton, AppStrings.get(AppLanguage.en, 'delete_card'));
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
    final restoreBtn = find.text(AppStrings.get(AppLanguage.en, 'restore_sample_games_btn'));
    if (restoreBtn.evaluate().isNotEmpty) {
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();
    }

    // Verify Magic header and cards exist
    expect(find.text('Magic'), findsWidgets);
    expect(find.text('"Black Lotus"'), findsOneWidget);

    // Find the Delete Game button for Magic
    final deleteGameButtons = find.widgetWithText(OutlinedButton, AppStrings.get(AppLanguage.en, 'delete_game'));
    expect(deleteGameButtons, findsWidgets);

    // Tap the delete game button for Magic
    await tester.tap(deleteGameButtons.first);
    await tester.pumpAndSettle();

    // Verify Confirmation Dialog appears
    expect(find.text(AppStrings.get(AppLanguage.en, 'confirm_delete_game_title')), findsOneWidget);
    expect(find.textContaining('Magic'), findsWidgets);

    // Tap confirm delete in dialog
    final confirmDeleteBtn = find.widgetWithText(ElevatedButton, AppStrings.get(AppLanguage.en, 'delete_game'));
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

    // 1. Verify No Games Empty State appears initially on start (English default)
    expect(find.text(AppStrings.get(AppLanguage.en, 'no_games_title')), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.en, 'create_first_game_btn')), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.en, 'restore_sample_games_btn')), findsOneWidget);

    // 2. Tap Restore Sample Games
    await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'restore_sample_games_btn')));
    await tester.pumpAndSettle();

    // 3. Verify games are restored
    expect(find.text('Magic'), findsWidgets);
    expect(find.text('Unstable Unicorns'), findsWidgets);
    expect(find.text('"Black Lotus"'), findsOneWidget);
  });

  testWidgets('When games exist but cards count is 0, Todos los Juegos displays "Aún no tienes cartas creadas" and NOT "Ninguna carta coincide con los filtros"', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(editorProvider.notifier);
    notifier.addCategoryToGame('policritics', const GameCategory(id: 'c1', name: 'General', icon: '🃏'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GrimoireApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "No cards match active filters" is NOT shown
    expect(find.text(AppStrings.get(AppLanguage.en, 'no_cards_match_filter')), findsNothing);
    expect(find.text(AppStrings.get(AppLanguage.en, 'filter_reset')), findsNothing);

    // Verify "No cards created yet" empty state is shown
    expect(find.text(AppStrings.get(AppLanguage.en, 'no_cards_in_studio_title')), findsOneWidget);
    expect(find.text('${AppStrings.get(AppLanguage.en, 'add_first_card_to')} "policritics"'), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.en, 'create_preset_card_model')), findsWidgets);
  });
}
