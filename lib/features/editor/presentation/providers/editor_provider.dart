import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../models/card_project.dart';
import '../../models/card_template.dart';
import '../../models/layer_item.dart';
import '../../models/game_category.dart';
import '../../services/game_folder_service.dart';

class EditorState {
  final CardProject project;
  final String? selectedLayerId;
  final double zoom;
  final bool showGrid;
  final bool showSnapping;
  final bool isGeneratingAi;
  final CardSide currentSide;
  final Set<String> deletedGames;
  final Map<String, List<GameCategory>> gameCategories;

  const EditorState({
    required this.project,
    this.selectedLayerId,
    this.zoom = 1.0,
    this.showGrid = true,
    this.showSnapping = true,
    this.isGeneratingAi = false,
    this.currentSide = CardSide.front,
    this.deletedGames = const {},
    this.gameCategories = const {},
  });

  LayerItem? get selectedLayer {
    if (selectedLayerId == null) return null;
    final layers = project.activeTemplate.getLayers(currentSide);
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
    CardSide? currentSide,
    Set<String>? deletedGames,
    Map<String, List<GameCategory>>? gameCategories,
  }) {
    return EditorState(
      project: project ?? this.project,
      selectedLayerId: clearSelectedLayer ? null : (selectedLayerId ?? this.selectedLayerId),
      zoom: zoom ?? this.zoom,
      showGrid: showGrid ?? this.showGrid,
      showSnapping: showSnapping ?? this.showSnapping,
      isGeneratingAi: isGeneratingAi ?? this.isGeneratingAi,
      currentSide: currentSide ?? this.currentSide,
      deletedGames: deletedGames ?? this.deletedGames,
      gameCategories: gameCategories ?? this.gameCategories,
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
      rows: sampleRows,
      activeRowIndex: 0,
    );

    return EditorState(
      project: initialProject,
      gameCategories: initialGameCategories,
    );
  }

  void selectLayer(String? id) {
    state = state.copyWith(selectedLayerId: id, clearSelectedLayer: id == null);
  }

  void updateLayerPosition(String id, double x, double y) {
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

  void updateLayer(LayerItem updated) {
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.map((l) {
      if (l.id == updated.id) return updated;
      return l;
    }).toList();

    _updateTemplateLayers(updatedLayers);
  }

  void addLayer(LayerItem layer) {
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = [...layers, layer];
    _updateTemplateLayers(updatedLayers);
    state = state.copyWith(selectedLayerId: layer.id);
  }

  void removeLayer(String id) {
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.where((l) => l.id != id).toList();
    _updateTemplateLayers(updatedLayers);
    if (state.selectedLayerId == id) {
      state = state.copyWith(clearSelectedLayer: true);
    }
  }

  void toggleLayerVisibility(String id) {
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.map((l) {
      if (l.id == id) return l.copyWith(isVisible: !l.isVisible);
      return l;
    }).toList();
    _updateTemplateLayers(updatedLayers);
  }

  void toggleLayerLock(String id) {
    final template = state.project.activeTemplate;
    final layers = template.getLayers(state.currentSide);
    final updatedLayers = layers.map((l) {
      if (l.id == id) return l.copyWith(isLocked: !l.isLocked);
      return l;
    }).toList();
    _updateTemplateLayers(updatedLayers);
  }

  void reorderLayers(int oldIndex, int newIndex) {
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
    final template = state.project.activeTemplate;
    final layers = List<LayerItem>.from(template.getLayers(state.currentSide));
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

  void assignCardToGame(int rowIndex, String gameName) {
    final rows = List<Map<String, dynamic>>.from(state.project.rows);
    if (rowIndex >= 0 && rowIndex < rows.length) {
      final updatedRow = Map<String, dynamic>.from(rows[rowIndex]);
      updatedRow['game'] = gameName;
      rows[rowIndex] = updatedRow;
      state = state.copyWith(
        project: state.project.copyWith(rows: rows),
      );
    }
  }

  List<GameCategory> getCategoriesForGame(String gameName) {
    if (state.gameCategories.containsKey(gameName)) {
      return state.gameCategories[gameName]!;
    }
    // Auto-discover unique categories from existing card rows
    final existingCategories = state.project.rows
        .where((r) => (r['game'] ?? '').toString().toLowerCase() == gameName.toLowerCase())
        .map((r) => (r['category'] ?? '').toString())
        .where((c) => c.isNotEmpty)
        .toSet();

    return existingCategories.map((c) => GameCategory(
      id: 'cat-${c.hashCode}',
      name: c,
      icon: '🃏',
      defaultType: 'Criatura',
    )).toList();
  }

  void addCategoryToGame(String gameName, GameCategory category) {
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
  }

  void deleteCategoryFromGame(String gameName, String categoryName) {
    final currentList = List<GameCategory>.from(state.gameCategories[gameName] ?? []);
    currentList.removeWhere((c) => c.name.toLowerCase() == categoryName.toLowerCase());
    final updatedCategories = Map<String, List<GameCategory>>.from(state.gameCategories);
    updatedCategories[gameName] = currentList;
    state = state.copyWith(gameCategories: updatedCategories);
  }

  void createCardFromCategory(String gameName, GameCategory category, {String? cardName}) {
    if (state.deletedGames.contains(gameName)) {
      final updatedDeleted = state.deletedGames.where((g) => g != gameName).toSet();
      state = state.copyWith(deletedGames: updatedDeleted);
    }

    final newCard = {
      'card_name': cardName ?? 'Nueva ${category.name}',
      'cost': category.defaultCost.isNotEmpty ? category.defaultCost : '3',
      'type': category.defaultType,
      'rarity': category.defaultRarity.isNotEmpty ? category.defaultRarity : 'Common',
      'attack': category.defaultAttack.isNotEmpty ? category.defaultAttack : (category.defaultType.toLowerCase().contains('creature') || category.defaultType.toLowerCase().contains('unicorn') ? '2' : '0'),
      'defense': category.defaultDefense.isNotEmpty ? category.defaultDefense : (category.defaultType.toLowerCase().contains('creature') || category.defaultType.toLowerCase().contains('unicorn') ? '2' : '0'),
      'creator': 'Grimoire Studio',
      'icon': category.icon,
      'art_color': category.defaultColor,
      'rules_text': category.defaultRules.isNotEmpty
          ? category.defaultRules
          : 'Habilidad de ${category.name} para $gameName.',
      'rules': category.defaultRules.isNotEmpty
          ? category.defaultRules
          : 'Habilidad de ${category.name} para $gameName.',
      'game': gameName,
      'category': category.name,
    };
    addRow(newCard);
  }

  void addCardToGame(
    String gameName, {
    String? cardName,
    String? type,
    String? icon,
    String? category,
    int? artColor,
    String? rulesText,
  }) {
    if (state.deletedGames.contains(gameName)) {
      final updatedDeleted = state.deletedGames.where((g) => g != gameName).toSet();
      state = state.copyWith(deletedGames: updatedDeleted);
    }

    final categories = getCategoriesForGame(gameName);
    final chosenCategory = category != null
        ? categories.firstWhere(
            (c) => c.name.toLowerCase() == category.toLowerCase(),
            orElse: () => GameCategory(id: 'cat', name: category),
          )
        : (categories.isNotEmpty ? categories.first : null);

    final finalCatName = chosenCategory?.name ?? category ?? 'General';
    final finalIcon = icon ?? chosenCategory?.icon ?? '🃏';
    final finalType = type ?? chosenCategory?.defaultType ?? 'Creature';
    final finalColor = artColor ?? chosenCategory?.defaultColor ?? 0xFF7C3AED;
    final finalRules = rulesText ?? (chosenCategory?.defaultRules.isNotEmpty == true
        ? chosenCategory!.defaultRules
        : 'Habilidad especial para el juego $gameName.');

    final newCard = {
      'card_name': cardName ?? 'Nueva Carta ($gameName)',
      'cost': '3',
      'type': finalType,
      'rarity': 'Common',
      'attack': finalType.toLowerCase().contains('creature') || finalType.toLowerCase().contains('unicorn') ? '2' : '0',
      'defense': finalType.toLowerCase().contains('creature') || finalType.toLowerCase().contains('unicorn') ? '2' : '0',
      'creator': 'Grimoire Studio',
      'icon': finalIcon,
      'art_color': finalColor,
      'rules_text': finalRules,
      'rules': finalRules,
      'game': gameName,
      'category': finalCatName,
    };
    addRow(newCard);
  }

  void deleteGame(String gameName) {
    final rows = state.project.rows
        .where((r) => (r['game'] ?? '').toString().toLowerCase() != gameName.toLowerCase())
        .toList();
    final newIndex = state.project.activeRowIndex >= rows.length
        ? (rows.isEmpty ? 0 : rows.length - 1)
        : state.project.activeRowIndex;
    final updatedDeletedGames = {...state.deletedGames, gameName};

    state = state.copyWith(
      project: state.project.copyWith(
        rows: rows,
        activeRowIndex: newIndex,
      ),
      deletedGames: updatedDeletedGames,
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

  void setActiveTemplate(int index) {
    if (index >= 0 && index < state.project.templates.length) {
      state = state.copyWith(
        project: state.project.copyWith(activeTemplateIndex: index),
        clearSelectedLayer: true,
      );
    }
  }

  void _updateTemplateLayers(List<LayerItem> layers) {
    final currentTemplate = state.project.activeTemplate;
    final updatedTemplate = state.currentSide == CardSide.front
        ? currentTemplate.copyWith(layers: layers)
        : currentTemplate.copyWith(backLayers: layers);
    final templates = List<CardTemplate>.from(state.project.templates);
    templates[state.project.activeTemplateIndex] = updatedTemplate;

    state = state.copyWith(
      project: state.project.copyWith(templates: templates),
    );
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
    final currentTemplate = state.project.activeTemplate;
    final updatedTemplate = state.currentSide == CardSide.front
        ? currentTemplate.copyWith(backgroundColor: color)
        : currentTemplate.copyWith(backBackgroundColor: color);
    final templates = List<CardTemplate>.from(state.project.templates);
    templates[state.project.activeTemplateIndex] = updatedTemplate;

    state = state.copyWith(
      project: state.project.copyWith(templates: templates),
    );
  }

  Future<void> syncGameDataCsv(String gameName) async {
    final gameCards = state.project.rows
        .where((r) => (r['game'] ?? '').toString().toLowerCase() == gameName.toLowerCase())
        .toList();
    await GameFolderService.saveGameDataCsv(gameName, gameCards);
  }

  Future<bool> reloadGameFromCsv(String gameName) async {
    final loadedCards = await GameFolderService.loadGameDataCsv(gameName);
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
    return true;
  }

  Future<bool> openGameFolder(String gameName) async {
    return await GameFolderService.openGameFolderInExplorer(gameName);
  }

  Future<String?> uploadImageForActiveCard(String sourceFilePath) async {
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? 'Magic').toString();
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) return null;

    final targetFile = await GameFolderService.importImageToGameAssets(gameName, sourceFile);
    final relativeUrl = 'assets/${targetFile.uri.pathSegments.last}';

    updateActiveRowData('art_url', relativeUrl);

    if (state.selectedLayer != null && state.selectedLayer!.type == LayerType.image) {
      updateLayer(state.selectedLayer!.copyWith(
        imagePath: targetFile.path,
        bindingKey: 'art_url',
      ));
    }

    await syncGameDataCsv(gameName);
    return relativeUrl;
  }

  Future<void> assignAssetToActiveCard(String assetRelativePath) async {
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? 'Magic').toString();
    updateActiveRowData('art_url', assetRelativePath);

    final resolvedFile = GameFolderService.resolveCardImageFile(gameName, assetRelativePath);
    if (state.selectedLayer != null && state.selectedLayer!.type == LayerType.image && resolvedFile != null) {
      updateLayer(state.selectedLayer!.copyWith(
        imagePath: resolvedFile.path,
        bindingKey: 'art_url',
      ));
    }
    await syncGameDataCsv(gameName);
  }
}

final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  return EditorNotifier();
});
