import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/layer_item.dart';

class GradientPresetItem {
  final String name;
  final Color startColor;
  final Color? middleColor;
  final Color endColor;
  final double angle;
  final LayerGradientType type;

  const GradientPresetItem({
    required this.name,
    required this.startColor,
    this.middleColor,
    required this.endColor,
    this.angle = 135.0,
    this.type = LayerGradientType.linear,
  });
}

class ShapePathBuilder {
  static const List<GradientPresetItem> gradientPresets = [
    GradientPresetItem(
      name: 'Mítico Púrpura',
      startColor: Color(0xFF0F0C24),
      middleColor: Color(0xFF3B0764),
      endColor: Color(0xFF7C3AED),
      angle: 135,
    ),
    GradientPresetItem(
      name: 'Fuego Infernal',
      startColor: Color(0xFF1F0606),
      middleColor: Color(0xFF991B1B),
      endColor: Color(0xFFF59E0B),
      angle: 160,
    ),
    GradientPresetItem(
      name: 'Arcano Cian',
      startColor: Color(0xFF091526),
      middleColor: Color(0xFF1E3A8A),
      endColor: Color(0xFF06B6D4),
      angle: 135,
    ),
    GradientPresetItem(
      name: 'Bosque Élfico',
      startColor: Color(0xFF051B14),
      middleColor: Color(0xFF065F46),
      endColor: Color(0xFF10B981),
      angle: 145,
    ),
    GradientPresetItem(
      name: 'Oro Imperial',
      startColor: Color(0xFF1C1305),
      middleColor: Color(0xFF78350F),
      endColor: Color(0xFFFBBF24),
      angle: 120,
    ),
    GradientPresetItem(
      name: 'Kawaii Caos',
      startColor: Color(0xFF2E1065),
      middleColor: Color(0xFF9D174D),
      endColor: Color(0xFFF472B6),
      angle: 135,
    ),
    GradientPresetItem(
      name: 'Abismo Nocturno',
      startColor: Color(0xFF05070B),
      middleColor: Color(0xFF131622),
      endColor: Color(0xFF2E3550),
      angle: 180,
    ),
    GradientPresetItem(
      name: 'Aura Radial',
      startColor: Color(0xFF4C1D95),
      middleColor: Color(0xFF1E1B4B),
      endColor: Color(0xFF090B10),
      type: LayerGradientType.radial,
    ),
  ];

