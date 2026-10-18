import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/models/card_template.dart';
import 'package:grimoire_studio/features/editor/models/game_category.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category Model Isolation & Base Card Selection Tests', () {
    test('createCardFromCategory with isCategoryDefault: true and baseCard clones template and marks as default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorProvider.notifier);

      // 1. Setup a game and a base card with a custom image layer
      const baseCardTpl = CardTemplate(
        id: 'tpl_base_card',
        name: 'Base Card Template',
        layers: [
          LayerItem(
            id: 'layer_base_img',
            name: 'Arte Base',
            type: LayerType.image,
            imagePath: 'assets/hero_art.png',
            x: 0,
            y: 0,
            width: 200,
            height: 200,
          ),
        ],
      );

      final currentTemplates = List<CardTemplate>.from(container.read(editorProvider).project.templates);
      currentTemplates.add(baseCardTpl);
      container.read(editorProvider.notifier).setProject(
        container.read(editorProvider).project.copyWith(
          templates: currentTemplates,
          rows: [
            {
              'card_name': 'Carta Original',
              'game': 'Dark Fantasy',
              'category': 'Criaturas',
              'template_id': 'tpl_base_card',
            },
          ],
        ),
      );

      final baseCard = container.read(editorProvider).project.rows.first;

      // 2. Create new category with model based on baseCard
      const newCat = GameCategory(
        id: 'cat_beasts',
        name: 'Bestias',
        icon: '🐺',
        defaultColor: 0xFFEF4444,
        defaultType: 'Bestia',
      );

      notifier.createCardFromCategory(
        'Dark Fantasy',
        newCat,
        cardName: 'Bestias (Modelo)',
        isCategoryDefault: true,
        baseCard: baseCard,
      );

      final rows = container.read(editorProvider).project.rows;
      expect(rows.length, 2);

      final modelRow = rows.last;
      expect(modelRow['card_name'], 'Bestias (Modelo)');
      expect(modelRow['is_category_default'], 'true');
      expect(notifier.isRowCategoryDefault(modelRow), isTrue);

      // Verify that template was cloned with independent template and layer IDs
      final modelTemplateId = modelRow['template_id'];
      expect(modelTemplateId, isNot('tpl_base_card'));
      expect(modelTemplateId.toString().startsWith('tpl_cat_'), isTrue);

      final modelTemplate = container.read(editorProvider).project.templates.firstWhere((t) => t.id == modelTemplateId);
      expect(modelTemplate.layers.length, 1);
      expect(modelTemplate.layers.first.imagePath, 'assets/hero_art.png');
      expect(modelTemplate.layers.first.id, isNot('layer_base_img'));
    });

    test('Editing layers on a normal card below does NOT alter the category model above or other cards', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorProvider.notifier);

      const cat = GameCategory(
        id: 'cat_spells',
        name: 'Hechizos',
        icon: '⚡',
        defaultColor: 0xFF3B82F6,
        defaultType: 'Hechizo',
      );

      // Create model mockup card upstairs
      notifier.createCardFromCategory(
        'Mystic Realms',
        cat,
        cardName: 'Hechizos (Modelo)',
        isCategoryDefault: true,
      );

      final modelRow = container.read(editorProvider).project.rows.last;
      final modelTplId = modelRow['template_id'];

      // Add a custom layer to the model mockup
      notifier.setActiveRow(container.read(editorProvider).project.rows.indexOf(modelRow));
      notifier.addLayer(const LayerItem(
        id: 'layer_model_art',
        name: 'Arte Modelo',
        type: LayerType.image,
        imagePath: 'assets/default_spell.png',
      ));
      final modelLayersAfterAdd = container.read(editorProvider).project.activeTemplate.layers;
      final originalModelLayerCount = modelLayersAfterAdd.length;

      // Now create a normal playable card below from this category
      notifier.createCardFromCategory(
        'Mystic Realms',
        cat,
        cardName: 'Rayo Fulminante',
        isCategoryDefault: false,
      );

      final cardRow = container.read(editorProvider).project.rows.last;
      expect(notifier.isRowCategoryDefault(cardRow), isFalse);
      expect(cardRow['template_id'], isNot(modelTplId));

      // Activate normal card and modify its image layer content
      notifier.setActiveRow(container.read(editorProvider).project.rows.indexOf(cardRow));
      final cardActiveTpl = container.read(editorProvider).project.activeTemplate;
      final imageLayer = cardActiveTpl.layers.firstWhere((l) => l.type == LayerType.image);

      notifier.selectLayer(imageLayer.id);
      notifier.updateLayer(imageLayer.copyWith(imagePath: 'assets/lightning_bolt.png'));

      // Verify the normal card was updated
      final updatedCardTpl = container.read(editorProvider).project.activeTemplate;
      final updatedImg = updatedCardTpl.layers.firstWhere((l) => l.id == imageLayer.id);
      expect(updatedImg.imagePath, 'assets/lightning_bolt.png');

      // VERIFY ISOLATION: Check that the model mockup upstairs was NOT modified!
      final modelTpl = container.read(editorProvider).project.templates.firstWhere((t) => t.id == modelTplId);
      expect(modelTpl.layers.length, originalModelLayerCount);
      for (final l in modelTpl.layers) {
        if (l.type == LayerType.image) {
          expect(l.imagePath, isNot('assets/lightning_bolt.png'),
              reason: 'Model template must NEVER replicate image change from normal card!');
        }
      }
    });

    test('Modifying model mockup card does not mutate already created cards', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorProvider.notifier);

      const cat = GameCategory(
        id: 'cat_shields',
        name: 'Escudos',
        icon: '🛡️',
        defaultColor: 0xFF10B981,
        defaultType: 'Escudo',
      );

      // Create model
      notifier.createCardFromCategory(
        'Kingdom Defense',
        cat,
        cardName: 'Escudos (Modelo)',
        isCategoryDefault: true,
      );
      final modelRow = container.read(editorProvider).project.rows.last;

      // Create normal card
      notifier.createCardFromCategory(
        'Kingdom Defense',
        cat,
        cardName: 'Escudo de Roble',
        isCategoryDefault: false,
      );
      final normalRow = container.read(editorProvider).project.rows.last;
      final normalRowIndex = container.read(editorProvider).project.rows.indexOf(normalRow);
      final initialNormalTplId = normalRow['template_id'];

      // Edit model mockup
      notifier.setActiveRow(container.read(editorProvider).project.rows.indexOf(modelRow));
      notifier.addLayer(const LayerItem(
        id: 'layer_new_title',
        name: 'Nuevo Título',
        type: LayerType.text,
        text: 'Encabezado',
      ));

      // Normal card's template and layers remain unchanged
      final normalRowAfter = container.read(editorProvider).project.rows[normalRowIndex];
      final normalTpl = container.read(editorProvider).project.templates.firstWhere((t) => t.id == initialNormalTplId);
      expect(normalRowAfter['template_id'], initialNormalTplId);
      expect(normalTpl.layers.where((l) => l.type == LayerType.text).length,
          isNot(container.read(editorProvider).project.activeTemplate.layers.where((l) => l.type == LayerType.text).length));
    });

    test('markActiveCardAsCategoryDefault saves template for future cards without modifying existing cards', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorProvider.notifier);

      // Card 1: Existing card with custom layer
      notifier.addCardToGame('Legends', cardName: 'Guerrero Alfa', category: 'Luchadores');
      final card1Idx = 0;
      notifier.setActiveRow(card1Idx);
      notifier.addLayer(const LayerItem(
        id: 'layer_unique_to_card1',
        name: 'Alfa Shield',
        type: LayerType.image,
        imagePath: 'assets/shield_alfa.png',
      ));
      final card1LayersCount = container.read(editorProvider).project.activeTemplate.layers.length;

      // Card 2: Another card with different layer
      notifier.addCardToGame('Legends', cardName: 'Guerrero Beta', category: 'Luchadores');
      final card2Idx = 1;
      notifier.setActiveRow(card2Idx);
      notifier.addLayer(const LayerItem(
        id: 'layer_beta_sword',
        name: 'Beta Sword',
        type: LayerType.image,
        imagePath: 'assets/sword_beta.png',
      ));

      // Now mark Card 2 as Category Default!
      notifier.markActiveCardAsCategoryDefault();

      // Card 2 is now category default
      final rows = container.read(editorProvider).project.rows;
      expect(rows[card2Idx]['is_category_default'], 'true');
      expect(rows[card1Idx]['is_category_default'], isNot('true'));

      // Check Card 1: MUST NOT have changed!
      final card1Row = rows[card1Idx];
      final card1Tpl = container.read(editorProvider).project.templates.firstWhere((t) => t.id == card1Row['template_id']);
      expect(card1Tpl.layers.any((l) => l.id == 'layer_unique_to_card1'), isTrue,
          reason: 'Existing card 1 must retain its unique layer!');
      expect(card1Tpl.layers.any((l) => l.id == 'layer_beta_sword'), isFalse,
          reason: 'Existing card 1 must NEVER get contaminated by Card 2 becoming default!');
      expect(card1Tpl.layers.length, card1LayersCount);

      // Future card 3 created from category inherits the new default template
      notifier.addCardToGame('Legends', cardName: 'Guerrero Gamma', category: 'Luchadores');
      final card3Idx = 2;
      notifier.setActiveRow(card3Idx);
      final card3Tpl = container.read(editorProvider).project.activeTemplate;
      expect(card3Tpl.layers.any((l) => l.name == 'Beta Sword'), isTrue,
          reason: 'New card 3 correctly inherits the new template design from Card 2');
    });

    test('setCategoryForActiveCard preserves existing stats and does not lose existing layers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorProvider.notifier);

      notifier.addCardToGame('Magic', cardName: 'Golem Personalizado');
      notifier.setActiveRow(0);

      // Add a custom layer to the card before setting category
      notifier.addLayer(const LayerItem(
        id: 'pre_existing_layer',
        name: 'Mi Capa Especial',
        type: LayerType.text,
        text: 'Especial',
      ));

      // Give it combat stats
      notifier.updateActiveRowData('attack', '8');
      notifier.updateActiveRowData('defense', '10');
      notifier.updateActiveRowData('cost', '5');
      notifier.updateActiveRowData('rarity', 'Mítica');

      // Now change category via dropdown
      notifier.setCategoryForActiveCard('Bloqueo');

      final activeRow = container.read(editorProvider).project.activeRow;
      expect(activeRow['category'], 'Bloqueo');
      expect(activeRow['attack'], '8', reason: 'Existing attack must NOT be erased');
      expect(activeRow['defense'], '10', reason: 'Existing defense must NOT be erased');
      expect(activeRow['cost'], '5', reason: 'Existing cost must NOT be erased');
      expect(activeRow['rarity'], 'Mítica', reason: 'Existing rarity must NOT be erased');

      final activeTpl = container.read(editorProvider).project.activeTemplate;
      expect(activeTpl.layers.any((l) => l.id == 'pre_existing_layer' || l.name == 'Mi Capa Especial'), isTrue,
          reason: 'Layer created before setting category must be preserved!');
    });

    test('duplicateCard creates an independent template so editing duplicate does not mutate original', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(editorProvider.notifier);

      notifier.addCardToGame('Magic', cardName: 'Original');
      notifier.setActiveRow(0);
      notifier.addLayer(const LayerItem(
        id: 'layer_orig',
        name: 'Original Layer',
        type: LayerType.text,
        text: 'V1',
      ));

      final originalTplId = container.read(editorProvider).project.rows[0]['template_id'];
      final originalLayerCount = container.read(editorProvider).project.activeTemplate.layers.length;

      // Duplicate
      notifier.duplicateCard(0);

      final duplicateIdx = 1;
      expect(container.read(editorProvider).project.activeRowIndex, duplicateIdx);
      final duplicateRow = container.read(editorProvider).project.rows[duplicateIdx];
      expect(duplicateRow['template_id'], isNot(originalTplId),
          reason: 'Duplicate must have its own independent template ID');

      // Edit duplicate
      notifier.addLayer(const LayerItem(
        id: 'layer_only_in_copy',
        name: 'Copy Extra',
        type: LayerType.text,
        text: 'V2',
      ));

      // Verify original is untouched
      final origTpl = container.read(editorProvider).project.templates.firstWhere((t) => t.id == originalTplId);
      expect(origTpl.layers.length, originalLayerCount);
      expect(origTpl.layers.any((l) => l.id == 'layer_only_in_copy'), isFalse);
    });
  });
}
