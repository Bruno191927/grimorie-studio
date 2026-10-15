import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../models/card_project.dart';
import '../../models/card_template.dart';
import '../../models/layer_item.dart';

class EditorState {
  final CardProject project;
  final String? selectedLayerId;
  final double zoom;
  final bool showGrid;
  final bool showSnapping;
  final bool isGeneratingAi;

  const EditorState({
    required this.project,
    this.selectedLayerId,
    this.zoom = 1.0,
    this.showGrid = true,
    this.showSnapping = true,
    this.isGeneratingAi = false,
  });

  LayerItem? get selectedLayer {
    if (selectedLayerId == null) return null;
    final layers = project.activeTemplate.layers;
    final index = layers.indexWhere((l) => l.id == selectedLayerId);
    return index != -1 ? layers[index] : null;
  }

  EditorState copyWith({
    CardProject? project,
    String? selectedLayerId,
    bool clearSelectedLayer = false,
    double? zoom,
    bool? showGrid,
    bool? showSnapping,
    bool? isGeneratingAi,
  }) {
    return EditorState(
      project: project ?? this.project,
      selectedLayerId: clearSelectedLayer ? null : (selectedLayerId ?? this.selectedLayerId),
      zoom: zoom ?? this.zoom,
      showGrid: showGrid ?? this.showGrid,
      showSnapping: showSnapping ?? this.showSnapping,
      isGeneratingAi: isGeneratingAi ?? this.isGeneratingAi,
    );
  }
}

class EditorNotifier extends StateNotifier<EditorState> {
  EditorNotifier() : super(_createInitialState());

