import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/screens/editor_screen.dart';
import 'package:grimoire_studio/core/widgets/grimoire_emoji_picker.dart';

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
      expect(find.text('Radio de Borde'), findsWidgets);
      expect(find.text('FONDO Y BORDE DE LA CARTA'), findsOneWidget);

      // Verify quick presets are available (e.g. 16 (Póker), 24 px)
      expect(find.text('16 (Póker)'), findsOneWidget);
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

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: EditorScreen(repaintBoundaryKey: GlobalKey()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Assets panel is present between canvas and inspector
      expect(find.text('Assets del Juego'), findsWidgets);
      expect(find.text('Subir Imagen'), findsWidgets);
      expect(find.text('Generar con IA'), findsWidgets);

      // 2. Verify sample Magic assets are displayed (e.g. black_lotus.png)
      expect(find.text('black_lotus.png'), findsOneWidget);

      // 3. Tap on black_lotus.png to assign it to the active card
      await tester.tap(find.text('black_lotus.png'));
      await tester.pumpAndSettle();

      // Active badge should be visible on the card
      expect(find.text('ACTIVA'), findsWidgets);

      // 4. Test collapsing the panel via the chevron button
      final collapseBtn = find.byTooltip('Plegar panel de assets');
      expect(collapseBtn, findsWidgets);
      await tester.tap(collapseBtn.first);
      await tester.pumpAndSettle();

      // Panel should now be collapsed showing the vertical label ASSETS
      expect(find.textContaining('ASSETS'), findsWidgets);

      // 5. Expand it back by tapping the collapsed rail
      final expandBtn = find.byTooltip('Desplegar panel de assets');
      expect(expandBtn, findsWidgets);
      await tester.tap(expandBtn.first);
      await tester.pumpAndSettle();

      // Title should be visible again
      expect(find.text('Assets del Juego'), findsWidgets);
    });
  });
}

