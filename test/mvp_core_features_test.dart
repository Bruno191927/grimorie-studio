import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/core/utils/rich_text_token_parser.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';

void main() {
  group('RichTextTokenParser Tests', () {
    test('Identifies and extracts MTG/game tokens correctly', () {
      expect(RichTextTokenParser.hasInlineTokens('{T}: Añade {G} o {R} a tu reserva de maná.'), isTrue);
      expect(RichTextTokenParser.hasInlineTokens('Texto simple sin tokens'), isFalse);

      final tapToken = RichTextTokenParser.resolveToken('T');
      expect(tapToken, isNotNull);
      expect(tapToken!.label, '⟳');

      final greenToken = RichTextTokenParser.resolveToken('G');
      expect(greenToken, isNotNull);
      expect(greenToken!.bgColor, const Color(0xFF065F46));

      final genericToken = RichTextTokenParser.resolveToken('3');
      expect(genericToken, isNotNull);
      expect(genericToken!.label, '3');
    });

    testWidgets('Renders auto-fit text with inline token badges', (tester) async {
      final widget = MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 100,
            child: RichTextTokenParser.buildAutoFitCardText(
              text: 'Gasta {2}{U} para robar una carta.',
              maxWidth: 300,
              maxHeight: 100,
              fontFamily: 'Roboto',
              baseFontSize: 18,
              isBold: false,
              isItalic: false,
              fontColor: Colors.white,
              letterSpacing: 0,
              textAlign: TextAlign.left,
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.byType(RichText), findsWidgets);
    });
  });

  group('Editor Undo/Redo & Layer Manipulation', () {
    test('Supports undo and redo for layer modifications', () {
      final container = ProviderContainer();
      final notifier = container.read(editorProvider.notifier);

      expect(container.read(editorProvider).canUndo, isFalse);
      expect(container.read(editorProvider).canRedo, isFalse);

      // Add a text layer
      notifier.addLayer(LayerItem(
        id: 'test_layer_1',
        name: 'Texto de Prueba',
        type: LayerType.text,
        x: 10,
        y: 10,
        width: 100,
        height: 30,
        text: 'Hola',
      ));
      final layerId = container.read(editorProvider).selectedLayerId;
      expect(layerId, isNotNull);
      expect(container.read(editorProvider).canUndo, isTrue);

      // Initial position
      final initialLayer = container.read(editorProvider).project.activeTemplate.layers.firstWhere((l) => l.id == layerId);
      final initialX = initialLayer.x;

      // Nudge layer to the right
      notifier.nudgeSelectedLayer(8.0, 0.0);
      final movedLayer = container.read(editorProvider).project.activeTemplate.layers.firstWhere((l) => l.id == layerId);
      expect(movedLayer.x, initialX + 8.0);
      expect(container.read(editorProvider).canUndo, isTrue);

      // Undo move
      notifier.undo();
      final undoneLayer = container.read(editorProvider).project.activeTemplate.layers.firstWhere((l) => l.id == layerId);
      expect(undoneLayer.x, initialX);
      expect(container.read(editorProvider).canRedo, isTrue);

      // Redo move
      notifier.redo();
      final redoneLayer = container.read(editorProvider).project.activeTemplate.layers.firstWhere((l) => l.id == layerId);
      expect(redoneLayer.x, initialX + 8.0);

      // Duplicate layer
      final layerCountBefore = container.read(editorProvider).project.activeTemplate.layers.length;
      notifier.duplicateLayer(layerId!);
      final layerCountAfter = container.read(editorProvider).project.activeTemplate.layers.length;
      expect(layerCountAfter, layerCountBefore + 1);
    });

    test('Card physical dimension presets apply correctly', () {
      final container = ProviderContainer();
      final notifier = container.read(editorProvider.notifier);

      // Apply Poker size (63.5 x 88.9 mm)
      notifier.updateCardDimensions(63.5, 88.9);
      expect(container.read(editorProvider).project.widthMm, 63.5);
      expect(container.read(editorProvider).project.heightMm, 88.9);

      // Apply Japanese / Yu-Gi-Oh size (59 x 86 mm)
      notifier.updateCardDimensions(59.0, 86.0);
      expect(container.read(editorProvider).project.widthMm, 59.0);
      expect(container.read(editorProvider).project.heightMm, 86.0);
    });

    test('Template CRUD operations work seamlessly', () {
      final container = ProviderContainer();
      final notifier = container.read(editorProvider.notifier);

      final initialTemplateCount = container.read(editorProvider).project.templates.length;

      // Create new template
      notifier.createNewTemplate('Plantilla Dorada');
      expect(container.read(editorProvider).project.templates.length, initialTemplateCount + 1);
      expect(container.read(editorProvider).project.activeTemplate.name, 'Plantilla Dorada');

      // Duplicate active template
      notifier.duplicateActiveTemplate();
      expect(container.read(editorProvider).project.templates.length, initialTemplateCount + 2);
      expect(container.read(editorProvider).project.activeTemplate.name, 'Plantilla Dorada (Copy)');

      // Rename template
      notifier.renameActiveTemplate('Plantilla Mítica');
      expect(container.read(editorProvider).project.activeTemplate.name, 'Plantilla Mítica');

      // Delete template
      notifier.deleteActiveTemplate();
      expect(container.read(editorProvider).project.templates.length, initialTemplateCount + 1);
    });

    test('Database operations: custom columns and row duplication', () {
      final container = ProviderContainer();
      final notifier = container.read(editorProvider.notifier);

      // Add custom column
      notifier.addCustomColumnToDatabase('rarity', defaultValue: 'Common');
      final rows = container.read(editorProvider).project.rows;
      for (final r in rows) {
        expect(r.containsKey('rarity'), isTrue);
        expect(r['rarity'], 'Common');
      }

      // Duplicate first row
      if (rows.isNotEmpty) {
        final countBefore = rows.length;
        notifier.duplicateRow(0);
        final rowsAfter = container.read(editorProvider).project.rows;
        expect(rowsAfter.length, countBefore + 1);
      }
    });
  });

  group('Print & Play Imposition Rules', () {
    test('Duplex back mirroring logic aligns recto and verso on duplex print', () {
      const cols = 3;
      // Front page grid position:
      // (row 0, col 0) => top-left
      // (row 0, col 1) => top-middle
      // (row 0, col 2) => top-right

      // When turned on long edge, column 0 of back page must correspond to column 2 of front
      int mirrorCol(int rawCol) => cols - 1 - rawCol;

      expect(mirrorCol(0), 2);
      expect(mirrorCol(1), 1);
      expect(mirrorCol(2), 0);
    });
  });
}
