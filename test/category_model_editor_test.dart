import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/screens/editor_screen.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';
import 'package:grimoire_studio/core/widgets/grimoire_emoji_picker.dart';
import 'package:grimoire_studio/features/gallery/presentation/screens/card_gallery_screen.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';

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
      notifier.restoreSampleGames();
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

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(editorProvider.notifier).restoreSampleGames();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EditorScreen(repaintBoundaryKey: GlobalKey()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check category label exists in toolbar
      expect(find.text(AppStrings.get(AppLanguage.en, 'category_label')), findsOneWidget);

      // Verify active card dropdown is present
      expect(find.text(AppStrings.get(AppLanguage.en, 'active_card')), findsOneWidget);
    });

    testWidgets('GrimoireEmojiPicker searches, categorizes, and selects emojis', (WidgetTester tester) async {
      String? selectedEmoji;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrimoireEmojiPicker(
              initialEmoji: '🦄',
              onEmojiSelected: (emoji) => selectedEmoji = emoji,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and categories are displayed
      expect(find.text('Selector de Íconos y Emojis'), findsOneWidget);
      expect(find.text('Fantasía & TCG'), findsOneWidget);
      expect(find.text('Criaturas & Animales'), findsOneWidget);

      // Search for dragon
      await tester.enterText(find.byType(TextField).first, 'dragón');
      await tester.pumpAndSettle();

      expect(find.text('🐉'), findsOneWidget);

      // Tap on dragon emoji
      await tester.tap(find.text('🐉'));
      await tester.pumpAndSettle();

      expect(selectedEmoji, equals('🐉'));
    });

    test('EditorNotifier updates corner radius and background color correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);

      // Verify initial corner radius
      expect(container.read(editorProvider).project.activeTemplate.cornerRadius, equals(16.0));

      // Update corner radius to 24.0 (Suave)
      notifier.updateCornerRadius(24.0);
      expect(container.read(editorProvider).project.activeTemplate.cornerRadius, equals(24.0));

      // Update background color
      const newColor = Color(0xFF1E293B);
      notifier.updateBackgroundColor(newColor);
      expect(container.read(editorProvider).project.activeTemplate.backgroundColor, equals(newColor));
    });

    testWidgets('EditorScreen Inspector displays corner radius and background color controls', (WidgetTester tester) async {
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

      // With no layer selected, Project Settings shows corner radius & background controls
      expect(find.text(AppStrings.get(AppLanguage.en, 'border_radius')), findsWidgets);
      expect(find.text(AppStrings.get(AppLanguage.en, 'card_background_settings').toUpperCase()), findsOneWidget);

      // Verify quick presets are available (e.g. 16 (Poker), 24 px)
      expect(find.text('16 (Poker)'), findsOneWidget);
      expect(find.text('24 px'), findsOneWidget);

      // Tap 24 px preset
      await tester.tap(find.text('24 px'));
      await tester.pumpAndSettle();

      // Badge should now show 24.0 px
      expect(find.text('24.0 px'), findsOneWidget);
    });

    testWidgets('EditorScreen displays GameAssetsCollapsiblePanel with assets, upload, and AI generation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(editorProvider.notifier).restoreSampleGames();

      // Ensure Magic assets folder exists with a test asset synchronously
      GameFolderService.ensureGameFolderExistsSync('Magic');
      final magicAssets = GameFolderService.getGameAssetsDir('Magic');
      const validPng1x1 = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ];
      final testAsset = File('${magicAssets.path}/black_lotus.png');
      testAsset.writeAsBytesSync(validPng1x1);
      addTearDown(() {
        try {
          if (testAsset.existsSync()) testAsset.deleteSync();
        } catch (_) {}
        try {
          final magicDir = GameFolderService.getGameDir('Magic');
          if (magicDir.existsSync()) magicDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EditorScreen(repaintBoundaryKey: GlobalKey()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Assets panel is present between canvas and inspector
      expect(find.text(AppStrings.get(AppLanguage.en, 'game_assets')), findsWidgets);
      expect(find.textContaining(AppStrings.get(AppLanguage.en, 'upload_asset')), findsWidgets);
      expect(find.text(AppStrings.get(AppLanguage.en, 'generate_ai_asset')), findsWidgets);

      // 2. Verify sample Magic assets are displayed (e.g. black_lotus.png)
      expect(find.text('black_lotus.png'), findsOneWidget);

      // 3. Tap on black_lotus.png to assign it to the active card
      await tester.tap(find.text('black_lotus.png'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Active badge should be visible on the card
      expect(find.text('ACTIVA'), findsWidgets);

      // 4. Test collapsing the panel via the chevron button
      final collapseBtn = find.byTooltip(AppStrings.get(AppLanguage.en, 'collapse_assets_panel'));
      expect(collapseBtn, findsWidgets);
      await tester.tap(collapseBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Panel should now be collapsed showing the vertical label ASSETS
      expect(find.textContaining('ASSETS'), findsWidgets);

      // 5. Expand it back by tapping the collapsed rail
      final expandBtn = find.byTooltip(AppStrings.get(AppLanguage.en, 'expand_assets_panel'));
      expect(expandBtn, findsWidgets);
      await tester.tap(expandBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Title should be visible again
      expect(find.text(AppStrings.get(AppLanguage.en, 'game_assets')), findsWidgets);
    });

    test('EditorNotifier.duplicateCategory clones category and creates preset card', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      const originalCat = GameCategory(
        id: 'cat-orig',
        name: 'Hechizo Elemental',
        icon: '🔥',
        defaultType: 'Instantáneo',
        defaultColor: 0xFFEF4444,
        hasCost: true,
        defaultCost: '2R',
        hasCombatStats: false,
        hasRarity: true,
        defaultRarity: 'Rara',
        hasRules: true,
        defaultRules: 'Inflige 3 puntos de daño.',
        customFields: {'elemento': 'Fuego'},
      );

      notifier.addCategoryToGame('Magic', originalCat);
      final initialRowCount = container.read(editorProvider).project.rows.length;

      // Duplicate category
      final dupCat = notifier.duplicateCategory(
        'Magic',
        originalCat,
        createPresetCard: true,
      );

      // Verify category was cloned and added
      expect(dupCat.name, equals('Copia de Hechizo Elemental'));
      expect(dupCat.icon, equals('🔥'));
      expect(dupCat.defaultCost, equals('2R'));
      expect(dupCat.defaultColor, equals(0xFFEF4444));
      expect(dupCat.customFields['elemento'], equals('Fuego'));
      expect(dupCat.id, isNot(equals('cat-orig')));

      // Verify preset card was automatically generated
      final state = container.read(editorProvider);
      expect(state.project.rows.length, equals(initialRowCount + 1));
      final presetCard = state.project.rows.last;
      expect(presetCard['card_name'], equals('Copia de Hechizo Elemental (Preset)'));
      expect(presetCard['category'], equals('Copia de Hechizo Elemental'));
      expect(presetCard['cost'], equals('2R'));
      expect(presetCard['rules_text'], equals('Inflige 3 puntos de daño.'));
      expect(presetCard['elemento'], equals('Fuego'));

      // Duplicate again to verify automatic name increment
      final dupCat2 = notifier.duplicateCategory(
        'Magic',
        originalCat,
        createPresetCard: false,
      );
      expect(dupCat2.name, equals('Copia de Hechizo Elemental 2'));
    });

    testWidgets('CardGalleryScreen displays "+ Modelo Preset" button and creates preset card model', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(editorProvider.notifier).restoreSampleGames();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: CardGalleryScreen(
              onOpenEditor: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "+ Nueva Plantilla" button is displayed in the game categories bar
      final presetModelBtn = find.byKey(const Key('btn_add_blueprint_model_card'));
      expect(presetModelBtn, findsWidgets);

      // Tap the button
      await tester.tap(presetModelBtn.first);
      await tester.pumpAndSettle();

      // Verify the dedicated "Crear Modelo Preset de Carta" dialog is displayed
      expect(find.text(AppStrings.get(AppLanguage.en, 'create_preset_card_model_title')), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'starter_archetypes')), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'archetype_creature_label')), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'archetype_spell_label')), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'archetype_hero_label')), findsOneWidget);

      // Change archetype to Hechizo / Magia
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'archetype_spell_label')));
      await tester.pumpAndSettle();

      // Verify default type and rules updated
      expect(find.text(AppStrings.get(AppLanguage.en, 'archetype_spell_name')), findsOneWidget);

      // Enter a custom preset model name
      final nameInput = find.byKey(const Key('input_preset_model_name'));
      await tester.enterText(nameInput, 'Hechizo Cósmico');
      await tester.pumpAndSettle();

      // Submit dialog
      final submitBtn = find.byKey(const Key('btn_submit_create_preset_model'));
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify category was added to the game
      final state = container.read(editorProvider);
      final magicCategories = state.gameCategories['Magic'] ?? [];
      final createdCat = magicCategories.firstWhere((c) => c.name == 'Hechizo Cósmico');
      expect(createdCat.name, equals('Hechizo Cósmico'));
      expect(createdCat.icon, equals('⚡'));

      // Verify sample preset card was automatically generated
      final lastCard = state.project.rows.last;
      expect(lastCard['card_name'], equals('Hechizo Cósmico (Preset)'));
      expect(lastCard['category'], equals('Hechizo Cósmico'));
    });

    testWidgets('Category Model Dialog shows clean category creation (Name, Icon, Type, Color) without hardcoded RPG stats', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      notifier.restoreSampleGames();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: CardGalleryScreen(
              onOpenEditor: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open new category dialog for first game
      final newCatBtn = find.byKey(const Key('btn_add_category_model')).first;
      await tester.tap(newCatBtn);
      await tester.pumpAndSettle();

      final dialogFinder = find.byType(AlertDialog);
      expect(dialogFinder, findsOneWidget);

      // Verify that category identity fields exist
      expect(find.descendant(of: dialogFinder, matching: find.byType(TextField)), findsWidgets);

      // Verify that the forced RPG combat stats block is NOT present
      expect(find.descendant(of: dialogFinder, matching: find.text('Atributos de esta Plantilla / Carta Predefinida:')), findsNothing);
      expect(find.descendant(of: dialogFinder, matching: find.text('Ataque (⚔️)')), findsNothing);
      expect(find.descendant(of: dialogFinder, matching: find.text('Defensa (🛡️)')), findsNothing);
    });
  });
}


