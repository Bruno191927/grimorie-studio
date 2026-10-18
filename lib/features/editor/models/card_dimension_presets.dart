class CardDimensionPreset {
  final String id;
  final String name;
  final String category;
  final double widthMm;
  final double heightMm;
  final String description;

  const CardDimensionPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.widthMm,
    required this.heightMm,
    required this.description,
  });

  static const List<CardDimensionPreset> standardPresets = [
    CardDimensionPreset(
      id: 'poker',
      name: 'Poker Standard (MTG / Pokémon)',
      category: 'TCG Estándar',
      widthMm: 63.5,
      heightMm: 88.9,
      description: '63.5 x 88.9 mm (2.5" x 3.5") - El estándar de oro en TCGs (Magic: The Gathering, Pokémon, One Piece, Lorcana).',
    ),
    CardDimensionPreset(
      id: 'bridge',
      name: 'Bridge / Baraja Española',
      category: 'Tradicional',
      widthMm: 57.0,
      heightMm: 88.9,
      description: '57.0 x 88.9 mm (2.25" x 3.5") - Cartas más estrechas ideales para manos grandes de naipes.',
    ),
    CardDimensionPreset(
      id: 'tarot',
      name: 'Tarot / Large Boardgame',
      category: 'Juegos de Mesa',
      widthMm: 70.0,
      heightMm: 120.0,
      description: '70.0 x 120.0 mm (2.75" x 4.75") - Formato Tarot grande para arte detallado y roles.',
    ),
    CardDimensionPreset(
      id: 'mini_american',
      name: 'Mini American',
      category: 'Miniaturas / Items',
      widthMm: 41.0,
      heightMm: 63.0,
      description: '41.0 x 63.0 mm (1.61" x 2.48") - Formato compacto para cartas de daño o equipo.',
    ),
    CardDimensionPreset(
      id: 'mini_euro',
      name: 'Mini European',
      category: 'Juegos Europeos',
      widthMm: 44.0,
      heightMm: 68.0,
      description: '44.0 x 68.0 mm (1.73" x 2.68") - Estándar Catan, Ticket to Ride, cartas de recursos.',
    ),
    CardDimensionPreset(
      id: 'square',
      name: 'Cuadrada (Square)',
      category: 'Especial',
      widthMm: 70.0,
      heightMm: 70.0,
      description: '70.0 x 70.0 mm (2.75" x 2.75") - Formato simétrico para losetas, hechizos y habilidades.',
    ),
    CardDimensionPreset(
      id: 'landscape_poker',
      name: 'Poker Apaisado / Horizontal',
      category: 'Horizontal',
      widthMm: 88.9,
      heightMm: 63.5,
      description: '88.9 x 63.5 mm (3.5" x 2.5") - Formato apaisado para vehículos, naves, localizaciones o batallas.',
    ),
  ];

  static CardDimensionPreset? match(double widthMm, double heightMm) {
    for (final p in standardPresets) {
      if ((p.widthMm - widthMm).abs() < 0.2 && (p.heightMm - heightMm).abs() < 0.2) {
        return p;
      }
    }
    return null;
  }
}
