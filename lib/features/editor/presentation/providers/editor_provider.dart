import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../models/card_project.dart';
import '../../models/card_template.dart';
import '../../models/layer_item.dart';
import '../../models/game_category.dart';
import '../../services/game_folder_service.dart';
import '../../../export/services/export_service.dart';

enum LayerAlignment {
  left,
  centerHorizontal,
  right,
  top,
  centerVertical,
  bottom,
  distributeHorizontal,
  distributeVertical,
}

class EditorState {
  final CardProject project;
  final String? selectedLayerId;
  final Set<String> selectedLayerIds;
  final double zoom;
  final bool showGrid;
  final bool showSnapping;
  final bool showBleedGuides;
  final bool isGeneratingAi;
  final CardSide currentSide;
  final Set<String> deletedGames;
  final Map<String, List<GameCategory>> gameCategories;
  final bool showAssetsPanel;
  final String? selectedAssetPath;
  final int undoCount;
  final int redoCount;
  final bool hasClipboardLayers;

  const EditorState({
    required this.project,
    this.selectedLayerId,
    this.selectedLayerIds = const {},
    this.zoom = 1.0,
    this.showGrid = true,
    this.showSnapping = true,
    this.showBleedGuides = false,
    this.isGeneratingAi = false,
    this.currentSide = CardSide.front,
    this.deletedGames = const {},
    this.gameCategories = const {},
    this.showAssetsPanel = true,
    this.selectedAssetPath,
    this.undoCount = 0,
    this.redoCount = 0,
    this.hasClipboardLayers = false,
  });

  bool get canUndo => undoCount > 0;
  bool get canRedo => redoCount > 0;

  LayerItem? get selectedLayer {
    if (selectedLayerId == null) return null;
    final layers = project.activeTemplate.getLayers(currentSide);
    final index = layers.indexWhere((l) => l.id == selectedLayerId);
    return index != -1 ? layers[index] : null;
  }

  List<LayerItem> get selectedLayers {
    final layers = project.activeTemplate.getLayers(currentSide);
    if (selectedLayerIds.isNotEmpty) {
      return layers.where((l) => selectedLayerIds.contains(l.id)).toList();
    }
    if (selectedLayerId != null) {
      final l = selectedLayer;
      return l != null ? [l] : const [];
    }
    return const [];
  }

  EditorState copyWith({
    CardProject? project,
    String? selectedLayerId,
    bool clearSelectedLayer = false,
    Set<String>? selectedLayerIds,
    double? zoom,
    bool? showGrid,
    bool? showSnapping,
    bool? showBleedGuides,
    bool? isGeneratingAi,
    CardSide? currentSide,
    Set<String>? deletedGames,
    Map<String, List<GameCategory>>? gameCategories,
    bool? showAssetsPanel,
    String? selectedAssetPath,
    bool clearSelectedAsset = false,
    int? undoCount,
    int? redoCount,
    bool? hasClipboardLayers,
  }) {
    return EditorState(
      project: project ?? this.project,
      selectedLayerId: clearSelectedLayer ? null : (selectedLayerId ?? this.selectedLayerId),
      selectedLayerIds: clearSelectedLayer
          ? const {}
          : (selectedLayerIds ?? (selectedLayerId != null ? {selectedLayerId} : this.selectedLayerIds)),
      zoom: zoom ?? this.zoom,
      showGrid: showGrid ?? this.showGrid,
      showSnapping: showSnapping ?? this.showSnapping,
      showBleedGuides: showBleedGuides ?? this.showBleedGuides,
      isGeneratingAi: isGeneratingAi ?? this.isGeneratingAi,
      currentSide: currentSide ?? this.currentSide,
      deletedGames: deletedGames ?? this.deletedGames,
      gameCategories: gameCategories ?? this.gameCategories,
      showAssetsPanel: showAssetsPanel ?? this.showAssetsPanel,
      selectedAssetPath: clearSelectedAsset ? null : (selectedAssetPath ?? this.selectedAssetPath),
      undoCount: undoCount ?? this.undoCount,
      redoCount: redoCount ?? this.redoCount,
      hasClipboardLayers: hasClipboardLayers ?? this.hasClipboardLayers,
    );
  }
}

class EditorNotifier extends StateNotifier<EditorState> {
  final bool enableDiskPersistence;
  final Directory? customPersistenceDir;

  EditorNotifier({
    bool? enableDiskPersistence,
    this.customPersistenceDir,
  })  : enableDiskPersistence =
            enableDiskPersistence ?? !Platform.environment.containsKey('FLUTTER_TEST'),
        super(
          _createInitialState(
            enableDiskPersistence:
                enableDiskPersistence ?? !Platform.environment.containsKey('FLUTTER_TEST'),
            customPersistenceDir: customPersistenceDir,
          ),
        );

