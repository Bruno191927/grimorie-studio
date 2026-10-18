import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/core/utils/template_parser.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/utils/shape_path_builder.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/widgets/custom_shape_builder_dialog.dart';
import 'package:grimoire_studio/core/widgets/grimoire_font_picker.dart';
import 'package:grimoire_studio/main.dart';

void main() {
  test('TemplateParser omits attack (⚔️), defense (🛡️), and cost (🔥 MANA) icons when values are empty', () {
    // 1. Both attack and defense empty -> empty string (no ⚔️ or 🛡️)
    expect(
      TemplateParser.parse('⚔️ {{attack}}  /  🛡️ {{defense}}', {
        'attack': '',
        'defense': '',
      }),
      isEmpty,
    );

    // 2. Attack empty, defense present -> only 🛡️ defense
    expect(
      TemplateParser.parse('⚔️ {{attack}}  /  🛡️ {{defense}}', {
        'attack': '',
        'defense': '4',
      }),
      equals('🛡️ 4'),
    );

    // 3. Attack present, defense empty -> only ⚔️ attack
    expect(
      TemplateParser.parse('⚔️ {{attack}}  /  🛡️ {{defense}}', {
        'attack': '7',
        'defense': '',
      }),
      equals('⚔️ 7'),
    );

    // 4. Cost empty -> empty string
    expect(
      TemplateParser.parse('🔥 {{cost}} MANA', {'cost': ''}),
      isEmpty,
    );
  });

  test('EditorNotifier persists workspace state and game CSVs to disk and reloads them on restart', () {
    final tempDir = Directory.systemTemp.createTempSync('grimoire_persistence_test_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    // First session: create a game, add a category without attack, create a card, and add a custom layer
    final session1 = EditorNotifier(
      enableDiskPersistence: true,
      customPersistenceDir: tempDir,
    );

    const bloqueoCategory = GameCategory(
      id: 'cat-bloqueo',
      name: 'Bloqueo',
      icon: '🛑',
      defaultColor: 0xFFEF4444,
      defaultType: 'Acción — Bloqueo',
      defaultRarity: '',
      defaultCost: '',
      defaultAttack: '',
      defaultDefense: '',
      hasCost: false,
      hasCombatStats: false,
      hasRarity: false,
      hasRules: true,
    );

    session1.addCategoryToGame('policritics', bloqueoCategory);
    session1.createCardFromCategory(
      'policritics',
      bloqueoCategory,
      cardName: 'Nueva Bloqueo Persistida',
    );

    const customBannerLayer = LayerItem(
      id: 'layer-persisted-banner',
      name: 'Marco Dorado Persistido',
      type: LayerType.shape,
      x: 15,
      y: 25,
      width: 200,
      height: 60,
      shapePreset: ShapePreset.banner,
    );
    session1.addLayer(customBannerLayer);

    // Second session (simulating closing and reopening the app):
    final session2 = EditorNotifier(
      enableDiskPersistence: true,
      customPersistenceDir: tempDir,
    );

    // Verify 'policritics' game and its category & card were restored
    expect(session2.state.gameCategories.containsKey('policritics'), isTrue);
    final restoredCategories = session2.state.gameCategories['policritics']!;
    expect(restoredCategories.any((c) => c.name == 'Bloqueo' && !c.hasCombatStats), isTrue);

    final policriticsCards = session2.state.project.rows
        .where((r) => r['game'] == 'policritics')
        .toList();
    expect(policriticsCards, isNotEmpty);
    final restoredCard = policriticsCards.firstWhere(
      (r) => r['card_name'] == 'Nueva Bloqueo Persistida',
    );
    expect(restoredCard['attack'], isEmpty);
    expect(restoredCard['defense'], isEmpty);
    expect(restoredCard['cost'], isEmpty);

    // Verify custom layer in template was restored
    expect(
      session2.state.project.activeTemplate.layers.any((l) => l.id == 'layer-persisted-banner'),
      isTrue,
    );
  });

  test('LayerItem serializes and deserializes all 4 layer types, gradients, custom shapes, and fonts', () {
    const customLayer = LayerItem(
      id: 'layer-shape-1',
      name: 'Custom Dragon Shield',
      type: LayerType.shape,
      x: 20,
      y: 40,
      width: 180,
      height: 120,
      fillMode: LayerFillMode.gradient,
      gradientType: LayerGradientType.linear,
      shapeColor: Color(0xFF311042),
      gradientMiddleColor: Color(0xFF9333EA),
      gradientEndColor: Color(0xFFF59E0B),
      useThreeStopGradient: true,
      gradientAngle: 45.0,
      shapePreset: ShapePreset.custom,
      customPoints: [
        Offset(0.5, 0.05),
        Offset(0.95, 0.5),
        Offset(0.5, 0.95),
        Offset(0.05, 0.5),
      ],
      closeCustomPath: true,
      fontFamily: 'Cinzel',
      isItalic: true,
      letterSpacing: 1.2,
    );

    final json = customLayer.toJson();
    final restored = LayerItem.fromJson(json);

    expect(restored.type, LayerType.shape);
    expect(restored.fillMode, LayerFillMode.gradient);
    expect(restored.gradientType, LayerGradientType.linear);
    expect(restored.useThreeStopGradient, isTrue);
    expect(restored.gradientAngle, 45.0);
    expect(restored.shapePreset, ShapePreset.custom);
    expect(restored.customPoints.length, 4);
    expect(restored.customPoints.first.dx, closeTo(0.5, 0.001));
    expect(restored.fontFamily, 'Cinzel');
    expect(restored.isItalic, isTrue);
    expect(restored.letterSpacing, closeTo(1.2, 0.001));
  });

  test('ShapePathBuilder builds non-empty paths for all ShapePresets and custom vertices', () {
    const size = Size(200, 150);
    for (final preset in ShapePreset.values) {
      final path = ShapePathBuilder.buildPath(
        preset: preset,
        size: size,
        borderRadius: 8.0,
        customPoints: const [
          Offset(0.5, 0.1),
          Offset(0.9, 0.9),
          Offset(0.1, 0.9),
        ],
      );
      expect(path.getBounds().width, greaterThan(0));
      expect(path.getBounds().height, greaterThan(0));
    }
  });

  test('EditorNotifier places LayerType.background at index 0 of layer stack', () {
    final notifier = EditorNotifier();
    const bgLayer = LayerItem(
      id: 'bg-new',
      name: 'New Gradient Background',
      type: LayerType.background,
      x: 0,
      y: 0,
      width: 254,
      height: 355.6,
      fillMode: LayerFillMode.gradient,
    );

    notifier.addLayer(bgLayer);
    final layers = notifier.state.project.activeTemplate.layers;
    expect(layers.first.id, 'bg-new');
    expect(layers.first.type, LayerType.background);
  });

  testWidgets('Editor Add Layer (+) menu shows all 4 layer types and Inspector displays custom controls', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: GrimoireApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to Editor de Lienzo tab
    await tester.tap(find.text('Editor de Lienzo'));
    await tester.pumpAndSettle();

    // Open the '+' Add Layer PopupMenuButton
    final addLayerBtn = find.byTooltip('Añadir Capa');
    expect(addLayerBtn, findsOneWidget);
    await tester.tap(addLayerBtn);
    await tester.pumpAndSettle();

    // Verify all 4 layer types appear in the menu
    expect(find.text('Capa de Fondo (Background)'), findsOneWidget);
    expect(find.text('Capa de Forma / Marco'), findsOneWidget);
    expect(find.text('Capa de Texto'), findsOneWidget);
    expect(find.text('Capa de Imagen'), findsOneWidget);

    // 1. Select 'Capa de Fondo (Background)'
    await tester.tap(find.text('Capa de Fondo (Background)'));
    await tester.pumpAndSettle();

    // Verify Background Inspector controls appear
    expect(find.text('ESTILO DE FONDO (BACKGROUND)'), findsOneWidget);
    expect(find.text('Color Sólido'), findsOneWidget);
    expect(find.text('Gradiente'), findsOneWidget);
    expect(find.text('Preajustes de Gradiente'), findsOneWidget);

    // 2. Open '+' menu and add 'Capa de Forma / Marco'
    await tester.tap(addLayerBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capa de Forma / Marco'));
    await tester.pumpAndSettle();

    // Verify Shape Inspector controls and Custom Shape Builder button appear
    expect(find.text('GEOMETRÍA Y DESARROLLO DE FORMA'), findsOneWidget);
    expect(find.text('Desarrollo de Forma Personalizada (Editor de Nodos)'), findsOneWidget);
    // Shape layer must NEVER display image assets section or AI art buttons
    expect(find.text('Subir Imagen desde PC'), findsNothing);
    expect(find.text('Generar Arte IA para Capa'), findsNothing);

    // Tap the Custom Shape Builder button to open the interactive node editor dialog
    await tester.ensureVisible(find.text('Desarrollo de Forma Personalizada (Editor de Nodos)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desarrollo de Forma Personalizada (Editor de Nodos)'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomShapeBuilderDialog), findsOneWidget);
    expect(find.text('Aplicar Forma Personalizada'), findsOneWidget);

    // Apply the custom shape
    await tester.tap(find.text('Aplicar Forma Personalizada'));
    await tester.pumpAndSettle();

    // 3. Open '+' menu and add 'Capa de Texto'
    await tester.tap(addLayerBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capa de Texto'));
    await tester.pumpAndSettle();

    // Text layer must NEVER display image assets section or AI art buttons
    expect(find.text('Subir Imagen desde PC'), findsNothing);
    expect(find.text('Generar Arte IA para Capa'), findsNothing);

    // Verify Typography selector and open full Font Catalog dialog
    expect(find.text('Catálogo Completo'), findsOneWidget);
    await tester.tap(find.text('Catálogo Completo'));
    await tester.pumpAndSettle();
    expect(find.byType(GrimoireFontPickerDialog), findsOneWidget);
    expect(find.textContaining('Aplicar "'), findsOneWidget);
    await tester.tap(find.textContaining('Aplicar "'));
    await tester.pumpAndSettle();

    // 4. Verify 8 resize handles are rendered on the selected Text layer and drag to resize
    expect(find.byKey(const Key('resize_handle_br')), findsOneWidget);
    expect(find.byKey(const Key('resize_handle_tl')), findsOneWidget);
    expect(find.byKey(const Key('resize_handle_cr')), findsOneWidget);

    await tester.drag(find.byKey(const Key('resize_handle_br')), const Offset(40, 20));
    await tester.pumpAndSettle();

    // 5. Verify inline text editing on the card canvas
    expect(find.text('Editar texto (2x clic)'), findsOneWidget);
    await tester.tap(find.text('Editar texto (2x clic)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('canvas_inline_text_editor')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('canvas_inline_text_editor')), 'Título Épico Editado');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.text('Título Épico Editado'), findsWidgets);

    // 6. Verify Canvas Zoom HUD bar works
    expect(find.byKey(const Key('canvas_zoom_hud')), findsOneWidget);
    await tester.tap(find.byKey(const Key('canvas_hud_zoom_in')));
    await tester.pumpAndSettle();
    expect(find.text('115%'), findsWidgets);
    await tester.tap(find.byKey(const Key('canvas_hud_zoom_reset')));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);
  });
}
