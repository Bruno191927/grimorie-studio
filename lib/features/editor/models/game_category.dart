class GameCategory {
  final String id;
  final String name;
  final String icon;
  final String defaultType;
  final int defaultColor;
  final String defaultRules;
  final String defaultCost;
  final String defaultAttack;
  final String defaultDefense;
  final String defaultRarity;

  const GameCategory({
    required this.id,
    required this.name,
    this.icon = '🃏',
    this.defaultType = 'Criatura',
    this.defaultColor = 0xFF7C3AED,
    this.defaultRules = '',
    this.defaultCost = '3',
    this.defaultAttack = '0',
    this.defaultDefense = '0',
    this.defaultRarity = 'Común',
  });

  GameCategory copyWith({
    String? id,
    String? name,
    String? icon,
    String? defaultType,
    int? defaultColor,
    String? defaultRules,
    String? defaultCost,
    String? defaultAttack,
    String? defaultDefense,
    String? defaultRarity,
  }) {
    return GameCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      defaultType: defaultType ?? this.defaultType,
      defaultColor: defaultColor ?? this.defaultColor,
      defaultRules: defaultRules ?? this.defaultRules,
      defaultCost: defaultCost ?? this.defaultCost,
      defaultAttack: defaultAttack ?? this.defaultAttack,
      defaultDefense: defaultDefense ?? this.defaultDefense,
      defaultRarity: defaultRarity ?? this.defaultRarity,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'defaultType': defaultType,
    'defaultColor': defaultColor,
    'defaultRules': defaultRules,
    'defaultCost': defaultCost,
    'defaultAttack': defaultAttack,
    'defaultDefense': defaultDefense,
    'defaultRarity': defaultRarity,
  };

  factory GameCategory.fromJson(Map<String, dynamic> json) => GameCategory(
    id: json['id'] as String? ?? 'cat-${DateTime.now().millisecondsSinceEpoch}',
    name: json['name'] as String? ?? 'General',
    icon: json['icon'] as String? ?? '🃏',
    defaultType: json['defaultType'] as String? ?? 'Criatura',
    defaultColor: json['defaultColor'] as int? ?? 0xFF7C3AED,
    defaultRules: json['defaultRules'] as String? ?? '',
    defaultCost: json['defaultCost'] as String? ?? '3',
    defaultAttack: json['defaultAttack'] as String? ?? '0',
    defaultDefense: json['defaultDefense'] as String? ?? '0',
    defaultRarity: json['defaultRarity'] as String? ?? 'Común',
  );
}
