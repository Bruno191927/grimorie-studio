import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/screens/editor_screen.dart';

void main() {
  group('Layer Alignment & Distribution Unit Tests', () {
    test('Aligning single layer moves it relative to card bounds (254x355.6)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      final layer1 = LayerItem(
        id: 'layer_align_1',
        name: 'Layer 1',
        type: LayerType.text,
        x: 50,
        y: 60,
        width: 100,
        height: 40,
      );
      notifier.addLayer(layer1);
      notifier.selectLayer('layer_align_1');

      // 1. Align Left -> x = 0
      notifier.alignSelectedLayers(LayerAlignment.left);
      var updated = container.read(editorProvider).selectedLayer!;
      expect(updated.x, 0.0);

      // 2. Align Center H -> x = (254 - 100) / 2 = 77.0
      notifier.alignSelectedLayers(LayerAlignment.centerHorizontal);
      updated = container.read(editorProvider).selectedLayer!;
      expect(updated.x, 77.0);

      // 3. Align Right -> x = 254 - 100 = 154.0
      notifier.alignSelectedLayers(LayerAlignment.right);
      updated = container.read(editorProvider).selectedLayer!;
      expect(updated.x, 154.0);

      // 4. Align Top -> y = 0
      notifier.alignSelectedLayers(LayerAlignment.top);
      updated = container.read(editorProvider).selectedLayer!;
      expect(updated.y, 0.0);

      // 5. Align Center V -> y = (355.6 - 40) / 2 = 157.8
      notifier.alignSelectedLayers(LayerAlignment.centerVertical);
      updated = container.read(editorProvider).selectedLayer!;
      expect(updated.y, 157.8);

      // 6. Align Bottom -> y = 355.6 - 40 = 315.6
      notifier.alignSelectedLayers(LayerAlignment.bottom);
      updated = container.read(editorProvider).selectedLayer!;
      expect(updated.y, 315.6);
    });

    test('Aligning multiple layers moves them relative to their collective bounding box', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      final layerA = LayerItem(
        id: 'layer_a',
        name: 'Layer A',
        type: LayerType.shape,
        x: 20,
        y: 30,
        width: 50,
        height: 40,
      );
      final layerB = LayerItem(
        id: 'layer_b',
        name: 'Layer B',
        type: LayerType.shape,
        x: 80,
        y: 100,
        width: 60,
        height: 50,
      );
      notifier.addLayer(layerA);
      notifier.addLayer(layerB);

      // Multi-select both layers: A & B
      notifier.selectLayer('layer_a');
      notifier.selectLayer('layer_b', multiSelect: true);
      expect(container.read(editorProvider).selectedLayerIds.length, 2);

      // Align Left: minX is 20 -> both get x = 20
      notifier.alignSelectedLayers(LayerAlignment.left);
      var layers = container.read(editorProvider).selectedLayers;
      expect(layers.firstWhere((l) => l.id == 'layer_a').x, 20.0);
      expect(layers.firstWhere((l) => l.id == 'layer_b').x, 20.0);

      // Align Top: minY is 30 -> both get y = 30
      notifier.alignSelectedLayers(LayerAlignment.top);
      layers = container.read(editorProvider).selectedLayers;
      expect(layers.firstWhere((l) => l.id == 'layer_a').y, 30.0);
      expect(layers.firstWhere((l) => l.id == 'layer_b').y, 30.0);
    });

    test('Distribute horizontally distributes 3+ layers evenly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      final l1 = LayerItem(id: 'd1', name: 'D1', type: LayerType.text, x: 0, y: 10, width: 20, height: 20);
      final l2 = LayerItem(id: 'd2', name: 'D2', type: LayerType.text, x: 30, y: 10, width: 20, height: 20);
      final l3 = LayerItem(id: 'd3', name: 'D3', type: LayerType.text, x: 100, y: 10, width: 20, height: 20);
      notifier.addLayer(l1);
      notifier.addLayer(l2);
      notifier.addLayer(l3);

      notifier.selectLayer('d1');
      notifier.selectLayer('d2', multiSelect: true);
      notifier.selectLayer('d3', multiSelect: true);

      notifier.alignSelectedLayers(LayerAlignment.distributeHorizontal);

      final layers = container.read(editorProvider).selectedLayers;
      final sorted = List<LayerItem>.from(layers)..sort((a, b) => a.x.compareTo(b.x));
      // First is at 0, last right edge at 120. Total width = 60. Remaining span = 60. Gap = 30.
      expect(sorted[0].x, 0.0);
      expect(sorted[1].x, 50.0); // 0 + 20 + 30
      expect(sorted[2].x, 100.0); // 50 + 20 + 30
    });
  });

  group('Layer Clipboard & Duplication Unit Tests', () {
    test('Copy and paste selected layers creates new unique layers with offset', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      final original = LayerItem(
        id: 'orig_layer',
        name: 'Original Title',
        type: LayerType.text,
        x: 15,
        y: 25,
        width: 100,
        height: 30,
      );
      notifier.addLayer(original);
      notifier.selectLayer('orig_layer');

      // Copy layer
      final copiedCount = notifier.copySelectedLayers();
      expect(copiedCount, 1);
      expect(container.read(editorProvider).hasClipboardLayers, true);

      // Paste layer
      notifier.pasteLayers();

      final state = container.read(editorProvider);
      final allLayers = state.project.activeTemplate.getLayers(state.currentSide);
      expect(allLayers.length, greaterThan(1));

      // Newly pasted layer is selected and offset by (+12, +12)
      final pasted = state.selectedLayer!;
      expect(pasted.id, isNot('orig_layer'));
      expect(pasted.name, 'Original Title');
      expect(pasted.x, 27.0); // 15 + 12
      expect(pasted.y, 37.0); // 25 + 12
    });

    test('Duplicate active card row creates isolated copy in 1-click', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      notifier.addRow({'card_name': 'Dragón de Fuego', 'game': 'Magic'});
      final initialCount = container.read(editorProvider).project.rows.length;

      // Duplicate active row (index 0)
      notifier.duplicateRow(0);

      final updatedState = container.read(editorProvider);
      expect(updatedState.project.rows.length, initialCount + 1);
      final duplicatedRow = updatedState.project.rows[1];
      expect(duplicatedRow['card_name'], contains('(Copy)'));
      // Template is duplicated and isolated
      expect(duplicatedRow['template_id'], isNotNull);
    });
  });

  group('Editor UI & Toolbar Widget Tests', () {
    testWidgets('1-click duplicate card button in Editor toolbar duplicates card and shows toast', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      container.read(editorProvider.notifier).addRow({'card_name': 'Dragón de Fuego', 'game': 'Magic'});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EditorScreen(repaintBoundaryKey: GlobalKey()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find 1-click duplicate card button in top bar
      final duplicateBtn = find.byKey(const Key('editor_duplicate_card_button'));
      expect(duplicateBtn, findsOneWidget);

      final rowsBefore = container.read(editorProvider).project.rows.length;

      // Click duplicate card button
      await tester.tap(duplicateBtn);
      await tester.pumpAndSettle();

      final rowsAfter = container.read(editorProvider).project.rows.length;
      expect(rowsAfter, rowsBefore + 1);

      // SnackBar confirmation is displayed
      expect(find.text('Carta duplicada con éxito'), findsOneWidget);
    });
  });
}