  static EditorState _createInitialState() {
    const uuid = Uuid();

    // Default template with realistic tabletop layers
    final defaultLayers = [
      // 1. Background Frame
      LayerItem(
        id: uuid.v4(),
        name: 'Card Background',
        type: LayerType.shape,
        x: 0,
        y: 0,
        width: 254, // in canvas units (~63.5mm * 4)
        height: 355.6, // in canvas units (~88.9mm * 4)
        shapeColor: const Color(0xFF131622),
        borderColor: const Color(0xFF23283E),
        borderWidth: 2,
        borderRadius: 16,
        isLocked: true,
      ),
      // 2. Illustration Area
      LayerItem(
        id: uuid.v4(),
        name: 'Art Artwork',
        type: LayerType.shape,
        x: 14,
        y: 45,
        width: 226,
        height: 160,
        shapeColor: const Color(0xFFF59E0B),
        borderColor: const Color(0xFF7C3AED),
        borderWidth: 1.5,
        borderRadius: 12,
        bindingKey: 'art_url',
      ),
      // 3. Mana Cost Badge
      LayerItem(
        id: uuid.v4(),
        name: 'Cost Badge',
        type: LayerType.text,
        x: 16,
        y: 12,
        width: 70,
        height: 24,
        text: '🔥 {{cost}} MANA',
        bindingKey: 'cost',
        fontSize: 11,
        isBold: true,
        fontColor: const Color(0xFFE9D5FF),
      ),
      // 4. Card Title
      LayerItem(
        id: uuid.v4(),
        name: 'Card Title',
        type: LayerType.text,
        x: 95,
        y: 12,
        width: 145,
        height: 24,
        text: '{{card_name}}',
        bindingKey: 'card_name',
        fontSize: 13,
        isBold: true,
        fontColor: Colors.white,
        textAlign: TextAlign.right,
      ),
      // 5. Rules Text Box Shape
      LayerItem(
        id: uuid.v4(),
        name: 'Rules Box Shape',
        type: LayerType.shape,
        x: 14,
        y: 215,
        width: 226,
        height: 90,
        shapeColor: const Color(0xFF0F121D),
        borderColor: const Color(0xFF1E2337),
        borderWidth: 1,
        borderRadius: 10,
      ),
      // 6. Rules Text Layer
      LayerItem(
        id: uuid.v4(),
        name: 'Rules Text',
        type: LayerType.text,
        x: 20,
        y: 222,
        width: 214,
        height: 75,
        text: '{{rules_text}}',
        bindingKey: 'rules_text',
        fontSize: 11,
        fontColor: const Color(0xFFCBD5E1),
      ),
      // 7. Power / Toughness Badge
      LayerItem(
        id: uuid.v4(),
        name: 'ATK / DEF Stats',
        type: LayerType.text,
        x: 150,
        y: 315,
        width: 90,
        height: 25,
        text: '⚔️ {{attack}} / 🛡️ {{defense}}',
        fontSize: 11,
        isBold: true,
        fontColor: const Color(0xFFFBBF24),
        textAlign: TextAlign.right,
      ),
    ];

    final defaultTemplate = CardTemplate(
      id: 'template-main',
      name: 'Standard Creature Frame',
      layers: defaultLayers,
    );

    // Sample data rows inspired by the reference image
    final sampleRows = [
      {
        'card_name': 'Flame Dress',
        'cost': '5',
        'type': 'Creature',
        'rarity': 'Mythic',
        'attack': '4',
        'defense': '3',
        'creator': 'Tyler Covington',
        'bid': '4.89 ETH',
        'chain': 'BSC',
        'icon': '🤖',
        'art_color': 0xFFF59E0B,
        'rules_text': 'When summoned, deals 3 damage to any target. If cost > 5, ignite enemy battlefield.',
        'prompt': 'Cute 3D robot character wearing futuristic glass helmet, miniature stylized tabletop figurine',
      },
      {
        'card_name': 'Hamlet Contemplates',
        'cost': '3',
        'type': 'Creature',
        'rarity': 'Rare',
        'attack': '2',
        'defense': '5',
        'creator': 'Freddie Carpeter',
        'bid': '4.89 ETH',
        'chain': 'BSC',
        'icon': '🐼',
        'art_color': 0xFFEAB308,
        'rules_text': 'Defender. At end of turn, draw 1 card if no damage was taken.',
        'prompt': 'Small cylindrical cyber panda robot contemplating on a minimalist platform, round aesthetic',
      },
      {
        'card_name': 'Loving Vase 01',
        'cost': '7',
        'type': 'Creature',
        'rarity': 'Mythic',
        'attack': '8',
        'defense': '6',
        'creator': 'Tyler Covington',
        'bid': '4.89 ETH',
        'chain': 'BSC',
        'icon': '🐻',
        'art_color': 0xFFEA580C,
        'rules_text': 'Trample. Whenever this creature attacks, gain 3 life.',
        'prompt': 'Stylized warm brown standing bear toy figure, glossy vinyl toy, tabletop mini',
      },
      {
        'card_name': 'Triumphant Awakening',
        'cost': '2',
        'type': 'Spell',
        'rarity': 'Common',
        'attack': '1',
        'defense': '3',
        'creator': 'Tyler Covington',
        'bid': '4.89 ETH',
        'chain': 'BSC',
        'icon': '🌱',
        'art_color': 0xFF16A34A,
        'rules_text': 'Target allied creature gets +2/+2 and vigilance until end of turn.',
        'prompt': 'Cute anthropomorphic plant sprout creature with leafy ears sticking out tongue',
      },
      {
        'card_name': 'Forest Nymph Stalker',
        'cost': '6',
        'type': 'Creature',
        'rarity': 'Epic',
        'attack': '6',
        'defense': '4',
        'creator': 'Tyler Covington',
        'bid': '4.89 ETH',
        'chain': 'BSC',
        'icon': '🦌',
        'art_color': 0xFF0D9488,
        'rules_text': 'Forestwalk. Cannot be countered by spell abilities.',
        'prompt': 'Slender mystical deer nymph with celestial horns and golden spots, enchanted forest',
      },
      {
        'card_name': 'Celestial Kitsune',
        'cost': '4',
        'type': 'Creature',
        'rarity': 'Rare',
        'attack': '3',
        'defense': '4',
        'creator': 'Tyler Covington',
        'bid': '4.89 ETH',
        'chain': 'BSC',
        'icon': '🦊',
        'art_color': 0xFF2563EB,
        'rules_text': 'Flash. When Celestial Kitsune enters, return target permanent to its owner hand.',
        'prompt': 'Blue magical fox spirit with glowing cyan eyes, mystical familiar for fantasy tabletop',
      },
    ];

    final initialProject = CardProject(
      id: uuid.v4(),
      name: 'Grimoire Chronicles: Tabletop Core Set',
      templates: [defaultTemplate],
      activeTemplateIndex: 0,
      rows: sampleRows,
      activeRowIndex: 0,
    );

    return EditorState(project: initialProject);
  }

