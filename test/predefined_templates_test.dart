import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/card_template.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/dialogs/predefined_templates_dialog.dart';
import 'package:grimoire_studio/features/editor/presentation/screens/editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Predefined Templates & Default Card Structure Tests', () {
    test('CardTemplate.createDefault() has the exact structure: fondo, titulo, imagen, shape, descripcion', () {
      final template = CardTemplate.createDefault();

      expect(template.layers.length, 5);
      final layerNames = template.layers.map((l) => l.name.toLowerCase()).toList();
      expect(layerNames, ['fondo', 'titulo', 'imagen', 'shape', 'descripcion']);

      // 1. fondo (background layer)
      final fondo = template.layers[0];
      expect(fondo.type, LayerType.background);
      expect(fondo.isLocked, true);

      // 2. titulo (text layer for card name at top)
      final titulo = template.layers[1];
      expect(titulo.type, LayerType.text);
      expect(titulo.bindingKey, 'card_name');
      expect(titulo.y, lessThan(fondo.height / 4));

      // 3. imagen (image layer in middle)
      final imagen = template.layers[2];
      expect(imagen.type, LayerType.image);
      expect(imagen.bindingKey, 'art_url');
      expect(imagen.y, greaterThan(titulo.y));

      // 4. shape (shape layer at bottom for description container)
      final shape = template.layers[3];
      expect(shape.type, LayerType.shape);
      expect(shape.y, greaterThan(imagen.y));

      // 5. descripcion (text layer rendered on top of shape)
      final descripcion = template.layers[4];
      expect(descripcion.type, LayerType.text);
      expect(descripcion.bindingKey, 'rules_text');
      // Positioned within the bounds of the shape
      expect(descripcion.y, greaterThanOrEqualTo(shape.y));
      expect(descripcion.y + descripcion.height, lessThanOrEqualTo(shape.y + shape.height + 10));

      // Layers list ordering guarantees descripcion renders above shape
      final shapeIndex = template.layers.indexOf(shape);
      final descIndex = template.layers.indexOf(descripcion);
      expect(descIndex, greaterThan(shapeIndex));
    });

    test('CardTemplate.predefinedPresets contains all styles including Default with badge', () {
      final presets = CardTemplate.predefinedPresets;
      expect(presets.length, greaterThanOrEqualTo(6));

      final defaultPreset = presets.firstWhere((p) => p.id == 'default');
      expect(defaultPreset.name, 'Default');
      expect(defaultPreset.badge, 'Default');
      expect(defaultPreset.isDefault, true);

      final presetIds = presets.map((p) => p.id).toSet();
      expect(presetIds.contains('default'), isTrue);
      expect(presetIds.contains('tcgFantasy'), isTrue);
      expect(presetIds.contains('boardgameAction'), isTrue);
      expect(presetIds.contains('tarotHero'), isTrue);
      expect(presetIds.contains('cyberpunk'), isTrue);
      expect(presetIds.contains('minimalist'), isTrue);
    });

    test('CardTemplate.getPresetById returns valid templates for all preset IDs', () {
      for (final preset in CardTemplate.predefinedPresets) {
        final tpl = CardTemplate.getPresetById(preset.id);
        expect(tpl, isNotNull);
        expect(tpl.layers.isNotEmpty, isTrue);
      }
    });

    test('Adding card to a brand-new game does NOT inherit previous game layers and uses clean default structure', () {
      final container = ProviderContainer();
      final notifier = container.read(editorProvider.notifier);

      // Game "rata-critics" does not exist yet
      notifier.addCardToGame('rata-critics');

      final state = container.read(editorProvider);
      final rataCards = state.project.rows.where((r) => r['game'] == 'rata-critics').toList();
      expect(rataCards.length, 1);

      final card = rataCards.first;
      final template = notifier.resolveTemplateForRow(card);

      // Verify the template has the clean default structure
      final names = template.layers.map((l) => l.name.toLowerCase()).toList();
      expect(names, contains('titulo'));
      expect(names, contains('imagen'));
      expect(names, contains('shape'));
      expect(names, contains('descripcion'));

      // Verify it does NOT contain customized layers from other games (like policritics borde or fondo_titulo)
      expect(names.contains('borde'), isFalse);
      expect(names.contains('fondo_titulo'), isFalse);
      expect(names.contains('fondo_descripcion'), isFalse);
    });

    test('Adding card to a brand-new game with presetTemplateId applies that preset', () {
      final container = ProviderContainer();
      final notifier = container.read(editorProvider.notifier);

      notifier.addCardToGame('cyber-deck', presetTemplateId: 'cyberpunk');

      final state = container.read(editorProvider);
      final cyberCards = state.project.rows.where((r) => r['game'] == 'cyber-deck').toList();
      expect(cyberCards.length, 1);

      final card = cyberCards.first;
      final template = notifier.resolveTemplateForRow(card);
      final names = template.layers.map((l) => l.name).toList();

      expect(names, contains('Marco Neón'));
      expect(names, contains('Cyber Título'));
      expect(names, contains('Holo Arte'));
      expect(names, contains('Caja de Datos'));
    });

    testWidgets('PredefinedTemplatesDialog displays header, presets with Default badge, and applies selection', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      CardTemplate? selectedTemplate;
      PredefinedTemplateAction? selectedAction;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => PredefinedTemplatesDialog.show(
                    context,
                    onTemplateSelected: (tpl, action) {
                      selectedTemplate = tpl;
                      selectedAction = action;
                    },
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Title and Subtitle
      expect(find.text('Agregar plantilla predefinida'), findsOneWidget);
      expect(find.textContaining('Selecciona un estilo base'), findsOneWidget);

      // Verify Default card with badge
      expect(find.text('Default'), findsWidgets);
      expect(find.text('TCG Fantasía'), findsWidgets);
      expect(find.textContaining('Juego de Mesa'), findsWidgets);
      expect(find.text('Tarot / Héroe'), findsWidgets);

      // Select TCG Fantasía
      await tester.tap(find.text('TCG Fantasía').first);
      await tester.pump();

      // Tap Confirm/Use Template button
      final confirmBtn = find.byKey(const Key('btn_confirm_predefined_template'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(selectedTemplate, isNotNull);
      expect(selectedAction, PredefinedTemplateAction.replaceActive);
    });

    testWidgets('EditorScreen toolbar has quick button and template menu has Agregar plantilla predefinida', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: EditorScreen(repaintBoundaryKey: GlobalKey()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Quick button on toolbar
      final quickBtnFinder = find.byTooltip('Agregar plantilla predefinida');
      expect(quickBtnFinder, findsOneWidget);

      // 2. Open template actions popup menu
      final menuFinder = find.byKey(const Key('template_actions_menu'));
      expect(menuFinder, findsOneWidget);
      await tester.tap(menuFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify menu contains "Agregar plantilla predefinida" and presets
      expect(find.text('Agregar plantilla predefinida'), findsWidgets);
      expect(find.text('Default (Estándar)'), findsOneWidget);
      expect(find.text('TCG Fantasía / Criatura'), findsOneWidget);
    });
  });
}
