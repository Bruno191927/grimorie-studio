import 'package:flutter/material.dart';
import 'layer_item.dart';

enum CardSide {
  front,
  back,
}

class CardTemplate {
  final String id;
  final String name;
  final List<LayerItem> layers; // Front layers
  final List<LayerItem> backLayers; // Back layers
  final Color backgroundColor;
  final Color backBackgroundColor;
  final String? backgroundImage;
  final String? backBackgroundImage;
  final double cornerRadius;

  const CardTemplate({
    required this.id,
    required this.name,
    this.layers = const [],
    this.backLayers = const [],
    this.backgroundColor = const Color(0xFF131622),
    this.backBackgroundColor = const Color(0xFF0C0E17),
    this.backgroundImage,
    this.backBackgroundImage,
    this.cornerRadius = 16,
  });

  List<LayerItem> getLayers(CardSide side) => side == CardSide.front ? layers : backLayers;

  Color getBackgroundColor(CardSide side) => side == CardSide.front ? backgroundColor : backBackgroundColor;

  String? getBackgroundImage(CardSide side) => side == CardSide.front ? backgroundImage : backBackgroundImage;

  CardTemplate copyWith({
    String? id,
    String? name,
    List<LayerItem>? layers,
    List<LayerItem>? backLayers,
    Color? backgroundColor,
    Color? backBackgroundColor,
    String? backgroundImage,
    String? backBackgroundImage,
    double? cornerRadius,
  }) {
    return CardTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      layers: layers ?? this.layers,
      backLayers: backLayers ?? this.backLayers,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backBackgroundColor: backBackgroundColor ?? this.backBackgroundColor,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      backBackgroundImage: backBackgroundImage ?? this.backBackgroundImage,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'layers': layers.map((l) => l.toJson()).toList(),
      'backLayers': backLayers.map((l) => l.toJson()).toList(),
      'backgroundColor': backgroundColor.toARGB32(),
      'backBackgroundColor': backBackgroundColor.toARGB32(),
      'backgroundImage': backgroundImage,
      'backBackgroundImage': backBackgroundImage,
      'cornerRadius': cornerRadius,
    };
  }

  factory CardTemplate.fromJson(Map<String, dynamic> json) {
    return CardTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Default Template',
      layers: (json['layers'] as List<dynamic>?)
              ?.map((l) => LayerItem.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      backLayers: (json['backLayers'] as List<dynamic>?)
              ?.map((l) => LayerItem.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'] as int)
          : const Color(0xFF131622),
      backBackgroundColor: json['backBackgroundColor'] != null
          ? Color(json['backBackgroundColor'] as int)
          : const Color(0xFF0C0E17),
      backgroundImage: json['backgroundImage'] as String?,
      backBackgroundImage: json['backBackgroundImage'] as String?,
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 16,
    );
  }

  /// Preset 0: Default structure requested by user:
  /// fondo (background), titulo (top), imagen (middle), shape (bottom), and encima del shape descripcion.
  factory CardTemplate.createDefault({
    String id = 'tpl_default',
    String name = 'Default',
  }) {
    return CardTemplate(
      id: id,
      name: name,
      backgroundColor: const Color(0xFF131622),
      backBackgroundColor: const Color(0xFF0C0E17),
      cornerRadius: 16,
      layers: const [
        // 1. fondo
        LayerItem(
          id: 'def_fondo',
          name: 'fondo',
          type: LayerType.background,
          x: 0,
          y: 0,
          width: 254,
          height: 355.6,
          fillMode: LayerFillMode.solid,
          shapeColor: Color(0xFF131622),
          borderRadius: 16,
          isLocked: true,
        ),
        // 2. titulo
        LayerItem(
          id: 'def_titulo',
          name: 'titulo',
          type: LayerType.text,
          x: 14,
          y: 14,
          width: 226,
          height: 28,
          text: '{{card_name}}',
          bindingKey: 'card_name',
          fontSize: 14,
          isBold: true,
          textAlign: TextAlign.center,
          fontColor: Colors.white,
        ),
        // 3. imagen
        LayerItem(
          id: 'def_imagen',
          name: 'imagen',
          type: LayerType.image,
          x: 14,
          y: 48,
          width: 226,
          height: 160,
          bindingKey: 'art_url',
          imageFit: BoxFit.cover,
          borderRadius: 8,
        ),
        // 4. shape
        LayerItem(
          id: 'def_shape',
          name: 'shape',
          type: LayerType.shape,
          x: 14,
          y: 218,
          width: 226,
          height: 122,
          borderRadius: 8,
          borderWidth: 1,
          borderColor: Color(0xFF2E3852),
          shapeColor: Color(0xFF181C2E),
        ),
        // 5. descripcion (encima del shape)
        LayerItem(
          id: 'def_descripcion',
          name: 'descripcion',
          type: LayerType.text,
          x: 22,
          y: 226,
          width: 210,
          height: 106,
          text: '{{rules_text}}',
          bindingKey: 'rules_text',
          fontSize: 10.5,
          fontColor: Color(0xFFCBD5E1),
          textAlign: TextAlign.left,
        ),
      ],
      backLayers: const [
        LayerItem(
          id: 'def_back_frame',
          name: 'Marco Reverso',
          type: LayerType.shape,
          x: 8,
          y: 8,
          width: 238,
          height: 340,
          borderRadius: 12,
          borderWidth: 2,
          borderColor: Color(0xFF7C3AED),
          shapeColor: Color(0xFF0D0F18),
        ),
        LayerItem(
          id: 'def_back_title',
          name: 'Título Reverso',
          type: LayerType.text,
          x: 20,
          y: 160,
          width: 214,
          height: 30,
          text: '✦ GRIMOIRE ✦',
          isBold: true,
          fontSize: 14,
          textAlign: TextAlign.center,
          fontColor: Colors.white,
        ),
      ],
    );
  }

  /// Preset 1: Standard TCG Fantasy Card (Magic / Hearthstone style)
  factory CardTemplate.createTcgFantasy({String id = 'tpl_tcg_fantasy', String name = 'TCG Fantasía Clásico'}) {
    return CardTemplate(
      id: id,
      name: name,
      backgroundColor: const Color(0xFF0F121C),
      backBackgroundColor: const Color(0xFF090B12),
      cornerRadius: 12,
      layers: const [
        // 1. Marco Exterior Dorado
        LayerItem(
          id: 'tcg_frame',
          name: 'Marco Exterior',
          type: LayerType.shape,
          x: 6,
          y: 6,
          width: 242,
          height: 344,
          borderRadius: 10,
          borderWidth: 2,
          borderColor: Color(0xFFD4AF37),
          shapeColor: Color(0xFF131726),
        ),
        // 2. Banner de Nombre
        LayerItem(
          id: 'tcg_title_bg',
          name: 'Fondo Título',
          type: LayerType.shape,
          x: 14,
          y: 12,
          width: 178,
          height: 28,
          borderRadius: 6,
          borderWidth: 1,
          borderColor: Color(0xFF333C57),
          shapeColor: Color(0xFF1B2033),
        ),
        LayerItem(
          id: 'tcg_title_text',
          name: 'Nombre de Carta',
          type: LayerType.text,
          x: 20,
          y: 16,
          width: 166,
          height: 20,
          text: 'Dragón Astral',
          bindingKey: 'card_name',
          isBold: true,
          fontSize: 12.5,
          fontColor: Colors.white,
        ),
        // 3. Orbe de Coste
        LayerItem(
          id: 'tcg_cost_orb',
          name: 'Orbe de Coste',
          type: LayerType.shape,
          x: 204,
          y: 10,
          width: 34,
          height: 32,
          shapePreset: ShapePreset.circle,
          shapeColor: Color(0xFF7C3AED),
          borderWidth: 1.5,
          borderColor: Color(0xFFD4AF37),
        ),
        LayerItem(
          id: 'tcg_cost_text',
          name: 'Coste',
          type: LayerType.text,
          x: 204,
          y: 15,
          width: 34,
          height: 22,
          text: '3',
          bindingKey: 'cost',
          isBold: true,
          fontSize: 13,
          textAlign: TextAlign.center,
          fontColor: Colors.white,
        ),
        // 4. Área de Ilustración
        LayerItem(
          id: 'tcg_art_box',
          name: 'Ilustración de Arte',
          type: LayerType.image,
          x: 14,
          y: 46,
          width: 226,
          height: 145,
          bindingKey: 'asset_file',
          imageFit: BoxFit.cover,
        ),
        // 5. Barra de Tipo
        LayerItem(
          id: 'tcg_type_bg',
          name: 'Fondo Tipo',
          type: LayerType.shape,
          x: 14,
          y: 196,
          width: 226,
          height: 22,
          borderRadius: 4,
          shapeColor: Color(0xFF1E243B),
          borderWidth: 1,
          borderColor: Color(0xFF3B4668),
        ),
        LayerItem(
          id: 'tcg_type_text',
          name: 'Tipo de Carta',
          type: LayerType.text,
          x: 20,
          y: 199,
          width: 214,
          height: 16,
          text: 'Criatura — Dragón Místico',
          bindingKey: 'type',
          isItalic: true,
          fontSize: 10,
          fontColor: Color(0xFFE2E8F0),
        ),
        // 6. Caja de Reglas / Efecto
        LayerItem(
          id: 'tcg_rules_bg',
          name: 'Caja de Reglas',
          type: LayerType.shape,
          x: 14,
          y: 224,
          width: 226,
          height: 86,
          borderRadius: 6,
          shapeColor: Color(0xFF0F1320),
          borderWidth: 1,
          borderColor: Color(0xFF2A324B),
        ),
        LayerItem(
          id: 'tcg_rules_text',
          name: 'Texto de Reglas',
          type: LayerType.text,
          x: 20,
          y: 230,
          width: 214,
          height: 74,
          text: 'Vuela, Prisa.\\n{T}: Inflige 2 puntos de daño a cualquier objetivo.',
          bindingKey: 'rules_text',
          fontSize: 10,
          fontColor: Color(0xFFCBD5E1),
        ),
        // 7. Escudo de Estadísticas (ATK / DEF)
        LayerItem(
          id: 'tcg_stats_badge',
          name: 'Escudo Stats',
          type: LayerType.shape,
          x: 172,
          y: 314,
          width: 68,
          height: 28,
          shapePreset: ShapePreset.shield,
          shapeColor: Color(0xFF1F2438),
          borderWidth: 1.5,
          borderColor: Color(0xFFD4AF37),
        ),
        LayerItem(
          id: 'tcg_stats_text',
          name: 'Ataque / Defensa',
          type: LayerType.text,
          x: 172,
          y: 318,
          width: 68,
          height: 20,
          text: '4 / 3',
          bindingKey: 'atk',
          isBold: true,
          fontSize: 12,
          textAlign: TextAlign.center,
          fontColor: Colors.white,
        ),
      ],
      backLayers: const [
        LayerItem(
          id: 'tcg_back_frame',
          name: 'Marco Reverso',
          type: LayerType.shape,
          x: 8,
          y: 8,
          width: 238,
          height: 340,
          borderRadius: 12,
          borderWidth: 2,
          borderColor: Color(0xFF7C3AED),
          shapeColor: Color(0xFF0D0F18),
        ),
        LayerItem(
          id: 'tcg_back_medallion',
          name: 'Medallón Central',
          type: LayerType.shape,
          x: 57,
          y: 108,
          width: 140,
          height: 140,
          shapePreset: ShapePreset.octagon,
          shapeColor: Color(0xFF1A173B),
          borderWidth: 2,
          borderColor: Color(0xFF9333EA),
        ),
        LayerItem(
          id: 'tcg_back_title',
          name: 'Título Reverso',
          type: LayerType.text,
          x: 57,
          y: 165,
          width: 140,
          height: 24,
          text: '✦ GRIMOIRE ✦',
          isBold: true,
          fontSize: 12,
          textAlign: TextAlign.center,
          fontColor: Colors.white,
        ),
      ],
    );
  }

  /// Preset 2: Modern Minimalist Board Game Action / Event Card
  factory CardTemplate.createBoardgameAction({String id = 'tpl_boardgame_action', String name = 'Juego de Mesa Acción'}) {
    return CardTemplate(
      id: id,
      name: name,
      backgroundColor: const Color(0xFF161926),
      backBackgroundColor: const Color(0xFF10131E),
      cornerRadius: 16,
      layers: const [
        // Borde exterior moderno
        LayerItem(
          id: 'bg_outer_border',
          name: 'Borde Exterior',
          type: LayerType.shape,
          x: 10,
          y: 10,
          width: 234,
          height: 336,
          borderRadius: 14,
          borderWidth: 1.5,
          borderColor: Color(0xFF06B6D4),
          shapeColor: Color(0xFF131622),
        ),
        // Cabecera con Título
        LayerItem(
          id: 'bg_title',
          name: 'Nombre de Acción',
          type: LayerType.text,
          x: 20,
          y: 20,
          width: 214,
          height: 26,
          text: 'Emboscar Caravana',
          bindingKey: 'card_name',
          isBold: true,
          fontSize: 14,
          textAlign: TextAlign.center,
          fontColor: Colors.white,
        ),
        // Ilustración central
        LayerItem(
          id: 'bg_art',
          name: 'Arte del Evento',
          type: LayerType.image,
          x: 24,
          y: 54,
          width: 206,
          height: 155,
          bindingKey: 'asset_file',
          imageFit: BoxFit.cover,
        ),
        // Caja de Efecto
        LayerItem(
          id: 'bg_effect_box',
          name: 'Caja de Efecto',
          type: LayerType.shape,
          x: 20,
          y: 220,
          width: 214,
          height: 105,
          borderRadius: 8,
          shapeColor: Color(0xFF1A1F30),
          borderWidth: 1,
          borderColor: Color(0xFF2E3852),
        ),
        LayerItem(
          id: 'bg_rules',
          name: 'Efecto de la Carta',
          type: LayerType.text,
          x: 26,
          y: 228,
          width: 202,
          height: 90,
          text: 'Roba 2 cartas del mazo. Todos los demás jugadores descartan 1 carta.',
          bindingKey: 'rules_text',
          fontSize: 11,
          fontColor: Color(0xFFF1F5F9),
        ),
      ],
      backLayers: const [
        LayerItem(
          id: 'bg_back_card',
          name: 'Reverso Acción',
          type: LayerType.shape,
          x: 10,
          y: 10,
          width: 234,
          height: 336,
          borderRadius: 14,
          borderWidth: 2,
          borderColor: Color(0xFF06B6D4),
          shapeColor: Color(0xFF0E1320),
        ),
        LayerItem(
          id: 'bg_back_icon',
          name: 'Icono Reverso',
          type: LayerType.text,
          x: 57,
          y: 155,
          width: 140,
          height: 40,
          text: '⚔️ EVENTO',
          isBold: true,
          fontSize: 14,
          textAlign: TextAlign.center,
          fontColor: Color(0xFF06B6D4),
        ),
      ],
    );
  }

  /// Preset 3: Mystic Tarot / Hero Character Card
  factory CardTemplate.createTarotHero({String id = 'tpl_tarot_hero', String name = 'Tarot / Héroe Legendario'}) {
    return CardTemplate(
      id: id,
      name: name,
      backgroundColor: const Color(0xFF0B0D14),
      backBackgroundColor: const Color(0xFF07080D),
      cornerRadius: 14,
      layers: const [
        // Ilustración vertical completa
        LayerItem(
          id: 'tarot_art',
          name: 'Retrato de Héroe',
          type: LayerType.image,
          x: 10,
          y: 10,
          width: 234,
          height: 270,
          bindingKey: 'asset_file',
          imageFit: BoxFit.cover,
        ),
        // Marco de Oro Fino
        LayerItem(
          id: 'tarot_border',
          name: 'Marco Místico',
          type: LayerType.shape,
          x: 6,
          y: 6,
          width: 242,
          height: 344,
          borderRadius: 12,
          borderWidth: 1.5,
          borderColor: Color(0xFFF59E0B),
          shapeColor: Colors.transparent,
        ),
        // Placa Inferior de Título y Lore
        LayerItem(
          id: 'tarot_plate',
          name: 'Placa de Nombre',
          type: LayerType.shape,
          x: 12,
          y: 286,
          width: 230,
          height: 58,
          borderRadius: 8,
          shapeColor: Color(0xFF121522),
          borderWidth: 1,
          borderColor: Color(0xFFF59E0B),
        ),
        LayerItem(
          id: 'tarot_name',
          name: 'Nombre del Héroe',
          type: LayerType.text,
          x: 16,
          y: 292,
          width: 222,
          height: 22,
          text: 'La Sacerdotisa de la Luna',
          bindingKey: 'card_name',
          isBold: true,
          fontSize: 12,
          textAlign: TextAlign.center,
          fontColor: Color(0xFFF59E0B),
        ),
        LayerItem(
          id: 'tarot_quote',
          name: 'Cita / Descripción',
          type: LayerType.text,
          x: 16,
          y: 314,
          width: 222,
          height: 26,
          text: 'Portadora de secretos eternos y luz estelar.',
          bindingKey: 'rules_text',
          isItalic: true,
          fontSize: 9,
          textAlign: TextAlign.center,
          fontColor: Color(0xFF94A3B8),
        ),
      ],
      backLayers: const [
        LayerItem(
          id: 'tarot_back_border',
          name: 'Borde Tarot Reverso',
          type: LayerType.shape,
          x: 6,
          y: 6,
          width: 242,
          height: 344,
          borderRadius: 12,
          borderWidth: 2,
          borderColor: Color(0xFFF59E0B),
          shapeColor: Color(0xFF090B12),
        ),
        LayerItem(
          id: 'tarot_back_symbol',
          name: 'Símbolo Místico',
          type: LayerType.text,
          x: 57,
          y: 155,
          width: 140,
          height: 40,
          text: '☽ ◯ ☾',
          fontSize: 20,
          textAlign: TextAlign.center,
          fontColor: Color(0xFFF59E0B),
        ),
      ],
    );
  }

  /// Preset 4: Cyberpunk / Sci-Fi Neon Card
  factory CardTemplate.createCyberpunk({String id = 'tpl_cyberpunk', String name = 'Cyberpunk Neón'}) {
    return CardTemplate(
      id: id,
      name: name,
      backgroundColor: const Color(0xFF080914),
      backBackgroundColor: const Color(0xFF05060D),
      cornerRadius: 14,
      layers: const [
        LayerItem(
          id: 'cyber_frame',
          name: 'Marco Neón',
          type: LayerType.shape,
          x: 6,
          y: 6,
          width: 242,
          height: 344,
          borderRadius: 10,
          borderWidth: 2,
          borderColor: Color(0xFFEC4899),
          shapeColor: Color(0xFF0F1123),
        ),
        LayerItem(
          id: 'cyber_title',
          name: 'Cyber Título',
          type: LayerType.text,
          x: 16,
          y: 14,
          width: 222,
          height: 24,
          text: '⚡ // {{card_name}}',
          bindingKey: 'card_name',
          isBold: true,
          fontSize: 12.5,
          fontColor: Color(0xFF38BDF8),
          textAlign: TextAlign.left,
        ),
        LayerItem(
          id: 'cyber_art',
          name: 'Holo Arte',
          type: LayerType.image,
          x: 14,
          y: 44,
          width: 226,
          height: 155,
          bindingKey: 'art_url',
          imageFit: BoxFit.cover,
        ),
        LayerItem(
          id: 'cyber_databox',
          name: 'Caja de Datos',
          type: LayerType.shape,
          x: 14,
          y: 208,
          width: 226,
          height: 130,
          borderRadius: 6,
          borderWidth: 1.5,
          borderColor: Color(0xFF06B6D4),
          shapeColor: Color(0xFF0D1326),
        ),
        LayerItem(
          id: 'cyber_rules',
          name: 'Protocolo / Reglas',
          type: LayerType.text,
          x: 20,
          y: 216,
          width: 214,
          height: 114,
          text: '{{rules_text}}',
          bindingKey: 'rules_text',
          fontSize: 10,
          fontColor: Color(0xFFE0F2FE),
        ),
      ],
      backLayers: const [
        LayerItem(
          id: 'cyber_back_frame',
          name: 'Marco Cyber Reverso',
          type: LayerType.shape,
          x: 6,
          y: 6,
          width: 242,
          height: 344,
          borderRadius: 10,
          borderWidth: 2,
          borderColor: Color(0xFF06B6D4),
          shapeColor: Color(0xFF070B16),
        ),
        LayerItem(
          id: 'cyber_back_icon',
          name: 'Icono Cyber Reverso',
          type: LayerType.text,
          x: 40,
          y: 150,
          width: 174,
          height: 40,
          text: '◈ CYBER // DECK ◈',
          isBold: true,
          fontSize: 13,
          textAlign: TextAlign.center,
          fontColor: Color(0xFF06B6D4),
        ),
      ],
    );
  }

  /// Preset 5: Minimalist Clean Modern Tabletop Card
  factory CardTemplate.createMinimalist({String id = 'tpl_minimalist', String name = 'Minimalista Moderno'}) {
    return CardTemplate(
      id: id,
      name: name,
      backgroundColor: const Color(0xFF1E2029),
      backBackgroundColor: const Color(0xFF14161F),
      cornerRadius: 18,
      layers: const [
        LayerItem(
          id: 'mini_border',
          name: 'Línea de Contorno',
          type: LayerType.shape,
          x: 10,
          y: 10,
          width: 234,
          height: 336,
          borderRadius: 14,
          borderWidth: 1,
          borderColor: Color(0xFF3B4252),
          shapeColor: Color(0xFF161822),
        ),
        LayerItem(
          id: 'mini_title',
          name: 'Título Minimalista',
          type: LayerType.text,
          x: 18,
          y: 20,
          width: 218,
          height: 24,
          text: '{{card_name}}',
          bindingKey: 'card_name',
          isBold: true,
          fontSize: 13,
          fontColor: Colors.white,
          textAlign: TextAlign.center,
        ),
        LayerItem(
          id: 'mini_art',
          name: 'Ilustración',
          type: LayerType.image,
          x: 20,
          y: 50,
          width: 214,
          height: 165,
          bindingKey: 'art_url',
          imageFit: BoxFit.cover,
        ),
        LayerItem(
          id: 'mini_desc_shape',
          name: 'Caja Texto',
          type: LayerType.shape,
          x: 20,
          y: 224,
          width: 214,
          height: 110,
          borderRadius: 8,
          shapeColor: Color(0xFF222638),
          borderWidth: 0,
          borderColor: Colors.transparent,
        ),
        LayerItem(
          id: 'mini_desc',
          name: 'Texto de Reglas',
          type: LayerType.text,
          x: 26,
          y: 232,
          width: 202,
          height: 94,
          text: '{{rules_text}}',
          bindingKey: 'rules_text',
          fontSize: 10.5,
          fontColor: Color(0xFFD8DEE9),
        ),
      ],
      backLayers: const [
        LayerItem(
          id: 'mini_back_border',
          name: 'Contorno Reverso',
          type: LayerType.shape,
          x: 10,
          y: 10,
          width: 234,
          height: 336,
          borderRadius: 14,
          borderWidth: 1,
          borderColor: Color(0xFF3B4252),
          shapeColor: Color(0xFF12131A),
        ),
        LayerItem(
          id: 'mini_back_title',
          name: 'Título Reverso',
          type: LayerType.text,
          x: 40,
          y: 160,
          width: 174,
          height: 30,
          text: 'G R I M O I R E',
          letterSpacing: 2.0,
          fontSize: 12,
          fontColor: Color(0xFF94A3B8),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// All predefined starter presets available in Grimoire Studio
  static List<PredefinedPresetInfo> get predefinedPresets => const [
    PredefinedPresetInfo(
      id: 'default',
      name: 'Default',
      badge: 'Default',
      description: 'Estructura estándar: Título, Imagen, Shape y encima Descripción.',
      isDefault: true,
      icon: Icons.dashboard_outlined,
      accentColor: Color(0xFF8B5CF6),
      builder: _buildDefault,
    ),
    PredefinedPresetInfo(
      id: 'tcgFantasy',
      name: 'TCG Fantasía',
      badge: 'TCG',
      description: 'Estilo clásico Magic / Hearthstone con orbe de coste y escudo de atributos.',
      icon: Icons.auto_awesome,
      accentColor: Color(0xFFD4AF37),
      builder: _buildTcg,
    ),
    PredefinedPresetInfo(
      id: 'boardgameAction',
      name: 'Juego de Mesa Acción',
      badge: 'Action',
      description: 'Carta de acción y eventos para juegos de tablero con bordes cian y diseño dinámico.',
      icon: Icons.casino_outlined,
      accentColor: Color(0xFF06B6D4),
      builder: _buildAction,
    ),
    PredefinedPresetInfo(
      id: 'tarotHero',
      name: 'Tarot / Héroe',
      badge: 'Tarot',
      description: 'Retrato vertical extendido con marco místico dorado y placa de lore.',
      icon: Icons.style_outlined,
      accentColor: Color(0xFFF59E0B),
      builder: _buildTarot,
    ),
    PredefinedPresetInfo(
      id: 'cyberpunk',
      name: 'Cyberpunk Neón',
      badge: 'Sci-Fi',
      description: 'Interfaz futurista con líneas de neón magenta/cian y caja holográfica.',
      icon: Icons.memory,
      accentColor: Color(0xFFEC4899),
      builder: _buildCyber,
    ),
    PredefinedPresetInfo(
      id: 'minimalist',
      name: 'Minimalista',
      badge: 'Clean',
      description: 'Diseño limpio y moderno con líneas suaves, espaciado amplio y alta legibilidad.',
      icon: Icons.crop_portrait_outlined,
      accentColor: Color(0xFF818CF8),
      builder: _buildMinimalist,
    ),
  ];

  static CardTemplate _buildDefault({String id = 'tpl_default', String name = 'Default'}) =>
      CardTemplate.createDefault(id: id, name: name);
  static CardTemplate _buildTcg({String id = 'tpl_tcg', String name = 'TCG Fantasía'}) =>
      CardTemplate.createTcgFantasy(id: id, name: name);
  static CardTemplate _buildAction({String id = 'tpl_action', String name = 'Juego de Mesa Acción'}) =>
      CardTemplate.createBoardgameAction(id: id, name: name);
  static CardTemplate _buildTarot({String id = 'tpl_tarot', String name = 'Tarot Héroe'}) =>
      CardTemplate.createTarotHero(id: id, name: name);
  static CardTemplate _buildCyber({String id = 'tpl_cyber', String name = 'Cyberpunk Neón'}) =>
      CardTemplate.createCyberpunk(id: id, name: name);
  static CardTemplate _buildMinimalist({String id = 'tpl_minimalist', String name = 'Minimalista Moderno'}) =>
      CardTemplate.createMinimalist(id: id, name: name);

  /// Retrieves a template preset by id
  static CardTemplate getPresetById(String presetId, {String? id, String? name}) {
    final lower = presetId.toLowerCase().trim();
    if (lower == 'default' || lower == 'estandar' || lower == 'standard') {
      return CardTemplate.createDefault(id: id ?? 'tpl_default', name: name ?? 'Default');
    }
    if (lower == 'tcgfantasy' || lower.contains('tcg') || lower.contains('fantasia')) {
      return CardTemplate.createTcgFantasy(id: id ?? 'tpl_tcg', name: name ?? 'TCG Fantasía');
    }
    if (lower == 'boardgameaction' || lower.contains('boardgame') || lower.contains('accion') || lower.contains('action')) {
      return CardTemplate.createBoardgameAction(id: id ?? 'tpl_action', name: name ?? 'Juego de Mesa Acción');
    }
    if (lower == 'tarothero' || lower.contains('tarot') || lower.contains('heroe') || lower.contains('hero')) {
      return CardTemplate.createTarotHero(id: id ?? 'tpl_tarot', name: name ?? 'Tarot Héroe');
    }
    if (lower == 'cyberpunk' || lower.contains('cyber') || lower.contains('neon')) {
      return CardTemplate.createCyberpunk(id: id ?? 'tpl_cyber', name: name ?? 'Cyberpunk Neón');
    }
    if (lower == 'minimalist' || lower.contains('minimal') || lower.contains('modern')) {
      return CardTemplate.createMinimalist(id: id ?? 'tpl_minimalist', name: name ?? 'Minimalista Moderno');
    }
    return CardTemplate.createDefault(id: id ?? 'tpl_default', name: name ?? 'Default');
  }
}

class PredefinedPresetInfo {
  final String id;
  final String name;
  final String badge;
  final String description;
  final bool isDefault;
  final IconData icon;
  final Color accentColor;
  final CardTemplate Function({String id, String name}) builder;

  const PredefinedPresetInfo({
    required this.id,
    required this.name,
    required this.badge,
    required this.description,
    this.isDefault = false,
    required this.icon,
    required this.accentColor,
    required this.builder,
  });
}

