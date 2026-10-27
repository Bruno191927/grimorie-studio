import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire_studio/core/utils/rich_text_token_parser.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/export/presentation/dialogs/export_options_dialog.dart';
import 'package:grimoire_studio/features/export/services/export_service.dart';

void main() {
  group('Premium Visuals & Inline Symbols Tests', () {
    test('Resolves English and Spanish inline badge tokens correctly', () {
      expect(RichTextTokenParser.resolveToken('T')?.label, '⟳');
      expect(RichTextTokenParser.resolveToken('GIRAR')?.label, '⟳');
      expect(RichTextTokenParser.resolveToken('Q')?.label, '⟲');
      expect(RichTextTokenParser.resolveToken('DESGIRAR')?.label, '⟲');
      expect(RichTextTokenParser.resolveToken('FIRE')?.label, '🔥');
      expect(RichTextTokenParser.resolveToken('FUEGO')?.label, '🔥');
      expect(RichTextTokenParser.resolveToken('WATER')?.label, '💧');
      expect(RichTextTokenParser.resolveToken('AGUA')?.label, '💧');
      expect(RichTextTokenParser.resolveToken('SKULL')?.label, '💀');
      expect(RichTextTokenParser.resolveToken('CALAVERA')?.label, '💀');
      expect(RichTextTokenParser.resolveToken('SWORD')?.label, '⚔️');
      expect(RichTextTokenParser.resolveToken('ESPADA')?.label, '⚔️');
      expect(RichTextTokenParser.resolveToken('SHIELD')?.label, '🛡️');
      expect(RichTextTokenParser.resolveToken('ESCUDO')?.label, '🛡️');
      expect(RichTextTokenParser.resolveToken('HEART')?.label, '❤️');
      expect(RichTextTokenParser.resolveToken('VIDA')?.label, '❤️');
      expect(RichTextTokenParser.resolveToken('ENERGY')?.label, '⚡');
      expect(RichTextTokenParser.resolveToken('ACCION')?.label, '⚡');
      expect(RichTextTokenParser.resolveToken('3')?.label, '3');
      expect(RichTextTokenParser.resolveToken('X')?.label, 'X');
    });

    test('Detects presence of inline tokens in card rules text', () {
      expect(RichTextTokenParser.hasInlineTokens('{T}: Añade {1} a tu reserva de maná.'), isTrue);
      expect(RichTextTokenParser.hasInlineTokens('Gasta {fuego} para causar 3 puntos de daño.'), isTrue);
      expect(RichTextTokenParser.hasInlineTokens('Texto simple sin símbolos.'), isFalse);
    });

    test('LayerItem preserves textStroke and foilFinish in copyWith and JSON', () {
      const layer = LayerItem(
        id: 'layer_title',
        name: 'Título TCG',
        type: LayerType.text,
        text: 'Dragón Ancestral',
        textStrokeWidth: 2.5,
        textStrokeColor: Colors.black,
        foilFinish: 'gold',
      );

      expect(layer.textStrokeWidth, 2.5);
      expect(layer.textStrokeColor, Colors.black);
      expect(layer.foilFinish, 'gold');

      final json = layer.toJson();
      final restored = LayerItem.fromJson(json);

      expect(restored.textStrokeWidth, 2.5);
      expect(restored.textStrokeColor, Colors.black);
      expect(restored.foilFinish, 'gold');

      final modified = layer.copyWith(textStrokeWidth: 3.0, foilFinish: 'cosmic');
      expect(modified.textStrokeWidth, 3.0);
      expect(modified.foilFinish, 'cosmic');
    });
  });

  group('Manufacturer & Digital Connectors Tests', () {
    test('ExportFormat includes theGameCrafter, makePlayingCards, screentopGg', () {
      expect(ExportFormat.values.contains(ExportFormat.theGameCrafter), isTrue);
      expect(ExportFormat.values.contains(ExportFormat.makePlayingCards), isTrue);
      expect(ExportFormat.values.contains(ExportFormat.screentopGg), isTrue);
    });
  });
}
