import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../models/layer_item.dart';
import '../../utils/shape_path_builder.dart';

class CustomShapeBuilderResult {
  final ShapePreset shapePreset;
  final List<Offset> customPoints;
  final double borderRadius;
  final bool closeCustomPath;

  const CustomShapeBuilderResult({
    required this.shapePreset,
    required this.customPoints,
    required this.borderRadius,
    required this.closeCustomPath,
  });
}

class CustomShapeBuilderDialog extends ConsumerStatefulWidget {
  final LayerItem layer;
  final ValueChanged<CustomShapeBuilderResult>? onLiveChanged;

  const CustomShapeBuilderDialog({
    super.key,
    required this.layer,
    this.onLiveChanged,
  });

  static Future<CustomShapeBuilderResult?> show(
    BuildContext context, {
    required LayerItem layer,
    ValueChanged<CustomShapeBuilderResult>? onLiveChanged,
  }) {
    return showDialog<CustomShapeBuilderResult>(
      context: context,
      builder: (ctx) => CustomShapeBuilderDialog(
        layer: layer,
        onLiveChanged: onLiveChanged,
      ),
    );
  }

  @override
  ConsumerState<CustomShapeBuilderDialog> createState() => _CustomShapeBuilderDialogState();
}

class _CustomShapeBuilderDialogState extends ConsumerState<CustomShapeBuilderDialog> {
  late List<Offset> _points;
  late double _borderRadius;
  late bool _closePath;
  bool _mirrorHorizontal = false;
  bool _snapToGrid = true;
  int? _selectedNodeIndex;

  @override
  void initState() {
    super.initState();
    if (widget.layer.customPoints.length >= 3) {
      _points = List<Offset>.from(widget.layer.customPoints);
    } else {
      _points = List<Offset>.from(
        ShapePathBuilder.getPresetNormalizedPoints(widget.layer.shapePreset),
      );
    }
    _borderRadius = widget.layer.borderRadius;
    _closePath = widget.layer.closeCustomPath;
  }

  void _notifyLiveChange() {
    widget.onLiveChanged?.call(
      CustomShapeBuilderResult(
        shapePreset: ShapePreset.custom,
        customPoints: List<Offset>.from(_points),
        borderRadius: _borderRadius,
        closeCustomPath: _closePath,
      ),
    );
  }

  Offset _normalizeAndSnap(Offset localPos, Size canvasSize) {
    double nx = (localPos.dx / canvasSize.width).clamp(0.0, 1.0);
    double ny = (localPos.dy / canvasSize.height).clamp(0.0, 1.0);
    if (_snapToGrid) {
      // Snap to 0.05 (20x20 grid)
      nx = (nx * 20).round() / 20.0;
      ny = (ny * 20).round() / 20.0;
    }
    return Offset(nx, ny);
  }

  void _updateNodePosition(int index, Offset newNormPos) {
    setState(() {
      final oldPos = _points[index];
      _points[index] = newNormPos;

      // If horizontal symmetry is active, also move the mirrored node across X = 0.5
      if (_mirrorHorizontal && (oldPos.dx - 0.5).abs() > 0.02) {
        final targetMirrorX = 1.0 - oldPos.dx;
        int? mirrorIdx;
        double bestDist = 0.12;
        for (int i = 0; i < _points.length; i++) {
          if (i == index) continue;
          final d = (Offset(targetMirrorX, oldPos.dy) - _points[i]).distance;
          if (d < bestDist) {
            bestDist = d;
            mirrorIdx = i;
          }
        }
        if (mirrorIdx != null) {
          _points[mirrorIdx] = Offset((1.0 - newNormPos.dx).clamp(0.0, 1.0), newNormPos.dy);
        }
      }
    });
    _notifyLiveChange();
  }

  void _insertMidpointOnBestEdge() {
    if (_points.length < 2) return;
    int insertIdx = _selectedNodeIndex ?? (_points.length - 1);
    final nextIdx = (insertIdx + 1) % _points.length;
    final p1 = _points[insertIdx];
    final p2 = _points[nextIdx];
    final mid = Offset((p1.dx + p2.dx) / 2.0, (p1.dy + p2.dy) / 2.0);
    setState(() {
      _points.insert(nextIdx, mid);
      _selectedNodeIndex = nextIdx;
    });
    _notifyLiveChange();
  }

  void _deleteSelectedNode() {
    if (_points.length <= 3 || _selectedNodeIndex == null) return;
    setState(() {
      _points.removeAt(_selectedNodeIndex!);
      _selectedNodeIndex = null;
    });
    _notifyLiveChange();
  }

