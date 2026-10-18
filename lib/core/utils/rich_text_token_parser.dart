import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/grimoire_theme.dart';
import '../widgets/grimoire_font_picker.dart';

class InlineBadgeSpec {
  final String label;
  final String? iconText;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const InlineBadgeSpec({
    required this.label,
    this.iconText,
    required this.bgColor,
    required this.borderColor,
    this.textColor = Colors.white,
  });
}

class RichTextTokenParser {
  static final RegExp _tokenRegex = RegExp(r'\{([A-Za-z0-9\+\-\/]+)\}');

  static InlineBadgeSpec? resolveToken(String tokenRaw) {
    final code = tokenRaw.trim().toUpperCase();
    switch (code) {
      case 'T':
      case 'TAP':
        return const InlineBadgeSpec(
          label: '⟳',
          bgColor: Color(0xFF334155),
          borderColor: Color(0xFF94A3B8),
          textColor: Colors.white,
        );
      case 'Q':
      case 'UNTAP':
        return const InlineBadgeSpec(
          label: '⟲',
          bgColor: Color(0xFF1E293B),
          borderColor: Color(0xFF38BDF8),
          textColor: Color(0xFF38BDF8),
        );
      case 'R':
      case 'FIRE':
        return const InlineBadgeSpec(
          label: '🔥',
          bgColor: Color(0xFF991B1B),
          borderColor: Color(0xFFF87171),
        );
      case 'U':
      case 'WATER':
        return const InlineBadgeSpec(
          label: '💧',
          bgColor: Color(0xFF1E40AF),
          borderColor: Color(0xFF60A5FA),
        );
      case 'G':
      case 'NATURE':
        return const InlineBadgeSpec(
          label: '🌿',
          bgColor: Color(0xFF065F46),
          borderColor: Color(0xFF34D399),
        );
      case 'B':
      case 'DARK':
        return const InlineBadgeSpec(
          label: '💀',
          bgColor: Color(0xFF18181B),
          borderColor: Color(0xFFA855F7),
        );
      case 'W':
      case 'LIGHT':
        return const InlineBadgeSpec(
          label: '☀️',
          bgColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFF59E0B),
          textColor: Color(0xFF78350F),
        );
      case 'C':
      case 'VOID':
        return const InlineBadgeSpec(
          label: '◇',
          bgColor: Color(0xFF334155),
          borderColor: Color(0xFFCBD5E1),
        );
      case 'ATK':
      case 'SWORD':
        return const InlineBadgeSpec(
          label: '⚔️',
          bgColor: Color(0xFF7C2D12),
          borderColor: Color(0xFFFB923C),
        );
      case 'DEF':
      case 'SHIELD':
        return const InlineBadgeSpec(
          label: '🛡️',
          bgColor: Color(0xFF1E3A8A),
          borderColor: Color(0xFF93C5FD),
        );
      case 'STAR':
      case 'MAGIC':
        return const InlineBadgeSpec(
          label: '✨',
          bgColor: Color(0xFF581C87),
          borderColor: Color(0xFFE879F9),
        );
      default:
        // Numeric or X/Y mana cost badges: {0}..{20}, {X}, {+1}
        if (RegExp(r'^[0-9XY\+\-]+$').hasMatch(code)) {
          return InlineBadgeSpec(
            label: code,
            bgColor: const Color(0xFF334155),
            borderColor: const Color(0xFF94A3B8),
            textColor: Colors.white,
          );
        }
        return null;
    }
  }

  /// Checks if the given text contains any inline `{TOKEN}` symbols
  static bool hasInlineTokens(String text) {
    if (!text.contains('{')) return false;
    for (final match in _tokenRegex.allMatches(text)) {
      final token = match.group(1);
      if (token != null && resolveToken(token) != null) {
        return true;
      }
    }
    return false;
  }

  /// Builds an auto-fitting text or rich-text widget that shrinks fontSize to fit within [maxWidth] x [maxHeight]
  static Widget buildAutoFitCardText({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required String fontFamily,
    required double baseFontSize,
    required bool isBold,
    required bool isItalic,
    required Color fontColor,
    required double letterSpacing,
    required TextAlign textAlign,
    bool enableAutoFit = true,
    bool enableInlineSymbols = true,
  }) {
    if (text.isEmpty) return const SizedBox.shrink();

    final effectiveFontSize = enableAutoFit
        ? _computeOptimalFontSize(
            text: text,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            fontFamily: fontFamily,
            baseFontSize: baseFontSize,
            isBold: isBold,
            isItalic: isItalic,
            letterSpacing: letterSpacing,
          )
        : baseFontSize;

    final baseStyle = GrimoireFontHelper.resolveTextStyle(
      fontFamily: fontFamily,
      fontSize: effectiveFontSize,
      isBold: isBold,
      isItalic: isItalic,
      color: fontColor,
      letterSpacing: letterSpacing,
    );

    if (!enableInlineSymbols || !hasInlineTokens(text)) {
      return Text(
        text,
        textAlign: textAlign,
        style: baseStyle,
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _tokenRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      final rawCode = match.group(1) ?? '';
      final badge = resolveToken(rawCode);

      if (badge != null) {
        final badgeSize = (effectiveFontSize * 1.32).clamp(11.0, 32.0);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: badge.bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: badge.borderColor, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  badge.label,
                  style: TextStyle(
                    fontSize: badgeSize * 0.58,
                    fontWeight: FontWeight.bold,
                    color: badge.textColor,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(
          text: match.group(0),
          style: baseStyle,
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
    );
  }

  static double _computeOptimalFontSize({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required String fontFamily,
    required double baseFontSize,
    required bool isBold,
    required bool isItalic,
    required double letterSpacing,
  }) {
    if (maxWidth <= 10 || maxHeight <= 10) return baseFontSize;

    // Strip {TOKEN} brackets to approximate layout width cleanly
    final cleanText = text.replaceAllMapped(_tokenRegex, (m) => ' ● ');
    double candidateSize = baseFontSize;
    final minFontSize = math.min(6.5, baseFontSize);

    while (candidateSize > minFontSize) {
      final style = GrimoireFontHelper.resolveTextStyle(
        fontFamily: fontFamily,
        fontSize: candidateSize,
        isBold: isBold,
        isItalic: isItalic,
        color: GrimoireTheme.textPrimary,
        letterSpacing: letterSpacing,
      );

      final tp = TextPainter(
        text: TextSpan(text: cleanText, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(12.0, maxWidth - 2));

      if (tp.height <= maxHeight && tp.width <= maxWidth) {
        break;
      }
      candidateSize -= 0.5;
    }

    return math.max(minFontSize, candidateSize);
  }
}