  /// Builds a Flutter [Gradient] from a [LayerItem]'s gradient configuration.
  static Gradient buildGradient({
    required LayerGradientType type,
    required Color startColor,
    required Color endColor,
    Color? middleColor,
    bool useThreeStops = false,
    double angleDegrees = 135.0,
  }) {
    final colors = useThreeStops && middleColor != null
        ? [startColor, middleColor, endColor]
        : [startColor, endColor];
    final stops = useThreeStops && middleColor != null
        ? const [0.0, 0.5, 1.0]
        : const [0.0, 1.0];

    switch (type) {
      case LayerGradientType.linear:
        final rad = (angleDegrees - 90.0) * math.pi / 180.0;
        final dx = math.cos(rad);
        final dy = math.sin(rad);
        return LinearGradient(
          begin: Alignment(-dx, -dy),
          end: Alignment(dx, dy),
          colors: colors,
          stops: stops,
        );
      case LayerGradientType.radial:
        return RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: colors,
          stops: stops,
        );
      case LayerGradientType.sweep:
        final rad = angleDegrees * math.pi / 180.0;
        return SweepGradient(
          center: Alignment.center,
          startAngle: 0.0,
          endAngle: math.pi * 2,
          transform: GradientRotation(rad),
          colors: [...colors, startColor],
          stops: useThreeStops && middleColor != null
              ? const [0.0, 0.35, 0.7, 1.0]
              : const [0.0, 0.5, 1.0],
        );
    }
  }

  /// Returns default normalized (0.0..1.0) polygon points for a given [ShapePreset].
  static List<Offset> getPresetNormalizedPoints(ShapePreset preset) {
    switch (preset) {
      case ShapePreset.rectangle:
        return const [
          Offset(0.0, 0.0),
          Offset(1.0, 0.0),
          Offset(1.0, 1.0),
          Offset(0.0, 1.0),
        ];
      case ShapePreset.triangle:
        return const [
          Offset(0.5, 0.0),
          Offset(1.0, 1.0),
          Offset(0.0, 1.0),
        ];
      case ShapePreset.diamond:
        return const [
          Offset(0.5, 0.0),
          Offset(1.0, 0.5),
          Offset(0.5, 1.0),
          Offset(0.0, 0.5),
        ];
      case ShapePreset.pentagon:
        return _regularPolygonPoints(5, startAngleDeg: -90);
      case ShapePreset.hexagon:
        return const [
          Offset(0.5, 0.0),
          Offset(1.0, 0.25),
          Offset(1.0, 0.75),
          Offset(0.5, 1.0),
          Offset(0.0, 0.75),
          Offset(0.0, 0.25),
        ];
      case ShapePreset.octagon:
        return const [
          Offset(0.30, 0.0),
          Offset(0.70, 0.0),
          Offset(1.0, 0.30),
          Offset(1.0, 0.70),
          Offset(0.70, 1.0),
          Offset(0.30, 1.0),
          Offset(0.0, 0.70),
          Offset(0.0, 0.30),
        ];
      case ShapePreset.shield:
        return const [
          Offset(0.5, 0.0),
          Offset(1.0, 0.12),
          Offset(0.95, 0.62),
          Offset(0.5, 1.0),
          Offset(0.05, 0.62),
          Offset(0.0, 0.12),
        ];
      case ShapePreset.banner:
        return const [
          Offset(0.0, 0.0),
          Offset(1.0, 0.0),
          Offset(0.88, 0.5),
          Offset(1.0, 1.0),
          Offset(0.0, 1.0),
          Offset(0.12, 0.5),
        ];
      case ShapePreset.crystal:
        return const [
          Offset(0.5, 0.0),
          Offset(0.85, 0.22),
          Offset(0.85, 0.78),
          Offset(0.5, 1.0),
          Offset(0.15, 0.78),
          Offset(0.15, 0.22),
        ];
      case ShapePreset.star:
        return _starPoints(5, innerRatio: 0.42);
      case ShapePreset.arch:
        return const [
          Offset(0.5, 0.0),
          Offset(0.82, 0.10),
          Offset(1.0, 0.32),
          Offset(1.0, 1.0),
          Offset(0.0, 1.0),
          Offset(0.0, 0.32),
          Offset(0.18, 0.10),
        ];
      case ShapePreset.circle:
        return _regularPolygonPoints(12, startAngleDeg: -90);
      case ShapePreset.custom:
        return const [
          Offset(0.15, 0.0),
          Offset(0.85, 0.0),
          Offset(1.0, 0.25),
          Offset(1.0, 0.80),
          Offset(0.50, 1.0),
          Offset(0.0, 0.80),
          Offset(0.0, 0.25),
        ];
    }
  }

  static List<Offset> _regularPolygonPoints(int sides, {double startAngleDeg = -90}) {
    final pts = <Offset>[];
    for (int i = 0; i < sides; i++) {
      final angle = (startAngleDeg + (360.0 * i / sides)) * math.pi / 180.0;
      pts.add(Offset(
        (0.5 + 0.5 * math.cos(angle)).clamp(0.0, 1.0),
        (0.5 + 0.5 * math.sin(angle)).clamp(0.0, 1.0),
      ));
    }
    return pts;
  }

  static List<Offset> _starPoints(int points, {double innerRatio = 0.42}) {
    final pts = <Offset>[];
    final totalVertices = points * 2;
    for (int i = 0; i < totalVertices; i++) {
      final r = i.isEven ? 0.5 : (0.5 * innerRatio);
      final angle = (-90.0 + (360.0 * i / totalVertices)) * math.pi / 180.0;
      pts.add(Offset(
        (0.5 + r * math.cos(angle)).clamp(0.0, 1.0),
        (0.5 + r * math.sin(angle)).clamp(0.0, 1.0),
      ));
    }
    return pts;
  }

  /// Builds the exact [Path] for a given [Size] and [LayerItem] shape configuration.
  static Path buildPath({
    required Size size,
    required ShapePreset preset,
    double borderRadius = 8.0,
    List<Offset> customPoints = const [],
    bool closePath = true,
  }) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    switch (preset) {
      case ShapePreset.rectangle:
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, w, h),
            Radius.circular(borderRadius),
          ),
        );
        return path;

      case ShapePreset.circle:
        path.addOval(Rect.fromLTWH(0, 0, w, h));
        return path;

      case ShapePreset.shield:
        path.moveTo(w * 0.5, 0);
        path.lineTo(w, h * 0.12);
        path.quadraticBezierTo(w, h * 0.68, w * 0.5, h);
        path.quadraticBezierTo(0, h * 0.68, 0, h * 0.12);
        path.close();
        return path;

      case ShapePreset.arch:
        final archRadius = math.min(w / 2, h * 0.45);
        path.moveTo(0, h);
        path.lineTo(0, archRadius);
        path.arcToPoint(
          Offset(w, archRadius),
          radius: Radius.circular(archRadius),
          clockwise: true,
        );
        path.lineTo(w, h);
        path.close();
        return path;

      case ShapePreset.custom:
        final pts = customPoints.length >= 3
            ? customPoints
            : getPresetNormalizedPoints(ShapePreset.custom);
        return _buildPolygonPath(size, pts, closePath: closePath, cornerRadius: borderRadius);

      default:
        final pts = getPresetNormalizedPoints(preset);
        return _buildPolygonPath(size, pts, closePath: true, cornerRadius: borderRadius);
    }
  }

  static Path _buildPolygonPath(
    Size size,
    List<Offset> normalizedPoints, {
    bool closePath = true,
    double cornerRadius = 0.0,
  }) {
    final path = Path();
    if (normalizedPoints.isEmpty) return path;

    final scaled = normalizedPoints
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    if (cornerRadius <= 0.5 || scaled.length < 3) {
      path.moveTo(scaled.first.dx, scaled.first.dy);
      for (int i = 1; i < scaled.length; i++) {
        path.lineTo(scaled[i].dx, scaled[i].dy);
      }
      if (closePath) path.close();
      return path;
    }

    // Rounded polygon corners when borderRadius > 0
    final n = scaled.length;
    for (int i = 0; i < n; i++) {
      final prev = scaled[(i - 1 + n) % n];
      final curr = scaled[i];
      final next = scaled[(i + 1) % n];

      final v1 = prev - curr;
      final v2 = next - curr;
      final len1 = v1.distance;
      final len2 = v2.distance;
      if (len1 < 0.001 || len2 < 0.001) {
        if (i == 0) {
          path.moveTo(curr.dx, curr.dy);
        } else {
          path.lineTo(curr.dx, curr.dy);
        }
        continue;
      }

      final r = math.min(cornerRadius, math.min(len1, len2) * 0.35);
      final pStart = curr + (v1 / len1) * r;
      final pEnd = curr + (v2 / len2) * r;

      if (i == 0) {
        path.moveTo(pStart.dx, pStart.dy);
      } else {
        path.lineTo(pStart.dx, pStart.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, pEnd.dx, pEnd.dy);
    }
    if (closePath) path.close();
    return path;
  }

  static String getPresetLabel(ShapePreset preset, {bool isEnglish = false}) {
    switch (preset) {
      case ShapePreset.rectangle:
        return isEnglish ? 'Rectangle / Frame' : 'Rectángulo / Marco';
      case ShapePreset.circle:
        return isEnglish ? 'Circle / Medallion' : 'Círculo / Medallón';
      case ShapePreset.shield:
        return isEnglish ? 'TCG Shield' : 'Escudo TCG';
      case ShapePreset.hexagon:
        return isEnglish ? 'Hexagon' : 'Hexágono';
      case ShapePreset.octagon:
        return isEnglish ? 'Octagon' : 'Octágono';
      case ShapePreset.diamond:
        return isEnglish ? 'Diamond / Rhombus' : 'Rombo / Diamante';
      case ShapePreset.banner:
        return isEnglish ? 'Ribbon Banner' : 'Estandarte / Cinta';
      case ShapePreset.star:
        return isEnglish ? 'Star Emblem' : 'Estrella / Emblema';
      case ShapePreset.pentagon:
        return isEnglish ? 'Pentagon' : 'Pentágono';
      case ShapePreset.triangle:
        return isEnglish ? 'Triangle' : 'Triángulo';
      case ShapePreset.arch:
        return isEnglish ? 'Gothic Arch' : 'Arco Gótico';
      case ShapePreset.crystal:
        return isEnglish ? 'Mana Crystal' : 'Cristal de Maná';
      case ShapePreset.custom:
        return isEnglish ? 'Custom Shape (Nodes)' : 'Personalizada (Nodos)';
    }
  }

  static IconData getPresetIcon(ShapePreset preset) {
    switch (preset) {
      case ShapePreset.rectangle:
        return Icons.crop_square_rounded;
      case ShapePreset.circle:
        return Icons.circle_outlined;
      case ShapePreset.shield:
        return Icons.shield_outlined;
      case ShapePreset.hexagon:
        return Icons.hexagon_outlined;
      case ShapePreset.octagon:
        return Icons.stop_circle_outlined;
      case ShapePreset.diamond:
        return Icons.diamond_outlined;
      case ShapePreset.banner:
        return Icons.bookmark_border;
      case ShapePreset.star:
        return Icons.star_outline;
      case ShapePreset.pentagon:
        return Icons.pentagon_outlined;
      case ShapePreset.triangle:
        return Icons.change_history;
      case ShapePreset.arch:
        return Icons.sensor_door_outlined;
      case ShapePreset.crystal:
        return Icons.auto_awesome_outlined;
      case ShapePreset.custom:
        return Icons.polyline_outlined;
    }
  }
}