  static EditorState _createInitialState({
    bool enableDiskPersistence = false,
    Directory? customPersistenceDir,
  }) {
    const uuid = Uuid();

    // Default template with realistic tabletop layers
    final defaultLayers = [
      // 1. Background Frame
      LayerItem(
        id: uuid.v4(),
        name: 'Card Background',
        type: LayerType.background,
        x: 0,
        y: 0,
        width: 254, // in canvas units (~63.5mm * 4)
        height: 355.6, // in canvas units (~88.9mm * 4)
        fillMode: LayerFillMode.solid,
        shapeColor: const Color(0xFF131622),
        gradientEndColor: const Color(0xFF2E1065),
        borderColor: Colors.transparent,
        borderWidth: 0,
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

    // Default Back Template layers (Classic tabletop / TCG card back)
    final defaultBackLayers = [
      // 1. Back Outer Frame
      LayerItem(
        id: uuid.v4(),
        name: 'Back Outer Frame',
        type: LayerType.shape,
        x: 0,
        y: 0,
        width: 254,
        height: 355.6,
        shapeColor: const Color(0xFF0C0E17),
        borderColor: const Color(0xFF7C3AED),
        borderWidth: 3,
        borderRadius: 16,
        isLocked: true,
      ),
      // 2. Back Inner Decorative Border
      LayerItem(
        id: uuid.v4(),
        name: 'Inner Rune Border',
        type: LayerType.shape,
        x: 14,
        y: 14,
        width: 226,
        height: 327.6,
        shapeColor: const Color(0xFF141828),
        borderColor: const Color(0xFF4C1D95),
        borderWidth: 1.5,
        borderRadius: 12,
        isLocked: true,
      ),
      // 3. Central Medallion
      LayerItem(
        id: uuid.v4(),
        name: 'Central Medallion',
        type: LayerType.shape,
        x: 67,
        y: 100,
        width: 120,
        height: 120,
        shapeColor: const Color(0xFF1E1B4B),
        borderColor: const Color(0xFFA855F7),
        borderWidth: 2,
        borderRadius: 60,
      ),
      // 4. Medallion Emblem
      LayerItem(
        id: uuid.v4(),
        name: 'Medallion Emblem',
        type: LayerType.text,
        x: 67,
        y: 130,
        width: 120,
        height: 60,
        text: '🔮',
        fontSize: 42,
        textAlign: TextAlign.center,
      ),
      // 5. Back Logo Title
      LayerItem(
        id: uuid.v4(),
        name: 'Back Title',
        type: LayerType.text,
        x: 20,
        y: 245,
        width: 214,
        height: 30,
        text: 'GRIMOIRE',
        fontSize: 18,
        isBold: true,
        fontColor: const Color(0xFFE9D5FF),
        textAlign: TextAlign.center,
      ),
      // 6. Back Subtitle
      LayerItem(
        id: uuid.v4(),
        name: 'Back Subtitle',
        type: LayerType.text,
        x: 20,
        y: 275,
        width: 214,
        height: 20,
        text: 'TABLETOP DECK',
        fontSize: 10,
        isBold: true,
        fontColor: const Color(0xFF94A3B8),
        textAlign: TextAlign.center,
      ),
    ];

    final defaultTemplate = CardTemplate(
      id: 'template-main',
      name: 'Standard Creature Frame',
      layers: defaultLayers,
      backLayers: defaultBackLayers,
    );

    // Dedicated Kawaii Chaos Template for Unstable Unicorns
    final unicornTemplate = CardTemplate(
      id: 'template-unicorn',
      name: 'Unicorn Stable Frame (Kawaii Chaos)',
      backgroundColor: const Color(0xFF1E1428),
      backBackgroundColor: const Color(0xFF231435),
      cornerRadius: 18,
      layers: [
        LayerItem(
          id: uuid.v4(),
          name: 'Card Background',
          type: LayerType.shape,
          x: 0,
          y: 0,
          width: 254,
          height: 355.6,
          shapeColor: const Color(0xFF191124),
          borderColor: const Color(0xFFEC4899),
          borderWidth: 2.5,
          borderRadius: 18,
          isLocked: true,
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Unicorn Art Frame',
          type: LayerType.shape,
          x: 14,
          y: 45,
          width: 226,
          height: 160,
          shapeColor: const Color(0xFFEC4899),
          borderColor: const Color(0xFFF472B6),
          borderWidth: 2,
          borderRadius: 14,
          bindingKey: 'art_url',
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Cost Badge',
          type: LayerType.text,
          x: 16,
          y: 12,
          width: 70,
          height: 24,
          text: '✨ {{cost}}',
          bindingKey: 'cost',
          fontSize: 12,
          isBold: true,
          fontColor: const Color(0xFFFDF2F8),
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Card Title',
          type: LayerType.text,
          x: 90,
          y: 12,
          width: 150,
          height: 24,
          text: '{{card_name}}',
          bindingKey: 'card_name',
          fontSize: 12,
          isBold: true,
          fontColor: Colors.white,
          textAlign: TextAlign.right,
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Rules Box Shape',
          type: LayerType.shape,
          x: 14,
          y: 215,
          width: 226,
          height: 90,
          shapeColor: const Color(0xFF130D1D),
          borderColor: const Color(0xFF381F4B),
          borderWidth: 1.5,
          borderRadius: 10,
          isLocked: true,
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Rules Text',
          type: LayerType.text,
          x: 20,
          y: 225,
          width: 214,
          height: 70,
          text: '{{rules_text}}',
          bindingKey: 'rules_text',
          fontSize: 9.5,
          fontColor: const Color(0xFFF5D0FE),
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Type Rarity',
          type: LayerType.text,
          x: 14,
          y: 312,
          width: 226,
          height: 20,
          text: '🦄 {{type}} • {{rarity}}',
          fontSize: 10,
          isBold: true,
          fontColor: const Color(0xFFF472B6),
          textAlign: TextAlign.center,
        ),
      ],
      backLayers: [
        LayerItem(
          id: uuid.v4(),
          name: 'Back Background',
          type: LayerType.shape,
          x: 0,
          y: 0,
          width: 254,
          height: 355.6,
          shapeColor: const Color(0xFF1E102E),
          borderColor: const Color(0xFFD946EF),
          borderWidth: 2.5,
          borderRadius: 18,
          isLocked: true,
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Pastel Inner Border',
          type: LayerType.shape,
          x: 14,
          y: 14,
          width: 226,
          height: 327.6,
          shapeColor: const Color(0xFF140A20),
          borderColor: const Color(0xFFEC4899),
          borderWidth: 1.5,
          borderRadius: 14,
          isLocked: true,
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Unicorn Medallion',
          type: LayerType.shape,
          x: 67,
          y: 95,
          width: 120,
          height: 120,
          shapeColor: const Color(0xFF2A123F),
          borderColor: const Color(0xFFF472B6),
          borderWidth: 2,
          borderRadius: 60,
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Unicorn Emblem',
          type: LayerType.text,
          x: 67,
          y: 122,
          width: 120,
          height: 60,
          text: '🦄',
          fontSize: 50,
          textAlign: TextAlign.center,
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Back Title',
          type: LayerType.text,
          x: 20,
          y: 240,
          width: 214,
          height: 30,
          text: 'UNSTABLE UNICORNS',
          fontSize: 15,
          isBold: true,
          fontColor: const Color(0xFFFDF2F8),
          textAlign: TextAlign.center,
        ),
        LayerItem(
          id: uuid.v4(),
          name: 'Back Subtitle',
          type: LayerType.text,
          x: 20,
          y: 270,
          width: 214,
          height: 20,
          text: 'EDICIÓN CAOS • TABLETOP DECK',
          fontSize: 9,
          isBold: true,
          fontColor: const Color(0xFFF472B6),
          textAlign: TextAlign.center,
        ),
      ],
    );

    // Board Game Specific Categories Configuration: Only Magic & Unstable Unicorns
    final initialGameCategories = <String, List<GameCategory>>{
      'Magic': [
        const GameCategory(
          id: 'mtg-creatures',
          name: 'Criaturas',
          icon: '🐉',
          defaultType: 'Criatura',
          defaultColor: 0xFFDC2626,
          defaultCost: '3',
          defaultAttack: '3',
          defaultDefense: '3',
          defaultRarity: 'Rara',
          defaultRules: 'Vuela, arrolla o combate en el campo de batalla.',
        ),
        const GameCategory(
          id: 'mtg-instants',
          name: 'Instantáneos',
          icon: '⚡',
          defaultType: 'Instantáneo',
          defaultColor: 0xFF2563EB,
          defaultCost: '1',
          defaultAttack: '0',
          defaultDefense: '0',
          defaultRarity: 'Común',
          defaultRules: 'Lanza este hechizo en cualquier momento en que tengas prioridad.',
        ),
        const GameCategory(
          id: 'mtg-sorceries',
          name: 'Conjuros',
          icon: '📜',
          defaultType: 'Conjuro',
          defaultColor: 0xFF9333EA,
          defaultCost: '3',
          defaultAttack: '0',
          defaultDefense: '0',
          defaultRarity: 'Poco Común',
          defaultRules: 'Lanza este hechizo únicamente durante tu fase principal.',
        ),
        const GameCategory(
          id: 'mtg-enchantments',
          name: 'Encantamientos',
          icon: '✨',
          defaultType: 'Encantamiento',
          defaultColor: 0xFF10B981,
          defaultCost: '2',
          defaultAttack: '0',
          defaultDefense: '0',
          defaultRarity: 'Rara',
          defaultRules: 'Permanece en el campo otorgando efectos continuos.',
        ),
        const GameCategory(
          id: 'mtg-lands',
          name: 'Tierras',
          icon: '🏔️',
          defaultType: 'Tierra',
          defaultColor: 0xFFD97706,
          defaultCost: '0',
          defaultAttack: '0',
          defaultDefense: '0',
          defaultRarity: 'Básica',
          defaultRules: '{T}: Agrega 1 maná a tu reserva de maná.',
        ),
        const GameCategory(
          id: 'mtg-artifacts',
          name: 'Artefactos',
          icon: '🛡️',
          defaultType: 'Artefacto',
          defaultColor: 0xFF64748B,
          defaultCost: '2',
          defaultAttack: '0',
          defaultDefense: '0',
          defaultRarity: 'Poco Común',
          defaultRules: 'Objeto incoloro con habilidades o equipo activado.',
        ),
      ],
      'Unstable Unicorns': [
        const GameCategory(
          id: 'uu-unicorns',
          name: 'Unicornios',
          icon: '🦄',
          defaultType: 'Unicornio Mágico',
          defaultColor: 0xFFEC4899,
          defaultCost: '2',
          defaultAttack: '2',
          defaultDefense: '2',
          defaultRarity: 'Común',
          defaultRules: 'Al entrar a tu establo, activa su efecto mágico.',
        ),
        const GameCategory(
          id: 'uu-upgrades',
          name: 'Cartas de Mejora',
          icon: '🌟',
          defaultType: 'Mejora',
          defaultColor: 0xFF06B6D4,
          defaultCost: '3',
          defaultAttack: '0',
          defaultDefense: '5',
          defaultRarity: 'Rara',
          defaultRules: 'Mejora para tu establo. Otorga bonificaciones permanentes.',
        ),
        const GameCategory(
          id: 'uu-downgrades',
          name: 'Cartas de Degradación',
          icon: '🏚️',
          defaultType: 'Degradación',
          defaultColor: 0xFFFACC15,
          defaultCost: '2',
          defaultAttack: '0',
          defaultDefense: '4',
          defaultRarity: 'Poco Común',
          defaultRules: 'Juega en el establo de un rival para perjudicarlo.',
        ),
        const GameCategory(
          id: 'uu-magic',
          name: 'Cartas de Magia',
          icon: '💣',
          defaultType: 'Magia',
          defaultColor: 0xFFE879F9,
          defaultCost: '3',
          defaultAttack: '0',
          defaultDefense: '0',
          defaultRarity: 'Rara',
          defaultRules: 'Efecto de hechizo inmediato que va al descarte tras resolverse.',
        ),
        const GameCategory(
          id: 'uu-neigh',
          name: 'Cartas de ¡Neigh! (Relincho)',
          icon: '🚫',
          defaultType: 'Instantánea',
          defaultColor: 0xFFEF4444,
          defaultCost: '1',
          defaultAttack: '0',
          defaultDefense: '0',
          defaultRarity: 'Rara',
          defaultRules: '¡Respuesta Inmediata! Cancela la carta que cualquier rival intente jugar.',
        ),
      ],
    };

    // Sample data rows: Only Magic and Unstable Unicorns
    final sampleRows = [
      // --- MAGIC: THE GATHERING ---
      {
        'card_name': 'Black Lotus',
        'cost': '0',
        'type': 'Artefacto',
        'rarity': 'Mítica',
        'attack': '0',
        'defense': '0',
        'creator': 'Richard Garfield / MTG',
        'icon': '🪷',
        'art_color': 0xFF312E81,
        'rules_text': '{T}, Sacrificar el Loto Negro: Agrega tres manás de cualquier color a tu reserva de maná.',
        'prompt': 'Mystical black lotus flower floating on serene dark water with ethereal purple petals and golden sparks',
        'game': 'Magic',
        'category': 'Artefactos',
        'art_url': 'assets/black_lotus.png',
      },
      {
        'card_name': 'Lightning Bolt',
        'cost': '1',
        'type': 'Instantáneo',
        'rarity': 'Común',
        'attack': '0',
        'defense': '0',
        'creator': 'Richard Garfield / MTG',
        'icon': '⚡',
        'art_color': 0xFFDC2626,
        'rules_text': 'Lightning Bolt hace 3 puntos de daño a cualquier objetivo.',
        'prompt': 'A colossal red lightning bolt striking down from stormy dark clouds, glowing electric energy',
        'game': 'Magic',
        'category': 'Instantáneos',
        'art_url': 'assets/lightning_bolt.png',
      },
      {
        'card_name': 'Counterspell',
        'cost': '2',
        'type': 'Instantáneo',
        'rarity': 'Poco Común',
        'attack': '0',
        'defense': '0',
        'creator': 'Richard Garfield / MTG',
        'icon': '💧',
        'art_color': 0xFF2563EB,
        'rules_text': 'Contrarresta el hechizo objetivo.',
        'prompt': 'Mystical wizard in blue robes creating a shimmering arcane water barrier deflecting enemy magic',
        'game': 'Magic',
        'category': 'Instantáneos',
        'art_url': 'assets/counterspell.png',
      },
      {
        'card_name': 'Serra Angel',
        'cost': '5',
        'type': 'Criatura',
        'rarity': 'Rara',
        'attack': '4',
        'defense': '4',
        'creator': 'Richard Garfield / MTG',
        'icon': '👼',
        'art_color': 0xFFF59E0B,
        'rules_text': 'Vuela, vigilancia (atacar no hace que el Ángel de Serra se gire).',
        'prompt': 'Glorious warrior angel with majestic white feathered wings holding a golden broadsword in radiant sunlight',
        'game': 'Magic',
        'category': 'Criaturas',
        'art_url': 'assets/serra_angel.png',
      },
      {
        'card_name': 'Shivan Dragon',
        'cost': '6',
        'type': 'Criatura',
        'rarity': 'Rara',
        'attack': '5',
        'defense': '5',
        'creator': 'Richard Garfield / MTG',
        'icon': '🐉',
        'art_color': 0xFFB91C1C,
        'rules_text': 'Vuela. {R}: El Dragón de Shiv obtiene +1/+0 hasta el final del turno.',
        'prompt': 'Ferocious red dragon soaring over a smoking volcanic mountain ridge breathing molten fiery breath',
        'game': 'Magic',
        'category': 'Criaturas',
        'art_url': 'assets/shivan_dragon.png',
      },
      {
        'card_name': 'Dark Ritual',
        'cost': '1',
        'type': 'Instantáneo',
        'rarity': 'Común',
        'attack': '0',
        'defense': '0',
        'creator': 'Richard Garfield / MTG',
        'icon': '💀',
        'art_color': 0xFF18181B,
        'rules_text': 'Agrega {B}{B}{B} a tu reserva de maná.',
        'prompt': 'Necromancer chanting in dark subterranean crypt surrounded by floating skulls and dark purple soul mist',
        'game': 'Magic',
        'category': 'Instantáneos',
        'art_url': 'assets/dark_ritual.png',
      },
      {
        'card_name': 'Wrath of God',
        'cost': '4',
        'type': 'Conjuro',
        'rarity': 'Rara',
        'attack': '0',
        'defense': '0',
        'creator': 'Richard Garfield / MTG',
        'icon': '⚔️',
        'art_color': 0xFFF8FAFC,
        'rules_text': 'Destruye todas las criaturas. No pueden ser regeneradas.',
        'prompt': 'Blinding divine pillar of white celestial light incinerating an entire fantasy battlefield into golden ash',
        'game': 'Magic',
        'category': 'Conjuros',
        'art_url': 'assets/wrath_of_god.png',
      },
      {
        'card_name': 'Islas Celestiales',
        'cost': '0',
        'type': 'Tierra',
        'rarity': 'Básica',
        'attack': '0',
        'defense': '0',
        'creator': 'Richard Garfield / MTG',
        'icon': '🏝️',
        'art_color': 0xFF0284C7,
        'rules_text': '{T}: Agrega {U} a tu reserva de maná.',
        'prompt': 'Floating tropical islands hovering over tranquil crystal blue sea with waterfalls pouring into clouds',
        'game': 'Magic',
        'category': 'Tierras',
        'art_url': 'assets/islas_celestiales.png',
      },

      // --- UNSTABLE UNICORNS (Edición Caos) ---
      {
        'card_name': 'Unicornio Bebé Arcoíris',
        'cost': '0',
        'type': 'Unicornio Bebé',
        'rarity': 'Inicial',
        'attack': '1',
        'defense': '1',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🦄🍼',
        'art_color': 0xFFF472B6,
        'rules_text': 'Si esta carta fuese a ser destruida o sacrificada, devuélvela a tu Guardería en lugar de enviarla al descarte.',
        'prompt': 'Cute pastel baby unicorn with soft rainbow mane drinking from baby bottle, kawaii vinyl toy',
        'game': 'Unstable Unicorns',
        'category': 'Unicornios',
      },
      {
        'card_name': 'Unicornio Bebé Galáctico',
        'cost': '0',
        'type': 'Unicornio Bebé',
        'rarity': 'Inicial',
        'attack': '1',
        'defense': '1',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🌌🦄',
        'art_color': 0xFFA855F7,
        'rules_text': 'Comienza la partida en la Guardería. Los rivales no pueden robar esta carta mientras sea un bebé.',
        'prompt': 'Cosmic starry galaxy baby unicorn floating among purple nebulae, cute chibi',
        'game': 'Unstable Unicorns',
        'category': 'Unicornios',
      },
      {
        'card_name': 'Unicornio Básico con Capa',
        'cost': '2',
        'type': 'Unicornio Básico',
        'rarity': 'Común',
        'attack': '2',
        'defense': '2',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🦄🦸',
        'art_color': 0xFF38BDF8,
        'rules_text': 'No tiene habilidades mágicas complejas, pero defiende tu establo con honor y valentía heroica.',
        'prompt': 'Heroic cute unicorn wearing a mini knight helmet and red heroic cape, pastel chibi style',
        'game': 'Unstable Unicorns',
        'category': 'Unicornios',
      },
      {
        'card_name': 'Unicornio Gamer Cósmico',
        'cost': '2',
        'type': 'Unicornio Básico',
        'rarity': 'Común',
        'attack': '2',
        'defense': '2',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🎮🦄',
        'art_color': 0xFF818CF8,
        'rules_text': 'Un unicornio adicto a los videojuegos retro. Si tu establo tiene al menos 3 unicornios, gana +1 de defensa.',
        'prompt': 'Pastel purple unicorn wearing gaming headset and holding a retro portable console',
        'game': 'Unstable Unicorns',
        'category': 'Unicornios',
      },
      {
        'card_name': 'Unicornio Seductor',
        'cost': '4',
        'type': 'Unicornio Mágico',
        'rarity': 'Rara',
        'attack': '3',
        'defense': '4',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🦄🧲',
        'art_color': 0xFFFB7185,
        'rules_text': 'Al entrar a tu establo, roba 1 carta de Unicornio del establo de cualquier rival y trasládala al tuyo.',
        'prompt': 'Elegant magical unicorn with sparkling magenta heart sunglasses and charming aura',
        'game': 'Unstable Unicorns',
        'category': 'Unicornios',
      },
      {
        'card_name': 'Motosierra Unicornio',
        'cost': '4',
        'type': 'Unicornio Mágico',
        'rarity': 'Épica',
        'attack': '5',
        'defense': '3',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🦄⚙️',
        'art_color': 0xFFFB923C,
        'rules_text': 'Al entrar a tu establo, destruye inmediatamente 1 carta de Mejora o Degradación en cualquier establo.',
        'prompt': 'Fierce humorous unicorn wielding a tiny cute chainsaw, glitter sparks flying',
        'game': 'Unstable Unicorns',
        'category': 'Unicornios',
      },
      {
        'card_name': 'Rinocornio Demoledor',
        'cost': '5',
        'type': 'Unicornio Mágico',
        'rarity': 'Mítica',
        'attack': '6',
        'defense': '5',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🦏⚡',
        'art_color': 0xFF8B5CF6,
        'rules_text': 'Al inicio de tu turno, puedes renunciar a tu robo de carta para destruir 1 Unicornio en el establo de un rival.',
        'prompt': 'Armored rhinocorn with a massive glowing crystal horn charging forward, vibrant comic art',
        'game': 'Unstable Unicorns',
        'category': 'Unicornios',
      },
      {
        'card_name': 'Unicornio Zombi',
        'cost': '4',
        'type': 'Unicornio Mágico',
        'rarity': 'Rara',
        'attack': '3',
        'defense': '3',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🧟🦄',
        'art_color': 0xFF34D399,
        'rules_text': 'Al inicio de tu turno, puedes descartar 1 carta de tu mano para revivir cualquier Unicornio de tu descarte a tu establo.',
        'prompt': 'Adorable zombie unicorn with soft green pastel fur and glowing purple stitches, kawaii undead',
        'game': 'Unstable Unicorns',
        'category': 'Unicornios',
      },
      {
        'card_name': 'Ginormous Unicorn',
        'cost': '6',
        'type': 'Unicornio Mágico',
        'rarity': 'Mítica',
        'attack': '8',
        'defense': '7',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🦖🦄',
        'art_color': 0xFFFBBF24,
        'rules_text': 'Cuenta como 2 Unicornios para la victoria. Mientras permanezca en tu establo, ningún jugador puede jugar cartas Instantáneas.',
        'prompt': 'Colossal dinosaur-sized unicorn stomping through a miniature cartoon farm, rainbow footprints',
        'game': 'Unstable Unicorns',
        'category': 'Unicornios',
      },
      {
        'card_name': '¡Relincho! (Neigh!)',
        'cost': '1',
        'type': 'Instantánea',
        'rarity': 'Rara',
        'attack': '0',
        'defense': '0',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🚫🦄',
        'art_color': 0xFFEF4444,
        'rules_text': '¡Respuesta Inmediata! Cancela la carta que cualquier rival intente jugar y envíala directamente a la pila de descarte.',
        'prompt': 'Sassy unicorn yelling with mouth wide open, red comic stop barrier, dramatic shockwaves',
        'game': 'Unstable Unicorns',
        'category': 'Cartas de ¡Neigh! (Relincho)',
      },
      {
        'card_name': 'Súper Relincho Místico',
        'cost': '2',
        'type': 'Instantánea',
        'rarity': 'Mítica',
        'attack': '0',
        'defense': '0',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🛑⚡',
        'art_color': 0xFFDC2626,
        'rules_text': 'Cancela cualquier jugada rival al instante. Esta carta es inmutable y no puede ser cancelada por ningún otro ¡Relincho!.',
        'prompt': 'Golden-horned supreme unicorn stamping hoof creating golden shockwave of denial, epic comic style',
        'game': 'Unstable Unicorns',
        'category': 'Cartas de ¡Neigh! (Relincho)',
      },
      {
        'card_name': 'Bomba de Purpurina',
        'cost': '3',
        'type': 'Magia',
        'rarity': 'Poco Común',
        'attack': '0',
        'defense': '0',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '💣✨',
        'art_color': 0xFFE879F9,
        'rules_text': 'Sacrifica 1 carta de tu establo. A cambio, destruye cualquier carta en el establo de un rival a tu elección.',
        'prompt': 'Sparkling glitter bomb exploding into multi-color star sparkles, vibrant pop-art',
        'game': 'Unstable Unicorns',
        'category': 'Cartas de Magia',
      },
      {
        'card_name': 'Súper Patada Equina',
        'cost': '2',
        'type': 'Magia',
        'rarity': 'Común',
        'attack': '0',
        'defense': '0',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '👢💨',
        'art_color': 0xFFF59E0B,
        'rules_text': 'Devuelve cualquier carta de un establo rival a la mano de su dueño. Roba 1 carta adicional de tu mazo.',
        'prompt': 'Cartoon unicorn delivering an energetic back kick with rainbow motion lines and stars',
        'game': 'Unstable Unicorns',
        'category': 'Cartas de Magia',
      },
      {
        'card_name': 'Melena Arcoíris Protectora',
        'cost': '3',
        'type': 'Mejora',
        'rarity': 'Épica',
        'attack': '0',
        'defense': '5',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🌈🛡️',
        'art_color': 0xFF22D3EE,
        'rules_text': 'Mejora de Establo: Tus Unicornios están bendecidos y son completamente inmunes a ser destruidos por efectos mágicos rivales.',
        'prompt': 'Prismatic glowing rainbow mane floating like a mystical aura halo, fantasy magical artifact',
        'game': 'Unstable Unicorns',
        'category': 'Cartas de Mejora',
      },
      {
        'card_name': 'Establo Inquebrantable',
        'cost': '4',
        'type': 'Mejora',
        'rarity': 'Mítica',
        'attack': '0',
        'defense': '7',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🏰🌟',
        'art_color': 0xFF6366F1,
        'rules_text': 'Mejora de Establo: Los rivales tienen prohibido jugar cartas de Degradación o Maldición en tu establo.',
        'prompt': 'Majestic pastel crystal fortress castle with magical rainbow forcefield and unicorn banners',
        'game': 'Unstable Unicorns',
        'category': 'Cartas de Mejora',
      },
      {
        'card_name': 'Luz Cegadora Desorientadora',
        'cost': '2',
        'type': 'Degradación',
        'rarity': 'Rara',
        'attack': '0',
        'defense': '4',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '☀️😵',
        'art_color': 0xFFFACC15,
        'rules_text': 'Degradación: Juega en el establo de un rival. Todos los Unicornios de ese jugador quedan incapacitados y pierden sus poderes mágicos.',
        'prompt': 'Blinding radiant miniature sun hovering over a chaotic cartoon stable, dizzy unicorns with spiral eyes',
        'game': 'Unstable Unicorns',
        'category': 'Cartas de Degradación',
      },
      {
        'card_name': 'Establo Diminuto',
        'cost': '2',
        'type': 'Degradación',
        'rarity': 'Poco Común',
        'attack': '0',
        'defense': '3',
        'creator': 'TeeTurtle / Grimoire',
        'icon': '🏚️🔒',
        'art_color': 0xFF64748B,
        'rules_text': 'Degradación: Juega en el establo de un rival. El límite máximo de Unicornios de ese jugador se reduce drásticamente a 3.',
        'prompt': 'Tiny cramped wooden barn with a giant cartoon padlock, comical sad unicorn squeezed inside',
        'game': 'Unstable Unicorns',
        'category': 'Cartas de Degradación',
      },
    ];

    final initialProject = CardProject(
      id: uuid.v4(),
      name: 'Grimoire Chronicles: Tabletop Core Set',
      templates: [defaultTemplate, unicornTemplate],
      activeTemplateIndex: 0,
      rows: const [],
      activeRowIndex: 0,
    );

    _cachedInitialSampleRows = sampleRows.map((r) => Map<String, dynamic>.from(r)).toList();
    _cachedSampleGameCategories = initialGameCategories.map(
      (k, v) => MapEntry(k, List<GameCategory>.from(v)),
    );

    if (enableDiskPersistence) {
      final persisted = GameFolderService.loadWorkspaceStateSync(
        customRootDir: customPersistenceDir,
      );
      if (persisted != null) {
        final baseProject = persisted.project ?? initialProject;
        final templates = baseProject.templates.isNotEmpty
            ? baseProject.templates
            : initialProject.templates;
        final combinedRows = [
          ...baseProject.rows.map((r) => GameFolderService.normalizeCardRow(r)),
          ...persisted.discoveredRows.map((r) => GameFolderService.normalizeCardRow(r)),
        ];
        final clampedRowIndex = combinedRows.isEmpty
            ? 0
            : baseProject.activeRowIndex.clamp(0, combinedRows.length - 1);
        int clampedTemplateIndex = templates.isEmpty
            ? 0
            : baseProject.activeTemplateIndex.clamp(0, templates.length - 1);

        if (combinedRows.isNotEmpty && clampedRowIndex >= 0 && clampedRowIndex < combinedRows.length) {
          final activeRow = combinedRows[clampedRowIndex];
          final tplId = (activeRow['template_id'] ?? '').toString().trim();
          if (tplId.isNotEmpty) {
            final matchIdx = templates.indexWhere((t) => t.id == tplId || t.name.toLowerCase() == tplId.toLowerCase());
            if (matchIdx != -1) {
              clampedTemplateIndex = matchIdx;
            }
          } else {
            final game = (activeRow['game'] ?? '').toString().trim();
            final category = (activeRow['category'] ?? '').toString().trim();
            if (game.isNotEmpty && category.isNotEmpty) {
              final safeGame = game.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
              final safeCat = category.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
              final catTplId = 'tpl_${safeGame}_$safeCat';
              final matchIdx = templates.indexWhere((t) => t.id == catTplId);
              if (matchIdx != -1) {
                clampedTemplateIndex = matchIdx;
              }
            }
          }
        }

        final mergedProject = baseProject.copyWith(
          templates: templates,
          activeTemplateIndex: clampedTemplateIndex,
          rows: combinedRows,
          activeRowIndex: clampedRowIndex,
        );

        // Clean up any orphaned categories that belong to deleted games or games with 0 rows
        final activeGameNamesExact = combinedRows
            .map((r) => (r['game'] ?? '').toString().trim().toLowerCase())
            .where((k) => k.isNotEmpty)
            .toSet();
        final activeGameNormKeys = combinedRows
            .map((r) => GameFolderService.normalizeGameKey((r['game'] ?? '').toString()))
            .where((k) => k.isNotEmpty)
            .toSet();
        final deletedExactKeys = persisted.deletedGames
            .map((g) => g.trim().toLowerCase())
            .toSet();
        final deletedNormKeys = persisted.deletedGames
            .map(GameFolderService.normalizeGameKey)
            .toSet();
        final cleanedCategories = Map<String, List<GameCategory>>.from(persisted.gameCategories)
          ..removeWhere((k, _) {
            final lowerK = k.trim().toLowerCase();
            final normK = GameFolderService.normalizeGameKey(k);
            // If this exact key was deleted and there are no rows with this exact name, purge it
            if (deletedExactKeys.contains(lowerK) && !activeGameNamesExact.contains(lowerK)) {
              return true;
            }
            return deletedNormKeys.contains(normK) || !activeGameNormKeys.contains(normK);
          });

        GameFolderService.saveWorkspaceStateSync(
          project: mergedProject,
          gameCategories: cleanedCategories,
          deletedGames: persisted.deletedGames,
          customRootDir: customPersistenceDir,
        );

        return EditorState(
          project: mergedProject,
          gameCategories: cleanedCategories,
          deletedGames: persisted.deletedGames,
        );
      }
    }

    return EditorState(
      project: initialProject,
      gameCategories: const {},
    );
  }

  static List<Map<String, dynamic>>? _cachedInitialSampleRows;
  static Map<String, List<GameCategory>>? _cachedSampleGameCategories;

  static List<Map<String, dynamic>> getInitialSampleRows() =>
      _cachedInitialSampleRows?.map((r) => Map<String, dynamic>.from(r)).toList() ?? [];

  static Map<String, List<GameCategory>> getInitialSampleCategories() =>
      _cachedSampleGameCategories?.map((k, v) => MapEntry(k, List<GameCategory>.from(v))) ?? {};

  final List<CardProject> _undoStack = [];
  final List<CardProject> _redoStack = [];
  DateTime _lastHistoryPushTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastContinuousMutationTag;
  final List<LayerItem> _clipboardLayers = [];
  bool get hasClipboardLayers => _clipboardLayers.isNotEmpty;
  List<LayerItem> get clipboardLayers => List.unmodifiable(_clipboardLayers);

  void _recordHistory({String? continuousTag}) {
    final now = DateTime.now();
    if (continuousTag != null &&
        continuousTag == _lastContinuousMutationTag &&
        now.difference(_lastHistoryPushTime).inMilliseconds < 550) {
      _lastHistoryPushTime = now;
      return;
    }
    _lastContinuousMutationTag = continuousTag;
    _lastHistoryPushTime = now;

    // Deep clone via JSON serialization to avoid shared map mutations
    final snapshot = CardProject.fromJson(state.project.toJson());
    _undoStack.add(snapshot);
    if (_undoStack.length > 40) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final currentSnapshot = CardProject.fromJson(state.project.toJson());
    _redoStack.add(currentSnapshot);
    final previousProject = _undoStack.removeLast();

    state = state.copyWith(
      project: previousProject,
      undoCount: _undoStack.length,
      redoCount: _redoStack.length,
    );
    _persistWorkspace();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final currentSnapshot = CardProject.fromJson(state.project.toJson());
    _undoStack.add(currentSnapshot);
    final nextProject = _redoStack.removeLast();

    state = state.copyWith(
      project: nextProject,
      undoCount: _undoStack.length,
      redoCount: _redoStack.length,
    );
    _persistWorkspace();
  }

  void _syncHistoryCounts() {
    if (state.undoCount != _undoStack.length || state.redoCount != _redoStack.length) {
      state = state.copyWith(
        undoCount: _undoStack.length,
        redoCount: _redoStack.length,
      );
    }
  }

  void _persistWorkspace({String? syncGameName}) {
    _syncHistoryCounts();
    if (!enableDiskPersistence) return;
    GameFolderService.saveWorkspaceStateSync(
      project: state.project,
      gameCategories: state.gameCategories,
      deletedGames: state.deletedGames,
      customRootDir: customPersistenceDir,
    );
    if (syncGameName != null && syncGameName.trim().isNotEmpty) {
      final gameCards = state.project.rows
          .where((r) => (r['game'] ?? '').toString().toLowerCase() == syncGameName.toLowerCase())
          .toList();
      GameFolderService.saveGameDataCsvSync(
        syncGameName,
        gameCards,
        customRootDir: customPersistenceDir,
      );
    }
  }

  void selectLayer(String? id, {bool multiSelect = false}) {
    if (id == null) {
      state = state.copyWith(selectedLayerId: null, clearSelectedLayer: true, selectedLayerIds: const {});
      return;
    }

    if (multiSelect) {
      final current = Set<String>.from(state.selectedLayerIds);
      if (state.selectedLayerId != null) current.add(state.selectedLayerId!);
      if (current.contains(id)) {
        current.remove(id);
      } else {
        current.add(id);
      }
      state = state.copyWith(
        selectedLayerId: current.isNotEmpty ? current.last : null,
        clearSelectedLayer: current.isEmpty,
        selectedLayerIds: current,
        clearSelectedAsset: true,
      );
    } else {
      state = state.copyWith(
        selectedLayerId: id,
        clearSelectedLayer: false,
        selectedLayerIds: {id},
        clearSelectedAsset: true,
      );
    }
  }

  void selectAsset(String? assetPath) {
    if (assetPath != null && assetPath.trim().isNotEmpty) {
      state = state.copyWith(
        selectedAssetPath: assetPath.trim(),
        selectedLayerId: null,
        clearSelectedLayer: true,
        selectedLayerIds: const {},
      );
    } else {
      state = state.copyWith(
        clearSelectedAsset: true,
      );
    }
  }

  bool renameAsset({
    required String gameName,
    required String oldFileName,
    required String newFileName,
  }) {
    final renamed = GameFolderService.renameGameAsset(gameName, oldFileName, newFileName);
    if (renamed == null) return false;

    final actualNewName = renamed.uri.pathSegments.last;
    final oldRelative = 'assets/$oldFileName';
    final newRelative = 'assets/$actualNewName';

    _recordHistory();

    // 1. Update project rows referencing the old asset
    final updatedRows = state.project.rows.map((row) {
      final art = (row['art_url'] ?? '').toString();
      if (art == oldRelative || art == oldFileName || art.endsWith('/$oldFileName')) {
        final newRow = Map<String, dynamic>.from(row);
        newRow['art_url'] = newRelative;
        return newRow;
      }
      return row;
    }).toList();

    // 2. Update template layers referencing the old asset
    final updatedTemplates = state.project.templates.map((tpl) {
      final updatedFront = tpl.layers.map((l) {
        if (l.imagePath == oldRelative || l.imagePath == oldFileName) {
          return l.copyWith(imagePath: newRelative);
        }
        return l;
      }).toList();
      final updatedBack = tpl.backLayers.map((l) {
        if (l.imagePath == oldRelative || l.imagePath == oldFileName) {
          return l.copyWith(imagePath: newRelative);
        }
        return l;
      }).toList();
      return tpl.copyWith(layers: updatedFront, backLayers: updatedBack);
    }).toList();

    state = state.copyWith(
      project: state.project.copyWith(
        rows: updatedRows,
        templates: updatedTemplates,
      ),
      selectedAssetPath: newRelative,
    );

    _persistWorkspace(syncGameName: gameName);
    return true;
  }

  bool moveAsset({
    required String gameName,
    required String relativeOrFileName,
    required String? targetSubfolder,
  }) {
    final targetFile = GameFolderService.resolveCardImageFile(gameName, relativeOrFileName);
    if (targetFile == null) return false;

    final oldRelative = GameFolderService.getRelativeAssetPath(gameName, targetFile);
    final moved = GameFolderService.moveAssetToFolder(gameName, targetFile, targetSubfolder);
    if (moved == null) return false;

    final newRelative = GameFolderService.getRelativeAssetPath(gameName, moved);

    _recordHistory();

    final oldFileName = targetFile.uri.pathSegments.last;

    // 1. Update project rows referencing the old asset
    final updatedRows = state.project.rows.map((row) {
      final art = (row['art_url'] ?? '').toString();
      if (art == oldRelative || art == relativeOrFileName || art.endsWith(oldFileName)) {
        final newRow = Map<String, dynamic>.from(row);
        newRow['art_url'] = newRelative;
        return newRow;
      }
      return row;
    }).toList();

    // 2. Update template layers referencing the old asset
    final oldPathClean = targetFile.path.replaceAll('\\', '/');
    final updatedTemplates = state.project.templates.map((tpl) {
      final updatedFront = tpl.layers.map((l) {
        final lPathClean = l.imagePath?.replaceAll('\\', '/');
        if (lPathClean == oldRelative ||
            lPathClean == oldPathClean ||
            (lPathClean != null && (lPathClean.endsWith('/$oldFileName') || lPathClean == oldFileName))) {
          return l.copyWith(imagePath: moved.path);
        }
        return l;
      }).toList();
      final updatedBack = tpl.backLayers.map((l) {
        final lPathClean = l.imagePath?.replaceAll('\\', '/');
        if (lPathClean == oldRelative ||
            lPathClean == oldPathClean ||
            (lPathClean != null && (lPathClean.endsWith('/$oldFileName') || lPathClean == oldFileName))) {
          return l.copyWith(imagePath: moved.path);
        }
        return l;
      }).toList();
      return tpl.copyWith(layers: updatedFront, backLayers: updatedBack);
    }).toList();

    final selectedClean = state.selectedAssetPath?.replaceAll('\\', '/');
    final isSelectedTarget = selectedClean != null &&
        (selectedClean == oldRelative ||
            selectedClean == oldPathClean ||
            selectedClean == relativeOrFileName.replaceAll('\\', '/') ||
            selectedClean.endsWith(oldFileName));

    state = state.copyWith(
      project: state.project.copyWith(
        rows: updatedRows,
        templates: updatedTemplates,
      ),
      selectedAssetPath: isSelectedTarget ? newRelative : state.selectedAssetPath,
    );

    _persistWorkspace(syncGameName: gameName);
    return true;
  }

  void moveSelectedLayers(double deltaX, double deltaY) {
    final ids = state.selectedLayerIds.isNotEmpty
        ? state.selectedLayerIds
        : (state.selectedLayerId != null ? {state.selectedLayerId!} : <String>{});
    if (ids.isEmpty) return;

    _recordHistory(continuousTag: 'move_multi');
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.map((l) {
      if (ids.contains(l.id) && !l.isLocked && l.type != LayerType.background) {
        return l.copyWith(x: l.x + deltaX, y: l.y + deltaY);
      }
      return l;
    }).toList();

    _updateTemplateLayers(updatedLayers);
  }

  void removeSelectedLayers() {
    final ids = state.selectedLayerIds.isNotEmpty
        ? state.selectedLayerIds
        : (state.selectedLayerId != null ? {state.selectedLayerId!} : <String>{});
    if (ids.isEmpty) return;

    _recordHistory();
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final remainingLayers = layers.where((l) => !ids.contains(l.id) || l.type == LayerType.background).toList();

    _updateTemplateLayers(remainingLayers);
    state = state.copyWith(
      selectedLayerId: null,
      clearSelectedLayer: true,
      selectedLayerIds: const {},
    );
    _persistWorkspace();
  }

  void updateLayerPosition(String id, double x, double y) {
    _recordHistory(continuousTag: 'pos_$id');
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.map((l) {
      if (l.id == id && !l.isLocked) {
        return l.copyWith(x: x, y: y);
      }
      return l;
    }).toList();

    _updateTemplateLayers(updatedLayers);
  }

  void nudgeSelectedLayer(double dx, double dy) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final layer = state.selectedLayer;
    if (layer == null || layer.isLocked || layer.type == LayerType.background) return;
    updateLayerPosition(id, layer.x + dx, layer.y + dy);
  }

  void duplicateLayer(String id) {
    final template = state.project.activeTemplate;
    final layers = List<LayerItem>.from(template.getLayers(state.currentSide));
    final idx = layers.indexWhere((l) => l.id == id);
    if (idx == -1) return;
    final original = layers[idx];
    if (original.type == LayerType.background) return;

    _recordHistory();
    const uuid = Uuid();
    final copy = original.copyWith(
      id: uuid.v4(),
      name: '${original.name} (Copy)',
      x: original.x + 10,
      y: original.y + 10,
      isLocked: false,
    );
    layers.insert(idx + 1, copy);
    _updateTemplateLayers(layers);
    state = state.copyWith(selectedLayerId: copy.id);
    _persistWorkspace();
  }

  int copySelectedLayers() {
    final targets = state.selectedLayers
        .where((l) => l.type != LayerType.background)
        .toList();
    if (targets.isEmpty) return 0;
    _clipboardLayers.clear();
    _clipboardLayers.addAll(targets.map((l) => l.copyWith()));
    state = state.copyWith(hasClipboardLayers: true);
    return _clipboardLayers.length;
  }

  void pasteLayers() {
    if (_clipboardLayers.isEmpty) return;
    _recordHistory();
    const uuid = Uuid();
    final template = state.project.activeTemplate;
    final currentLayers = List<LayerItem>.from(template.getLayers(state.currentSide));
    final newLayers = <LayerItem>[];
    final updatedClipboard = <LayerItem>[];

    for (final layer in _clipboardLayers) {
      final copy = layer.copyWith(
        id: uuid.v4(),
        x: layer.x + 12.0,
        y: layer.y + 12.0,
        isLocked: false,
      );
      newLayers.add(copy);
      // Advance position for sequential cascading paste
      updatedClipboard.add(copy);
    }
    _clipboardLayers.clear();
    _clipboardLayers.addAll(updatedClipboard);

    currentLayers.addAll(newLayers);
    _updateTemplateLayers(currentLayers);

    state = state.copyWith(
      selectedLayerId: newLayers.first.id,
      selectedLayerIds: newLayers.map((l) => l.id).toSet(),
      hasClipboardLayers: true,
    );
    _persistWorkspace();
  }

  void duplicateSelectedLayers() {
    final targets = state.selectedLayers
        .where((l) => l.type != LayerType.background)
        .toList();
    if (targets.isEmpty) return;

    if (targets.length == 1) {
      duplicateLayer(targets.first.id);
      return;
    }

    _recordHistory();
    const uuid = Uuid();
    final template = state.project.activeTemplate;
    final layers = List<LayerItem>.from(template.getLayers(state.currentSide));
    final newDuplicates = <LayerItem>[];

    for (final target in targets) {
      final copy = target.copyWith(
        id: uuid.v4(),
        name: '${target.name} (Copy)',
        x: target.x + 10.0,
        y: target.y + 10.0,
        isLocked: false,
      );
      newDuplicates.add(copy);
      final idx = layers.indexWhere((l) => l.id == target.id);
      if (idx != -1) {
        layers.insert(idx + 1, copy);
      } else {
        layers.add(copy);
      }
    }

    _updateTemplateLayers(layers);
    state = state.copyWith(
      selectedLayerId: newDuplicates.first.id,
      selectedLayerIds: newDuplicates.map((l) => l.id).toSet(),
    );
    _persistWorkspace();
  }

  void alignSelectedLayers(LayerAlignment alignment) {
    final targets = state.selectedLayers
        .where((l) => !l.isLocked && l.type != LayerType.background)
        .toList();
    if (targets.isEmpty) return;

    _recordHistory();
    final cardW = state.project.widthMm * 4.0;
    final cardH = state.project.heightMm * 4.0;
    final Map<String, LayerItem> modified = {};

    if (targets.length == 1) {
      final layer = targets.first;
      double newX = layer.x;
      double newY = layer.y;

      switch (alignment) {
        case LayerAlignment.left:
          newX = 0;
          break;
        case LayerAlignment.centerHorizontal:
          newX = (cardW - layer.width) / 2.0;
          break;
        case LayerAlignment.right:
          newX = cardW - layer.width;
          break;
        case LayerAlignment.top:
          newY = 0;
          break;
        case LayerAlignment.centerVertical:
          newY = (cardH - layer.height) / 2.0;
          break;
        case LayerAlignment.bottom:
          newY = cardH - layer.height;
          break;
        case LayerAlignment.distributeHorizontal:
        case LayerAlignment.distributeVertical:
          return;
      }
      modified[layer.id] = layer.copyWith(x: newX, y: newY);
    } else {
      final minX = targets.map((l) => l.x).reduce(math.min);
      final maxX = targets.map((l) => l.x + l.width).reduce(math.max);
      final minY = targets.map((l) => l.y).reduce(math.min);
      final maxY = targets.map((l) => l.y + l.height).reduce(math.max);
      final centerX = (minX + maxX) / 2.0;
      final centerY = (minY + maxY) / 2.0;

      switch (alignment) {
        case LayerAlignment.left:
          for (final l in targets) {
            modified[l.id] = l.copyWith(x: minX);
          }
          break;
        case LayerAlignment.centerHorizontal:
          for (final l in targets) {
            modified[l.id] = l.copyWith(x: centerX - l.width / 2.0);
          }
          break;
        case LayerAlignment.right:
          for (final l in targets) {
            modified[l.id] = l.copyWith(x: maxX - l.width);
          }
          break;
        case LayerAlignment.top:
          for (final l in targets) {
            modified[l.id] = l.copyWith(y: minY);
          }
          break;
        case LayerAlignment.centerVertical:
          for (final l in targets) {
            modified[l.id] = l.copyWith(y: centerY - l.height / 2.0);
          }
          break;
        case LayerAlignment.bottom:
          for (final l in targets) {
            modified[l.id] = l.copyWith(y: maxY - l.height);
          }
          break;
        case LayerAlignment.distributeHorizontal:
          if (targets.length >= 3) {
            final sorted = List<LayerItem>.from(targets)
              ..sort((a, b) => a.x.compareTo(b.x));
            final totalWidths = sorted.fold<double>(0.0, (sum, l) => sum + l.width);
            final span = maxX - minX;
            final spacing = (span - totalWidths) / (sorted.length - 1);
            double curX = minX;
            for (final l in sorted) {
              modified[l.id] = l.copyWith(x: curX);
              curX += l.width + spacing;
            }
          }
          break;
        case LayerAlignment.distributeVertical:
          if (targets.length >= 3) {
            final sorted = List<LayerItem>.from(targets)
              ..sort((a, b) => a.y.compareTo(b.y));
            final totalHeights = sorted.fold<double>(0.0, (sum, l) => sum + l.height);
            final span = maxY - minY;
            final spacing = (span - totalHeights) / (sorted.length - 1);
            double curY = minY;
            for (final l in sorted) {
              modified[l.id] = l.copyWith(y: curY);
              curY += l.height + spacing;
            }
          }
          break;
      }
    }

    if (modified.isEmpty) return;

    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.map((l) => modified[l.id] ?? l).toList();
    _updateTemplateLayers(updatedLayers);
    _persistWorkspace();
  }

  void updateLayerGeometry(
    String id, {
    double? x,
    double? y,
    double? width,
    double? height,
    double? fontSize,
  }) {
    _recordHistory(continuousTag: 'geom_$id');
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.map((l) {
      if (l.id == id && !l.isLocked && l.type != LayerType.background) {
        return l.copyWith(
          x: x ?? l.x,
          y: y ?? l.y,
          width: width ?? l.width,
          height: height ?? l.height,
          fontSize: fontSize ?? l.fontSize,
        );
      }
      return l;
    }).toList();

    _updateTemplateLayers(updatedLayers);
  }

  void updateLayer(LayerItem updated) {
    _recordHistory(continuousTag: 'upd_${updated.id}');
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.map((l) {
      if (l.id == updated.id) return updated;
      return l;
    }).toList();

    _updateTemplateLayers(updatedLayers);
  }

  void addLayer(LayerItem layer) {
    _recordHistory();
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layer.type == LayerType.background
        ? [layer, ...layers]
        : [...layers, layer];
    _updateTemplateLayers(updatedLayers);
    state = state.copyWith(selectedLayerId: layer.id);
    _persistWorkspace();
  }

  void removeLayer(String id) {
    _recordHistory();
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.where((l) => l.id != id).toList();
    _updateTemplateLayers(updatedLayers);
    if (state.selectedLayerId == id) {
      state = state.copyWith(clearSelectedLayer: true);
    }
    _persistWorkspace();
  }

  void toggleLayerVisibility(String id) {
    _recordHistory();
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.map((l) {
      if (l.id == id) return l.copyWith(isVisible: !l.isVisible);
      return l;
    }).toList();
    _updateTemplateLayers(updatedLayers);
  }

  void toggleLayerLock(String id) {
    _recordHistory();
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.map((l) {
      if (l.id == id) return l.copyWith(isLocked: !l.isLocked);
      return l;
    }).toList();
    _updateTemplateLayers(updatedLayers);
  }

  void reorderLayers(int oldIndex, int newIndex) {
    _recordHistory();
    final template = state.project.activeTemplate;
    final layers = List<LayerItem>.from(template.getLayers(state.currentSide));
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = layers.removeAt(oldIndex);
    layers.insert(newIndex, item);
    _updateTemplateLayers(layers);
  }

  void reorderLayersDirect(int oldIndex, int newIndex) {
    _recordHistory();
    final template = state.project.activeTemplate;
    final layers = List<LayerItem>.from(template.getLayers(state.currentSide));
    final item = layers.removeAt(oldIndex);
    layers.insert(newIndex, item);
    _updateTemplateLayers(layers);
  }

  void setActiveRow(int index) {
    if (index == -1 || (index >= 0 && index < state.project.rows.length)) {
      int targetTemplateIdx = state.project.activeTemplateIndex;
      if (index >= 0 && index < state.project.rows.length) {
        final row = state.project.rows[index];
        final resolvedTpl = resolveTemplateForRow(row);
        final foundIdx = state.project.templates.indexWhere((t) => t.id == resolvedTpl.id);
        if (foundIdx != -1) {
          targetTemplateIdx = foundIdx;
        }
      }
      state = state.copyWith(
        project: state.project.copyWith(
          activeRowIndex: index,
          activeTemplateIndex: targetTemplateIdx,
        ),
      );
      _persistWorkspace();
    }
  }

  void syncActiveTemplateWithActiveRow() {
    if (state.project.rows.isEmpty) return;
    final activeIdx = state.project.activeRowIndex;
    if (activeIdx >= 0 && activeIdx < state.project.rows.length) {
      final row = state.project.rows[activeIdx];
      final resolvedTpl = resolveTemplateForRow(row);
      final foundIdx = state.project.templates.indexWhere((t) => t.id == resolvedTpl.id);
      if (foundIdx != -1 && foundIdx != state.project.activeTemplateIndex) {
        state = state.copyWith(
          project: state.project.copyWith(activeTemplateIndex: foundIdx),
        );
        _persistWorkspace();
      }
    }
  }

  void updateActiveRowData(String key, dynamic value) {
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    if (state.project.activeRowIndex >= 0 && state.project.activeRowIndex < rows.length) {
      final updatedRow = Map<String, dynamic>.from(rows[state.project.activeRowIndex]);
      updatedRow[key] = value;
      // Mirror title_name and card_name if appropriate
      if (key == 'title_name' && value.toString().trim().isNotEmpty) {
        final currentCardName = (updatedRow['card_name'] ?? '').toString().trim();
        if (currentCardName.isEmpty ||
            currentCardName.startsWith('Nueva') ||
            currentCardName.startsWith('Carta') ||
            currentCardName == '{{title_name}}' ||
            currentCardName == '{{title}}') {
          updatedRow['card_name'] = value.toString().trim();
        }
      } else if (key == 'card_name' && value.toString().trim().isNotEmpty && value.toString() != '{{title_name}}') {
        if (updatedRow.containsKey('title_name') && (updatedRow['title_name']?.toString().trim().isEmpty ?? true)) {
          updatedRow['title_name'] = value.toString().trim();
        }
      }
      rows[state.project.activeRowIndex] = updatedRow;
      state = state.copyWith(
        project: state.project.copyWith(rows: rows),
      );
      final game = (updatedRow['game'] ?? '').toString();
      _persistWorkspace(syncGameName: game);
    }
  }

  void updateRow(int index, Map<String, dynamic> row) {
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    if (index >= 0 && index < rows.length) {
      rows[index] = row;
      state = state.copyWith(
        project: state.project.copyWith(rows: rows),
      );
      final game = (row['game'] ?? '').toString();
      _persistWorkspace(syncGameName: game);
    }
  }

  void updateRowData(int index, String key, dynamic value) {
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    if (index >= 0 && index < rows.length) {
      final updatedRow = Map<String, dynamic>.from(rows[index]);
      updatedRow[key] = value;
      rows[index] = updatedRow;
      state = state.copyWith(
        project: state.project.copyWith(rows: rows),
      );
      final game = (updatedRow['game'] ?? '').toString();
      _persistWorkspace(syncGameName: game);
    }
  }

  void addRow(Map<String, dynamic> row) {
    final normalized = GameFolderService.normalizeCardRow(row, defaultGame: (row['game'] ?? '').toString());
    final rows = [...state.project.rows, normalized];
    final resolvedTpl = resolveTemplateForRow(normalized);
    final tplIdx = state.project.templates.indexWhere((t) => t.id == resolvedTpl.id);
    state = state.copyWith(
      project: state.project.copyWith(
        rows: rows,
        activeRowIndex: rows.length - 1,
        activeTemplateIndex: tplIdx != -1 ? tplIdx : state.project.activeTemplateIndex,
      ),
    );
    final game = (normalized['game'] ?? '').toString();
    _persistWorkspace(syncGameName: game);
  }

  void assignCardToGame(int rowIndex, String gameName) {
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    if (rowIndex >= 0 && rowIndex < rows.length) {
      final oldGame = (rows[rowIndex]['game'] ?? '').toString();
      final updatedRow = Map<String, dynamic>.from(rows[rowIndex]);
      updatedRow['game'] = gameName;
      rows[rowIndex] = updatedRow;
      state = state.copyWith(
        project: state.project.copyWith(rows: rows),
      );
      if (oldGame.isNotEmpty) {
        _persistWorkspace(syncGameName: oldGame);
      }
      _persistWorkspace(syncGameName: gameName);
    }
  }

  List<GameCategory> getCategoriesForGame(String gameName) {
    final cleanGame = gameName.trim();
    final normKey = cleanGame.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');

    // 1. Look up in state.gameCategories (direct match or normalized match)
    List<GameCategory>? existing = state.gameCategories[cleanGame];
    if (existing == null || existing.isEmpty) {
      for (final entry in state.gameCategories.entries) {
        final entryNorm = entry.key.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
        if (entryNorm == normKey && entry.value.isNotEmpty) {
          existing = entry.value;
          break;
        }
      }
    }

    final result = <GameCategory>[...(existing ?? [])];
    final seen = result.map((c) => c.name.toLowerCase().trim()).toSet();

    // 2. Auto-discover unique categories from existing card rows
    final gameCards = state.project.rows.where((r) {
      final g = (r['game'] ?? '').toString().trim();
      final gNorm = g.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
      return gNorm == normKey || g.toLowerCase() == cleanGame.toLowerCase();
    }).toList();

    for (final r in gameCards) {
      final c = (r['category'] ?? '').toString().trim();
      if (c.isEmpty || seen.contains(c.toLowerCase())) continue;
      seen.add(c.toLowerCase());
      final atk = (r['attack']?.toString() ?? '').trim();
      final def = (r['defense']?.toString() ?? '').trim();
      final cost = (r['cost']?.toString() ?? '').trim();
      final rarity = (r['rarity']?.toString() ?? '').trim();
      final rules = (r['rules_text'] ?? r['rules'] ?? '').toString().trim();

      int parsedColor = 0xFF7C3AED;
      final artColor = r['art_color'];
      if (artColor is int) {
        parsedColor = artColor;
      } else if (artColor != null) {
        parsedColor = int.tryParse(artColor.toString()) ?? 0xFF7C3AED;
      }

      result.add(
        GameCategory(
          id: 'cat-${c.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
          name: c,
          icon: (r['icon'] ?? '🃏').toString(),
          defaultType: (r['type'] ?? c).toString(),
          defaultColor: parsedColor,
          hasCost: cost.isNotEmpty,
          defaultCost: cost,
          hasCombatStats: atk.isNotEmpty || def.isNotEmpty,
          defaultAttack: atk,
          defaultDefense: def,
          hasRarity: rarity.isNotEmpty,
          defaultRarity: rarity,
          hasRules: rules.isNotEmpty,
          defaultRules: rules,
        ),
      );
    }
    return result;
  }

  void addCategoryToGame(
    String gameName,
    GameCategory category, {
    bool createDefaultCard = false,
  }) {
    final currentList = List<GameCategory>.from(state.gameCategories[gameName] ?? []);
    final existingIdx = currentList.indexWhere((c) => c.name.toLowerCase() == category.name.toLowerCase());
    if (existingIdx != -1) {
      currentList[existingIdx] = category;
    } else {
      currentList.add(category);
    }
    final updatedCategories = Map<String, List<GameCategory>>.from(state.gameCategories);
    updatedCategories[gameName] = currentList;
    state = state.copyWith(gameCategories: updatedCategories);
    _persistWorkspace();

    if (createDefaultCard) {
      createCardFromCategory(
        gameName,
        category,
        cardName: '${category.name} (Modelo)',
        isCategoryDefault: true,
      );
    }
  }

  void deleteCategoryFromGame(String gameName, String categoryName) {
    final currentList = List<GameCategory>.from(state.gameCategories[gameName] ?? []);
    currentList.removeWhere((c) => c.name.toLowerCase() == categoryName.toLowerCase());
    final updatedCategories = Map<String, List<GameCategory>>.from(state.gameCategories);
    updatedCategories[gameName] = currentList;
    state = state.copyWith(gameCategories: updatedCategories);
    _persistWorkspace();
  }

  GameCategory duplicateCategory(
    String gameName,
    GameCategory sourceCategory, {
    String? newName,
    bool createPresetCard = true,
  }) {
    final currentList = List<GameCategory>.from(state.gameCategories[gameName] ?? []);
    final baseName = newName ?? 'Copia de ${sourceCategory.name}';
    String finalName = baseName;
    int counter = 2;
    while (currentList.any((c) => c.name.toLowerCase() == finalName.toLowerCase())) {
      finalName = '$baseName $counter';
      counter++;
    }

    final newCat = sourceCategory.copyWith(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: finalName,
    );
    addCategoryToGame(gameName, newCat, createDefaultCard: false);

    if (createPresetCard) {
      createCardFromCategory(gameName, newCat, cardName: '$finalName (Preset)', isCategoryDefault: true);
    }

    return newCat;
  }

  void createCardFromCategory(
    String gameName,
    GameCategory category, {
    String? cardName,
    bool isCategoryDefault = false,
    Map<String, dynamic>? baseCard,
  }) {
    final normTarget = GameFolderService.normalizeGameKey(gameName);
    if (state.deletedGames.any((g) => GameFolderService.normalizeGameKey(g) == normTarget)) {
      final updatedDeleted = state.deletedGames
          .where((g) => GameFolderService.normalizeGameKey(g) != normTarget)
          .toSet();
      final updatedCategories = Map<String, List<GameCategory>>.from(state.gameCategories)
        ..removeWhere((k, _) => GameFolderService.normalizeGameKey(k) == normTarget);
      state = state.copyWith(
        deletedGames: updatedDeleted,
        gameCategories: updatedCategories,
      );
    }

    String assignedTemplateId;
    if (isCategoryDefault) {
      const uuid = Uuid();
      final sourceTpl = baseCard != null
          ? resolveTemplateForRow(baseCard)
          : state.project.activeTemplate;
      final clonedFront = sourceTpl.layers.map((l) => l.copyWith(id: uuid.v4())).toList();
      final clonedBack = sourceTpl.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList();
      final safeGame = gameName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final safeCat = category.name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final newTemplate = CardTemplate(
        id: 'tpl_cat_${safeGame}_${safeCat}_${uuid.v4().substring(0, 8)}',
        name: '${category.name} Template',
        layers: clonedFront,
        backLayers: clonedBack,
        backgroundColor: sourceTpl.backgroundColor,
        backBackgroundColor: sourceTpl.backBackgroundColor,
        cornerRadius: sourceTpl.cornerRadius,
      );
      assignedTemplateId = newTemplate.id;
      final updatedTemplates = [...state.project.templates, newTemplate];
      state = state.copyWith(
        project: state.project.copyWith(
          templates: updatedTemplates,
          activeTemplateIndex: updatedTemplates.length - 1,
        ),
      );
    } else {
      final modelCard = getCategoryDefaultCard(gameName, category.name);
      final sourceTpl = modelCard != null
          ? resolveTemplateForRow(modelCard)
          : resolveTemplateForRow({'game': gameName, 'category': category.name});
      const uuid = Uuid();
      final cardTplId = 'tpl_card_${uuid.v4().substring(0, 8)}';
      final cardTpl = CardTemplate(
        id: cardTplId,
        name: '${cardName ?? category.name} Template',
        layers: sourceTpl.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
        backLayers: sourceTpl.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
        backgroundColor: sourceTpl.backgroundColor,
        backBackgroundColor: sourceTpl.backBackgroundColor,
        cornerRadius: sourceTpl.cornerRadius,
      );
      assignedTemplateId = cardTplId;
      final updatedTemplates = [...state.project.templates, cardTpl];
      state = state.copyWith(
        project: state.project.copyWith(
          templates: updatedTemplates,
        ),
      );
    }

    final finalCost = category.hasCost && category.defaultCost.isNotEmpty
        ? category.defaultCost
        : (category.hasCost ? '1' : '');
    final finalType = category.defaultType.isNotEmpty ? category.defaultType : 'Carta Normal';
    final finalRarity = category.hasRarity && category.defaultRarity.isNotEmpty
        ? category.defaultRarity
        : (category.hasRarity ? 'Común' : '');
    final finalAttack = category.hasCombatStats && category.defaultAttack.isNotEmpty
        ? category.defaultAttack
        : (category.hasCombatStats ? '0' : '');
    final finalDefense = category.hasCombatStats && category.defaultDefense.isNotEmpty
        ? category.defaultDefense
        : (category.hasCombatStats ? '0' : '');
    final finalRules = category.defaultRules.isNotEmpty
        ? category.defaultRules
        : (category.hasRules ? 'Habilidad especial de ${category.name}.' : '');

    final newCard = <String, dynamic>{
      'card_name': cardName ?? (isCategoryDefault ? '${category.name} (Modelo)' : 'Nueva ${category.name}'),
      'game': gameName,
      'category': category.name,
      'card_status': isCategoryDefault ? 'Muestra' : 'Definitiva',
      'qty': '1',
      'cost': finalCost,
      'type': finalType,
      'rarity': finalRarity,
      'attack': finalAttack,
      'defense': finalDefense,
      'creator': 'Grimoire Studio',
      'icon': category.icon.isNotEmpty ? category.icon : '🃏',
      'art_color': category.defaultColor,
      'art_url': (baseCard?['art_url']?.toString().trim().isNotEmpty ?? false)
          ? baseCard!['art_url'].toString().trim()
          : () {
              final tplToCheck = state.project.templates.firstWhere(
                (t) => t.id == assignedTemplateId,
                orElse: () => state.project.activeTemplate,
              );
              final imgL = [...tplToCheck.layers, ...tplToCheck.backLayers].cast<LayerItem>().firstWhere(
                (l) => (l.type == LayerType.image || l.bindingKey == 'art_url') && (l.imagePath ?? '').trim().isNotEmpty,
                orElse: () => const LayerItem(id: '', name: '', type: LayerType.image),
              );
              if ((imgL.imagePath ?? '').trim().isNotEmpty) {
                String norm = imgL.imagePath!.trim().replaceAll('\\', '/');
                final aIdx = norm.indexOf('assets/');
                return aIdx != -1 ? norm.substring(aIdx) : norm;
              }
              return '';
            }(),
      'prompt': '',
      'rules_text': finalRules,
      'rules': finalRules,
      if (assignedTemplateId.isNotEmpty) 'template_id': assignedTemplateId,
      if (isCategoryDefault) 'is_category_default': 'true',
    };

    category.customFields.forEach((k, v) {
      newCard[k] = v;
    });

    // Initialize any dynamic variables present in the template
    for (final v in state.project.getAllTemplateVariables()) {
      if (!GameFolderService.internalKeys.contains(v) && !newCard.containsKey(v)) {
        if (v == 'title_name' || v == 'title' || v == 'titulo') {
          newCard[v] = newCard['card_name'];
        } else {
          final matchingLayer = state.project.templates
              .expand((t) => [...t.layers, ...t.backLayers])
              .firstWhere(
                (l) => l.bindingKey == v && l.type == LayerType.text && l.text.trim().isNotEmpty && !l.text.contains('{{$v}}'),
                orElse: () => const LayerItem(id: '', name: '', type: LayerType.text),
              );
          newCard[v] = matchingLayer.text.trim().isNotEmpty ? matchingLayer.text : '';
        }
      }
    }
    addRow(newCard);
  }

  void setCategoryForActiveCard(String categoryName, {bool applyModelAttributes = false}) {
    if (state.project.rows.isEmpty) return;
    final activeRow = Map<String, dynamic>.from(state.project.activeRow);
    activeRow['category'] = categoryName;

    final game = (activeRow['game'] ?? 'Magic').toString();
    final categories = getCategoriesForGame(game);
    final match = categories.firstWhere(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => GameCategory(id: 'cat', name: categoryName),
    );

    if (match.id != 'cat') {
      activeRow['icon'] = match.icon;
      activeRow['art_color'] = match.defaultColor;

      if (applyModelAttributes) {
        if (!match.hasCombatStats || match.defaultAttack.trim().isEmpty) {
          activeRow['attack'] = '';
        } else {
          activeRow['attack'] = match.defaultAttack;
        }
        if (!match.hasCombatStats || match.defaultDefense.trim().isEmpty) {
          activeRow['defense'] = '';
        } else {
          activeRow['defense'] = match.defaultDefense;
        }
        if (!match.hasCost || match.defaultCost.trim().isEmpty) {
          activeRow['cost'] = '';
        } else {
          activeRow['cost'] = match.defaultCost;
        }
        if (match.defaultType.isNotEmpty) activeRow['type'] = match.defaultType;
        if (match.hasRarity) {
          activeRow['rarity'] = match.defaultRarity;
        } else {
          activeRow['rarity'] = '';
        }
        if (match.hasRules && match.defaultRules.isNotEmpty) {
          activeRow['rules_text'] = match.defaultRules;
          activeRow['rules'] = match.defaultRules;
        }
        match.customFields.forEach((k, v) {
          activeRow[k] = v;
        });
      }
    }

    // Preserve the card's current visual template and layers!
    final currentTplId = (activeRow['template_id'] ?? '').toString().trim();
    if (currentTplId.isEmpty) {
      final currentTpl = resolveTemplateForRow(activeRow);
      const uuid = Uuid();
      final dedicatedCardTplId = 'tpl_card_${uuid.v4().substring(0, 8)}';
      final clonedTpl = currentTpl.copyWith(
        id: dedicatedCardTplId,
        name: '${activeRow['card_name'] ?? categoryName} Template',
        layers: currentTpl.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
        backLayers: currentTpl.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
      );
      final currentTemplates = List<CardTemplate>.from(state.project.templates);
      currentTemplates.add(clonedTpl);
      activeRow['template_id'] = dedicatedCardTplId;
      state = state.copyWith(
        project: state.project.copyWith(templates: currentTemplates),
      );
    }

    updateRow(state.project.activeRowIndex, activeRow);

    final resolvedTpl = resolveTemplateForRow(activeRow);
    final tplIdx = state.project.templates.indexWhere((t) => t.id == resolvedTpl.id);
    if (tplIdx != -1 && tplIdx != state.project.activeTemplateIndex) {
      state = state.copyWith(
        project: state.project.copyWith(activeTemplateIndex: tplIdx),
      );
    }

    syncGameDataCsv(game);
  }

  void applyCategoryModelToActiveCard(GameCategory category) {
    if (state.project.rows.isEmpty) return;
    final activeRow = Map<String, dynamic>.from(state.project.activeRow);
    activeRow['category'] = category.name;
    activeRow['icon'] = category.icon;
    activeRow['art_color'] = category.defaultColor;
    if (category.defaultType.isNotEmpty) activeRow['type'] = category.defaultType;
    if (category.hasCost) {
      activeRow['cost'] = category.defaultCost;
    } else {
      activeRow['cost'] = '';
    }
    if (category.hasCombatStats) {
      activeRow['attack'] = category.defaultAttack;
      activeRow['defense'] = category.defaultDefense;
    } else {
      activeRow['attack'] = '';
      activeRow['defense'] = '';
    }
    if (category.hasRarity) {
      activeRow['rarity'] = category.defaultRarity;
    } else {
      activeRow['rarity'] = '';
    }
    if (category.hasRules && category.defaultRules.isNotEmpty) {
      activeRow['rules_text'] = category.defaultRules;
      activeRow['rules'] = category.defaultRules;
    }
    category.customFields.forEach((k, v) {
      activeRow[k] = v;
    });

    final game = (activeRow['game'] ?? 'Magic').toString();
    final safeGame = game.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final safeCat = category.name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final catTplId = 'tpl_${safeGame}_$safeCat';
    final hasCatTpl = state.project.templates.any((t) => t.id == catTplId);

    final catModel = getCategoryDefaultCard(game, category.name);
    final modelTplId = (catModel?['template_id'] ?? '').toString().trim();

    CardTemplate? sourceTpl;
    if (modelTplId.isNotEmpty) {
      sourceTpl = state.project.templates.where((t) => t.id == modelTplId).firstOrNull;
    }
    sourceTpl ??= hasCatTpl
        ? state.project.templates.firstWhere((t) => t.id == catTplId)
        : resolveTemplateForRow({'game': game, 'category': category.name});

    // Clone into dedicated card template so it does not mutate model or other cards
    const uuid = Uuid();
    final dedicatedCardTplId = 'tpl_card_${uuid.v4().substring(0, 8)}';
    final clonedTpl = sourceTpl.copyWith(
      id: dedicatedCardTplId,
      name: '${activeRow['card_name'] ?? category.name} Template',
      layers: sourceTpl.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
      backLayers: sourceTpl.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
    );
    final currentTemplates = List<CardTemplate>.from(state.project.templates);
    currentTemplates.add(clonedTpl);
    activeRow['template_id'] = dedicatedCardTplId;

    state = state.copyWith(
      project: state.project.copyWith(templates: currentTemplates),
    );

    updateRow(state.project.activeRowIndex, activeRow);

    final tplIdx = currentTemplates.length - 1;
    state = state.copyWith(
      project: state.project.copyWith(activeTemplateIndex: tplIdx),
    );

    syncGameDataCsv(game);
  }

  bool isRowCategoryDefault(Map<String, dynamic> row) {
    final val = (row['is_category_default'] ?? '').toString().toLowerCase().trim();
    return val == 'true' || val == '1' || val == 'yes';
  }

  bool isRowGameDefault(Map<String, dynamic> row) {
    final val = (row['is_game_default'] ?? '').toString().toLowerCase().trim();
    return val == 'true' || val == '1' || val == 'yes';
  }

  Map<String, dynamic>? getCategoryDefaultCard(String gameName, String categoryName) {
    if (categoryName.trim().isEmpty) return null;
    return state.project.rows.where((r) {
      final g = (r['game'] ?? '').toString().toLowerCase().trim();
      final c = (r['category'] ?? '').toString().toLowerCase().trim();
      return g == gameName.toLowerCase().trim() &&
          c == categoryName.toLowerCase().trim() &&
          isRowCategoryDefault(r);
    }).firstOrNull;
  }

  Map<String, dynamic>? getGameDefaultCard(String gameName) {
    return state.project.rows.where((r) {
      final g = (r['game'] ?? '').toString().toLowerCase().trim();
      return g == gameName.toLowerCase().trim() && isRowGameDefault(r);
    }).firstOrNull;
  }

  void markActiveCardAsCategoryDefault() {
    if (state.project.rows.isEmpty) return;
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? '').toString().trim();
    final categoryName = (activeRow['category'] ?? '').toString().trim();
    if (categoryName.isEmpty || gameName.isEmpty) return;

    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    final activeIdx = state.project.activeRowIndex.clamp(0, rows.length - 1);
    final activeTemplate = state.project.activeTemplate;

    const uuid = Uuid();
    final safeGame = gameName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final safeCat = categoryName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final catTemplateId = 'tpl_${safeGame}_$safeCat';

    final currentTemplates = List<CardTemplate>.from(state.project.templates);
    final existingIdx = currentTemplates.indexWhere((t) => t.id == catTemplateId);

    // Freeze and preserve the appearance of ALL other cards that were using or resolving to catTemplateId or activeTemplate
    if (existingIdx != -1) {
      final oldCatTemplate = currentTemplates[existingIdx];
      for (int i = 0; i < rows.length; i++) {
        if (i != activeIdx) {
          final r = rows[i];
          final rTplId = (r['template_id'] ?? '').toString().trim();
          if (rTplId == catTemplateId || (rTplId.isEmpty && resolveTemplateForRow(r).id == catTemplateId)) {
            final preservedId = 'tpl_card_${uuid.v4().substring(0, 8)}';
            final preservedTpl = CardTemplate(
              id: preservedId,
              name: '${r['card_name'] ?? 'Carta'} Plantilla',
              layers: oldCatTemplate.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
              backLayers: oldCatTemplate.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
              backgroundColor: oldCatTemplate.backgroundColor,
              backBackgroundColor: oldCatTemplate.backBackgroundColor,
              cornerRadius: oldCatTemplate.cornerRadius,
            );
            currentTemplates.add(preservedTpl);
            final updatedR = Map<String, dynamic>.from(r);
            updatedR['template_id'] = preservedId;
            rows[i] = updatedR;
          }
        }
      }
    }

    for (int i = 0; i < rows.length; i++) {
      if (i != activeIdx) {
        final r = rows[i];
        final rTplId = (r['template_id'] ?? '').toString().trim();
        if (rTplId == activeTemplate.id && activeTemplate.id != catTemplateId) {
          final preservedId = 'tpl_card_${uuid.v4().substring(0, 8)}';
          final preservedTpl = CardTemplate(
            id: preservedId,
            name: '${r['card_name'] ?? 'Carta'} Plantilla',
            layers: activeTemplate.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
            backLayers: activeTemplate.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
            backgroundColor: activeTemplate.backgroundColor,
            backBackgroundColor: activeTemplate.backBackgroundColor,
            cornerRadius: activeTemplate.cornerRadius,
          );
          currentTemplates.add(preservedTpl);
          final updatedR = Map<String, dynamic>.from(r);
          updatedR['template_id'] = preservedId;
          rows[i] = updatedR;
        }
      }
    }

    CardTemplate catTemplate;
    if (existingIdx != -1) {
      catTemplate = currentTemplates[existingIdx].copyWith(
        layers: activeTemplate.layers.map((l) => l.copyWith()).toList(),
        backLayers: activeTemplate.backLayers.map((l) => l.copyWith()).toList(),
        backgroundColor: activeTemplate.backgroundColor,
        backBackgroundColor: activeTemplate.backBackgroundColor,
        cornerRadius: activeTemplate.cornerRadius,
      );
      currentTemplates[existingIdx] = catTemplate;
    } else {
      catTemplate = CardTemplate(
        id: catTemplateId,
        name: '$gameName - $categoryName Modelo',
        layers: activeTemplate.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
        backLayers: activeTemplate.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
        backgroundColor: activeTemplate.backgroundColor,
        backBackgroundColor: activeTemplate.backBackgroundColor,
        cornerRadius: activeTemplate.cornerRadius,
      );
      currentTemplates.add(catTemplate);
    }

    final catTplIndex = currentTemplates.indexWhere((t) => t.id == catTemplateId);

    for (int i = 0; i < rows.length; i++) {
      final rGame = (rows[i]['game'] ?? '').toString().toLowerCase().trim();
      final rCat = (rows[i]['category'] ?? '').toString().toLowerCase().trim();
      if (rGame == gameName.toLowerCase() && rCat == categoryName.toLowerCase()) {
        final updated = Map<String, dynamic>.from(rows[i]);
        if (i == activeIdx) {
          updated['is_category_default'] = 'true';
          updated['template_id'] = catTemplateId;
        } else {
          updated['is_category_default'] = 'false';
        }
        rows[i] = updated;
      }
    }

    final currentCats = List<GameCategory>.from(getCategoriesForGame(gameName));
    final catIdx = currentCats.indexWhere((c) => c.name.toLowerCase() == categoryName.toLowerCase());
    if (catIdx == -1) {
      currentCats.add(GameCategory(
        id: 'cat_${uuid.v4().substring(0, 8)}',
        name: categoryName,
        icon: (activeRow['icon'] ?? '🛑').toString(),
        defaultColor: activeRow['art_color'] is int
            ? activeRow['art_color'] as int
            : (int.tryParse(activeRow['art_color']?.toString() ?? '') ?? 0xFFEF4444),
        defaultType: (activeRow['type'] ?? categoryName).toString(),
        defaultRules: (activeRow['rules_text'] ?? activeRow['rules'] ?? '').toString(),
      ));
    }
    final updatedCategories = Map<String, List<GameCategory>>.from(state.gameCategories);
    updatedCategories[gameName] = currentCats;

    state = state.copyWith(
      gameCategories: updatedCategories,
      project: state.project.copyWith(
        templates: currentTemplates,
        activeTemplateIndex: catTplIndex >= 0 ? catTplIndex : state.project.activeTemplateIndex,
        rows: rows,
      ),
    );
    _persistWorkspace(syncGameName: gameName);
  }

