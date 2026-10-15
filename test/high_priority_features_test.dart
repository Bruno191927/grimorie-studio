import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:archive/archive.dart';
import 'package:grimoire_studio/main.dart';
import 'package:grimoire_studio/features/editor/models/card_template.dart';
import 'package:grimoire_studio/features/editor/models/layer_item.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/export/services/export_service.dart';

/// Helper to generate a dummy 100x140 PNG image byte buffer for testing
Future<Uint8List> createTestPngBytes({Color color = const Color(0xFF7C3AED)}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = color;
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 100, 140), paint);
  final picture = recorder.endRecording();
  final img = await picture.toImage(100, 140);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Dual-Sided Card Architecture (Front & Back Faces)', () {
    test('CardTemplate handles front and back layers with JSON serialization', () {
      final frontLayer = LayerItem(
        id: 'front-1',
        name: 'Front Title',
        type: LayerType.text,
        text: 'Ethereal Dragon',
      );
      final backLayer = LayerItem(
        id: 'back-1',
        name: 'Back Medallion',
        type: LayerType.shape,
      );

      final template = CardTemplate(
        id: 'tpl-1',
        name: 'Dual Template',
        layers: [frontLayer],
        backLayers: [backLayer],
        backgroundColor: const Color(0xFF131622),
        backBackgroundColor: const Color(0xFF0C0E17),
      );

      expect(template.getLayers(CardSide.front).length, 1);
      expect(template.getLayers(CardSide.front).first.name, 'Front Title');

      expect(template.getLayers(CardSide.back).length, 1);
      expect(template.getLayers(CardSide.back).first.name, 'Back Medallion');

      expect(template.getBackgroundColor(CardSide.front), const Color(0xFF131622));
      expect(template.getBackgroundColor(CardSide.back), const Color(0xFF0C0E17));

      // Test JSON roundtrip
      final json = template.toJson();
      final reconstructed = CardTemplate.fromJson(json);

      expect(reconstructed.layers.length, 1);
      expect(reconstructed.backLayers.length, 1);
      expect(reconstructed.layers.first.name, 'Front Title');
      expect(reconstructed.backLayers.first.name, 'Back Medallion');
    });

    test('EditorNotifier switches sides and isolates layer operations', () {
      final notifier = EditorNotifier();
      expect(notifier.state.currentSide, CardSide.front);

      final initialFrontCount = notifier.state.project.activeTemplate.layers.length;
      final initialBackCount = notifier.state.project.activeTemplate.backLayers.length;

      // Switch to Back
      notifier.switchSide(CardSide.back);
      expect(notifier.state.currentSide, CardSide.back);

      // Add layer while on back side
      final newBackLayer = LayerItem(
        id: 'test-back-layer',
        name: 'Custom Rune Stamp',
        type: LayerType.shape,
      );
      notifier.addLayer(newBackLayer);

      // Verify back layers increased, but front layers remained unchanged
      expect(notifier.state.project.activeTemplate.backLayers.length, initialBackCount + 1);
      expect(notifier.state.project.activeTemplate.layers.length, initialFrontCount);

      // Toggle side back to Front
      notifier.toggleSide();
      expect(notifier.state.currentSide, CardSide.front);

      // Update background color on front
      notifier.updateBackgroundColor(const Color(0xFF223344));
      expect(notifier.state.project.activeTemplate.backgroundColor, const Color(0xFF223344));
      expect(notifier.state.project.activeTemplate.backBackgroundColor, const Color(0xFF0C0E17));
    });
  });

  group('2. Bleed & Guillotine Crop Marks Export', () {
    test('exportCardsToPdf generates PDF with 3mm bleed, crop marks, and duplex backs', () async {
      final frontBytes = await createTestPngBytes(color: const Color(0xFF7C3AED));
      final backBytes = await createTestPngBytes(color: const Color(0xFF0C0E17));

      final pdfFile = await ExportService.exportCardsToPdf(
        cardImages: [frontBytes, frontBytes],
        backImage: backBytes,
        fileName: 'test_duplex_bleed_deck',
        includeBleedAndCropMarks: true,
        includeBacks: true,
        outputDirectory: Directory.systemTemp,
      );

      expect(pdfFile.existsSync(), isTrue);
      final length = await pdfFile.length();
      expect(length, greaterThan(1000));

      // Clean up
      if (pdfFile.existsSync()) await pdfFile.delete();
    });

    test('exportCardsToPdf generates standard trim PDF without bleed', () async {
      final frontBytes = await createTestPngBytes();

      final pdfFile = await ExportService.exportCardsToPdf(
        cardImages: [frontBytes],
        fileName: 'test_standard_trim',
        includeBleedAndCropMarks: false,
        includeBacks: false,
        outputDirectory: Directory.systemTemp,
      );

      expect(pdfFile.existsSync(), isTrue);
      final length = await pdfFile.length();
      expect(length, greaterThan(500));

      // Clean up
      if (pdfFile.existsSync()) await pdfFile.delete();
    });
  });

  group('3. Tabletop Simulator (TTS) Deck Export', () {
    test('exportTabletopSimulatorDeck generates valid ZIP with sprite sheet and config', () async {
      final card1 = await createTestPngBytes(color: const Color(0xFF7C3AED));
      final card2 = await createTestPngBytes(color: const Color(0xFF0284C7));
      final back = await createTestPngBytes(color: const Color(0xFF1E1B4B));

      final zipFile = await ExportService.exportTabletopSimulatorDeck(
        cardImages: [card1, card2],
        backImage: back,
        deckName: 'Test_Fantasy_TTS',
        outputDirectory: Directory.systemTemp,
      );

      expect(zipFile.existsSync(), isTrue);
      final zipBytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // Verify files inside zip
      final fileNames = archive.map((f) => f.name).toList();
      expect(fileNames, contains('TTS_Deck_Front.png'));
      expect(fileNames, contains('TTS_Deck_Back_Sheet.png'));
      expect(fileNames, contains('TTS_Card_Back_Single.png'));
      expect(fileNames, contains('TTS_Deck_Config.txt'));

      // Verify TTS config contents
      final configFile = archive.firstWhere((f) => f.name == 'TTS_Deck_Config.txt');
      final configContent = String.fromCharCodes(configFile.content as List<int>);
      expect(configContent, contains('Tabletop Simulator (TTS) Custom Deck Configuration'));
      expect(configContent, contains('Total Cards: 2'));
      expect(configContent, contains('Grid Columns (Width): 2'));
      expect(configContent, contains('Grid Rows (Height): 1'));

      // Clean up
      if (zipFile.existsSync()) await zipFile.delete();
    });
  });

  group('4. UI Integration: Editor Face Switcher & Export Dialog', () {
    testWidgets('Editor subtoolbar allows flipping between Front and Back face', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: GrimoireApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Canvas Editor tab
      final editorNavTab = find.text('Editor de Lienzo');
      expect(editorNavTab, findsOneWidget);
      await tester.tap(editorNavTab);
      await tester.pumpAndSettle();

      // Verify Front side is initially selected
      expect(find.text('Anverso (Frontal)'), findsWidgets);

      // Tap on Back side toggle button
      final backSideToggle = find.text('Reverso (Trasera)').first;
      await tester.tap(backSideToggle);
      await tester.pumpAndSettle();

      // Verify Back template layers are now visible in Layer Tree (e.g., 'Central Medallion')
      expect(find.text('Central Medallion'), findsOneWidget);
      expect(find.text('Inner Rune Border'), findsOneWidget);

      // Tap 300 DPI Export Button to open ExportOptionsDialog
      final exportBtn = find.text('Renderizar Carta 300 DPI');
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      // Verify Export Modal Dialog opens with high-priority export options
      expect(find.text('Exportar Lote & Configuración'), findsOneWidget);
      expect(find.text('PDF Imprenta'), findsOneWidget);
      expect(find.text('TTS Sprite Sheet'), findsOneWidget);
      expect(find.text('PNG Individual'), findsOneWidget);

      // Verify Sangrado (Bleed 3mm) and Crop Marks switches
      expect(find.text('Sangrado de Imprenta (Bleed 3mm)'), findsOneWidget);
      expect(find.text('Marcas de Corte de Guillotina'), findsOneWidget);
      expect(find.text('Impresión Dúplex (Incluir Reverso)'), findsOneWidget);

      // Switch to Tabletop Simulator format in dialog
      final ttsTab = find.text('TTS Sprite Sheet');
      await tester.tap(ttsTab);
      await tester.pumpAndSettle();

      // Verify TTS info card appears
      expect(find.text('Tabletop Simulator (TTS) Ready'), findsOneWidget);
      expect(find.text('Hoja Frontal (Grid hasta 10x7)'), findsOneWidget);

      // Close dialog
      final cancelBtn = find.text('Cancelar');
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.text('Exportar Lote & Configuración'), findsNothing);
    });
  });
}
