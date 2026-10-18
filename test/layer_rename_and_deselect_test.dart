import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/widgets/layer_tree_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Layer Double Click Rename & Deselection Tests', () {
    test('setActiveRow(-1) allows clearing table row selection safely', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      expect(container.read(editorProvider).project.activeRowIndex, greaterThanOrEqualTo(0));

      // Deselect row
      notifier.setActiveRow(-1);
      expect(container.read(editorProvider).project.activeRowIndex, equals(-1));

      // activeRow getter safely returns fallback without crashing
      final active = container.read(editorProvider).project.activeRow;
      expect(active, isNotNull);
    });

    test('Creating a new LayerType.image does not bind to art_url', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      const newImgLayer = LayerItem(
        id: 'user_img_layer_test',
        name: 'Empty Image Frame',
        type: LayerType.image,
        x: 20,
        y: 40,
        width: 200,
        height: 140,
        bindingKey: '',
        imagePath: null,
      );

      notifier.addLayer(newImgLayer);
      final added = container
          .read(editorProvider)
          .project
          .activeTemplate
          .layers
          .firstWhere((l) => l.id == 'user_img_layer_test');

      expect(added.bindingKey, isEmpty);
      expect(added.imagePath, isNull);
    });

    test('updateLayer updates the layer name on rename', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      final layers = container.read(editorProvider).project.activeTemplate.layers;
      expect(layers, isNotEmpty);
      final first = layers.first;

      notifier.updateLayer(first.copyWith(name: 'Renamed Custom Layer'));
      final updated = container
          .read(editorProvider)
          .project
          .activeTemplate
          .layers
          .firstWhere((l) => l.id == first.id);

      expect(updated.name, equals('Renamed Custom Layer'));
    });

    test('selectLayer(null) clears selection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editorProvider.notifier);
      final layers = container.read(editorProvider).project.activeTemplate.layers;
      notifier.selectLayer(layers.first.id);
      expect(container.read(editorProvider).selectedLayerId, equals(layers.first.id));

      notifier.selectLayer(null);
      expect(container.read(editorProvider).selectedLayerId, isNull);
      expect(container.read(editorProvider).selectedLayerIds, isEmpty);
    });

    testWidgets('LayerTreePanel double tap on layer triggers inline rename TextField', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            themeMode: ThemeMode.dark,
            home: Scaffold(
              body: LayerTreePanel(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final layers = container.read(editorProvider).project.activeTemplate.layers;
      expect(layers, isNotEmpty);
      final firstLayerName = layers.first.name;

      // Verify layer title is rendered as Text
      final titleFinder = find.text(firstLayerName);
      expect(titleFinder, findsOneWidget);

      // Double tap on the layer title
      await tester.tap(titleFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(titleFinder);
      await tester.pumpAndSettle();

      // An inline TextField should now be present for renaming
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Enter new name and submit
      await tester.enterText(textFieldFinder, 'Super Awesome Layer');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Check layer was renamed
      final updatedLayer = container
          .read(editorProvider)
          .project
          .activeTemplate
          .layers
          .firstWhere((l) => l.id == layers.first.id);
      expect(updatedLayer.name, equals('Super Awesome Layer'));
      expect(find.text('Super Awesome Layer'), findsOneWidget);
    });
  });
}
