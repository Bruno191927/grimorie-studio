import 'package:flutter/material.dart';

enum LayerType {
  text,
  image,
  shape,
}

class LayerItem {
  final String id;
  final String name;
  final LayerType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation; // in radians or degrees
  final double opacity;
  final bool isVisible;
  final bool isLocked;

  // Data-binding key (e.g. 'card_name', 'cost', 'art_url')
  final String bindingKey;

  // Smart Tokens / Conditional rules:
  // e.g. {'condition': 'cost > 5', 'action': 'show', 'borderColor': '#EC4899'}
  final Map<String, dynamic> conditionalRules;

  // Styling properties
  final String text;
  final double fontSize;
  final bool isBold;
  final Color fontColor;
  final TextAlign textAlign;

  final String? imagePath;
  final Color shapeColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;

  const LayerItem({
    required this.id,
    required this.name,
    required this.type,
    this.x = 10,
    this.y = 10,
    this.width = 120,
    this.height = 40,
    this.rotation = 0,
    this.opacity = 1.0,
    this.isVisible = true,
    this.isLocked = false,
    this.bindingKey = '',
    this.conditionalRules = const {},
    this.text = '',
    this.fontSize = 14,
    this.isBold = false,
    this.fontColor = Colors.white,
    this.textAlign = TextAlign.left,
    this.imagePath,
    this.shapeColor = const Color(0xFF1F2438),
    this.borderColor = const Color(0xFF7C3AED),
    this.borderWidth = 0,
    this.borderRadius = 8,
  });

  LayerItem copyWith({
    String? id,
    String? name,
    LayerType? type,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    bool? isVisible,
    bool? isLocked,
    String? bindingKey,
    Map<String, dynamic>? conditionalRules,
    String? text,
    double? fontSize,
    bool? isBold,
    Color? fontColor,
    TextAlign? textAlign,
    String? imagePath,
    Color? shapeColor,
    Color? borderColor,
    double? borderWidth,
    double? borderRadius,
  }) {
    return LayerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      bindingKey: bindingKey ?? this.bindingKey,
      conditionalRules: conditionalRules ?? this.conditionalRules,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      fontColor: fontColor ?? this.fontColor,
      textAlign: textAlign ?? this.textAlign,
      imagePath: imagePath ?? this.imagePath,
      shapeColor: shapeColor ?? this.shapeColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'opacity': opacity,
      'isVisible': isVisible,
      'isLocked': isLocked,
      'bindingKey': bindingKey,
      'conditionalRules': conditionalRules,
      'text': text,
      'fontSize': fontSize,
      'isBold': isBold,
      'fontColor': fontColor.value,
      'textAlign': textAlign.name,
      'imagePath': imagePath,
      'shapeColor': shapeColor.value,
      'borderColor': borderColor.value,
      'borderWidth': borderWidth,
      'borderRadius': borderRadius,
    };
  }

  factory LayerItem.fromJson(Map<String, dynamic> json) {
    return LayerItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Layer',
      type: LayerType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => LayerType.text,
      ),
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 100,
      height: (json['height'] as num?)?.toDouble() ?? 30,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      bindingKey: json['bindingKey'] as String? ?? '',
      conditionalRules: (json['conditionalRules'] as Map<String, dynamic>?) ?? {},
      text: json['text'] as String? ?? '',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14,
      isBold: json['isBold'] as bool? ?? false,
      fontColor: json['fontColor'] != null ? Color(json['fontColor'] as int) : Colors.white,
      textAlign: TextAlign.values.firstWhere(
        (a) => a.name == json['textAlign'],
        orElse: () => TextAlign.left,
      ),
      imagePath: json['imagePath'] as String?,
      shapeColor: json['shapeColor'] != null ? Color(json['shapeColor'] as int) : const Color(0xFF1F2438),
      borderColor: json['borderColor'] != null ? Color(json['borderColor'] as int) : const Color(0xFF7C3AED),
      borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 0,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 8,
    );
  }
}