  void selectLayer(String? id) {
    state = state.copyWith(selectedLayerId: id, clearSelectedLayer: id == null);
  }

  void updateLayerPosition(String id, double x, double y) {
    final template = state.project.activeTemplate;
    final updatedLayers = template.layers.map((l) {
      if (l.id == id && !l.isLocked) {
        return l.copyWith(x: x, y: y);
      }
      return l;
    }).toList();

    _updateTemplateLayers(updatedLayers);
  }

  void updateLayer(LayerItem updated) {
    final template = state.project.activeTemplate;
    final updatedLayers = template.layers.map((l) {
      if (l.id == updated.id) return updated;
      return l;
    }).toList();

    _updateTemplateLayers(updatedLayers);
  }

  void addLayer(LayerItem layer) {
    final template = state.project.activeTemplate;
    final updatedLayers = [...template.layers, layer];
    _updateTemplateLayers(updatedLayers);
    state = state.copyWith(selectedLayerId: layer.id);
  }

  void removeLayer(String id) {
    final template = state.project.activeTemplate;
    final updatedLayers = template.layers.where((l) => l.id != id).toList();
    _updateTemplateLayers(updatedLayers);
    if (state.selectedLayerId == id) {
      state = state.copyWith(clearSelectedLayer: true);
    }
  }

  void toggleLayerVisibility(String id) {
    final template = state.project.activeTemplate;
    final updatedLayers = template.layers.map((l) {
      if (l.id == id) return l.copyWith(isVisible: !l.isVisible);
      return l;
    }).toList();
    _updateTemplateLayers(updatedLayers);
  }

  void toggleLayerLock(String id) {
    final template = state.project.activeTemplate;
    final updatedLayers = template.layers.map((l) {
      if (l.id == id) return l.copyWith(isLocked: !l.isLocked);
      return l;
    }).toList();
    _updateTemplateLayers(updatedLayers);
  }

  void reorderLayers(int oldIndex, int newIndex) {
    final template = state.project.activeTemplate;
    final layers = List<LayerItem>.from(template.layers);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = layers.removeAt(oldIndex);
    layers.insert(newIndex, item);
    _updateTemplateLayers(layers);
  }

  void setActiveRow(int index) {
    if (index >= 0 && index < state.project.rows.length) {
      state = state.copyWith(
        project: state.project.copyWith(activeRowIndex: index),
      );
    }
  }

  void updateActiveRowData(String key, dynamic value) {
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    if (state.project.activeRowIndex < rows.length) {
      final updatedRow = Map<String, dynamic>.from(rows[state.project.activeRowIndex]);
      updatedRow[key] = value;
      rows[state.project.activeRowIndex] = updatedRow;
      state = state.copyWith(
        project: state.project.copyWith(rows: rows),
      );
    }
  }

  void addRow(Map<String, dynamic> row) {
    final rows = [...state.project.rows, row];
    state = state.copyWith(
      project: state.project.copyWith(
        rows: rows,
        activeRowIndex: rows.length - 1,
      ),
    );
  }

  void removeRow(int index) {
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    if (index >= 0 && index < rows.length) {
      rows.removeAt(index);
      final newIndex = (state.project.activeRowIndex >= rows.length)
          ? (rows.isEmpty ? 0 : rows.length - 1)
          : state.project.activeRowIndex;
      state = state.copyWith(
        project: state.project.copyWith(
          rows: rows,
          activeRowIndex: newIndex,
        ),
      );
    }
  }

  void setZoom(double newZoom) {
    state = state.copyWith(zoom: newZoom.clamp(0.4, 3.0));
  }

  void toggleGrid() {
    state = state.copyWith(showGrid: !state.showGrid);
  }

  void toggleSnapping() {
    state = state.copyWith(showSnapping: !state.showSnapping);
  }

  void setProject(CardProject project) {
    state = state.copyWith(project: project, clearSelectedLayer: true);
  }

  void _updateTemplateLayers(List<LayerItem> layers) {
    final template = state.project.activeTemplate.copyWith(layers: layers);
    final templates = List<CardTemplate>.from(state.project.templates);
    templates[state.project.activeTemplateIndex] = template;

    state = state.copyWith(
      project: state.project.copyWith(templates: templates),
    );
  }
}

final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  return EditorNotifier();
});
