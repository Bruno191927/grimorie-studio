import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/gallery/presentation/screens/card_gallery_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category Template & Layer Preservation Tests', () {
    test('Duplicated card preserves dedicated category template and custom layers when activated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorProvider.notifier);

      // 1. Create a category "Bloqueo" for game "policritics"
      const catBloqueo = GameCategory(
        id: 'cat_bloqueo',
        name: 'Bloqueo',
        icon: '🛑',
        defaultColor: 0xFFEF4444,
      );
      notifier.addCategoryToGame('policritics', catBloqueo);

      // 2. Add a card to "policritics"
      notifier.addCardToGame('policritics', cardName: 'Carta Bloqueo Base', category: 'Bloqueo');
      final rows = container.read(editorProvider).project.rows;
      final activeCardIdx = rows.length - 1;
      notifier.setActiveRow(activeCardIdx);

      // 3. Add an extra layer (e.g. Image Frame)
      const customLayer = LayerItem(
        id: 'layer_image_frame',
        name: 'Image Frame',
        type: LayerType.image,
      );
      notifier.addLayer(customLayer);

      // 4. Mark active card as default category model for "Bloqueo"
      notifier.markActiveCardAsCategoryDefault();

      final stateAfterMark = container.read(editorProvider);
      final activeTpl = stateAfterMark.project.activeTemplate;
      expect(activeTpl.id, equals('tpl_policritics_bloqueo'));
      expect(activeTpl.layers.any((l) => l.name == 'Image Frame'), isTrue);

      // 5. Duplicate the card
      notifier.duplicateCard(activeCardIdx);

      final stateAfterDup = container.read(editorProvider);
      final dupIndex = activeCardIdx + 1;
      final dupCard = stateAfterDup.project.rows[dupIndex];
      expect(dupCard['card_name'], contains('(Copia)'));
      expect(dupCard['category'], equals('Bloqueo'));

      // Check active template after duplication
      final activeTplAfterDup = stateAfterDup.project.activeTemplate;
      expect(activeTplAfterDup.id, isNot(equals('template-main')));
      expect(activeTplAfterDup.layers.any((l) => l.name == 'Image Frame'), isTrue);

      // 6. Change active row away and back to duplicated card
      notifier.setActiveRow(0); // Go to first card
      expect(container.read(editorProvider).project.activeRowIndex, equals(0));

      notifier.setActiveRow(dupIndex); // Select duplicated card
      final reloadedState = container.read(editorProvider);
      expect(reloadedState.project.activeRowIndex, equals(dupIndex));
      expect(reloadedState.project.activeTemplate.id, isNot(equals('template-main')));
      expect(reloadedState.project.activeTemplate.layers.any((l) => l.name == 'Image Frame'), isTrue);
    });

    testWidgets('Tapping a card in CardGalleryScreen activates its dedicated template, preserving custom layers', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorProvider.notifier);

      // Setup game and card with category template
      const catBloqueo = GameCategory(
        id: 'cat_bloqueo',
        name: 'Bloqueo',
        icon: '🛑',
      );
      notifier.addCategoryToGame('policritics', catBloqueo);
      notifier.addCardToGame('policritics', cardName: 'Carta Bloqueo Test', category: 'Bloqueo');
      final cardIdx = container.read(editorProvider).project.rows.length - 1;
      notifier.setActiveRow(cardIdx);

      // Add special layer
      notifier.addLayer(const LayerItem(
        id: 'special_icon_layer',
        name: 'Icono Especial',
        type: LayerType.image,
      ));
      notifier.markActiveCardAsCategoryDefault();

      // Duplicate card
      notifier.duplicateCard(cardIdx);
      final dupIdx = cardIdx + 1;

      // Force active template to template 0 as if coming from another screen
      notifier.setActiveTemplate(0);

      bool editorOpened = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardGalleryScreen(
                onOpenEditor: () {
                  editorOpened = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the duplicated card in the gallery and tap it
      final cardFinder = find.textContaining('Carta Bloqueo Test (Copia)').first;
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(editorOpened, isTrue);

      // Verify that activeTemplate is now the dedicated category template, NOT template 0
      final editorState = container.read(editorProvider);
      expect(editorState.project.activeRowIndex, equals(dupIdx));
      expect(editorState.project.activeTemplate.id, isNot(equals('template-main')));
      expect(editorState.project.activeTemplate.layers.any((l) => l.name == 'Icono Especial'), isTrue);
    });
  });
}
