import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/widgets/inspector_panel.dart';
import 'package:grimoire_studio/features/editor/presentation/widgets/card_canvas.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';

void main() {
  group('LayerItem TextDataType Model Unit Tests', () {
    test(
      'Default TextDataType is text with empty prefix/suffix and empty enumValues',
      () {
        const layer = LayerItem(
          id: 'layer_1',
          name: 'Title',
          type: LayerType.text,
        );

        expect(layer.textDataType, equals(TextDataType.text));
        expect(layer.numberPrefix, isEmpty);
        expect(layer.numberSuffix, isEmpty);
        expect(layer.numberMin, isNull);
        expect(layer.numberMax, isNull);
        expect(layer.numberStep, equals(1.0));
        expect(layer.enumValues, isEmpty);
      },
    );

    test('formatDisplayValue formats numbers with prefix and suffix', () {
      const layer = LayerItem(
        id: 'layer_cost',
        name: 'Coste',
        type: LayerType.text,
        textDataType: TextDataType.number,
        numberPrefix: '+',
        numberSuffix: ' MP',
      );

      expect(layer.formatDisplayValue('3'), equals('+3 MP'));
      expect(layer.formatDisplayValue(' 5 '), equals('+5 MP'));
      expect(layer.formatDisplayValue('0'), equals('+0 MP'));
    });

    test(
      'formatDisplayValue returns raw text if not number type or non-numeric string',
      () {
        const layer = LayerItem(
          id: 'layer_text',
          name: 'Name',
          type: LayerType.text,
          textDataType: TextDataType.text,
          numberPrefix: '+',
          numberSuffix: ' MP',
        );

        expect(layer.formatDisplayValue('Sword'), equals('Sword'));

        const numberLayer = LayerItem(
          id: 'layer_num',
          name: 'Num',
          type: LayerType.text,
          textDataType: TextDataType.number,
          numberPrefix: '+',
          numberSuffix: ' MP',
        );
        // Non-parseable text returns raw string
        expect(numberLayer.formatDisplayValue('Invalid'), equals('Invalid'));
      },
    );

    test('toJson and fromJson preserves all TextDataType schema fields', () {
      const original = LayerItem(
        id: 'layer_enum',
        name: 'Type',
        type: LayerType.text,
        text: 'Creature',
        textDataType: TextDataType.enumeration,
        numberPrefix: '\$',
        numberSuffix: ' coins',
        numberMin: 0,
        numberMax: 100,
        numberStep: 5.0,
        enumValues: ['Creature', 'Spell', 'Artifact'],
      );

      final json = original.toJson();
      expect(json['textDataType'], equals('enumeration'));
      expect(json['numberPrefix'], equals('\$'));
      expect(json['numberSuffix'], equals(' coins'));
      expect(json['numberMin'], equals(0.0));
      expect(json['numberMax'], equals(100.0));
      expect(json['numberStep'], equals(5.0));
      expect(json['enumValues'], equals(['Creature', 'Spell', 'Artifact']));

      final deserialized = LayerItem.fromJson(json);
      expect(deserialized.textDataType, equals(TextDataType.enumeration));
      expect(deserialized.numberPrefix, equals('\$'));
      expect(deserialized.numberSuffix, equals(' coins'));
      expect(deserialized.numberMin, equals(0.0));
      expect(deserialized.numberMax, equals(100.0));
      expect(deserialized.numberStep, equals(5.0));
      expect(
        deserialized.enumValues,
        equals(['Creature', 'Spell', 'Artifact']),
      );
      expect(deserialized.text, equals('Creature'));
    });

    test(
      'fromJson defaults to TextDataType.text when JSON lacks new fields (backward compatibility)',
      () {
        final legacyJson = {
          'id': 'legacy_1',
          'name': 'Old Layer',
          'type': 'text',
          'text': 'Hello World',
        };

        final layer = LayerItem.fromJson(legacyJson);
        expect(layer.textDataType, equals(TextDataType.text));
        expect(layer.numberPrefix, isEmpty);
        expect(layer.numberSuffix, isEmpty);
        expect(layer.enumValues, isEmpty);
      },
    );

    test(
      'copyWith allows mutating textDataType, enumValues and number options',
      () {
        const initial = LayerItem(
          id: 'l1',
          name: 'Stats',
          type: LayerType.text,
        );

        final updated = initial.copyWith(
          textDataType: TextDataType.number,
          numberPrefix: 'LVL ',
          numberSuffix: ' ★',
          numberMin: 1,
          numberMax: 10,
          numberStep: 1,
        );

        expect(updated.textDataType, equals(TextDataType.number));
        expect(updated.numberPrefix, equals('LVL '));
        expect(updated.numberSuffix, equals(' ★'));
        expect(updated.numberMin, equals(1.0));
        expect(updated.numberMax, equals(10.0));

        final withEnums = updated.copyWith(
          textDataType: TextDataType.enumeration,
          enumValues: ['Warrior', 'Mage', 'Rogue'],
        );
        expect(withEnums.textDataType, equals(TextDataType.enumeration));
        expect(withEnums.enumValues, equals(['Warrior', 'Mage', 'Rogue']));
      },
    );
  });

  group('Multilingual Localization for TextDataType (5 Languages)', () {
    const keysToCheck = [
      'text_data_type',
      'data_type_text',
      'data_type_number',
      'data_type_enum',
      'numeric_stepper_title',
      'number_step',
      'number_prefix',
      'number_suffix',
      'enum_allowed_values',
      'add_enum_option_hint',
      'select_enum_placeholder',
    ];

    for (final lang in AppLanguage.values) {
      test(
        'Language ${lang.name} contains valid translations for all TextDataType keys',
        () {
          for (final key in keysToCheck) {
            final translated = AppStrings.get(lang, key);
            expect(
              translated,
              isNotEmpty,
              reason: 'Key $key in ${lang.name} should not be empty',
            );
            expect(
              translated,
              isNot(equals(key)),
              reason: 'Key $key in ${lang.name} should not match raw key',
            );
          }
        },
      );
    }
  });

  group('InspectorPanel TextDataType UI & Interaction Tests', () {
    Widget buildInspectorHarness(LayerItem initialLayer) {
      return ProviderScope(
        overrides: [
          editorProvider.overrideWith((ref) {
            final notifier = EditorNotifier();
            notifier.addLayer(initialLayer);
            notifier.selectLayer(initialLayer.id);
            return notifier;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: InspectorPanel())),
      );
    }

    testWidgets(
      'Displays text data type segmented selector (Text, Number, Enum)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        const layer = LayerItem(
          id: 'txt_1',
          name: 'Nombre',
          type: LayerType.text,
          text: 'Dragón',
          textDataType: TextDataType.text,
        );

        await tester.pumpWidget(buildInspectorHarness(layer));
        await tester.pumpAndSettle();

        expect(
          find.text(AppStrings.get(AppLanguage.en, 'data_type_text')),
          findsOneWidget,
        );
        expect(
          find.text(AppStrings.get(AppLanguage.en, 'data_type_number')),
          findsOneWidget,
        );
        expect(
          find.text(AppStrings.get(AppLanguage.en, 'data_type_enum')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Switching to Number displays numeric stepper and controls', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      const layer = LayerItem(
        id: 'cost_layer',
        name: 'Coste',
        type: LayerType.text,
        text: '5',
        textDataType: TextDataType.number,
        numberStep: 1,
      );

      await tester.pumpWidget(buildInspectorHarness(layer));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.get(AppLanguage.en, 'numeric_stepper_title')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Tap [+] to increment
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('6'), findsOneWidget);

      // Tap [-] to decrement
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets(
      'Switching to Enum displays allowed options, add option, and selection chips',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        const layer = LayerItem(
          id: 'type_layer',
          name: 'Tipo de Carta',
          type: LayerType.text,
          text: 'Criatura',
          textDataType: TextDataType.enumeration,
          enumValues: ['Criatura', 'Hechizo'],
        );

        await tester.pumpWidget(buildInspectorHarness(layer));
        await tester.pumpAndSettle();

        expect(
          find.text(AppStrings.get(AppLanguage.en, 'enum_allowed_values')),
          findsOneWidget,
        );
        expect(find.text('Criatura'), findsWidgets);
        expect(find.text('Hechizo'), findsOneWidget);

        // Add a new enum option 'Reliquia'
        await tester.enterText(find.byType(TextFormField).last, 'Reliquia');
        await tester.tap(find.byTooltip('Añadir opción'));
        await tester.pumpAndSettle();

        expect(find.text('Reliquia'), findsOneWidget);

        // Click on 'Hechizo' chip to switch value
        await tester.tap(find.text('Hechizo'));
        await tester.pumpAndSettle();
      },
    );
  });

  group('CardCanvas TextDataType Rendering Tests', () {
    testWidgets(
      'Canvas renders number layer with formatted prefix and suffix',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        const layer = LayerItem(
          id: 'card_hp',
          name: 'Vida',
          type: LayerType.text,
          text: '20',
          textDataType: TextDataType.number,
          numberPrefix: '+',
          numberSuffix: ' HP',
          x: 20,
          y: 20,
          width: 120,
          height: 35,
        );

        final repaintKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              editorProvider.overrideWith((ref) {
                final notifier = EditorNotifier();
                notifier.addLayer(layer);
                notifier.selectLayer(layer.id);
                return notifier;
              }),
            ],
            child: MaterialApp(
              home: Scaffold(body: CardCanvas(repaintBoundaryKey: repaintKey)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Formatted text '+20 HP' should appear on canvas
        expect(find.text('+20 HP'), findsOneWidget);
      },
    );
  });
}
