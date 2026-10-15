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
  final bool hasCost;
  final bool hasCombatStats;
  final bool hasRarity;
  final bool hasRules;
  final Map<String, String> customFields;

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
    this.hasCost = true,
    this.hasCombatStats = true,
    this.hasRarity = true,
    this.hasRules = true,
    this.customFields = const {},
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
    bool? hasCost,
    bool? hasCombatStats,
    bool? hasRarity,
    bool? hasRules,
    Map<String, String>? customFields,
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
      hasCost: hasCost ?? this.hasCost,
      hasCombatStats: hasCombatStats ?? this.hasCombatStats,
      hasRarity: hasRarity ?? this.hasRarity,
      hasRules: hasRules ?? this.hasRules,
      customFields: customFields ?? this.customFields,
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
    'hasCost': hasCost,
    'hasCombatStats': hasCombatStats,
    'hasRarity': hasRarity,
    'hasRules': hasRules,
    'customFields': customFields,
  };

  factory GameCategory.fromJson(Map<String, dynamic> json) {
    final costStr = json['defaultCost']?.toString() ?? '3';
    final hasCostVal = json['hasCost'] as bool? ?? (costStr.isNotEmpty && costStr != '-');
    final atkStr = json['defaultAttack']?.toString() ?? '0';
    final defStr = json['defaultDefense']?.toString() ?? '0';
    final hasCombatVal = json['hasCombatStats'] as bool? ?? true;
    final rarityStr = json['defaultRarity']?.toString() ?? 'Común';
    final hasRarityVal = json['hasRarity'] as bool? ?? true;
    final rulesStr = json['defaultRules']?.toString() ?? '';
    final hasRulesVal = json['hasRules'] as bool? ?? true;

    final fields = <String, String>{};
    if (json['customFields'] is Map) {
      (json['customFields'] as Map).forEach((k, v) {
        if (k != null && v != null) {
          fields[k.toString()] = v.toString();
        }
      });
    }

    return GameCategory(
      id: json['id'] as String? ?? 'cat-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'General',
      icon: json['icon'] as String? ?? '🃏',
      defaultType: json['defaultType'] as String? ?? 'Criatura',
      defaultColor: json['defaultColor'] as int? ?? 0xFF7C3AED,
      defaultRules: rulesStr,
      defaultCost: costStr,
      defaultAttack: atkStr,
      defaultDefense: defStr,
      defaultRarity: rarityStr,
      hasCost: hasCostVal,
      hasCombatStats: hasCombatVal,
      hasRarity: hasRarityVal,
      hasRules: hasRulesVal,
      customFields: fields,
    );
  }
}