  void _loadPresetPoints(ShapePreset preset) {
    setState(() {
      _points = List<Offset>.from(ShapePathBuilder.getPresetNormalizedPoints(preset));
      _selectedNodeIndex = null;
    });
    _notifyLiveChange();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.layer.fillMode == LayerFillMode.gradient
        ? ShapePathBuilder.buildGradient(
            type: widget.layer.gradientType,
            startColor: widget.layer.shapeColor,
            endColor: widget.layer.gradientEndColor,
            middleColor: widget.layer.gradientMiddleColor,
            useThreeStops: widget.layer.useThreeStopGradient,
            angleDegrees: widget.layer.gradientAngle,
          )
        : null;

    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GrimoireTheme.accentAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: GrimoireTheme.accentAmber.withValues(alpha: 0.5)),
                          ),
                          child: const Icon(Icons.polyline_outlined, color: GrimoireTheme.accentAmber, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.tr('custom_shape_builder_title'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                ref.tr('custom_shape_builder_desc'),
                                style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Main Workspace: Left Interactive Node Canvas + Right Controls
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Interactive Vector Canvas
                  Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0C14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const pad = 28.0;
                        final drawSize = Size(
                          constraints.maxWidth - pad * 2,
                          constraints.maxHeight - pad * 2,
                        );

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            final local = details.localPosition - const Offset(pad, pad);
                            // Check if user tapped near an existing node first
                            for (int i = 0; i < _points.length; i++) {
                              final ptPx = Offset(_points[i].dx * drawSize.width, _points[i].dy * drawSize.height);
                              if ((ptPx - local).distance <= 14) {
                                setState(() => _selectedNodeIndex = i);
                                return;
                              }
                            }
                            // Otherwise insert a new vertex on the closest polygon segment
                            final norm = _normalizeAndSnap(local, drawSize);
                            int bestEdge = _points.length;
                            double bestDist = double.infinity;
                            for (int i = 0; i < _points.length; i++) {
                              final a = _points[i];
                              final b = _points[(i + 1) % _points.length];
                              final d = _distanceToSegment(norm, a, b);
                              if (d < bestDist) {
                                bestDist = d;
                                bestEdge = i + 1;
                              }
                            }
                            setState(() {
                              _points.insert(bestEdge, norm);
                              _selectedNodeIndex = bestEdge;
                            });
                            _notifyLiveChange();
                          },
                          child: Stack(
                            children: [
                              // Background Grid + Symmetry Axis + Shape Preview
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(pad),
                                  child: CustomPaint(
                                    painter: _NodeEditorCanvasPainter(
                                      points: _points,
                                      borderRadius: _borderRadius,
                                      closePath: _closePath,
                                      mirrorHorizontal: _mirrorHorizontal,
                                      fillColor: widget.layer.shapeColor,
                                      fillGradient: gradient,
                                      borderColor: widget.layer.borderColor,
                                      borderWidth: math.max(widget.layer.borderWidth, 2.0),
                                    ),
                                  ),
                                ),
                              ),

                              // Draggable Vertex Handles
                              for (int i = 0; i < _points.length; i++)
                                Positioned(
                                  left: pad + _points[i].dx * drawSize.width - 11,
                                  top: pad + _points[i].dy * drawSize.height - 11,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedNodeIndex = i),
                                    onSecondaryTap: () {
                                      if (_points.length > 3) {
                                        setState(() {
                                          _points.removeAt(i);
                                          _selectedNodeIndex = null;
                                        });
                                        _notifyLiveChange();
                                      }
                                    },
                                    onPanStart: (_) => setState(() => _selectedNodeIndex = i),
                                    onPanUpdate: (details) {
                                      final currentPx = Offset(
                                        _points[i].dx * drawSize.width,
                                        _points[i].dy * drawSize.height,
                                      );
                                      final nextPx = currentPx + details.delta;
                                      final norm = _normalizeAndSnap(nextPx, drawSize);
                                      _updateNodePosition(i, norm);
                                    },
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: _selectedNodeIndex == i
                                            ? GrimoireTheme.accentAmber
                                            : GrimoireTheme.accentPurple,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedNodeIndex == i ? Colors.black : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 18),

                  // Right Controls Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Base Geometry Templates to start sculpting from
                        const Text(
                          'PARTIR DE PLANTILLA GEOMÉTRICA:',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary, letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final preset in [
                              ShapePreset.shield,
                              ShapePreset.hexagon,
                              ShapePreset.octagon,
                              ShapePreset.diamond,
                              ShapePreset.banner,
                              ShapePreset.star,
                              ShapePreset.crystal,
                              ShapePreset.arch,
                              ShapePreset.triangle,
                              ShapePreset.rectangle,
                            ])
                              InkWell(
                                onTap: () => _loadPresetPoints(preset),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF141828),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: GrimoireTheme.borderSubtle),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(ShapePathBuilder.getPresetIcon(preset), size: 12, color: GrimoireTheme.accentAmber),
                                      const SizedBox(width: 4),
                                      Text(
                                        ShapePathBuilder.getPresetLabel(preset),
                                        style: const TextStyle(fontSize: 10, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Node Actions
                        const Text(
                          'HERRAMIENTAS DE NODOS Y SIMETRÍA:',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary, letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: GrimoireTheme.accentEmerald,
                                  side: const BorderSide(color: GrimoireTheme.accentEmerald),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: const Icon(Icons.add_circle_outline, size: 14),
                                label: const Text('Añadir Nodo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: _insertMidpointOnBestEdge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: GrimoireTheme.accentPink,
                                  side: BorderSide(
                                    color: (_selectedNodeIndex != null && _points.length > 3)
                                        ? GrimoireTheme.accentPink
                                        : GrimoireTheme.borderSubtle,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: const Icon(Icons.remove_circle_outline, size: 14),
                                label: const Text('Quitar Nodo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: (_selectedNodeIndex != null && _points.length > 3)
                                    ? _deleteSelectedNode
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Toggles: Mirror X & Grid Snap
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121524),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: GrimoireTheme.borderSubtle),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Row(
                                      children: [
                                        Icon(Icons.flip, size: 14, color: GrimoireTheme.accentPurple),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Simetría Horizontal (Espejo X)',
                                            style: TextStyle(fontSize: 11, color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _mirrorHorizontal,
                                    activeThumbColor: GrimoireTheme.accentPurple,
                                    onChanged: (val) => setState(() => _mirrorHorizontal = val),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Row(
                                      children: [
                                        Icon(Icons.grid_4x4, size: 14, color: GrimoireTheme.accentEmerald),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Ajustar a Cuadrícula (Snap)',
                                            style: TextStyle(fontSize: 11, color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _snapToGrid,
                                    activeThumbColor: GrimoireTheme.accentEmerald,
                                    onChanged: (val) => setState(() => _snapToGrid = val),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Corner Smoothing Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'SUAVIZADO DE VÉRTICES (CURVATURA):',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_borderRadius.toStringAsFixed(1)} px',
                              style: const TextStyle(fontSize: 10, color: GrimoireTheme.accentAmber, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Slider(
                          value: _borderRadius.clamp(0.0, 48.0),
                          min: 0.0,
                          max: 48.0,
                          activeColor: GrimoireTheme.accentAmber,
                          onChanged: (val) {
                            setState(() => _borderRadius = val);
                            _notifyLiveChange();
                          },
                        ),
                        Text(
                          'Nodos activos: ${_points.length} vértices • Clic derecho sobre un nodo para eliminarlo.',
                          style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(ref.tr('apply_custom_shape'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        CustomShapeBuilderResult(
                          shapePreset: ShapePreset.custom,
                          customPoints: List<Offset>.from(_points),
                          borderRadius: _borderRadius,
                          closeCustomPath: _closePath,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0.0) return (p - a).distance;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lenSq).clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - proj).distance;
  }
}

class _NodeEditorCanvasPainter extends CustomPainter {
  final List<Offset> points;
  final double borderRadius;
  final bool closePath;
  final bool mirrorHorizontal;
  final Color fillColor;
  final Gradient? fillGradient;
  final Color borderColor;
  final double borderWidth;

  const _NodeEditorCanvasPainter({
    required this.points,
    required this.borderRadius,
    required this.closePath,
    required this.mirrorHorizontal,
    required this.fillColor,
    this.fillGradient,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle coordinate grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2337)
      ..strokeWidth = 0.8;

    for (int i = 0; i <= 10; i++) {
      final x = size.width * (i / 10.0);
      final y = size.height * (i / 10.0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Draw symmetry center line if enabled
    if (mirrorHorizontal) {
      final symPaint = Paint()
        ..color = GrimoireTheme.accentPurple.withValues(alpha: 0.6)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), symPaint);
    }

    // 3. Draw custom shape path
    final path = ShapePathBuilder.buildPath(
      size: size,
      preset: ShapePreset.custom,
      borderRadius: borderRadius,
      customPoints: points,
      closePath: closePath,
    );

    final fillPaint = Paint()..style = PaintingStyle.fill;
    if (fillGradient != null) {
      fillPaint.shader = fillGradient!.createShader(Offset.zero & size);
    } else {
      fillPaint.color = fillColor.a > 0 ? fillColor : GrimoireTheme.accentPurple.withValues(alpha: 0.25);
    }
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = borderColor.a > 0 ? borderColor : GrimoireTheme.accentAmber
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // 4. Draw dashed/wireframe polygon edges connecting raw vertices
    if (points.length >= 2) {
      final wirePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 1.0;
      final wirePath = Path();
      wirePath.moveTo(points.first.dx * size.width, points.first.dy * size.height);
      for (int i = 1; i < points.length; i++) {
        wirePath.lineTo(points[i].dx * size.width, points[i].dy * size.height);
      }
      if (closePath) wirePath.close();
      canvas.drawPath(wirePath, wirePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NodeEditorCanvasPainter oldDelegate) => true;
}
