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
}
