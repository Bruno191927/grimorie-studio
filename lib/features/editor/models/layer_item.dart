import 'package:flutter/material.dart';

enum LayerType {
  background,
  text,
  image,
  shape,
}

enum LayerFillMode {
  solid,
  gradient,
  image,
}

enum LayerGradientType {
  linear,
  radial,
  sweep,
}

enum ShapePreset {
  rectangle,
  circle,
  shield,
  hexagon,
  octagon,
  diamond,
  banner,
  star,
  pentagon,
  triangle,
  arch,
  crystal,
  custom,
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

  // Typography properties
  final String text;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final String fontFamily;
  final double letterSpacing;
  final Color fontColor;
  final TextAlign textAlign;

  // Fill, Image & Gradient properties (used by background, shape, and image layers)
  final String? imagePath;
  final BoxFit imageFit;
  final LayerFillMode fillMode;
  final Color shapeColor;
  final LayerGradientType gradientType;
  final Color gradientEndColor;
  final Color gradientMiddleColor;
  final bool useThreeStopGradient;
  final double gradientAngle; // 0 to 360 degrees

  // Shape & Border properties
  final ShapePreset shapePreset;
  final List<Offset> customPoints; // Normalized (0.0..1.0) vertices for custom shapes
  final bool closeCustomPath;
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
    this.isItalic = false,
    this.fontFamily = 'Inter',
    this.letterSpacing = 0.2,
    this.fontColor = Colors.white,
    this.textAlign = TextAlign.left,
    this.imagePath,
    this.imageFit = BoxFit.cover,
    this.fillMode = LayerFillMode.solid,
    this.shapeColor = const Color(0xFF1F2438),
    this.gradientType = LayerGradientType.linear,
    this.gradientEndColor = const Color(0xFF4C1D95),
    this.gradientMiddleColor = const Color(0xFF7C3AED),
    this.useThreeStopGradient = false,
    this.gradientAngle = 135.0,
    this.shapePreset = ShapePreset.rectangle,
    this.customPoints = const [],
    this.closeCustomPath = true,
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
    bool? isItalic,
    String? fontFamily,
    double? letterSpacing,
    Color? fontColor,
    TextAlign? textAlign,
    String? imagePath,
    bool clearImagePath = false,
    BoxFit? imageFit,
    LayerFillMode? fillMode,
    Color? shapeColor,
    LayerGradientType? gradientType,
    Color? gradientEndColor,
    Color? gradientMiddleColor,
    bool? useThreeStopGradient,
    double? gradientAngle,
    ShapePreset? shapePreset,
    List<Offset>? customPoints,
    bool? closeCustomPath,
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
      isItalic: isItalic ?? this.isItalic,
      fontFamily: fontFamily ?? this.fontFamily,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      fontColor: fontColor ?? this.fontColor,
      textAlign: textAlign ?? this.textAlign,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      imageFit: imageFit ?? this.imageFit,
      fillMode: fillMode ?? this.fillMode,
      shapeColor: shapeColor ?? this.shapeColor,
      gradientType: gradientType ?? this.gradientType,
      gradientEndColor: gradientEndColor ?? this.gradientEndColor,
      gradientMiddleColor: gradientMiddleColor ?? this.gradientMiddleColor,
      useThreeStopGradient: useThreeStopGradient ?? this.useThreeStopGradient,
      gradientAngle: gradientAngle ?? this.gradientAngle,
      shapePreset: shapePreset ?? this.shapePreset,
      customPoints: customPoints ?? this.customPoints,
      closeCustomPath: closeCustomPath ?? this.closeCustomPath,
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
      'isItalic': isItalic,
      'fontFamily': fontFamily,
      'letterSpacing': letterSpacing,
      'fontColor': fontColor.toARGB32(),
      'textAlign': textAlign.name,
      'imagePath': imagePath,
      'imageFit': imageFit.name,
      'fillMode': fillMode.name,
      'shapeColor': shapeColor.toARGB32(),
      'gradientType': gradientType.name,
      'gradientEndColor': gradientEndColor.toARGB32(),
      'gradientMiddleColor': gradientMiddleColor.toARGB32(),
      'useThreeStopGradient': useThreeStopGradient,
      'gradientAngle': gradientAngle,
      'shapePreset': shapePreset.name,
      'customPoints': customPoints.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'closeCustomPath': closeCustomPath,
      'borderColor': borderColor.toARGB32(),
      'borderWidth': borderWidth,
      'borderRadius': borderRadius,
    };
  }

  factory LayerItem.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['customPoints'] as List<dynamic>?;
    final parsedPoints = rawPoints != null
        ? rawPoints.map((pt) {
            final map = pt as Map<String, dynamic>;
            return Offset(
              (map['x'] as num?)?.toDouble() ?? 0.0,
              (map['y'] as num?)?.toDouble() ?? 0.0,
            );
          }).toList()
        : const <Offset>[];

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
      isItalic: json['isItalic'] as bool? ?? false,
      fontFamily: json['fontFamily'] as String? ?? 'Inter',
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.2,
      fontColor: json['fontColor'] != null ? Color(json['fontColor'] as int) : Colors.white,
      textAlign: TextAlign.values.firstWhere(
        (a) => a.name == json['textAlign'],
        orElse: () => TextAlign.left,
      ),
      imagePath: json['imagePath'] as String?,
      imageFit: BoxFit.values.firstWhere(
        (f) => f.name == json['imageFit'],
        orElse: () => BoxFit.cover,
      ),
      fillMode: LayerFillMode.values.firstWhere(
        (m) => m.name == json['fillMode'],
        orElse: () => LayerFillMode.solid,
      ),
      shapeColor: json['shapeColor'] != null ? Color(json['shapeColor'] as int) : const Color(0xFF1F2438),
      gradientType: LayerGradientType.values.firstWhere(
        (g) => g.name == json['gradientType'],
        orElse: () => LayerGradientType.linear,
      ),
      gradientEndColor: json['gradientEndColor'] != null
          ? Color(json['gradientEndColor'] as int)
          : const Color(0xFF4C1D95),
      gradientMiddleColor: json['gradientMiddleColor'] != null
          ? Color(json['gradientMiddleColor'] as int)
          : const Color(0xFF7C3AED),
      useThreeStopGradient: json['useThreeStopGradient'] as bool? ?? false,
      gradientAngle: (json['gradientAngle'] as num?)?.toDouble() ?? 135.0,
      shapePreset: ShapePreset.values.firstWhere(
        (s) => s.name == json['shapePreset'],
        orElse: () => ShapePreset.rectangle,
      ),
      customPoints: parsedPoints,
      closeCustomPath: json['closeCustomPath'] as bool? ?? true,
      borderColor: json['borderColor'] != null ? Color(json['borderColor'] as int) : const Color(0xFF7C3AED),
      borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 0,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 8,
    );
  }
}
