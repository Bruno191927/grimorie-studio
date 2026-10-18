import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/widgets/inspector_panel.dart';

void main() {
  testWidgets('Inspector displays Ajustes de Imagen when an image layer is selected', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer();

    // 1. Initial state: No layer selected -> "Ajustes de Proyecto y Carta"
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: InspectorPanel(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajustes de Proyecto y Carta'), findsOneWidget);

    // 2. Select an image layer -> "Ajustes de Imagen"
    final notifier = container.read(editorProvider.notifier);
    final imageLayer = LayerItem(
      id: 'img_test_1',
      name: 'Arte Principal',
      type: LayerType.image,
      x: 10,
      y: 10,
      width: 100,
      height: 100,
    );
    notifier.addLayer(imageLayer);
    notifier.selectLayer('img_test_1');

    await tester.pumpAndSettle();

    expect(find.text('Ajustes de Imagen'), findsOneWidget);
    expect(find.textContaining('Arte Principal'), findsWidgets);
    expect(find.text('ARTE Y ORIGEN DEL ASSET'), findsOneWidget);
    expect(find.text('APARIENCIA Y ESCALA DE IMAGEN'), findsOneWidget);
    expect(find.text('Ajustes de Proyecto y Carta'), findsNothing);

    // 3. Select a text layer -> "Ajustes de Capa"
    final textLayer = LayerItem(
      id: 'txt_test_1',
      name: 'Nombre de Criatura',
      type: LayerType.text,
      text: 'Dragón',
      x: 10,
      y: 120,
      width: 100,
      height: 30,
    );
    notifier.addLayer(textLayer);
    notifier.selectLayer('txt_test_1');

    await tester.pumpAndSettle();

    expect(find.text('Ajustes de Capa'), findsOneWidget);
    expect(find.textContaining('Nombre de Criatura'), findsWidgets);
    expect(find.text('Ajustes de Imagen'), findsNothing);

    // 4. Deselect layer -> back to "Ajustes de Proyecto y Carta"
    notifier.selectLayer(null);
    await tester.pumpAndSettle();

    expect(find.text('Ajustes de Proyecto y Carta'), findsOneWidget);
    expect(find.text('Ajustes de Imagen'), findsNothing);
    expect(find.text('Ajustes de Capa'), findsNothing);
  });
}
