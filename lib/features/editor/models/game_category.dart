class GameCategory {
  final String id;
  final String name;
  final String icon;
  final String defaultType;
  final int defaultColor;
  final String defaultRules;

  const GameCategory({
    required this.id,
    required this.name,
    this.icon = '🃏',
    this.defaultType = 'Criatura',
    this.defaultColor = 0xFF7C3AED,
    this.defaultRules = '',
  });

  GameCategory copyWith({
    String? id,
    String? name,
    String? icon,
    String? defaultType,
    int? defaultColor,
    String? defaultRules,
  }) {
    return GameCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      defaultType: defaultType ?? this.defaultType,
      defaultColor: defaultColor ?? this.defaultColor,
      defaultRules: defaultRules ?? this.defaultRules,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'defaultType': defaultType,
    'defaultColor': defaultColor,
    'defaultRules': defaultRules,
  };

  factory GameCategory.fromJson(Map<String, dynamic> json) => GameCategory(
    id: json['id'] as String? ?? 'cat-${DateTime.now().millisecondsSinceEpoch}',
    name: json['name'] as String? ?? 'General',
    icon: json['icon'] as String? ?? '🃏',
    defaultType: json['defaultType'] as String? ?? 'Criatura',
    defaultColor: json['defaultColor'] as int? ?? 0xFF7C3AED,
    defaultRules: json['defaultRules'] as String? ?? '',
  );
}