class LayerShapeClipper extends CustomClipper<Path> {
  final ShapePreset preset;
  final double borderRadius;
  final List<Offset> customPoints;
  final bool closePath;

  const LayerShapeClipper({
    required this.preset,
    required this.borderRadius,
    this.customPoints = const [],
    this.closePath = true,
  });

  @override
  Path getClip(Size size) {
    return ShapePathBuilder.buildPath(
      size: size,
      preset: preset,
      borderRadius: borderRadius,
      customPoints: customPoints,
      closePath: closePath,
    );
  }

  @override
  bool shouldReclip(covariant LayerShapeClipper oldClipper) {
    return oldClipper.preset != preset ||
        oldClipper.borderRadius != borderRadius ||
        oldClipper.closePath != closePath ||
        oldClipper.customPoints != customPoints;
  }
}

class LayerShapePainter extends CustomPainter {
  final ShapePreset preset;
  final double borderRadius;
  final List<Offset> customPoints;
  final bool closePath;
  final Color fillColor;
  final Gradient? fillGradient;
  final Color borderColor;
  final double borderWidth;

  const LayerShapePainter({
    required this.preset,
    required this.borderRadius,
    this.customPoints = const [],
    this.closePath = true,
    required this.fillColor,
    this.fillGradient,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = ShapePathBuilder.buildPath(
      size: size,
      preset: preset,
      borderRadius: borderRadius,
      customPoints: customPoints,
      closePath: closePath,
    );

    final fillPaint = Paint()..style = PaintingStyle.fill;
    if (fillGradient != null) {
      fillPaint.shader = fillGradient!.createShader(Offset.zero & size);
    } else {
      fillPaint.color = fillColor;
    }
    canvas.drawPath(path, fillPaint);

    if (borderWidth > 0 && borderColor.a > 0) {
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = borderColor
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LayerShapePainter oldDelegate) {
    return oldDelegate.preset != preset ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.customPoints != customPoints ||
        oldDelegate.closePath != closePath ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.fillGradient != fillGradient ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}
