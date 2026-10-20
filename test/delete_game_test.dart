import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';
import 'package:grimoire_studio/features/gallery/presentation/screens/card_gallery_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('grimoire_delete_game_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('deleteGame removes cards, categories, physical folder, and recreates cleanly without resurrection', () {
    final notifier = EditorNotifier(
      enableDiskPersistence: true,
      customPersistenceDir: tempDir,
    );

    // 1. Create a game with cards and a category
    const testGame = 'poli-critics';
    notifier.addCategoryToGame(
      testGame,
      const GameCategory(id: 'cat_politics', name: 'Politicians', icon: '🏛️'),
    );
    notifier.addCardToGame(
      testGame,
      cardName: 'President Card',
      category: 'Politicians',
      rulesText: 'Original secret card data',
    );

    // Verify game folder exists on disk with data.csv
    final gameDir = GameFolderService.getGameDir(testGame, customRootDir: tempDir);
    final dataCsv = GameFolderService.getGameDataCsvFile(testGame, customRootDir: tempDir);
    expect(gameDir.existsSync(), isTrue);
    expect(dataCsv.existsSync(), isTrue);
    expect(dataCsv.readAsStringSync().contains('President Card'), isTrue);

    // Verify state has cards and categories for testGame
    expect(notifier.state.project.rows.any((r) => r['game'] == testGame), isTrue);
    expect(notifier.state.gameCategories.containsKey(testGame), isTrue);

    // 2. Delete the game
    notifier.deleteGame(testGame);

    // Verify memory state is completely cleared
    expect(notifier.state.project.rows.any((r) => r['game'] == testGame), isFalse);
    expect(notifier.state.gameCategories.containsKey(testGame), isFalse);
    expect(notifier.state.deletedGames.contains(testGame), isTrue);

    // Verify physical folder is completely gone from disk
    expect(gameDir.existsSync(), isFalse);

    // 3. Re-create a new game with the EXACT SAME name
    notifier.addCardToGame(
      testGame,
      cardName: 'Brand New Card',
      category: 'General',
      rulesText: 'Fresh content',
    );

    // Verify deletedGames no longer contains testGame
    expect(notifier.state.deletedGames.contains(testGame), isFalse);

    // Verify only the new card exists and old cards did NOT resurrect
    final currentGameCards = notifier.state.project.rows.where((r) => r['game'] == testGame).toList();
    expect(currentGameCards.length, equals(1));
    expect(currentGameCards.first['card_name'], equals('Brand New Card'));
    expect(currentGameCards.any((r) => r['card_name'] == 'President Card'), isFalse);
    expect(notifier.state.gameCategories[testGame]?.any((c) => c.name == 'Politicians') ?? false, isFalse);
  });

  testWidgets('Sidebar game tile shows delete icon button and triggers delete dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(editorProvider.notifier);

    notifier.addCardToGame('poli-critics', cardName: 'Card A');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: CardGalleryScreen(
              onOpenEditor: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify poli-critics is in the left sidebar
    expect(find.text('poli-critics'), findsWidgets);

    // Tap on poli-critics in sidebar to select it
    await tester.tap(find.text('poli-critics').first);
    await tester.pumpAndSettle();

    // The delete icon button should now be visible on the selected tile
    final deleteIconBtn = find.byIcon(Icons.delete_outline);
    expect(deleteIconBtn, findsWidgets);

    // Tap the delete icon button on the sidebar
    await tester.tap(deleteIconBtn.first);
    await tester.pumpAndSettle();

    // Confirm dialog is shown
    expect(find.byIcon(Icons.delete_sweep_outlined), findsWidgets);
  });

  test('deleteGame and recreating with hyphenated/normalized name (policritics vs poli-critics) does not resurrect categories', () {
    final notifier = EditorNotifier(
      enableDiskPersistence: true,
      customPersistenceDir: tempDir,
    );

    // 1. Create "policritics" (no hyphen) with custom categories
    notifier.addCategoryToGame(
      'policritics',
      const GameCategory(id: 'cat_bloqueo', name: 'Bloqueo', icon: '🛑'),
    );
    notifier.addCategoryToGame(
      'policritics',
      const GameCategory(id: 'cat_congresista', name: 'Congresista', icon: '🏛️'),
    );
    notifier.addCardToGame(
      'policritics',
      cardName: 'Carta Antigua',
      category: 'Bloqueo',
    );

    expect(notifier.getCategoriesForGame('poli-critics').any((c) => c.name == 'Bloqueo'), isTrue);

    // 2. Delete using hyphenated name "poli-critics" (or delete "policritics" and recreate "poli-critics")
    notifier.deleteGame('policritics');

    // Categories for both "policritics" and "poli-critics" must be empty
    expect(notifier.getCategoriesForGame('policritics'), isEmpty);
    expect(notifier.getCategoriesForGame('poli-critics'), isEmpty);

    // 3. Recreate as "poli-critics" (with hyphen) without specifying a category (just like Nuevo Juego dialog)
    notifier.addCardToGame('poli-critics');

    // Verify ONLY the default "General" category exists and old categories ("Bloqueo", "Congresista") did NOT come back
    final cats = notifier.getCategoriesForGame('poli-critics');
    expect(cats.length, equals(1));
    expect(cats.first.name, equals('General'));
    expect(cats.any((c) => c.name == 'Bloqueo'), isFalse);
    expect(cats.any((c) => c.name == 'Congresista'), isFalse);

    final cards = notifier.state.project.rows
        .where((r) => GameFolderService.normalizeGameKey((r['game'] ?? '').toString()) == 'policritics')
        .toList();
    expect(cards.length, equals(1));
    expect(cards.first['category'], equals('General'));
  });
}
