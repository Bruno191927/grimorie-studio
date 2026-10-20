import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/main.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';
import 'package:grimoire_studio/features/export/services/export_service.dart';

Future<Uint8List> createSampleCardImage({Color color = const Color(0xFF06B6D4)}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = color;
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 120, 168), paint);
  final picture = recorder.endRecording();
  final img = await picture.toImage(120, 168);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Low Priority Features: CMYK / PDF-X Pre-flight & Interactive 3D Web Showcase', () {
    test('1. PreflightReport calculates DPI, Bleed, Crop marks, Gamut & Duplex accurately', () {
      // Test when bleed is enabled
      final readyReport = ExportService.generatePreflightReport(
        widthMm: 63.5,
        heightMm: 88.9,
        bleedEnabled: true,
        cropMarksEnabled: true,
        duplexEnabled: true,
      );

      expect(readyReport.warningCount, 0);
      expect(readyReport.passCount, greaterThanOrEqualTo(3));
      expect(readyReport.checks.any((c) => c.title.contains('300 DPI')), isTrue);
      expect(readyReport.checks.any((c) => c.title.contains('Sangrado Exterior Activo')), isTrue);
      expect(readyReport.checks.any((c) => c.title.contains('Marcas de Corte')), isTrue);
      expect(readyReport.checks.any((c) => c.title.contains('CMYK')), isTrue);
      expect(readyReport.checks.any((c) => c.title.contains('Zona de Seguridad')), isTrue);

      // Test when bleed is disabled (should trigger a prepress warning)
      final warningReport = ExportService.generatePreflightReport(
        widthMm: 63.5,
        heightMm: 88.9,
        bleedEnabled: false,
        cropMarksEnabled: false,
        duplexEnabled: false,
      );

      expect(warningReport.warningCount, greaterThanOrEqualTo(1));
      final bleedCheck = warningReport.checks.firstWhere((c) => c.title.contains('Sangrado'));
      expect(bleedCheck.status, PreflightStatus.warning);
      expect(bleedCheck.description, contains('Sin desborde perimetral'));
    });

    test('2. ExportService.exportHtmlShowcase produces self-contained 3D showcase HTML', () async {
      final card1 = await createSampleCardImage(color: const Color(0xFF7C3AED));
      final card2 = await createSampleCardImage(color: const Color(0xFFEC4899));
      final back = await createSampleCardImage(color: const Color(0xFF1E1B4B));

      final htmlFile = await ExportService.exportHtmlShowcase(
        cardImages: [card1, card2],
        cardNames: ['Void Walker', 'Solar Phoenix'],
        backImage: back,
        showcaseTitle: 'Grimoire Showcase Test',
        cardDataList: [
          {'type': 'Creature', 'cost': '4U', 'rules_text': 'Flying, Hexproof'},
          {'type': 'Mythic', 'cost': '3RR', 'rules_text': 'When this dies, return it to battlefield.'},
        ],
        outputDirectory: Directory.systemTemp,
      );

      expect(htmlFile.existsSync(), isTrue);
      final htmlContent = await htmlFile.readAsString();

      // Check essential HTML markup and tags
      expect(htmlContent, contains('<!DOCTYPE html>'));
      expect(htmlContent, contains('Grimoire Showcase Test - Grimoire 3D Showcase'));
      expect(htmlContent, contains('data:image/png;base64,'));
      expect(htmlContent, contains('Void Walker'));
      expect(htmlContent, contains('Solar Phoenix'));

      // Check 3D tilt styles and holographic sheen classes
      expect(htmlContent, contains('perspective: 1000px'));
      expect(htmlContent, contains('transform-style: preserve-3d'));
      expect(htmlContent, contains('class="glare"'));
      expect(htmlContent, contains('rotateX('));
      expect(htmlContent, contains('rotateY('));

      // Check interactive search filter & modal inspection functions
      expect(htmlContent, contains('id="search-input"'));
      expect(htmlContent, contains('openModal('));
      expect(htmlContent, contains('toggleModalFlip()'));
      expect(htmlContent, contains('toggleFlipAll()'));

      // Cleanup
      if (htmlFile.existsSync()) {
        await htmlFile.delete();
      }
    });

    testWidgets('3. UI: ExportOptionsDialog displays Pre-flight Checklist and Web 3D Showcase tab', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: GrimoireApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Canvas Editor
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'nav_editor')));
      await tester.pumpAndSettle();

      // Tap 300 DPI button to open dialog
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'render_300dpi_card')));
      await tester.pumpAndSettle();

      // Verify Pre-flight Checklist is rendered under default PDF Imprenta
      expect(find.text(AppStrings.get(AppLanguage.en, 'format_pdf_print')), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'preflight_checklist_title')), findsOneWidget);
      expect(find.text('300 DPI Print Resolution'), findsOneWidget);
      expect(find.text('Active Outer Bleed (3.0 mm)'), findsOneWidget);
      expect(find.text('Active Vector Crop Marks'), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'preflight_ready')), findsOneWidget);

      // Verify Web 3D Showcase tab is present and selectable
      final web3dTab = find.text(AppStrings.get(AppLanguage.en, 'format_web_3d'));
      expect(web3dTab, findsOneWidget);
      await tester.tap(web3dTab);
      await tester.pumpAndSettle();

      // Verify Web 3D information card appears
      expect(find.text(AppStrings.get(AppLanguage.en, 'interactive_web_3d_viewer')), findsOneWidget);
      expect(find.text('Tilt 3D & Holographic Sheen'), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'flip_front_back')), findsOneWidget);
      expect(find.text('100% Offline'), findsOneWidget);

      // Close modal
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'cancel')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.get(AppLanguage.en, 'interactive_web_3d_viewer')), findsNothing);
    });
  });
}
