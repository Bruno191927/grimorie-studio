import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';
import 'package:grimoire_studio/features/playtest/models/playtest_models.dart';
import 'package:grimoire_studio/features/playtest/services/playmat_service.dart';
import 'package:grimoire_studio/features/playtest/presentation/screens/playtest_screen.dart';
import 'package:grimoire_studio/features/export/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Playtest Tabletop Simulator Features', () {
    test('1. PlaytestCard handles rotation, face-down status, and notes', () {
      final card = PlaytestCard(
        id: 'c1',
        data: {'card_name': 'Black Lotus', 'cost': '0'},
        position: const Offset(100, 100),
      );

      expect(card.isFaceDown, isFalse);
      expect(card.rotationAngle, 0.0);

      // Flip face down
      card.isFaceDown = true;
      expect(card.isFaceDown, isTrue);

      // Rotate to 90 degrees
      card.rotationDegrees = 90;
      expect(card.rotationAngle, 1.5708);

      // Add note
      card.note = 'Congelado';
      expect(card.note, 'Congelado');
    });

    test('2. PlaymatTheme presets are available with distinct styles', () {
      final presets = PlaymatTheme.presets;
      expect(presets.length, greaterThanOrEqualTo(4));
      expect(presets.any((p) => p.name.contains('Místico')), isTrue);
      expect(presets.any((p) => p.name.contains('Casino')), isTrue);
      expect(presets.any((p) => p.name.contains('Taberna')), isTrue);
      expect(presets.any((p) => p.name.contains('Cyber')), isTrue);
    });

    test('3. BattleLogEntry formats time and supports diverse types', () {
      final entry = BattleLogEntry(
        timestamp: DateTime(2026, 10, 16, 14, 30, 45),
        message: 'J1 jugó Black Lotus',
        type: BattleLogType.play,
        player: 1,
      );

      expect(entry.formattedTime, '14:30:45');
      expect(entry.type, BattleLogType.play);
      expect(entry.player, 1);
    });

    test('4. ExportService generates valid Tabletop Simulator deck JSON', () async {
      final tempDir = await Directory.systemTemp.createTemp('tts_test_');
      try {
        final cards = [
          {'card_name': 'Test Creature', 'cost': '3', 'type': 'Criatura', 'attack': '3', 'defense': '2'},
          {'card_name': 'Test Spell', 'cost': '1', 'type': 'Instantáneo', 'rules_text': 'Destruye 1 criatura'},
        ];

        final file = await ExportService.exportTabletopSimulatorDeckJson(
          gameName: 'TestGame',
          cards: cards,
          outputDirectory: tempDir,
        );

        expect(file.existsSync(), isTrue);
        expect(file.path.endsWith('_TabletopSimulator_Deck.json'), isTrue);

        final content = await file.readAsString();
        expect(content.contains('DeckCustom'), isTrue);
        expect(content.contains('Test Creature'), isTrue);
        expect(content.contains('Test Spell'), isTrue);
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    testWidgets('5. PlaytestScreen renders with new toolbar controls and toggles Duel mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PlaytestScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check toolbar buttons exist
      expect(find.text(AppStrings.get(AppLanguage.en, 'tokens')), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'analytics')), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'solo_mode')), findsOneWidget);

      // Toggle Duel Mode
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Should show Duel label
      expect(find.text(AppStrings.get(AppLanguage.en, 'duel_mode')), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'player_2')), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'player_1')), findsOneWidget);
    });

    testWidgets('6. PlaytestScreen allows toggling combat mode for non-combat games', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PlaytestScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shield icon button for combat toggle exists
      final shieldIconFinder = find.byIcon(Icons.shield_outlined);
      final activeShieldFinder = find.byIcon(Icons.shield);
      expect(shieldIconFinder.evaluate().isNotEmpty || activeShieldFinder.evaluate().isNotEmpty, isTrue);

      final targetFinder = shieldIconFinder.evaluate().isNotEmpty ? shieldIconFinder : activeShieldFinder;
      await tester.tap(targetFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
    });

    test('7. TableDivisionMode supports 1, 2, 3, 4, 6, and 8 player divisions with correct counts', () {
      expect(TableDivisionMode.none.playerCount, 1);
      expect(TableDivisionMode.duel.playerCount, 2);
      expect(TableDivisionMode.twoSideBySide.playerCount, 2);
      expect(TableDivisionMode.threeRadial.playerCount, 3);
      expect(TableDivisionMode.fourCross.playerCount, 4);
      expect(TableDivisionMode.sixRadial.playerCount, 6);
      expect(TableDivisionMode.eightRadial.playerCount, 8);

      expect(TableDivisionMode.sixRadial.label, contains('6 Jugadores'));
      expect(TableDivisionMode.eightRadial.label, contains('8 Jugadores'));
    });

    testWidgets('8. PlaytestScreen renders zoom HUD and supports table division for multiple players', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PlaytestScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Zoom HUD buttons exist
      expect(find.byIcon(Icons.add), findsWidgets);
      expect(find.byIcon(Icons.remove), findsWidgets);
      expect(find.byIcon(Icons.fit_screen_outlined), findsOneWidget);

      // Check Zoom In and Zoom Out buttons can be tapped
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.fit_screen_outlined));
      await tester.pumpAndSettle();

      // Tap Table Division Popup Menu
      final divisionMenuFinder = find.byTooltip(AppStrings.get(AppLanguage.en, 'divide_table_tooltip'));
      expect(divisionMenuFinder, findsOneWidget);
      await tester.tap(divisionMenuFinder);
      await tester.pumpAndSettle();

      // Select 6 Players (Radial / Hexagonal)
      final sixPlayersOption = find.text('6 Jugadores (Radial 60° - Hexagonal)');
      expect(sixPlayersOption, findsOneWidget);
      await tester.tap(sixPlayersOption);
      await tester.pumpAndSettle();

      // Check multiplayer zones and J1-J6 badges exist
      expect(find.text('J1'), findsWidgets);
      expect(find.text('J2'), findsWidgets);
      expect(find.text('J3'), findsWidgets);
      expect(find.text('J4'), findsWidgets);
      expect(find.text('J5'), findsWidgets);
      expect(find.text('J6'), findsWidgets);

      // Verify Center Hub reflects 6 players
      expect(find.text(AppStrings.get(AppLanguage.en, 'common_area')), findsOneWidget);
    });

    test('9. CustomPlaymatConfig serializes and deserializes properly and PlaymatService handles persistence', () async {
      const config = CustomPlaymatConfig(
        isEnabled: true,
        imagePath: '/path/to/playmat.png',
        fit: BoxFit.contain,
        overlayDim: 0.35,
        showDivisionLines: false,
        divisionLinesOpacity: 0.5,
        tableWidth: 2400.0,
        tableHeight: 1600.0,
      );

      final json = config.toJson();
      expect(json['isEnabled'], isTrue);
      expect(json['imagePath'], '/path/to/playmat.png');
      expect(json['fit'], 'contain');
      expect(json['overlayDim'], 0.35);
      expect(json['showDivisionLines'], isFalse);
      expect(json['tableWidth'], 2400.0);
      expect(json['tableHeight'], 1600.0);

      final restored = CustomPlaymatConfig.fromJson(json);
      expect(restored.isEnabled, isTrue);
      expect(restored.imagePath, '/path/to/playmat.png');
      expect(restored.fit, BoxFit.contain);
      expect(restored.overlayDim, 0.35);
      expect(restored.showDivisionLines, isFalse);
      expect(restored.tableWidth, 2400.0);
      expect(restored.tableHeight, 1600.0);

      // Verify PlaymatService config file generation
      final file = PlaymatService.getConfigFile('TestGame');
      expect(file.path.contains('TestGame'), isTrue);
      expect(file.path.endsWith('playmat_config.json'), isTrue);
    });

    testWidgets('10. PlaytestScreen renders custom playmat toolbar button', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PlaytestScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Custom Playmat icon button exists in toolbar
      final playmatButton = find.byTooltip('Subir Mesa de Juego Personalizada (Tapete)');
      expect(playmatButton, findsOneWidget);
    });
  });
}
