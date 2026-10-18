import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/card_template.dart';
import '../../models/layer_item.dart';
import '../../services/game_folder_service.dart';
import '../../utils/shape_path_builder.dart';
import '../../../../core/utils/template_parser.dart';
import '../../../../core/utils/expression_evaluator.dart';
import '../../../../core/utils/rich_text_token_parser.dart';
import '../../../../core/theme/grimoire_theme.dart';

/// Pure, standalone renderer for any [CardTemplate] + [cardData] row.
/// Used by the interactive Canvas, off-screen 300 DPI Batch Exporter, and the Playtest Mat.
class CardRendererWidget extends StatelessWidget {
  final CardTemplate template;
  final Map<String, dynamic> cardData;
  final CardSide side;
  final double cardWidth;
  final double cardHeight;
  final bool showGrid;
  final String? hiddenLayerId;

  const CardRendererWidget({
    super.key,
    required this.template,
    required this.cardData,
    this.side = CardSide.front,
    this.cardWidth = 254.0,
    this.cardHeight = 355.6,
    this.showGrid = false,
    this.hiddenLayerId,
  });

  @override
  Widget build(BuildContext context) {
    final layers = template.getLayers(side);

    return Container(
      width: cardWidth,
      height: cardHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: template.getBackgroundColor(side),
        borderRadius: BorderRadius.circular(template.cornerRadius),
      ),
      child: Stack(
        children: [
          if (showGrid)
            CustomPaint(
              size: Size(cardWidth, cardHeight),
              painter: _StaticGridPainter(),
            ),
          for (final layer in layers)
            if (layer.isVisible)
              _buildLayer(context, layer),
        ],
      ),
    );
  }

  Widget _buildLayer(BuildContext context, LayerItem layer) {
    bool isVisibleByRule = true;
    Color shapeColor = layer.shapeColor;
    Color borderColor = layer.borderColor;

    if (layer.conditionalRules.containsKey('condition')) {
      final condition = layer.conditionalRules['condition'] as String;
      final passes = ExpressionEvaluator.evaluate(condition, cardData);
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

    final isBackgroundType = layer.type == LayerType.background;
    final effectiveLeft = isBackgroundType ? 0.0 : layer.x;
    final effectiveTop = isBackgroundType ? 0.0 : layer.y;
    final effectiveWidth = isBackgroundType ? cardWidth : layer.width;
    final effectiveHeight = isBackgroundType ? cardHeight : layer.height;

    return Positioned(
      left: effectiveLeft,
      top: effectiveTop,
      width: effectiveWidth,
      height: effectiveHeight,
      child: Opacity(
        opacity: layer.opacity,
        child: buildLayerVisualContent(
          layer: layer,
          activeRow: cardData,
          shapeColor: shapeColor,
          borderColor: borderColor,
          effectiveWidth: effectiveWidth,
          effectiveHeight: effectiveHeight,
          isHiddenForInlineEdit: hiddenLayerId == layer.id,
        ),
      ),
    );
  }

  static Widget buildLayerVisualContent({
    required LayerItem layer,
    required Map<String, dynamic> activeRow,
    required Color shapeColor,
    required Color borderColor,
    required double effectiveWidth,
    required double effectiveHeight,
    bool isHiddenForInlineEdit = false,
  }) {
    switch (layer.type) {
      case LayerType.background:
        File? bgImgFile;
        if (layer.fillMode == LayerFillMode.image) {
          if (layer.imagePath != null && File(layer.imagePath!).existsSync()) {
            bgImgFile = File(layer.imagePath!);
          } else {
            final game = (activeRow['game'] ?? '').toString();
            final key = layer.bindingKey.isNotEmpty ? layer.bindingKey : 'art_url';
            final bindingVal = activeRow[key]?.toString();
            bgImgFile = GameFolderService.resolveCardImageFile(game, bindingVal);
          }
        }

        final Gradient? bgGradient = layer.fillMode == LayerFillMode.gradient
            ? ShapePathBuilder.buildGradient(
                type: layer.gradientType,
                startColor: shapeColor,
                endColor: layer.gradientEndColor,
                middleColor: layer.gradientMiddleColor,
                useThreeStops: layer.useThreeStopGradient,
                angleDegrees: layer.gradientAngle,
              )
            : null;

        return Container(
          width: effectiveWidth,
          height: effectiveHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: layer.fillMode == LayerFillMode.gradient ? null : shapeColor,
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(layer.borderRadius),
            border: layer.borderWidth > 0
                ? Border.all(color: borderColor, width: layer.borderWidth)
                : null,
          ),
          child: layer.fillMode == LayerFillMode.image
              ? (bgImgFile != null && bgImgFile.existsSync()
                  ? Image.file(
                      bgImgFile,
                      fit: layer.imageFit,
                      width: effectiveWidth,
                      height: effectiveHeight,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [shapeColor, layer.gradientEndColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.wallpaper_outlined,
                          color: Colors.white24,
                          size: 48,
                        ),
                      ),
                    ))
              : null,
        );

      case LayerType.text:
        if (isHiddenForInlineEdit) {
          return const SizedBox.expand();
        }

        String rawText = layer.bindingKey.isNotEmpty && activeRow.containsKey(layer.bindingKey)
            ? activeRow[layer.bindingKey].toString()
            : layer.text;

        final layerNameLower = layer.name.toLowerCase().trim();
        final rawTextLower = rawText.toLowerCase().trim();

        // Auto-detect title layers if bindingKey was omitted or placeholder was used
        if (layer.bindingKey.isEmpty || layer.bindingKey == 'card_name') {
          if (layerNameLower == 'titulo' ||
              layerNameLower == 'título' ||
              layerNameLower == 'title' ||
              layerNameLower == 'nombre' ||
              layerNameLower.contains('card_name') ||
              rawTextLower == 'título' ||
              rawTextLower == 'titulo' ||
              rawTextLower == 'title') {
            final cardName = (activeRow['card_name'] ?? '').toString().trim();
            if (cardName.isNotEmpty) {
              rawText = cardName;
            }
          }
        }

        // Auto-detect description / rules layers if bindingKey was omitted or placeholder was used
        if (layer.bindingKey.isEmpty || layer.bindingKey == 'rules_text' || layer.bindingKey == 'rules') {
          if (layerNameLower == 'descripcion' ||
              layerNameLower == 'descripción' ||
              layerNameLower == 'rules' ||
              layerNameLower == 'reglas' ||
              layerNameLower.contains('rules') ||
              rawTextLower.contains('descripcion de la carta') ||
              rawTextLower.contains('descripción de la carta')) {
            final rulesText = (activeRow['rules_text'] ?? activeRow['rules'] ?? '').toString().trim();
            if (rulesText.isNotEmpty) {
              rawText = rulesText;
            }
          }
        }

        final displayText = TemplateParser.parse(rawText, activeRow);

        return SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: Align(
            alignment: _getAlignment(layer.textAlign),
            child: RichTextTokenParser.buildAutoFitCardText(
              text: displayText,
              maxWidth: effectiveWidth,
              maxHeight: effectiveHeight,
              fontFamily: layer.fontFamily,
              baseFontSize: layer.fontSize,
              isBold: layer.isBold,
              isItalic: layer.isItalic,
              fontColor: layer.fontColor,
              letterSpacing: layer.letterSpacing,
              textAlign: layer.textAlign,
              enableAutoFit: true,
              enableInlineSymbols: true,
            ),
          ),
        );

      case LayerType.shape:
        Color effectiveColor = shapeColor;
        if (activeRow.containsKey('art_color') && layer.bindingKey == 'art_color') {
          effectiveColor = Color(activeRow['art_color'] as int);
        }

        final isBgShape = layer.name.toLowerCase().contains('background') && layer.isLocked;
        final effectiveBorderWidth = (isBgShape && (layer.borderWidth <= 2.0 || layer.borderColor == const Color(0xFF23283E)))
            ? 0.0
            : layer.borderWidth;

        final Gradient? shapeGradient = layer.fillMode == LayerFillMode.gradient
            ? ShapePathBuilder.buildGradient(
                type: layer.gradientType,
                startColor: effectiveColor,
                endColor: layer.gradientEndColor,
                middleColor: layer.gradientMiddleColor,
                useThreeStops: layer.useThreeStopGradient,
                angleDegrees: layer.gradientAngle,
              )
            : null;

        return SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: CustomPaint(
            painter: LayerShapePainter(
              preset: layer.shapePreset,
              borderRadius: layer.borderRadius,
              customPoints: layer.customPoints,
              closePath: layer.closeCustomPath,
              fillColor: effectiveColor,
              fillGradient: shapeGradient,
              borderColor: borderColor,
              borderWidth: effectiveBorderWidth,
            ),
          ),
        );

      case LayerType.image:
        File? imgFile;
        if (layer.imagePath != null && File(layer.imagePath!).existsSync()) {
          imgFile = File(layer.imagePath!);
        } else {
          final game = (activeRow['game'] ?? '').toString();
          final key = layer.bindingKey.isNotEmpty ? layer.bindingKey : 'art_url';
          final bindingVal = activeRow[key]?.toString();
          imgFile = GameFolderService.resolveCardImageFile(game, bindingVal);
        }

        if (imgFile != null && imgFile.existsSync()) {
          Widget imageWidget = ClipRRect(
            borderRadius: BorderRadius.circular(layer.borderRadius),
            child: Image.file(
              imgFile,
              fit: layer.imageFit,
              width: effectiveWidth,
              height: effectiveHeight,
            ),
          );

          if (layer.borderWidth > 0 && layer.borderColor != Colors.transparent && layer.borderColor.a > 0) {
            imageWidget = Container(
              width: effectiveWidth,
              height: effectiveHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(layer.borderRadius),
                border: Border.all(
                  color: layer.borderColor,
                  width: layer.borderWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(layer.borderRadius > layer.borderWidth ? layer.borderRadius - layer.borderWidth : 0),
                child: Image.file(
                  imgFile,
                  fit: layer.imageFit,
                  width: effectiveWidth,
                  height: effectiveHeight,
                ),
              ),
            );
          }

          return SizedBox(
            width: effectiveWidth,
            height: effectiveHeight,
            child: imageWidget,
          );
        }
        return Container(
          width: effectiveWidth,
          height: effectiveHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2337),
            borderRadius: BorderRadius.circular(layer.borderRadius),
            border: layer.borderWidth > 0
                ? Border.all(color: borderColor, width: layer.borderWidth)
                : null,
          ),
          child: const Center(
            child: Icon(Icons.image_outlined, color: GrimoireTheme.textMuted, size: 36),
          ),
        );
    }
  }

  static Alignment _getAlignment(TextAlign align) {
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

class _StaticGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    const step = 16.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
