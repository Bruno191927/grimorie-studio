import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:grimoire_studio/features/editor/services/background_removal_service.dart';

void main() {
  group('BackgroundRemovalService Tests', () {
    test('detectBackgroundColor correctly identifies white background', () {
      // Create a 10x10 image with white border and black center
      final image = img.Image(width: 10, height: 10, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));

      final detected = BackgroundRemovalService.detectBackgroundColor(image);
      expect((detected.r * 255).round(), equals(255));
      expect((detected.g * 255).round(), equals(255));
      expect((detected.b * 255).round(), equals(255));
    });

    test('Contiguous removal clears outer background but preserves inner subject matching color', () {
      // 10x10 image:
      // Outer is white (255, 255, 255)
      // Character is a black box outline from (2,2) to (7,7)
      // Inside character (4,4) is white (255, 255, 255) - e.g. white eye/shirt
      final image = img.Image(width: 10, height: 10, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));

      // Draw black character outline (0, 0, 0)
      for (int x = 2; x <= 7; x++) {
        image.setPixelRgba(x, 2, 0, 0, 0, 255);
        image.setPixelRgba(x, 7, 0, 0, 0, 255);
      }
      for (int y = 2; y <= 7; y++) {
        image.setPixelRgba(2, y, 0, 0, 0, 255);
        image.setPixelRgba(7, y, 0, 0, 0, 255);
      }
      // Inside pixel at (4,4) is white (255, 255, 255, 255)
      image.setPixelRgba(4, 4, 255, 255, 255, 255);

      final processed = BackgroundRemovalService.removeBackground(
        image,
        options: const BackgroundRemovalOptions(
          keyColor: Color(0xFFFFFFFF),
          tolerance: 0.1,
          feather: 0.0,
          contiguousOnly: true,
        ),
      );

      // Outer background at (0, 0) should be transparent (alpha = 0)
      final outerPixel = processed.getPixel(0, 0);
      expect(outerPixel.a.toInt(), equals(0));

      // Subject border at (2, 2) should remain opaque black
      final borderPixel = processed.getPixel(2, 2);
      expect(borderPixel.a.toInt(), equals(255));
      expect(borderPixel.r.toInt(), equals(0));

      // Inner white at (4, 4) MUST remain opaque because contiguousOnly = true protects it!
      final innerPixel = processed.getPixel(4, 4);
      expect(innerPixel.a.toInt(), equals(255));
      expect(innerPixel.r.toInt(), equals(255));
    });

    test('removeBackgroundFromBytes produces valid transparent PNG bytes', () {
      final image = img.Image(width: 20, height: 20, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(0, 255, 0, 255)); // Green screen
      // Add red dot in middle
      image.setPixelRgba(10, 10, 255, 0, 0, 255);

      final pngBytes = img.encodePng(image);
      final resultBytes = BackgroundRemovalService.removeBackgroundFromBytes(
        pngBytes,
        options: const BackgroundRemovalOptions(
          keyColor: Color(0xFF00FF00), // Chroma green
          tolerance: 0.2,
          feather: 0.0,
          contiguousOnly: false,
        ),
      );

      expect(resultBytes, isNotEmpty);
      final decodedResult = img.decodeImage(resultBytes);
      expect(decodedResult, isNotNull);
      expect(decodedResult!.width, equals(20));

      // Green pixel should be transparent
      expect(decodedResult.getPixel(0, 0).a.toInt(), equals(0));
      // Red dot should be opaque
      expect(decodedResult.getPixel(10, 10).a.toInt(), equals(255));
      expect(decodedResult.getPixel(10, 10).r.toInt(), equals(255));
    });

    test('removeBackgroundFromFile creates sibling file with _nobg suffix', () async {
      final tempDir = Directory.systemTemp.createTempSync('grimoire_nobg_test_');
      try {
        final testFile = File('${tempDir.path}/sample_card.png');
        final image = img.Image(width: 16, height: 16, numChannels: 4);
        img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
        await testFile.writeAsBytes(img.encodePng(image));

        final resultFile = await BackgroundRemovalService.removeBackgroundFromFile(testFile);
        expect(resultFile.existsSync(), isTrue);
        expect(resultFile.path.endsWith('sample_card_nobg.png'), isTrue);

        final bytes = await resultFile.readAsBytes();
        final decoded = img.decodeImage(bytes);
        expect(decoded, isNotNull);
        expect(decoded!.getPixel(0, 0).a.toInt(), equals(0));
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
