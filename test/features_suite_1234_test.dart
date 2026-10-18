import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/card_dimension_presets.dart';
import 'package:grimoire_studio/features/editor/models/card_template.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/dialogs/batch_card_creation_dialog.dart';
import 'package:grimoire_studio/features/editor/presentation/dialogs/card_3d_viewer_dialog.dart';
import 'package:grimoire_studio/features/playtest/models/playtest_models.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';

void main() {
  group('1. Playtest Mat Enhancements: Tapping, Graveyard & Multi-Counters', () {
    test('PlaytestCard supports tap rotation toggle', () {
      final card = PlaytestCard(
        id: 'c1',
        data: {'card_name': 'Dragón Ancestral'},
        position: const Offset(100, 100),
        isTapped: false,
      );

      expect(card.isTapped, false);
      expect(card.rotationDegrees, 0);

      card.toggleTap();
      expect(card.isTapped, true);
      expect(card.rotationDegrees, 90);
      expect(card.rotationAngle, closeTo(1.57, 0.01));

      card.toggleTap();
      expect(card.isTapped, false);
      expect(card.rotationDegrees, 0);
    });

    test('PlaytestCard counters: +1/+1, damage, energy, and poison', () {
      final card = PlaytestCard(
        id: 'c2',
        data: {'card_name': 'Elfo Druida'},
        position: const Offset(200, 200),
        counters: 2,
        damageCounters: 1,
        energyCounters: 3,
        poisonCounters: 0,
      );

      expect(card.counters, 2);
      expect(card.damageCounters, 1);
      expect(card.energyCounters, 3);
      expect(card.poisonCounters, 0);

      // Mutate counters
      card.energyCounters += 2;
      card.poisonCounters += 1;
      card.counters += 1;
      card.damageCounters += 3;

      expect(card.energyCounters, 5);
      expect(card.poisonCounters, 1);
      expect(card.counters, 3);
      expect(card.damageCounters, 4);
    });

    test('Playtest graveyard simulated collection and revive flow', () {
      final card1 = PlaytestCard(
        id: 'c1',
        data: {'card_name': 'Espectro'},
        position: const Offset(0, 0),
      );
      final card2 = PlaytestCard(
        id: 'c2',
        data: {'card_name': 'Zombi'},
        position: const Offset(0, 0),
      );

      final graveyard = <PlaytestCard>[card1, card2];
      final battlefield = <PlaytestCard>[];

      expect(graveyard.length, 2);
      expect(graveyard.last.data['card_name'], 'Zombi');

      // Revive to battlefield
      final revived = graveyard.removeLast();
      battlefield.add(revived);

      expect(graveyard.length, 1);
      expect(battlefield.length, 1);
      expect(battlefield.first.data['card_name'], 'Zombi');
    });
  });

  group('2. Standard Print Industry Presets & Dimensions', () {
    test('CardDimensionPreset definitions and standard presets list', () {
      expect(CardDimensionPreset.standardPresets.isNotEmpty, true);
      final poker = CardDimensionPreset.standardPresets.firstWhere((p) => p.id == 'poker');
      expect(poker.widthMm, 63.5);
      expect(poker.heightMm, 88.9);

      final tarot = CardDimensionPreset.standardPresets.firstWhere((p) => p.id == 'tarot');
      expect(tarot.widthMm, 70.0);
      expect(tarot.heightMm, 120.0);

      final bridge = CardDimensionPreset.standardPresets.firstWhere((p) => p.id == 'bridge');
      expect(bridge.widthMm, 57.0);
      expect(bridge.heightMm, 88.9);
    });

    test('CardDimensionPreset.match finds existing preset within 0.5mm tolerance', () {
      final matchedPoker = CardDimensionPreset.match(63.51, 88.89);
      expect(matchedPoker, isNotNull);
      expect(matchedPoker!.id, 'poker');

      final custom = CardDimensionPreset.match(100.0, 150.0);
      expect(custom, isNull);
    });
  });

  group('3. Batch Card Generator & Quick Duplication', () {
    test('duplicateCard clones card row and saves correctly', () {
      final notifier = EditorNotifier();
      notifier.restoreSampleGames();

      final initialCount = notifier.state.project.rows.length;
      expect(initialCount > 0, true);

      // Duplicate card at index 0
      notifier.duplicateCard(0);

      expect(notifier.state.project.rows.length, initialCount + 1);
      final duplicated = notifier.state.project.rows[1];
      expect(duplicated['card_name'].toString().contains('(Copia)'), true);
    });

    test('batchCreateCards stamps multiple cards from category template', () {
      final notifier = EditorNotifier();
      notifier.restoreSampleGames();

      final categories = notifier.getCategoriesForGame('Magic');
      expect(categories.isNotEmpty, true);
      final category = categories.first;

      final initialCount = notifier.state.project.rows.length;
      final names = ['Lobo Alfa', 'Lobo Sombra', 'Lobo Polar'];

      notifier.batchCreateCards(
        gameName: 'Magic',
        category: category,
        cardNames: names,
      );

      expect(notifier.state.project.rows.length, initialCount + 3);
      expect(notifier.state.project.rows.any((r) => r['card_name'] == 'Lobo Alfa'), true);
      expect(notifier.state.project.rows.any((r) => r['card_name'] == 'Lobo Sombra'), true);
      expect(notifier.state.project.rows.any((r) => r['card_name'] == 'Lobo Polar'), true);
    });
  });

  group('4. Visual Effects & 3D Foil / Linen Finish Inspector UI', () {
    testWidgets('Card3DViewerDialog renders with Foil, Linen, and Auto Giro controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const template = CardTemplate(
        id: 'tmpl_1',
        name: 'Standard Template',
        cornerRadius: 28,
        layers: [],
      );
      final cardData = {
        'card_name': 'Holographic Dragon',
        'type': 'Criatura Épica',
        'cost': '5',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card3DViewerDialog(
              template: template,
              cardData: cardData,
              widthMm: 63.5,
              heightMm: 88.9,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.textContaining('Inspección 3D & Acabados'), findsOneWidget);
      expect(find.textContaining('Holographic Dragon'), findsOneWidget);

      // Verify controls
      expect(find.text('Voltear Dorso'), findsOneWidget);
      expect(find.text('Foil / Holo'), findsOneWidget);
      expect(find.text('Textura Lino'), findsOneWidget);
      expect(find.text('Auto Giro'), findsOneWidget);

      // Tap on Voltear Dorso
      await tester.tap(find.text('Voltear Dorso'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Ver Frente'), findsOneWidget);

      // Toggle Auto Giro
      await tester.tap(find.text('Auto Giro'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Auto Giro'), findsOneWidget);
    });

    testWidgets('BatchCardCreationDialog renders inputs and mode toggle', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BatchCardCreationDialog(initialGame: 'Magic'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Creación en Lote'), findsOneWidget);
      expect(find.text('Por Lista de Nombres'), findsOneWidget);
      expect(find.text('Por Cantidad Numérica'), findsOneWidget);
      expect(find.text('Generar Cartas'), findsOneWidget);
    });
  });

  group('5. Multilingual Localization Keys Verification', () {
    test('All new strings are present in AppStrings for all 5 languages', () {
      final keys = [
        'batch_card_creator',
        'duplicate_card',
        'inspect_3d',
        'tap_card',
        'untap_card',
        'inspect_graveyard',
        'manage_counters',
        'shuffle_deck',
        'print_size_presets',
        'cut_safety_guides',
        'bleed_legend',
        'custom_size',
        'revive_to_field',
        'return_to_hand',
        'put_on_top_deck',
      ];

      for (final lang in AppLanguage.values) {
        for (final k in keys) {
          final val = AppStrings.get(lang, k);
          expect(val.isNotEmpty, true, reason: 'Key $k missing in ${lang.name}');
          expect(val != k, true, reason: 'Key $k not translated in ${lang.name}');
        }
      }
    });
  });
}