  void unmarkActiveCardAsCategoryDefault() {
    if (state.project.rows.isEmpty) return;
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? '').toString().trim();
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    final activeIdx = state.project.activeRowIndex.clamp(0, rows.length - 1);
    final updated = Map<String, dynamic>.from(rows[activeIdx]);
    updated['is_category_default'] = 'false';
    rows[activeIdx] = updated;
    state = state.copyWith(project: state.project.copyWith(rows: rows));
    _persistWorkspace(syncGameName: gameName);
  }

  void markActiveCardAsGameDefault() {
    if (state.project.rows.isEmpty) return;
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? '').toString().trim();
    if (gameName.isEmpty) return;

    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    final activeIdx = state.project.activeRowIndex.clamp(0, rows.length - 1);
    final activeTemplate = state.project.activeTemplate;

    const uuid = Uuid();
    final safeGame = gameName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final gameTemplateId = 'tpl_${safeGame}_base';

    final currentTemplates = List<CardTemplate>.from(state.project.templates);
    final existingIdx = currentTemplates.indexWhere((t) => t.id == gameTemplateId);

    // Freeze and preserve the appearance of ALL other cards that were using or resolving to gameTemplateId or activeTemplate
    if (existingIdx != -1) {
      final oldGameTemplate = currentTemplates[existingIdx];
      for (int i = 0; i < rows.length; i++) {
        if (i != activeIdx) {
          final r = rows[i];
          final rTplId = (r['template_id'] ?? '').toString().trim();
          if (rTplId == gameTemplateId || (rTplId.isEmpty && resolveTemplateForRow(r).id == gameTemplateId)) {
            final preservedId = 'tpl_card_${uuid.v4().substring(0, 8)}';
            final preservedTpl = CardTemplate(
              id: preservedId,
              name: '${r['card_name'] ?? 'Carta'} Plantilla',
              layers: oldGameTemplate.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
              backLayers: oldGameTemplate.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
              backgroundColor: oldGameTemplate.backgroundColor,
              backBackgroundColor: oldGameTemplate.backBackgroundColor,
              cornerRadius: oldGameTemplate.cornerRadius,
            );
            currentTemplates.add(preservedTpl);
            final updatedR = Map<String, dynamic>.from(r);
            updatedR['template_id'] = preservedId;
            rows[i] = updatedR;
          }
        }
      }
    }

    for (int i = 0; i < rows.length; i++) {
      if (i != activeIdx) {
        final r = rows[i];
        final rTplId = (r['template_id'] ?? '').toString().trim();
        if (rTplId == activeTemplate.id && activeTemplate.id != gameTemplateId) {
          final preservedId = 'tpl_card_${uuid.v4().substring(0, 8)}';
          final preservedTpl = CardTemplate(
            id: preservedId,
            name: '${r['card_name'] ?? 'Carta'} Plantilla',
            layers: activeTemplate.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
            backLayers: activeTemplate.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
            backgroundColor: activeTemplate.backgroundColor,
            backBackgroundColor: activeTemplate.backBackgroundColor,
            cornerRadius: activeTemplate.cornerRadius,
          );
          currentTemplates.add(preservedTpl);
          final updatedR = Map<String, dynamic>.from(r);
          updatedR['template_id'] = preservedId;
          rows[i] = updatedR;
        }
      }
    }

    CardTemplate gameTemplate;
    if (existingIdx != -1) {
      gameTemplate = currentTemplates[existingIdx].copyWith(
        layers: activeTemplate.layers.map((l) => l.copyWith()).toList(),
        backLayers: activeTemplate.backLayers.map((l) => l.copyWith()).toList(),
        backgroundColor: activeTemplate.backgroundColor,
        backBackgroundColor: activeTemplate.backBackgroundColor,
        cornerRadius: activeTemplate.cornerRadius,
      );
      currentTemplates[existingIdx] = gameTemplate;
    } else {
      gameTemplate = CardTemplate(
        id: gameTemplateId,
        name: '$gameName Modelo Base',
        layers: activeTemplate.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
        backLayers: activeTemplate.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
        backgroundColor: activeTemplate.backgroundColor,
        backBackgroundColor: activeTemplate.backBackgroundColor,
        cornerRadius: activeTemplate.cornerRadius,
      );
      currentTemplates.add(gameTemplate);
    }

    final gameTplIndex = currentTemplates.indexWhere((t) => t.id == gameTemplateId);

    for (int i = 0; i < rows.length; i++) {
      final rGame = (rows[i]['game'] ?? '').toString().toLowerCase().trim();
      if (rGame == gameName.toLowerCase()) {
        final updated = Map<String, dynamic>.from(rows[i]);
        if (i == activeIdx) {
          updated['is_game_default'] = 'true';
          updated['template_id'] = gameTemplateId;
        } else {
          updated['is_game_default'] = 'false';
        }
        rows[i] = updated;
      }
    }

    state = state.copyWith(
      project: state.project.copyWith(
        templates: currentTemplates,
        activeTemplateIndex: gameTplIndex >= 0 ? gameTplIndex : state.project.activeTemplateIndex,
        rows: rows,
      ),
    );
    _persistWorkspace(syncGameName: gameName);
  }

  void unmarkActiveCardAsGameDefault() {
    if (state.project.rows.isEmpty) return;
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? '').toString().trim();
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    final activeIdx = state.project.activeRowIndex.clamp(0, rows.length - 1);
    final updated = Map<String, dynamic>.from(rows[activeIdx]);
    updated['is_game_default'] = 'false';
    rows[activeIdx] = updated;
    state = state.copyWith(project: state.project.copyWith(rows: rows));
    _persistWorkspace(syncGameName: gameName);
  }

  void addCardToGame(
    String gameName, {
    String? cardName,
    String? type,
    String? icon,
    String? category,
    int? artColor,
    String? rulesText,
    String? presetTemplateId,
  }) {
    final normTarget = GameFolderService.normalizeGameKey(gameName);
    final hasExistingCardsForGame = state.project.rows
        .any((r) => GameFolderService.normalizeGameKey((r['game'] ?? '').toString()) == normTarget);

    if (state.deletedGames.any((g) => GameFolderService.normalizeGameKey(g) == normTarget) ||
        (!hasExistingCardsForGame && category == null)) {
      final updatedDeleted = state.deletedGames
          .where((g) => GameFolderService.normalizeGameKey(g) != normTarget)
          .toSet();
      final updatedCategories = Map<String, List<GameCategory>>.from(state.gameCategories)
        ..removeWhere((k, _) => GameFolderService.normalizeGameKey(k) == normTarget);
      state = state.copyWith(
        deletedGames: updatedDeleted,
        gameCategories: updatedCategories,
      );
    }

    // 1. Look for category default card first
    Map<String, dynamic>? modelCard;
    if (category != null && category.isNotEmpty) {
      modelCard = getCategoryDefaultCard(gameName, category);
    }
    // 2. If none, look for game default card
    modelCard ??= getGameDefaultCard(gameName);

    final categories = getCategoriesForGame(gameName);
    GameCategory? chosenCategory;
    if (category != null && category.isNotEmpty) {
      chosenCategory = categories.firstWhere(
        (c) => c.name.toLowerCase() == category.toLowerCase(),
        orElse: () => GameCategory(id: 'cat', name: category),
      );
    } else if (categories.isNotEmpty) {
      chosenCategory = categories.first;
    } else {
      // Game has no categories yet! Ensure default 'General' category is created
      final defaultCat = GameCategory(
        id: 'cat_general_${DateTime.now().millisecondsSinceEpoch}',
        name: 'General',
        icon: '🃏',
        defaultType: type ?? 'Carta Normal',
        defaultCost: '',
        defaultRarity: 'Común',
        defaultAttack: '',
        defaultDefense: '',
        defaultRules: rulesText ?? '',
        defaultColor: 0xFF7C3AED,
        hasCost: false,
        hasCombatStats: false,
        hasRarity: false,
        hasRules: false,
      );
      final updatedCats = Map<String, List<GameCategory>>.from(state.gameCategories);
      updatedCats[gameName] = [defaultCat];
      state = state.copyWith(gameCategories: updatedCats);
      chosenCategory = defaultCat;
    }

    final hasValidCat = chosenCategory.id != 'cat';
    final preferModel = category == null && modelCard != null;

    final finalCatName = category ?? (preferModel && modelCard['category']?.toString().isNotEmpty == true
        ? modelCard['category'].toString()
        : (hasValidCat ? chosenCategory.name : 'General'));

    final finalIcon = icon ?? (preferModel && modelCard['icon']?.toString().isNotEmpty == true
        ? modelCard['icon'].toString()
        : (hasValidCat ? chosenCategory.icon : '🃏'));

    final finalType = type ?? (preferModel && modelCard['type']?.toString().isNotEmpty == true
        ? modelCard['type'].toString()
        : (hasValidCat && chosenCategory.defaultType.isNotEmpty ? chosenCategory.defaultType : 'Carta Normal'));

    final finalColor = artColor ??
        (preferModel && modelCard['art_color'] != null
            ? (modelCard['art_color'] is int
                ? modelCard['art_color'] as int
                : int.tryParse(modelCard['art_color'].toString()))
            : (hasValidCat ? chosenCategory.defaultColor : null)) ??
        0xFF7C3AED;

    final finalRules = rulesText ??
        (preferModel && modelCard['rules_text']?.toString().isNotEmpty == true
            ? modelCard['rules_text'].toString()
            : (hasValidCat && chosenCategory.defaultRules.isNotEmpty
                ? chosenCategory.defaultRules
                : 'Habilidad especial para el juego $gameName.'));

    final finalCost = preferModel
        ? (modelCard['cost']?.toString() ?? '1')
        : (hasValidCat && !chosenCategory.hasCost
            ? ''
            : (hasValidCat && chosenCategory.defaultCost.isNotEmpty ? chosenCategory.defaultCost : '1'));

    final finalRarity = preferModel
        ? (modelCard['rarity']?.toString() ?? 'Común')
        : (hasValidCat && !chosenCategory.hasRarity
            ? ''
            : (hasValidCat && chosenCategory.defaultRarity.isNotEmpty ? chosenCategory.defaultRarity : 'Común'));

    final finalAtk = preferModel
        ? (modelCard['attack']?.toString() ?? '')
        : (hasValidCat && !chosenCategory.hasCombatStats
            ? ''
            : (hasValidCat && chosenCategory.defaultAttack.isNotEmpty ? chosenCategory.defaultAttack : '1'));

    final finalDef = preferModel
        ? (modelCard['defense']?.toString() ?? '')
        : (hasValidCat && !chosenCategory.hasCombatStats
            ? ''
            : (hasValidCat && chosenCategory.defaultDefense.isNotEmpty ? chosenCategory.defaultDefense : '1'));

    final existingGameCards = state.project.rows
        .where((r) => GameFolderService.normalizeGameKey((r['game'] ?? '').toString()) == normTarget)
        .toList();

    CardTemplate sourceTpl;
    if (modelCard != null) {
      sourceTpl = resolveTemplateForRow(modelCard);
    } else if (presetTemplateId != null && presetTemplateId.isNotEmpty) {
      sourceTpl = CardTemplate.getPresetById(presetTemplateId);
    } else if (existingGameCards.isNotEmpty) {
      sourceTpl = resolveTemplateForRow({'game': gameName, 'category': finalCatName});
    } else {
      // Game is brand new! Always initialize with clean default structure
      final cleanGame = gameName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      sourceTpl = CardTemplate.createDefault(
        id: 'tpl_${cleanGame}_default',
        name: '$gameName Plantilla',
      );
    }

    const uuid = Uuid();
    final cardTplId = 'tpl_card_${uuid.v4().substring(0, 8)}';
    final cardTpl = CardTemplate(
      id: cardTplId,
      name: '${cardName ?? 'Carta Normal'} Plantilla',
      layers: sourceTpl.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
      backLayers: sourceTpl.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
      backgroundColor: sourceTpl.backgroundColor,
      backBackgroundColor: sourceTpl.backBackgroundColor,
      cornerRadius: sourceTpl.cornerRadius,
    );
    final updatedTemplates = [...state.project.templates, cardTpl];
    state = state.copyWith(
      project: state.project.copyWith(templates: updatedTemplates),
    );

    final newCard = <String, dynamic>{
      'card_name': cardName ?? 'Carta Normal ($gameName)',
      'game': gameName,
      'category': finalCatName.isNotEmpty ? finalCatName : 'General',
      'card_status': 'Definitiva',
      'qty': '1',
      'cost': finalCost,
      'type': finalType.isNotEmpty ? finalType : 'Carta Normal',
      'rarity': finalRarity.isNotEmpty ? finalRarity : 'Común',
      'attack': finalAtk,
      'defense': finalDef,
      'rules_text': finalRules,
      'rules': finalRules,
      'template_id': cardTplId,
      'creator': 'Grimoire Studio',
      'icon': finalIcon.isNotEmpty ? finalIcon : '🃏',
      'art_color': finalColor,
      'art_url': (modelCard?['art_url']?.toString().trim().isNotEmpty ?? false)
          ? modelCard!['art_url'].toString().trim()
          : () {
              final imgL = [...sourceTpl.layers, ...sourceTpl.backLayers].cast<LayerItem>().firstWhere(
                (l) => (l.type == LayerType.image || l.bindingKey == 'art_url') && (l.imagePath ?? '').trim().isNotEmpty,
                orElse: () => const LayerItem(id: '', name: '', type: LayerType.image),
              );
              if ((imgL.imagePath ?? '').trim().isNotEmpty) {
                String norm = imgL.imagePath!.trim().replaceAll('\\', '/');
                final aIdx = norm.indexOf('assets/');
                return aIdx != -1 ? norm.substring(aIdx) : norm;
              }
              return '';
            }(),
      'prompt': '',
    };
    // Initialize any dynamic variables present in the template
    for (final v in sourceTpl.getReferencedVariables()) {
      if (!GameFolderService.internalKeys.contains(v) && !newCard.containsKey(v)) {
        if (v == 'title_name' || v == 'title' || v == 'titulo') {
          newCard[v] = newCard['card_name'];
        } else {
          final matchingLayer = [...sourceTpl.layers, ...sourceTpl.backLayers].firstWhere(
            (l) => l.bindingKey == v && l.type == LayerType.text && l.text.trim().isNotEmpty && !l.text.contains('{{$v}}'),
            orElse: () => const LayerItem(id: '', name: '', type: LayerType.text),
          );
          newCard[v] = matchingLayer.text.trim().isNotEmpty ? matchingLayer.text : '';
        }
      }
    }
    addRow(newCard);
  }

  void duplicateCard(int index) {
    if (index < 0 || index >= state.project.rows.length) return;
    _recordHistory();
    const uuid = Uuid();
    final source = Map<String, dynamic>.from(state.project.rows[index]);
    final cloned = Map<String, dynamic>.from(source);
    cloned.remove('is_category_default');
    cloned.remove('is_game_default');
    final originalName = source['card_name']?.toString() ?? 'Carta';
    cloned['card_name'] = '$originalName (Copia)';
    final game = cloned['game']?.toString() ?? 'Magic';

    final sourceTpl = resolveTemplateForRow(source);
    final clonedTplId = 'tpl_card_${uuid.v4().substring(0, 8)}';
    final clonedTpl = CardTemplate(
      id: clonedTplId,
      name: '${cloned['card_name']} Plantilla',
      layers: sourceTpl.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
      backLayers: sourceTpl.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
      backgroundColor: sourceTpl.backgroundColor,
      backBackgroundColor: sourceTpl.backBackgroundColor,
      cornerRadius: sourceTpl.cornerRadius,
    );
    cloned['template_id'] = clonedTplId;

    final templates = List<CardTemplate>.from(state.project.templates)..add(clonedTpl);
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    rows.insert(index + 1, cloned);
    state = state.copyWith(
      project: state.project.copyWith(
        templates: templates,
        rows: rows,
        activeRowIndex: index + 1,
        activeTemplateIndex: templates.length - 1,
      ),
    );
    _persistWorkspace(syncGameName: game);
  }

  void batchCreateCards({
    required String gameName,
    required GameCategory category,
    required List<String> cardNames,
  }) {
    if (cardNames.isEmpty) return;
    _recordHistory();
    for (final name in cardNames) {
      final cleanName = name.trim();
      if (cleanName.isNotEmpty) {
        createCardFromCategory(gameName, category, cardName: cleanName);
      }
    }
    _persistWorkspace(syncGameName: gameName);
  }

  void deleteGame(String gameName) {
    _recordHistory();
    final normTarget = GameFolderService.normalizeGameKey(gameName);
    final safeGame = gameName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

    final deletedRowTemplateIds = <String>{};
    final rows = <Map<String, dynamic>>[];
    for (final r in state.project.rows) {
      final rGame = (r['game'] ?? '').toString();
      if (GameFolderService.normalizeGameKey(rGame) == normTarget) {
        final tplId = (r['template_id'] ?? '').toString().trim();
        if (tplId.isNotEmpty) {
          deletedRowTemplateIds.add(tplId);
        }
      } else {
        rows.add(r);
      }
    }

    // Keep track of template IDs still used by remaining rows
    final remainingTemplateIds = rows
        .map((r) => (r['template_id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    var updatedTemplates = state.project.templates.where((t) {
      if (remainingTemplateIds.contains(t.id)) return true;
      if (deletedRowTemplateIds.contains(t.id)) return false;
      final lowerId = t.id.toLowerCase();
      if (lowerId.startsWith('tpl_${safeGame}_') ||
          lowerId.startsWith('tpl_${normTarget}_') ||
          lowerId.startsWith('tpl_cat_${safeGame}_') ||
          lowerId.startsWith('tpl_cat_${normTarget}_')) {
        return false;
      }
      return true;
    }).toList();

    if (updatedTemplates.isEmpty) {
      updatedTemplates = [CardTemplate.createDefault()];
    }

    final newIndex = state.project.activeRowIndex >= rows.length
        ? (rows.isEmpty ? 0 : rows.length - 1)
        : state.project.activeRowIndex;
    final newTplIndex = state.project.activeTemplateIndex >= updatedTemplates.length
        ? (updatedTemplates.isEmpty ? 0 : updatedTemplates.length - 1)
        : state.project.activeTemplateIndex;

    final updatedDeletedGames = {...state.deletedGames, gameName};

    // Remove categories associated with this game (using normalized key matching)
    final updatedCategories = Map<String, List<GameCategory>>.from(state.gameCategories)
      ..removeWhere((k, _) => GameFolderService.normalizeGameKey(k) == normTarget);

    state = state.copyWith(
      project: state.project.copyWith(
        templates: updatedTemplates,
        activeTemplateIndex: newTplIndex,
        rows: rows,
        activeRowIndex: newIndex,
      ),
      gameCategories: updatedCategories,
      deletedGames: updatedDeletedGames,
    );

    // Completely delete the physical folder games/<gameName> from disk
    if (enableDiskPersistence) {
      GameFolderService.deleteGameFolderSync(gameName, customRootDir: customPersistenceDir);
    }
    _persistWorkspace();
  }

  void restoreSampleGames() {
    final defaultRows = getInitialSampleRows();
    final defaultCategories = getInitialSampleCategories();
    state = state.copyWith(
      project: state.project.copyWith(
        rows: defaultRows,
        activeRowIndex: 0,
      ),
      gameCategories: defaultCategories,
      deletedGames: {},
    );
    _persistWorkspace();
  }

  void removeRow(int index) {
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    if (index >= 0 && index < rows.length) {
      final game = (rows[index]['game'] ?? '').toString();
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
      _persistWorkspace(syncGameName: game);
    }
  }

  void setZoom(double newZoom) {
    state = state.copyWith(zoom: newZoom.clamp(0.4, 4.0));
  }

  void toggleGrid() {
    state = state.copyWith(showGrid: !state.showGrid);
  }

  void toggleSnapping() {
    state = state.copyWith(showSnapping: !state.showSnapping);
  }

  void toggleBleedGuides() {
    state = state.copyWith(showBleedGuides: !state.showBleedGuides);
  }

  void setProject(CardProject project) {
    state = state.copyWith(project: project, clearSelectedLayer: true);
    _persistWorkspace();
  }

  void setActiveTemplate(int index) {
    if (index >= 0 && index < state.project.templates.length) {
      state = state.copyWith(
        project: state.project.copyWith(activeTemplateIndex: index),
        clearSelectedLayer: true,
      );
      _persistWorkspace();
    }
  }

  void _ensureActiveCardHasDedicatedTemplate() {
    if (state.project.rows.isEmpty) return;
    if (state.project.activeRowIndex < 0 || state.project.activeRowIndex >= state.project.rows.length) return;
    final activeRow = state.project.activeRow;
    final game = (activeRow['game'] ?? '').toString().trim();
    if (game.isEmpty) return;

    final isCategoryDefault = isRowCategoryDefault(activeRow);
    final isGameDefault = isRowGameDefault(activeRow);
    final isModel = isCategoryDefault || isGameDefault;

    final currentTemplate = state.project.activeTemplate;
    final cardsResolvingToThisTemplate = state.project.rows.where((r) => resolveTemplateForRow(r).id == currentTemplate.id).length;

    final isShared = cardsResolvingToThisTemplate > 1 || currentTemplate.id == 'template-main';
    final isModelTemplateUsedByNormalCard = !isModel && (
      currentTemplate.id.startsWith('tpl_cat_') ||
      currentTemplate.id.startsWith('tpl_model_') ||
      currentTemplate.id.contains('_base') ||
      state.project.rows.any((r) => (isRowCategoryDefault(r) || isRowGameDefault(r)) && resolveTemplateForRow(r).id == currentTemplate.id)
    );

    if (isModel) {
      // If other cards were sharing this template, fork them so their appearance is preserved
      final otherCardsIndices = <int>[];
      for (int i = 0; i < state.project.rows.length; i++) {
        if (i != state.project.activeRowIndex) {
          final r = state.project.rows[i];
          if (resolveTemplateForRow(r).id == currentTemplate.id) {
            otherCardsIndices.add(i);
          }
        }
      }
      if (otherCardsIndices.isNotEmpty) {
        const uuid = Uuid();
        final currentTemplates = List<CardTemplate>.from(state.project.templates);
        final updatedRows = List<Map<String, dynamic>>.from(state.project.rows);
        for (final idx in otherCardsIndices) {
          final r = updatedRows[idx];
          final preservedId = 'tpl_card_${uuid.v4().substring(0, 8)}';
          final preservedTpl = CardTemplate(
            id: preservedId,
            name: '${r['card_name'] ?? 'Carta'} Plantilla',
            layers: currentTemplate.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
            backLayers: currentTemplate.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
            backgroundColor: currentTemplate.backgroundColor,
            backBackgroundColor: currentTemplate.backBackgroundColor,
            cornerRadius: currentTemplate.cornerRadius,
          );
          currentTemplates.add(preservedTpl);
          final updatedR = Map<String, dynamic>.from(r);
          updatedR['template_id'] = preservedId;
          updatedRows[idx] = updatedR;
        }
        state = state.copyWith(
          project: state.project.copyWith(
            templates: currentTemplates,
            rows: updatedRows,
          ),
        );
      }
    } else if (isShared || isModelTemplateUsedByNormalCard) {
      const uuid = Uuid();
      final dedicatedId = 'tpl_card_${uuid.v4().substring(0, 8)}';

      final forked = CardTemplate(
        id: dedicatedId,
        name: '${currentTemplate.name} (Copia)',
        layers: currentTemplate.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
        backLayers: currentTemplate.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
        backgroundColor: currentTemplate.backgroundColor,
        backBackgroundColor: currentTemplate.backBackgroundColor,
        cornerRadius: currentTemplate.cornerRadius,
      );

      final currentTemplates = List<CardTemplate>.from(state.project.templates);
      currentTemplates.add(forked);
      final newIdx = currentTemplates.length - 1;

      final updatedRows = List<Map<String, dynamic>>.from(state.project.rows);
      final updatedActive = Map<String, dynamic>.from(activeRow);
      updatedActive['template_id'] = dedicatedId;
      updatedRows[state.project.activeRowIndex] = updatedActive;

      state = state.copyWith(
        project: state.project.copyWith(
          templates: currentTemplates,
          activeTemplateIndex: newIdx,
          rows: updatedRows,
        ),
      );
    }
  }

  void _updateTemplateLayers(List<LayerItem> layers) {
    _ensureActiveCardHasDedicatedTemplate();
    final currentTemplate = state.project.activeTemplate;
    final updatedTemplate = state.currentSide == CardSide.front
        ? currentTemplate.copyWith(layers: layers)
        : currentTemplate.copyWith(backLayers: layers);
    final templates = List<CardTemplate>.from(state.project.templates);
    templates[state.project.activeTemplateIndex] = updatedTemplate;

    state = state.copyWith(
      project: state.project.copyWith(templates: templates),
    );
    _persistWorkspace();
  }

  void switchSide(CardSide side) {
    if (state.currentSide != side) {
      state = state.copyWith(currentSide: side, clearSelectedLayer: true);
    }
  }

  void toggleSide() {
    final nextSide = state.currentSide == CardSide.front ? CardSide.back : CardSide.front;
    switchSide(nextSide);
  }

  void updateBackgroundColor(Color color) {
    _ensureActiveCardHasDedicatedTemplate();
    final currentTemplate = state.project.activeTemplate;
    final updatedTemplate = state.currentSide == CardSide.front
        ? currentTemplate.copyWith(backgroundColor: color)
        : currentTemplate.copyWith(backBackgroundColor: color);
    final templates = List<CardTemplate>.from(state.project.templates);
    templates[state.project.activeTemplateIndex] = updatedTemplate;

    state = state.copyWith(
      project: state.project.copyWith(templates: templates),
    );
    _persistWorkspace();
  }

  void updateCornerRadius(double radius) {
    _ensureActiveCardHasDedicatedTemplate();
    final currentTemplate = state.project.activeTemplate;
    final updatedTemplate = currentTemplate.copyWith(cornerRadius: radius);
    final templates = List<CardTemplate>.from(state.project.templates);
    templates[state.project.activeTemplateIndex] = updatedTemplate;

    state = state.copyWith(
      project: state.project.copyWith(templates: templates),
    );
    _persistWorkspace();
  }

  Future<void> syncGameDataCsv(String gameName) async {
    final gameCards = state.project.rows
        .where((r) => (r['game'] ?? '').toString().toLowerCase() == gameName.toLowerCase())
        .toList();
    await GameFolderService.saveGameDataCsv(gameName, gameCards, customRootDir: customPersistenceDir);
    _persistWorkspace();
  }

  Future<bool> reloadGameFromCsv(String gameName) async {
    final loadedCards = await GameFolderService.loadGameDataCsv(gameName, customRootDir: customPersistenceDir);
    if (loadedCards.isEmpty) return false;

    final otherCards = state.project.rows
        .where((r) => (r['game'] ?? '').toString().toLowerCase() != gameName.toLowerCase())
        .toList();
    final updatedRows = [...otherCards, ...loadedCards];

    final newIndex = state.project.activeRowIndex >= updatedRows.length
        ? 0
        : state.project.activeRowIndex;

    state = state.copyWith(
      project: state.project.copyWith(
        rows: updatedRows,
        activeRowIndex: newIndex,
      ),
    );
    _persistWorkspace();
    return true;
  }

  Future<bool> openGameFolder(String gameName) async {
    return await GameFolderService.openGameFolderInExplorer(gameName);
  }

  Future<bool> openGameAssetsFolder(String gameName) async {
    return await GameFolderService.openGameAssetsFolderInExplorer(gameName);
  }

  /// Imports a .grimoire package archive and updates current editor & workspace state
  Future<GrimoireImportResult> importGrimoirePackage(File packageFile) async {
    final result = await ExportService.importGrimoirePackage(
      packageFile: packageFile,
      gamesRootDir: customPersistenceDir,
    );

    if (result.success) {
      final persisted = GameFolderService.loadWorkspaceStateSync(
        customRootDir: customPersistenceDir,
      );

      if (persisted != null) {
        final combinedRows = [
          if (persisted.project != null) ...persisted.project!.rows.map((r) => GameFolderService.normalizeCardRow(r)),
          ...persisted.discoveredRows.map((r) => GameFolderService.normalizeCardRow(r)),
        ];

        final currentProject = persisted.project ?? state.project;
        state = state.copyWith(
          project: currentProject.copyWith(
            rows: combinedRows.isNotEmpty ? combinedRows : currentProject.rows,
            activeRowIndex: 0,
          ),
          gameCategories: persisted.gameCategories.isNotEmpty ? persisted.gameCategories : state.gameCategories,
          deletedGames: persisted.deletedGames,
          clearSelectedLayer: true,
        );
      }
      _persistWorkspace();
    }

    return result;
  }

  /// Exports the workspace or a specific game to a portable .grimoire package
  Future<File> exportGrimoirePackage({String? gameName, Directory? outputDirectory}) async {
    _persistWorkspace();
    final workspaceFile = GameFolderService.getWorkspaceStateFile(customRootDir: customPersistenceDir);
    Map<String, dynamic> payload = {};
    if (workspaceFile.existsSync()) {
      try {
        payload = jsonDecode(workspaceFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {}
    }
    if (payload.isEmpty) {
      payload = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'project': state.project.toJson(),
        'gameCategories': state.gameCategories.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())),
        'deletedGames': state.deletedGames.toList(),
      };
    }

    final pkgName = (gameName != null && gameName.trim().isNotEmpty)
        ? gameName.trim()
        : (state.project.name.isNotEmpty ? state.project.name : 'Grimoire_Workspace');

    return await ExportService.exportGrimoirePackage(
      workspaceStatePayload: payload,
      packageName: pkgName,
      filterGameName: gameName,
      gamesRootDir: customPersistenceDir ?? GameFolderService.getGamesRootDir(),
      outputDirectory: outputDirectory,
    );
  }

  /// Replaces layers and appearance of the active template
  void replaceActiveTemplateLayers({
    String? name,
    required List<LayerItem> layers,
    List<LayerItem> backLayers = const [],
    Color? backgroundColor,
    Color? backBackgroundColor,
    double? cornerRadius,
  }) {
    _recordHistory();
    const uuid = Uuid();
    final active = state.project.activeTemplate;
    final updated = active.copyWith(
      name: name ?? active.name,
      layers: layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
      backLayers: backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
      backgroundColor: backgroundColor,
      backBackgroundColor: backBackgroundColor,
      cornerRadius: cornerRadius,
    );

    final templates = List<CardTemplate>.from(state.project.templates);
    final idx = templates.indexWhere((t) => t.id == active.id);
    if (idx != -1) {
      templates[idx] = updated;
    } else {
      templates.add(updated);
    }

    state = state.copyWith(
      project: state.project.copyWith(templates: templates),
      selectedLayerId: null,
      selectedLayerIds: {},
    );
    _persistWorkspace();
  }

  /// Adds a custom template to the project and optionally activates it
  void addCustomTemplate(CardTemplate newTemplate, {bool setAsActive = true}) {
    _recordHistory();
    final templates = List<CardTemplate>.from(state.project.templates);
    final existingIdx = templates.indexWhere((t) => t.id == newTemplate.id);
    if (existingIdx >= 0) {
      templates[existingIdx] = newTemplate;
    } else {
      templates.add(newTemplate);
    }

    final activeIdx = setAsActive ? templates.indexOf(newTemplate) : state.project.activeTemplateIndex;

    if (setAsActive && state.project.rows.isNotEmpty) {
      updateActiveRowData('template_id', newTemplate.id);
    }

    state = state.copyWith(
      project: state.project.copyWith(
        templates: templates,
        activeTemplateIndex: activeIdx >= 0 ? activeIdx : 0,
      ),
      selectedLayerId: null,
      selectedLayerIds: {},
    );
    _persistWorkspace();
  }

  /// Applies a pre-configured starter card template (Default, TCG, Action, Tarot, Cyberpunk, Minimalist)
  void applyPresetTemplate(String presetType, {bool createAsNew = false}) {
    final activeGame = (state.project.activeRow['game'] ?? 'Magic').toString();
    final cleanGame = activeGame.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

    final preset = CardTemplate.getPresetById(
      presetType,
      id: 'tpl_${cleanGame}_$presetType',
      name: '$activeGame ${CardTemplate.predefinedPresets.firstWhere((p) => p.id == presetType, orElse: () => CardTemplate.predefinedPresets.first).name}',
    );

    if (createAsNew) {
      addCustomTemplate(preset, setAsActive: true);
    } else {
      replaceActiveTemplateLayers(
        name: preset.name,
        layers: preset.layers,
        backLayers: preset.backLayers,
        backgroundColor: preset.backgroundColor,
        backBackgroundColor: preset.backBackgroundColor,
        cornerRadius: preset.cornerRadius,
      );
    }
  }

  /// Synchronizes active game data.csv and persists workspace state
  Future<void> saveActiveProjectAndCsv() async {
    final activeGame = (state.project.activeRow['game'] ?? 'Magic').toString();
    await syncGameDataCsv(activeGame);
    _persistWorkspace();
  }

  /// Uploads an image to the game's assets repository WITHOUT auto-assigning to any card or layer
  Future<String?> uploadImageToGameAssets(String sourceFilePath, {String? targetSubfolder}) async {
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? 'Magic').toString();
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) return null;

    final targetFile = await GameFolderService.importImageToGameAssets(
      gameName,
      sourceFile,
      subfolder: targetSubfolder,
    );
    final relativeUrl = GameFolderService.getRelativeAssetPath(gameName, targetFile);
    return relativeUrl;
  }

  /// Uploads multiple images or folders of images to the game's assets repository
  Future<List<String>> uploadMultipleImagesToGameAssets(
    List<String> sourceFilePaths, {
    String? targetSubfolder,
  }) async {
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? 'Magic').toString();
    final results = <String>[];
    const validExtensions = ['png', 'jpg', 'jpeg', 'webp', 'svg', 'gif', 'bmp'];

    for (final path in sourceFilePaths) {
      if (FileSystemEntity.isDirectorySync(path)) {
        try {
          final dir = Directory(path);
          final entities = dir.listSync(recursive: true);
          for (final entity in entities) {
            if (entity is File) {
              final ext = entity.path.toLowerCase().split('.').last;
              if (validExtensions.contains(ext)) {
                final targetFile = await GameFolderService.importImageToGameAssets(
                  gameName,
                  entity,
                  subfolder: targetSubfolder,
                );
                final relativeUrl = GameFolderService.getRelativeAssetPath(gameName, targetFile);
                results.add(relativeUrl);
              }
            }
          }
        } catch (_) {}
      } else if (FileSystemEntity.isFileSync(path)) {
        final ext = path.toLowerCase().split('.').last;
        if (validExtensions.contains(ext)) {
          final sourceFile = File(path);
          final targetFile = await GameFolderService.importImageToGameAssets(
            gameName,
            sourceFile,
            subfolder: targetSubfolder,
          );
          final relativeUrl = GameFolderService.getRelativeAssetPath(gameName, targetFile);
          results.add(relativeUrl);
        }
      }
    }
    return results;
  }

  Future<String?> uploadImageForActiveCard(String sourceFilePath) async {
    // Simply import into the game's assets bank without forcing onto any element
    return uploadImageToGameAssets(sourceFilePath);
  }

  /// Assign an asset to a specific layer (Image layer or Background layer)
  void assignAssetToLayer(String layerId, String assetRelativePath) {
    _ensureActiveCardHasDedicatedTemplate();
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? 'Magic').toString();
    final resolvedFile = GameFolderService.resolveCardImageFile(gameName, assetRelativePath);
    if (resolvedFile == null) return;

    final template = state.project.activeTemplate;
    final side = state.currentSide;
    final layers = template.getLayers(side);

    final updatedLayers = layers.map((l) {
      if (l.id == layerId) {
        if (l.type == LayerType.image) {
          return l.copyWith(
            imagePath: resolvedFile.path,
            bindingKey: l.bindingKey,
          );
        } else if (l.type == LayerType.background) {
          return l.copyWith(
            fillMode: LayerFillMode.image,
            imagePath: resolvedFile.path,
          );
        }
      }
      return l;
    }).toList();

    final updatedTemplate = side == CardSide.front
        ? template.copyWith(layers: updatedLayers)
        : template.copyWith(backLayers: updatedLayers);

    // Also synchronize asset path to active row data if layer has bindingKey or is image
    final targetLayer = layers.firstWhere(
      (l) => l.id == layerId,
      orElse: () => const LayerItem(id: '', name: '', type: LayerType.image),
    );
    final bindKey = targetLayer.bindingKey.isNotEmpty
        ? targetLayer.bindingKey
        : (targetLayer.type == LayerType.image ? 'art_url' : '');

    List<Map<String, dynamic>> updatedRows = state.project.rows;
    if (bindKey.isNotEmpty &&
        state.project.activeRowIndex >= 0 &&
        state.project.activeRowIndex < state.project.rows.length) {
      String norm = assetRelativePath.replaceAll('\\', '/');
      final aIdx = norm.indexOf('assets/');
      if (aIdx != -1) norm = norm.substring(aIdx);

      final currentRows = List<Map<String, dynamic>>.from(state.project.rows);
      final r = Map<String, dynamic>.from(currentRows[state.project.activeRowIndex]);
      r[bindKey] = norm;
      currentRows[state.project.activeRowIndex] = r;
      updatedRows = currentRows;
    }

    state = state.copyWith(
      project: state.project.copyWith(
        templates: state.project.templates.map((t) => t.id == updatedTemplate.id ? updatedTemplate : t).toList(),
        rows: updatedRows,
      ),
    );
    _persistWorkspace();
  }

  /// Remove/clear asset from a specific layer
  void removeAssetFromLayer(String layerId) {
    _ensureActiveCardHasDedicatedTemplate();
    final template = state.project.activeTemplate;
    final side = state.currentSide;
    final layers = template.getLayers(side);

    final updatedLayers = layers.map((l) {
      if (l.id == layerId) {
        if (l.type == LayerType.background) {
          return l.copyWith(
            fillMode: LayerFillMode.solid,
            imagePath: null,
          );
        }
        return l.copyWith(
          imagePath: null,
          bindingKey: '',
        );
      }
      return l;
    }).toList();

    final updatedTemplate = side == CardSide.front
        ? template.copyWith(layers: updatedLayers)
        : template.copyWith(backLayers: updatedLayers);

    final targetLayer = layers.firstWhere(
      (l) => l.id == layerId,
      orElse: () => const LayerItem(id: '', name: '', type: LayerType.image),
    );
    final bindKey = targetLayer.bindingKey.isNotEmpty
        ? targetLayer.bindingKey
        : (targetLayer.type == LayerType.image ? 'art_url' : '');

    List<Map<String, dynamic>> updatedRows = state.project.rows;
    if (bindKey.isNotEmpty &&
        state.project.activeRowIndex >= 0 &&
        state.project.activeRowIndex < state.project.rows.length) {
      final currentRows = List<Map<String, dynamic>>.from(state.project.rows);
      final r = Map<String, dynamic>.from(currentRows[state.project.activeRowIndex]);
      r[bindKey] = '';
      currentRows[state.project.activeRowIndex] = r;
      updatedRows = currentRows;
    }

    state = state.copyWith(
      project: state.project.copyWith(
        templates: state.project.templates.map((t) => t.id == updatedTemplate.id ? updatedTemplate : t).toList(),
        rows: updatedRows,
      ),
    );
    _persistWorkspace();
  }

  Future<void> assignAssetToActiveCard(String assetRelativePath) async {
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? 'Magic').toString();
    updateActiveRowData('art_url', assetRelativePath);

    final resolvedFile = GameFolderService.resolveCardImageFile(gameName, assetRelativePath);
    if (state.selectedLayer != null && resolvedFile != null) {
      if (state.selectedLayer!.type == LayerType.image) {
        updateLayer(state.selectedLayer!.copyWith(
          imagePath: resolvedFile.path,
          bindingKey: 'art_url',
        ));
      } else if (state.selectedLayer!.type == LayerType.background) {
        updateLayer(state.selectedLayer!.copyWith(
          fillMode: LayerFillMode.image,
          imagePath: resolvedFile.path,
        ));
      }
    }
    await syncGameDataCsv(gameName);
  }

  void toggleAssetsPanel() {
    state = state.copyWith(showAssetsPanel: !state.showAssetsPanel);
  }

  void setAssetsPanelOpen(bool open) {
    state = state.copyWith(showAssetsPanel: open);
  }

  // --- TEMPLATE MANAGEMENT & CARD DIMENSIONS ---

  void createNewTemplate(String name, {CardTemplate? baseTemplate}) {
    _recordHistory();
    const uuid = Uuid();
    final templateName = name.trim().isEmpty ? 'Nueva Plantilla' : name.trim();
    final base = baseTemplate ?? CardTemplate.createDefault(
      id: 'template_${uuid.v4()}',
      name: templateName,
    );
    final clonedFront = base.layers.map((l) => l.copyWith(id: uuid.v4())).toList();
    final clonedBack = base.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList();

    final newTemplate = CardTemplate(
      id: 'template_${uuid.v4()}',
      name: templateName,
      layers: clonedFront,
      backLayers: clonedBack,
      backgroundColor: base.backgroundColor,
      backBackgroundColor: base.backBackgroundColor,
      cornerRadius: base.cornerRadius,
    );

    final updatedTemplates = [...state.project.templates, newTemplate];
    state = state.copyWith(
      project: state.project.copyWith(
        templates: updatedTemplates,
        activeTemplateIndex: updatedTemplates.length - 1,
      ),
      clearSelectedLayer: true,
    );
    _persistWorkspace();
  }

  void duplicateActiveTemplate() {
    final active = state.project.activeTemplate;
    createNewTemplate('${active.name} (Copy)', baseTemplate: active);
  }

  void renameActiveTemplate(String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    _recordHistory();
    final templates = List<CardTemplate>.from(state.project.templates);
    final idx = state.project.activeTemplateIndex.clamp(0, templates.length - 1);
    templates[idx] = templates[idx].copyWith(name: trimmed);
    state = state.copyWith(
      project: state.project.copyWith(templates: templates),
    );
    _persistWorkspace();
  }

  bool deleteActiveTemplate() {
    if (state.project.templates.length <= 1) return false;
    _recordHistory();
    final templates = List<CardTemplate>.from(state.project.templates);
    final idx = state.project.activeTemplateIndex.clamp(0, templates.length - 1);
    templates.removeAt(idx);
    final nextIdx = idx >= templates.length ? templates.length - 1 : idx;
    state = state.copyWith(
      project: state.project.copyWith(
        templates: templates,
        activeTemplateIndex: nextIdx,
      ),
      clearSelectedLayer: true,
    );
    _persistWorkspace();
    return true;
  }

  void updateCardDimensions(double widthMm, double heightMm) {
    _recordHistory();
    final newCanvasW = widthMm * 4.0;
    final newCanvasH = heightMm * 4.0;

    final updatedTemplates = state.project.templates.map((tpl) {
      final updatedFront = tpl.layers.map((l) {
        if (l.type == LayerType.background || (l.name.toLowerCase().contains('background') && l.isLocked)) {
          return l.copyWith(width: newCanvasW, height: newCanvasH);
        }
        return l;
      }).toList();
      final updatedBack = tpl.backLayers.map((l) {
        if (l.type == LayerType.background || (l.name.toLowerCase().contains('background') && l.isLocked)) {
          return l.copyWith(width: newCanvasW, height: newCanvasH);
        }
        return l;
      }).toList();
      return tpl.copyWith(layers: updatedFront, backLayers: updatedBack);
    }).toList();

    state = state.copyWith(
      project: state.project.copyWith(
        widthMm: widthMm,
        heightMm: heightMm,
        templates: updatedTemplates,
      ),
    );
    _persistWorkspace();
  }

  /// Resolves the appropriate CardTemplate for a given card row
  CardTemplate resolveTemplateForRow(Map<String, dynamic> row) {
    final templates = state.project.templates;
    if (templates.isEmpty) return state.project.activeTemplate;

    final tplId = (row['template_id'] ?? '').toString().trim();
    if (tplId.isNotEmpty) {
      final match = templates.where((t) => t.id == tplId || t.name.toLowerCase() == tplId.toLowerCase()).firstOrNull;
      if (match != null) return match;
    }

    final game = (row['game'] ?? '').toString().trim();
    final category = (row['category'] ?? '').toString().trim();

    // Check dedicated category template
    if (game.isNotEmpty && category.isNotEmpty) {
      final safeGame = game.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final safeCat = category.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final catTplId = 'tpl_${safeGame}_$safeCat';
      final matchCat = templates.where((t) => t.id == catTplId).firstOrNull;
      if (matchCat != null) return matchCat;

      final catModel = getCategoryDefaultCard(game, category);
      final modelTplId = (catModel?['template_id'] ?? '').toString().trim();
      if (modelTplId.isNotEmpty) {
        final matchModel = templates.where((t) => t.id == modelTplId).firstOrNull;
        if (matchModel != null) return matchModel;
      }
    }

    // Check dedicated game base template
    if (game.isNotEmpty) {
      final safeGame = game.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final gameTplId = 'tpl_${safeGame}_base';
      final matchGame = templates.where((t) => t.id == gameTplId).firstOrNull;
      if (matchGame != null) return matchGame;

      final gameModel = getGameDefaultCard(game);
      final modelTplId = (gameModel?['template_id'] ?? '').toString().trim();
      if (modelTplId.isNotEmpty) {
        final matchModel = templates.where((t) => t.id == modelTplId).firstOrNull;
        if (matchModel != null) return matchModel;
      }
    }

    final gameLower = game.toLowerCase();
    if (gameLower.contains('unicorn')) {
      final unicornTpl = templates.where((t) => t.id.contains('unicorn') || t.name.toLowerCase().contains('unicorn')).firstOrNull;
      if (unicornTpl != null) return unicornTpl;
    }

    if (game.isNotEmpty) {
      final safeGame = game.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final gameMatch = templates.where((t) => t.id.toLowerCase().contains(safeGame) || t.name.toLowerCase().contains(gameLower)).firstOrNull;
      if (gameMatch != null) return gameMatch;
    }

    return templates.isNotEmpty ? templates.first : state.project.activeTemplate;
  }

  /// Synchronizes all dynamic template variables (bindingKey and {{variable}}) across rows.
  /// Ensures that columns defined in layer templates exist in every card's dictionary,
  /// enabling rapid data manipulation in CSV and data tables.
  void syncTemplateVariablesToRows() {
    final vars = state.project.getAllTemplateVariables();
    if (vars.isEmpty && state.project.rows.isEmpty) return;

    bool changed = false;
    final updatedRows = state.project.rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      final cardTpl = resolveTemplateForRow(map);
      final cardLayers = [...cardTpl.layers, ...cardTpl.backLayers];

      for (final v in vars) {
        if (GameFolderService.internalKeys.contains(v)) continue;

        final currentValue = map[v]?.toString().trim() ?? '';
        final isMissingOrEmpty = !map.containsKey(v) || currentValue.isEmpty;

        if (isMissingOrEmpty) {
          // If the variable is a title alias and card_name is populated, mirror it
          if ((v == 'title_name' || v == 'title' || v == 'titulo') &&
              (map['card_name']?.toString().trim().isNotEmpty ?? false) &&
              map['card_name'].toString().trim() != '{{title_name}}') {
            map[v] = map['card_name'];
            changed = true;
          } else {
            // Look for matching layer in card's own template first, then any template
            LayerItem? matchingLayer = cardLayers.where((l) => l.bindingKey == v).firstOrNull;
            matchingLayer ??= state.project.templates
                .expand((t) => [...t.layers, ...t.backLayers])
                .firstWhere(
                  (l) => l.bindingKey == v,
                  orElse: () => const LayerItem(id: '', name: '', type: LayerType.text),
                );

            if (matchingLayer.type == LayerType.image) {
              final rawPath = (matchingLayer.imagePath ?? '').trim();
              if (rawPath.isNotEmpty) {
                String norm = rawPath.replaceAll('\\', '/');
                final aIdx = norm.indexOf('assets/');
                if (aIdx != -1) norm = norm.substring(aIdx);
                map[v] = norm;
                changed = true;
              } else if (!map.containsKey(v)) {
                map[v] = '';
                changed = true;
              }
            } else if (matchingLayer.type == LayerType.text &&
                       matchingLayer.text.trim().isNotEmpty &&
                       !matchingLayer.text.contains('{{$v}}')) {
              map[v] = matchingLayer.text.trim();
              changed = true;
            } else if (!map.containsKey(v)) {
              map[v] = '';
              changed = true;
            }
          }
        }
      }

      // If art_url exists or is in vars but is empty, try to resolve from template's image layers
      final artVal = map['art_url']?.toString().trim() ?? '';
      if (artVal.isEmpty) {
        final imgL = cardLayers.firstWhere(
          (l) => (l.type == LayerType.image || l.bindingKey == 'art_url') && (l.imagePath ?? '').trim().isNotEmpty,
          orElse: () => const LayerItem(id: '', name: '', type: LayerType.image),
        );
        if ((imgL.imagePath ?? '').trim().isNotEmpty) {
          String norm = imgL.imagePath!.trim().replaceAll('\\', '/');
          final aIdx = norm.indexOf('assets/');
          if (aIdx != -1) norm = norm.substring(aIdx);
          map['art_url'] = norm;
          changed = true;
        }
      }

      // If card_name was literally set to {{title_name}}, clean it
      if (map['card_name'] == '{{title_name}}' || map['card_name'] == '{{title}}') {
        final fallback = (map['title_name']?.toString().trim().isNotEmpty ?? false)
            ? map['title_name']
            : (map['category']?.toString().isNotEmpty == true ? 'Nueva ${map['category']}' : 'Nueva Carta');
        map['card_name'] = fallback;
        changed = true;
      }
      return map;
    }).toList();

    if (changed) {
      state = state.copyWith(
        project: state.project.copyWith(rows: updatedRows),
      );
      _persistWorkspace();
    }
  }

  // --- DATABASE COLUMN MANAGEMENT ---

  void addCustomColumnToDatabase(String columnName, {String defaultValue = ''}) {
    final cleanKey = columnName.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    if (cleanKey.isEmpty) return;
    _recordHistory();
    final rows = state.project.rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      if (!map.containsKey(cleanKey)) {
        map[cleanKey] = defaultValue;
      }
      return map;
    }).toList();
    state = state.copyWith(
      project: state.project.copyWith(rows: rows),
    );
    _persistWorkspace();
  }

  void removeCustomColumnFromDatabase(String columnKey) {
    final cleanKey = columnKey.trim();
    if (cleanKey.isEmpty) return;
    _recordHistory();
    final rows = state.project.rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      map.remove(cleanKey);
      return map;
    }).toList();
    state = state.copyWith(
      project: state.project.copyWith(rows: rows),
    );
    _persistWorkspace();
  }

  void renameCustomColumnInDatabase(String oldKey, String newKey) {
    final cleanOld = oldKey.trim();
    final cleanNew = newKey.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    if (cleanOld.isEmpty || cleanNew.isEmpty || cleanOld == cleanNew) return;
    _recordHistory();
    final rows = state.project.rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      if (map.containsKey(cleanOld)) {
        final val = map.remove(cleanOld);
        map[cleanNew] = val;
      }
      return map;
    }).toList();
    state = state.copyWith(
      project: state.project.copyWith(rows: rows),
    );
    _persistWorkspace();
  }

  void duplicateRow(int index) {
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    if (index < 0 || index >= rows.length) return;
    _recordHistory();
    const uuid = Uuid();
    final original = Map<String, dynamic>.from(rows[index]);
    original.remove('is_category_default');
    original.remove('is_game_default');
    original['card_name'] = '${original['card_name'] ?? 'Card'} (Copy)';

    final sourceTpl = resolveTemplateForRow(rows[index]);
    final clonedTplId = 'tpl_card_${uuid.v4().substring(0, 8)}';
    final clonedTpl = CardTemplate(
      id: clonedTplId,
      name: '${original['card_name']} Plantilla',
      layers: sourceTpl.layers.map((l) => l.copyWith(id: uuid.v4())).toList(),
      backLayers: sourceTpl.backLayers.map((l) => l.copyWith(id: uuid.v4())).toList(),
      backgroundColor: sourceTpl.backgroundColor,
      backBackgroundColor: sourceTpl.backBackgroundColor,
      cornerRadius: sourceTpl.cornerRadius,
    );
    original['template_id'] = clonedTplId;

    final templates = List<CardTemplate>.from(state.project.templates)..add(clonedTpl);
    rows.insert(index + 1, original);
    state = state.copyWith(
      project: state.project.copyWith(
        templates: templates,
        rows: rows,
        activeRowIndex: index + 1,
        activeTemplateIndex: templates.length - 1,
      ),
    );
    final game = (original['game'] ?? '').toString();
    _persistWorkspace(syncGameName: game);
  }
}

final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  return EditorNotifier();
});
