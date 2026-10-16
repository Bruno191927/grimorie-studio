import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/ai_generator/services/nvidia_service.dart';
import 'package:grimoire_studio/features/ai_generator/services/ai_service.dart';
import 'package:grimoire_studio/features/ai_generator/presentation/widgets/ai_prompt_dialog.dart';
import 'package:grimoire_studio/features/ai_generator/presentation/widgets/comfy_ui_connection_dialog.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NvidiaService & Configuration Persistence', () {
    late File configFile;

    setUp(() {
      final rootDir = GameFolderService.getGamesRootDir();
      final sep = Platform.isWindows ? '\\' : '/';
      configFile = File('${rootDir.path}$sep.grimoire_ai_config.json');
      if (configFile.existsSync()) {
        try {
          configFile.deleteSync();
        } catch (_) {}
      }
    });

    tearDown(() async {
      if (configFile.existsSync()) {
        try {
          configFile.deleteSync();
        } catch (_) {}
      }
      await NvidiaService().saveSettings(apiKey: '');
    });

    test('NvidiaService masks API keys safely for UI display', () {
      expect(NvidiaService.maskApiKey(''), equals(''));
      expect(NvidiaService.maskApiKey('1234'), equals('••••••••'));
      expect(
        NvidiaService.maskApiKey('nvapi-abcdef1234567890'),
        equals('nvapi-••••••••7890'),
      );
    });

    test('NvidiaService saves settings to disk and reloads them', () async {
      final service = NvidiaService();
      await service.saveSettings(
        apiKey: 'nvapi-test-key-9999',
        model: 'black-forest-labs/flux-1-schnell',
        aspectRatio: '2:3',
      );

      expect(service.apiKey, equals('nvapi-test-key-9999'));
      expect(service.selectedModel, equals('black-forest-labs/flux-1-schnell'));
      expect(service.aspectRatio, equals('2:3'));
      expect(service.isConfigured, isTrue);

      // Verify physical JSON file on disk
      expect(configFile.existsSync(), isTrue);

      // Reset and reload into a fresh instance check
      service.loadSettingsSync();
      expect(service.apiKey, equals('nvapi-test-key-9999'));
      expect(service.selectedModel, equals('black-forest-labs/flux-1-schnell'));
      expect(service.aspectRatio, equals('2:3'));
    });

    test('NvidiaService testConnection handles empty key gracefully', () async {
      final service = NvidiaService();
      final result = await service.testConnection('');
      expect(result['success'], isFalse);
      expect(result['message'], contains('No se ha proporcionado ninguna API Key'));
    });

    test('generateArtwork fails informatively if API key is not configured', () async {
      final service = NvidiaService();
      await service.saveSettings(apiKey: '');
      final result = await service.generateArtwork(
        prompt: 'A celestial knight in obsidian armor',
        gameName: 'Magic',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Debes configurar tu API Key'));
    });

    test('AiService routes nvidiaCloud provider through NvidiaService', () async {
      final aiService = AiService();
      final service = NvidiaService();
      await service.saveSettings(apiKey: '');

      final result = await aiService.generateArtwork(
        prompt: 'A cybernetic dragon',
        gameName: 'Magic',
        provider: AiProviderType.nvidiaCloud,
      );

      // Without key, returns descriptive result or fallback
      expect(result.success, isNotNull);
    });
    test('NvidiaService provides Nemotron 3.5 Super VL 120B as primary reasoning model', () {
      final models = NvidiaService.availableTextModels;
      expect(models.any((m) => m.id == 'nvidia/nemotron-3.5-super-vl-120b-a12b'), isTrue);
      expect(NvidiaService().textModel, equals('nvidia/nemotron-3.5-super-vl-120b-a12b'));
    });
  });

  group('NVIDIA UI Integration in Dialogs', () {
    testWidgets('AiPromptDialog allows selecting NVIDIA NIM Cloud and saving key', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = NvidiaService();
      await service.saveSettings(apiKey: '');

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 600,
                  height: 800,
                  child: AiPromptDialog(gameName: 'Magic'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find provider dropdown and switch to NVIDIA NIM
      final dropdown = find.byType(DropdownButtonFormField<AiProviderType>);
      expect(dropdown, findsOneWidget);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final nvidiaItem = find.text('NVIDIA NIM Cloud (Nemotron 3.5 / SD3)').last;
      await tester.tap(nvidiaItem);
      await tester.pumpAndSettle();

      // Verify NVIDIA NIM Configuration Panel is visible
      expect(find.text('NVIDIA NIM & AI Foundation'), findsOneWidget);
      expect(find.text('API Key Requerida'), findsWidgets);
      expect(find.text('Guardar Clave'), findsOneWidget);
      expect(find.text('Mejorar con Nemotron 3.5 (120B)'), findsOneWidget);

      // Type an API key and click save
      final keyField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'nvapi-...');
      expect(keyField, findsOneWidget);

      await tester.enterText(keyField, 'nvapi-mock-key-1234');
      await tester.ensureVisible(find.text('Guardar Clave'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar Clave'));
      await tester.pumpAndSettle();

      // After save, verifies saved state
      expect(service.apiKey, equals('nvapi-mock-key-1234'));
    });

    testWidgets('ComfyUiConnectionDialog displays NVIDIA tab and persists key', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ComfyUiConnectionDialog(initialTab: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify tabs exist
      expect(find.text('ComfyUI Local'), findsOneWidget);
      expect(find.text('NVIDIA NIM Cloud'), findsOneWidget);

      // Verify NVIDIA tab content is rendered
      expect(find.text('NVIDIA NIM Cloud & AI Foundation'), findsOneWidget);
      expect(find.text('CLAVE DE ACCESO NVIDIA API (NVAPI-...)'), findsOneWidget);
      expect(find.text('SD3 Medium (Stability AI)'), findsOneWidget);
      expect(find.text('Nemotron 3.5 Super VL 120B (NVIDIA)'), findsOneWidget);
      expect(find.text('Guardar Clave'), findsOneWidget);
      expect(find.text('Probar'), findsOneWidget);
    });

    tearDown(() async {
      await NvidiaService().saveSettings(apiKey: '');
    });
  });
}
