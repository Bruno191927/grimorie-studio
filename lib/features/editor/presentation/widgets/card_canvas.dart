import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/layer_item.dart';
import '../../services/game_folder_service.dart';
import '../providers/editor_provider.dart';
import '../../../../core/utils/template_parser.dart';
import '../../../../core/utils/expression_evaluator.dart';
import '../../../../core/theme/grimoire_theme.dart';

class CardCanvas extends ConsumerStatefulWidget {
  final GlobalKey repaintBoundaryKey;

  const CardCanvas({
    super.key,
    required this.repaintBoundaryKey,
  });

  @override
  ConsumerState<CardCanvas> createState() => _CardCanvasState();
}

class _CardCanvasState extends ConsumerState<CardCanvas> {
  // Snapping guide states
  double? _snapGuideX;
  double? _snapGuideY;

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final project = editorState.project;
    final template = project.activeTemplate;
    final activeRow = project.activeRow;
    final selectedId = editorState.selectedLayerId;

    // Card dimensions in canvas coordinates
    final cardWidth = project.widthMm * 4.0; // ~254 px
    final cardHeight = project.heightMm * 4.0; // ~355.6 px

    return Center(
      child: Transform.scale(
        scale: editorState.zoom,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(template.cornerRadius + 2),
            boxShadow: [
              BoxShadow(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.18),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: RepaintBoundary(
            key: widget.repaintBoundaryKey,
            child: Container(
              width: cardWidth,
              height: cardHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: template.getBackgroundColor(editorState.currentSide),
                borderRadius: BorderRadius.circular(template.cornerRadius),
                border: Border.all(
                  color: GrimoireTheme.borderStrong,
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // Optional Card Background Grid
                  if (editorState.showGrid)
                    CustomPaint(
                      size: Size(cardWidth, cardHeight),
                      painter: _CanvasGridPainter(),
                    ),

                  // Render Layers in Order for active side
                  for (final layer in template.getLayers(editorState.currentSide))
                    if (layer.isVisible)
                      _buildLayerWidget(
                        context,
                        layer,
                        activeRow,
                        isSelected: layer.id == selectedId,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                      ),

                  // Visual Snapping Guidelines
                  if (_snapGuideX != null)
                    Positioned(
                      left: _snapGuideX!,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: GrimoireTheme.accentPink,
                      ),
                    ),
                  if (_snapGuideY != null)
                    Positioned(
                      top: _snapGuideY!,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: GrimoireTheme.accentPink,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayerWidget(
    BuildContext context,
    LayerItem layer,
    Map<String, dynamic> activeRow, {
    required bool isSelected,
    required double cardWidth,
    required double cardHeight,
  }) {
    // Evaluate Smart Token conditional rule (if any)
    bool isVisibleByRule = true;
    Color shapeColor = layer.shapeColor;
    Color borderColor = layer.borderColor;

    if (layer.conditionalRules.containsKey('condition')) {
      final condition = layer.conditionalRules['condition'] as String;
      final passes = ExpressionEvaluator.evaluate(condition, activeRow);
      if (!passes) {
        if (layer.conditionalRules['action'] == 'hide') {
          isVisibleByRule = false;
        }
      } else {
        if (layer.conditionalRules.containsKey('accentColor')) {
          borderColor = Color(layer.conditionalRules['accentColor'] as int);
        }
      }
    }

    if (!isVisibleByRule) return const SizedBox.shrink();

    return Positioned(
      left: layer.x,
      top: layer.y,
      child: GestureDetector(
        onTap: () {
          ref.read(editorProvider.notifier).selectLayer(layer.id);
        },
        onPanUpdate: layer.isLocked
            ? null
            : (details) {
                double newX = layer.x + details.delta.dx;
                double newY = layer.y + details.delta.dy;

                // Snapping Logic
                double? snapX;
                double? snapY;

                // Snap to card horizontal center
                final centerX = (cardWidth - layer.width) / 2;
                if ((newX - centerX).abs() < 6) {
                  newX = centerX;
                  snapX = cardWidth / 2;
                }

                // Snap to card vertical center
                final centerY = (cardHeight - layer.height) / 2;
                if ((newY - centerY).abs() < 6) {
                  newY = centerY;
                  snapY = cardHeight / 2;
                }

                setState(() {
                  _snapGuideX = snapX;
                  _snapGuideY = snapY;
                });

                ref.read(editorProvider.notifier).updateLayerPosition(layer.id, newX, newY);
              },
        onPanEnd: (_) {
          setState(() {
            _snapGuideX = null;
            _snapGuideY = null;
          });
        },
        child: Container(
          width: layer.width,
          height: layer.height,
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: GrimoireTheme.accentPurple, width: 2)
                : null,
            borderRadius: BorderRadius.circular(layer.borderRadius + (isSelected ? 2 : 0)),
          ),
          child: Opacity(
            opacity: layer.opacity,
            child: _buildLayerContent(layer, activeRow, shapeColor, borderColor),
          ),
        ),
      ),
    );
  }

  Widget _buildLayerContent(
    LayerItem layer,
    Map<String, dynamic> activeRow,
    Color shapeColor,
    Color borderColor,
  ) {
    switch (layer.type) {
      case LayerType.text:
        final rawText = layer.bindingKey.isNotEmpty && activeRow.containsKey(layer.bindingKey)
            ? activeRow[layer.bindingKey].toString()
            : layer.text;
        final displayText = TemplateParser.parse(rawText, activeRow);

        return Align(
          alignment: _getAlignment(layer.textAlign),
          child: Text(
            displayText,
            textAlign: layer.textAlign,
            style: TextStyle(
              fontSize: layer.fontSize,
              fontWeight: layer.isBold ? FontWeight.bold : FontWeight.normal,
              color: layer.fontColor,
              letterSpacing: 0.2,
            ),
          ),
        );

      case LayerType.shape:
        Color effectiveColor = shapeColor;
        if (activeRow.containsKey('art_color') && layer.bindingKey == 'art_url') {
          effectiveColor = Color(activeRow['art_color'] as int);
        }

        Widget? content;
        if (layer.bindingKey == 'art_url') {
          final game = (activeRow['game'] ?? '').toString();
          final artFile = GameFolderService.resolveCardImageFile(game, activeRow['art_url']?.toString());
          if (artFile != null) {
            content = ClipRRect(
              borderRadius: BorderRadius.circular(layer.borderRadius),
              child: Image.file(
                artFile,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    activeRow['icon']?.toString() ?? '✨',
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
            );
          } else {
            content = Center(
              child: Text(
                activeRow['icon']?.toString() ?? '✨',
                style: const TextStyle(fontSize: 48),
              ),
            );
          }
        }

        return Container(
          width: layer.width,
          height: layer.height,
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(layer.borderRadius),
            border: layer.borderWidth > 0
                ? Border.all(color: borderColor, width: layer.borderWidth)
                : null,
          ),
          child: content,
        );

      case LayerType.image:
        if (layer.imagePath != null && File(layer.imagePath!).existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(layer.borderRadius),
            child: Image.file(
              File(layer.imagePath!),
              fit: BoxFit.cover,
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2337),
            borderRadius: BorderRadius.circular(layer.borderRadius),
          ),
          child: const Center(
            child: Icon(Icons.image_outlined, color: GrimoireTheme.textMuted),
          ),
        );
    }
  }

  Alignment _getAlignment(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }
}

class _CanvasGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF23283E).withValues(alpha: 0.35)
      ..strokeWidth = 0.5;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
