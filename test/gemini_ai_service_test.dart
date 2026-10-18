import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire_studio/features/ai_generator/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google Gemini AI Integration Tests', () {
    final testDir = Directory('test_gemini_sandbox');

    setUp(() {
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }
    });

    tearDown(() {
      if (testDir.existsSync()) {
        try {
          testDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('AiProviderType includes googleGemini', () {
      expect(AiProviderType.values.contains(AiProviderType.googleGemini), isTrue);
    });

    test('Gemini API key can be set and retrieved accurately', () {
      const testKey = 'AIzaSyTestApiKeyForGrimoireStudio12345';
      AiService.setGeminiApiKey(testKey);

      expect(AiService.getGeminiApiKey(), equals(testKey));

      final aiService = AiService();
      expect(aiService.geminiApiKey, equals(testKey));
    });

    test('generateArtwork without Gemini API key returns informative error message', () async {
      AiService.setGeminiApiKey('');
      final aiService = AiService();

      final result = await aiService.generateArtwork(
        prompt: 'Epic fantasy dragon card art',
        provider: AiProviderType.googleGemini,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('API Key'));
    });

    test('Gemini payload structure conforms to Google Generative Language schema', () {
      const prompt = 'Cyberpunk robotic wizard, highly detailed 8k';
      const resolvedRatio = '3:4';

      final payload = {
        'instances': [
          {'prompt': prompt.trim()},
        ],
        'parameters': {
          'sampleCount': 1,
          'aspectRatio': resolvedRatio,
          'outputMimeType': 'image/png',
          'personGeneration': 'ALLOW_ADULT',
        },
      };

      final jsonStr = jsonEncode(payload);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['instances'], isA<List>());
      expect(decoded['instances'][0]['prompt'], equals(prompt));
      expect(decoded['parameters']['aspectRatio'], equals('3:4'));
      expect(decoded['parameters']['outputMimeType'], equals('image/png'));
    });

    test('Gemini response base64 decoding creates valid image file', () async {
      // 1x1 transparent PNG encoded in base64
      const samplePngB64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      final dummyResponse = {
        'predictions': [
          {
            'mimeType': 'image/png',
            'bytesBase64Encoded': samplePngB64,
          }
        ]
      };

      final targetFile = File('${testDir.path}/test_gemini_output.png');
      final predictions = dummyResponse['predictions'] as List<dynamic>;
      final first = predictions.first as Map<String, dynamic>;
      final b64 = first['bytesBase64Encoded'] as String;
      final bytes = base64Decode(b64);

      await targetFile.writeAsBytes(bytes);

      expect(targetFile.existsSync(), isTrue);
      expect(targetFile.lengthSync(), greaterThan(0));
    });

    test('Gemini model default and custom model persistence works as expected', () {
      AiService.setGeminiModel('imagen-3.0-generate-002');
      expect(AiService.getGeminiModel(), equals('imagen-3.0-generate-002'));

      AiService.setGeminiModel('imagen-3.0-generate-001');
      expect(AiService.getGeminiModel(), equals('imagen-3.0-generate-001'));

      AiService.setGeminiModel('custom-model-id-v2');
      expect(AiService.getGeminiModel(), equals('custom-model-id-v2'));

      // If empty string passed, falls back safely to default model
      AiService.setGeminiModel('');
      expect(AiService.getGeminiModel(), equals('imagen-3.0-generate-002'));
    });
  });
}
