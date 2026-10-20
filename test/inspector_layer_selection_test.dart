import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/widgets/inspector_panel.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';

void main() {
  testWidgets('Inspector displays Ajustes de Imagen when an image layer is selected', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer();

    // 1. Initial state: No layer selected -> "Project & Card Settings"
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

    expect(find.text(AppStrings.get(AppLanguage.en, 'project_card_settings')), findsOneWidget);

    // 2. Select an image layer -> "Image Settings"
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

    expect(find.text(AppStrings.get(AppLanguage.en, 'image_settings')), findsOneWidget);
    expect(find.textContaining('Arte Principal'), findsWidgets);
    expect(find.text(AppStrings.get(AppLanguage.en, 'image_origin_source').toUpperCase()), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.en, 'image_appearance_scale').toUpperCase()), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.en, 'project_card_settings')), findsNothing);

    // 3. Select a text layer -> "Layer Settings"
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

    expect(find.text(AppStrings.get(AppLanguage.en, 'layer_settings')), findsOneWidget);
    expect(find.textContaining('Nombre de Criatura'), findsWidgets);
    expect(find.text(AppStrings.get(AppLanguage.en, 'image_settings')), findsNothing);

    // 4. Deselect layer -> back to "Project & Card Settings"
    notifier.selectLayer(null);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.get(AppLanguage.en, 'project_card_settings')), findsOneWidget);
    expect(find.text(AppStrings.get(AppLanguage.en, 'image_settings')), findsNothing);
    expect(find.text(AppStrings.get(AppLanguage.en, 'layer_settings')), findsNothing);
  });
}
