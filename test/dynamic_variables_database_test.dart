import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/database/presentation/widgets/data_table_view.dart';
import 'package:grimoire_studio/features/editor/models/card_project.dart';
import 'package:grimoire_studio/features/editor/models/card_template.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';

void main() {
  test('Template variables extraction and row synchronization test', () {
    final template = CardTemplate(
      id: 'tpl_policritics',
      name: 'Policritics Template',
      layers: [
        const LayerItem(
          id: 'l1',
          name: 'imagen',
          type: LayerType.image,
          bindingKey: 'card_url',
        ),
        const LayerItem(
          id: 'l2',
          name: 'border',
          type: LayerType.image,
          bindingKey: 'art_url',
        ),
        const LayerItem(
          id: 'l3',
          name: 'title',
          type: LayerType.text,
          bindingKey: 'title_name',
          text: '{{title_name}}',
        ),
        const LayerItem(
          id: 'l4',
          name: 'Image Frame',
          type: LayerType.image,
          bindingKey: 'category_url',
        ),
        const LayerItem(
          id: 'l5',
          name: 'accion',
          type: LayerType.text,
          bindingKey: 'action_text',
          text: '{{action_text}}',
        ),
        const LayerItem(
          id: 'l6',
          name: 'frase',
          type: LayerType.text,
          bindingKey: 'frase',
          text: '{{frase}}',
        ),
      ],
    );

    final vars = template.getReferencedVariables();
    expect(vars, containsAll(['card_url', 'art_url', 'title_name', 'category_url', 'action_text', 'frase']));

    final project = CardProject(
      id: 'proj_1',
      name: 'Policritics Project',
      templates: [template],
      rows: [
        {
          'card_name': 'Nueva General',
          'game': 'policritics',
          'category': 'Congresista',
          'qty': '1',
          'type': 'Criatura',
          'rarity': 'Común',
          'attack': '',
          'defense': '',
          'cost': '',
          'rules_text': 'Habilidad especial',
          'art_url': 'assets/categorias/border.png',
        }
      ],
    );

    expect(project.getAllTemplateVariables(), containsAll(vars));
  });

  testWidgets('DataTableView dynamically displays template variables and omits unused attack/defense', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final template = CardTemplate(
      id: 'tpl_policritics_custom',
      name: 'Policritics Template',
      layers: [
        const LayerItem(
          id: 'l1',
          name: 'imagen',
          type: LayerType.image,
          bindingKey: 'card_url',
        ),
        const LayerItem(
          id: 'l2',
          name: 'title',
          type: LayerType.text,
          bindingKey: 'title_name',
        ),
        const LayerItem(
          id: 'l3',
          name: 'accion',
          type: LayerType.text,
          bindingKey: 'action_text',
        ),
        const LayerItem(
          id: 'l4',
          name: 'frase',
          type: LayerType.text,
          bindingKey: 'frase',
        ),
      ],
    );

    final container = ProviderContainer();
    final notifier = container.read(editorProvider.notifier);
    notifier.addCustomTemplate(template, setAsActive: true);

    notifier.addRow({
      'card_name': 'Nueva General',
      'game': 'policritics',
      'category': 'Congresista',
      'qty': '1',
      'type': 'Criatura',
      'rarity': 'Común',
      'attack': '',
      'defense': '',
      'cost': '',
      'rules_text': 'Habilidad especial',
    });

    notifier.syncTemplateVariablesToRows();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: DataTableView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify template variable column headers are visible
    expect(find.text('card_url'), findsOneWidget);
    expect(find.text('title_name'), findsOneWidget);
    expect(find.text('action_text'), findsOneWidget);
    expect(find.text('frase'), findsOneWidget);

    // Verify unused combat columns (attack & defense) are not shown
    expect(find.text('attack'), findsNothing);
    expect(find.text('defense'), findsNothing);
  });

  test('Card status normalization and preset identification', () {
    // 1. Default user card normalizes to Definitiva
    final userCard = GameFolderService.normalizeCardRow({
      'card_name': 'Mi Carta Definitiva',
      'game': 'policritics',
      'category': 'Congresista',
    });
    expect(userCard['card_status'], 'Definitiva');

    // 2. Predefined category default normalizes to Muestra
    final sampleCard = GameFolderService.normalizeCardRow({
      'card_name': 'Plantilla Base',
      'game': 'policritics',
      'is_category_default': 'true',
    });
    expect(sampleCard['card_status'], 'Muestra');

    // 3. Raw CSV preset/is_preset flags properly normalize to Muestra
    final csvPresetCard = GameFolderService.normalizeCardRow({
      'card_name': 'Carta de Muestra',
      'preset': 'true',
    });
    expect(csvPresetCard['card_status'], 'Muestra');

    // 4. Custom status preservation
    final customStatusCard = GameFolderService.normalizeCardRow({
      'card_name': 'Carta Final',
      'card_status': 'Definitiva',
    });
    expect(customStatusCard['card_status'], 'Definitiva');
  });
}
