import 'package:flutter/material.dart';
import 'layer_item.dart';

class CardTemplate {
  final String id;
  final String name;
  final List<LayerItem> layers;
  final Color backgroundColor;
  final String? backgroundImage;
  final double cornerRadius;

  const CardTemplate({
    required this.id,
    required this.name,
    this.layers = const [],
    this.backgroundColor = const Color(0xFF131622),
    this.backgroundImage,
    this.cornerRadius = 16,
  });

  CardTemplate copyWith({
    String? id,
    String? name,
    List<LayerItem>? layers,
    Color? backgroundColor,
    String? backgroundImage,
    double? cornerRadius,
  }) {
    return CardTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      layers: layers ?? this.layers,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'layers': layers.map((l) => l.toJson()).toList(),
      'backgroundColor': backgroundColor.value,
      'backgroundImage': backgroundImage,
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
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'] as int)
          : const Color(0xFF131622),
      backgroundImage: json['backgroundImage'] as String?,
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 16,
    );
  }
}
