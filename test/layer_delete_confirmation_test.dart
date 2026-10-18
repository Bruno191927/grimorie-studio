import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/dialogs/layer_delete_dialog.dart';
import 'package:grimoire_studio/features/editor/presentation/screens/editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Layer Delete Confirmation & Keyboard Shortcut Tests', () {
    testWidgets('LayerDeleteDialog shows confirmation popup and cancels correctly', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testLayer = LayerItem(
        id: 'test_layer_delete_1',
        name: 'Marco Heroico',
        type: LayerType.shape,
        x: 10,
        y: 10,
        width: 100,
        height: 100,
      );

      container.read(editorProvider.notifier).addLayer(testLayer);
      container.read(editorProvider.notifier).selectLayer('test_layer_delete_1');

      bool? dialogResult;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    dialogResult = await LayerDeleteDialog.show(context: ctx, ref: ref);
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Trigger dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify popup content
      expect(find.text('¿Eliminar capa?'), findsOneWidget);
      expect(find.textContaining('¿Estás seguro de que deseas borrar la capa "Marco Heroico"?'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);

      // Layer should still exist
      final layers = container.read(editorProvider).project.activeTemplate.layers;
      expect(layers.any((l) => l.id == 'test_layer_delete_1'), isTrue);
    });

    testWidgets('LayerDeleteDialog deletes layer on confirm and updates selection', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testLayer = LayerItem(
        id: 'test_layer_delete_2',
        name: 'Icono Espada',
        type: LayerType.shape,
        x: 20,
        y: 20,
        width: 40,
        height: 40,
      );

      container.read(editorProvider.notifier).addLayer(testLayer);
      container.read(editorProvider.notifier).selectLayer('test_layer_delete_2');

      bool? dialogResult;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    dialogResult = await LayerDeleteDialog.show(context: ctx, ref: ref);
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Click button to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar capa?'), findsOneWidget);
      expect(find.textContaining('¿Estás seguro de que deseas borrar la capa "Icono Espada"?'), findsOneWidget);

      // Click Delete
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);

      // Layer should now be deleted
      final layers = container.read(editorProvider).project.activeTemplate.layers;
      expect(layers.any((l) => l.id == 'test_layer_delete_2'), isFalse);
      expect(container.read(editorProvider).selectedLayerId, isNull);
    });

    testWidgets('Background layer deletion is blocked', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bgLayer = container.read(editorProvider).project.activeTemplate.layers.firstWhere(
            (l) => l.type == LayerType.background,
          );

      container.read(editorProvider.notifier).selectLayer(bgLayer.id);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => LayerDeleteDialog.show(context: ctx, ref: ref),
                  child: const Text('Try Delete BG'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Try Delete BG'));
      await tester.pumpAndSettle();

      // No confirmation popup should be shown for background layer
      expect(find.text('¿Eliminar capa?'), findsNothing);
      expect(find.text('La capa de fondo no se puede eliminar (solo editar).'), findsOneWidget);
    });

    testWidgets('Pressing Delete key in EditorScreen opens confirmation popup for selected layer', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testLayer = LayerItem(
        id: 'shortcut_test_layer',
        name: 'Texto Leyenda',
        type: LayerType.text,
        x: 10,
        y: 10,
        width: 100,
        height: 30,
      );

      container.read(editorProvider.notifier).addLayer(testLayer);
      container.read(editorProvider.notifier).selectLayer('shortcut_test_layer');

      final key = GlobalKey();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EditorScreen(repaintBoundaryKey: key),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Send LogicalKeyboardKey.delete (Suprimir)
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      // Confirmation dialog must appear
      expect(find.text('¿Eliminar capa?'), findsOneWidget);
      expect(find.textContaining('¿Estás seguro de que deseas borrar la capa "Texto Leyenda"?'), findsOneWidget);

      // Confirm delete
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      // Layer deleted
      final layers = container.read(editorProvider).project.activeTemplate.layers;
      expect(layers.any((l) => l.id == 'shortcut_test_layer'), isFalse);
    });

    testWidgets('Pressing Backspace key in EditorScreen also opens confirmation popup for selected layer', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testLayer = LayerItem(
        id: 'backspace_test_layer',
        name: 'Marco Dorado',
        type: LayerType.shape,
        x: 15,
        y: 15,
        width: 80,
        height: 80,
      );

      container.read(editorProvider.notifier).addLayer(testLayer);
      container.read(editorProvider.notifier).selectLayer('backspace_test_layer');

      final key = GlobalKey();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EditorScreen(repaintBoundaryKey: key),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Send LogicalKeyboardKey.backspace
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      // Confirmation dialog must appear
      expect(find.text('¿Eliminar capa?'), findsOneWidget);
      expect(find.textContaining('¿Estás seguro de que deseas borrar la capa "Marco Dorado"?'), findsOneWidget);

      // Confirm delete
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      // Layer deleted
      final layers = container.read(editorProvider).project.activeTemplate.layers;
      expect(layers.any((l) => l.id == 'backspace_test_layer'), isFalse);
    });

    testWidgets('Backspace key deletes letter by letter when inline editing on canvas', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testLayer = LayerItem(
        id: 'test_inline_backspace',
        name: 'Titulo Carta',
        type: LayerType.text,
        text: 'Dragon',
        x: 10,
        y: 10,
        width: 150,
        height: 40,
      );

      container.read(editorProvider.notifier).addLayer(testLayer);
      container.read(editorProvider.notifier).selectLayer('test_inline_backspace');

      final key = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EditorScreen(repaintBoundaryKey: key),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter inline text editing
      final editButton = find.text('Editar texto (2x clic)');
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      final inlineField = find.byKey(const Key('canvas_inline_text_editor'));
      expect(inlineField, findsOneWidget);

      final tf = tester.widget<TextField>(inlineField);
      expect(tf.controller?.text, equals('Dragon'));

      // Move cursor to end (after 'n')
      tf.controller?.selection = const TextSelection.collapsed(offset: 6);

      // Send Backspace key event
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(tf.controller?.text, equals('Drago'));

      // Send another Backspace key event
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(tf.controller?.text, equals('Drag'));
    });

    testWidgets('Backspace key deletes letter by letter in Inspector text field', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testLayer = LayerItem(
        id: 'test_inspector_backspace',
        name: 'Titulo Inspector',
        type: LayerType.text,
        text: 'Dragon',
        x: 10,
        y: 10,
        width: 150,
        height: 40,
      );

      container.read(editorProvider.notifier).addLayer(testLayer);
      container.read(editorProvider.notifier).selectLayer('test_inspector_backspace');

      final key = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EditorScreen(repaintBoundaryKey: key),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inspectorField = find.byKey(const ValueKey('text_test_inspector_backspace'));
      expect(inspectorField, findsOneWidget);

      await tester.tap(inspectorField);
      await tester.pumpAndSettle();

      final editableTextFinder = find.descendant(of: inspectorField, matching: find.byType(EditableText));
      final editableTextState = tester.state<EditableTextState>(editableTextFinder);
      editableTextState.updateEditingValue(const TextEditingValue(
        text: 'Dragon',
        selection: TextSelection.collapsed(offset: 6),
      ));
      await tester.pumpAndSettle();

      // Send Backspace key event
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(editableTextState.textEditingValue.text, equals('Drago'));

      // Send another Backspace key event
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(editableTextState.textEditingValue.text, equals('Drag'));
    });
  });
}
