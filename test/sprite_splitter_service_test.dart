import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:grimoire_studio/features/editor/services/sprite_splitter_service.dart';
import 'package:grimoire_studio/features/editor/presentation/dialogs/sprite_sheet_splitter_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpriteSplitterService Tests', () {
    final testDir = Directory('test_sprite_splitter_sandbox');

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

    test('calculateGrid accurately computes cell dimensions and count in Grid Mode', () {
      const options = SpriteSplitOptions(
        columns: 4,
        rows: 2,
        marginX: 10,
        marginY: 10,
        spacingX: 4,
        spacingY: 4,
      );

      final grid = SpriteSplitterService.calculateGrid(
        imageWidth: 400,
        imageHeight: 200,
        options: options,
      );

      expect(grid.totalCols, equals(4));
      expect(grid.totalRows, equals(2));
      // usableW = 400 - 20 - (3 * 4) = 368 -> 368 ~/ 4 = 92
      expect(grid.cellWidth, equals(92));
      // usableH = 200 - 20 - (1 * 4) = 176 -> 176 ~/ 2 = 88
      expect(grid.cellHeight, equals(88));
    });

    test('calculateGrid computes columns and rows in Fixed Size Mode', () {
      const options = SpriteSplitOptions(
        spriteWidth: 64,
        spriteHeight: 64,
        marginX: 0,
        marginY: 0,
        spacingX: 0,
        spacingY: 0,
      );

      final grid = SpriteSplitterService.calculateGrid(
        imageWidth: 256,
        imageHeight: 128,
        options: options,
      );

      expect(grid.cellWidth, equals(64));
      expect(grid.cellHeight, equals(64));
      expect(grid.totalCols, equals(4)); // 256 / 64
      expect(grid.totalRows, equals(2)); // 128 / 64
    });

    test('splitSpriteSheet slices image into individual PNG sprite files', () async {
      // 1. Create a 2x2 sprite sheet (100x100 px with 4 colored quadrants)
      final spriteSheet = img.Image(width: 100, height: 100);
      for (int y = 0; y < 100; y++) {
        for (int x = 0; x < 100; x++) {
          if (x < 50 && y < 50) {
            spriteSheet.setPixelRgba(x, y, 255, 0, 0, 255); // Red
          } else if (x >= 50 && y < 50) {
            spriteSheet.setPixelRgba(x, y, 0, 255, 0, 255); // Green
          } else if (x < 50 && y >= 50) {
            spriteSheet.setPixelRgba(x, y, 0, 0, 255, 255); // Blue
          } else {
            spriteSheet.setPixelRgba(x, y, 255, 255, 0, 255); // Yellow
          }
        }
      }

      final sourceFile = File('${testDir.path}/sheet_sample.png');
      await sourceFile.writeAsBytes(img.encodePng(spriteSheet));

      final outputDir = Directory('${testDir.path}/output_sprites');

      // 2. Perform splitting
      const options = SpriteSplitOptions(
        columns: 2,
        rows: 2,
        namePrefix: 'test_icon',
        skipEmptyCells: true,
      );

      final result = await SpriteSplitterService.splitSpriteSheet(
        sourceFile: sourceFile,
        outputDir: outputDir,
        options: options,
      );

      expect(result.success, isTrue);
      expect(result.totalSlices, equals(4));
      expect(result.createdFiles.length, equals(4));

      // 3. Verify each output file exists and has correct dimensions
      for (int i = 1; i <= 4; i++) {
        final spriteFile = File('${outputDir.path}/test_icon_$i.png');
        expect(spriteFile.existsSync(), isTrue);

        final decodedSprite = img.decodeImage(spriteFile.readAsBytesSync());
        expect(decodedSprite, isNotNull);
        expect(decodedSprite!.width, equals(50));
        expect(decodedSprite.height, equals(50));
      }
    });

    test('splitSpriteSheet skips completely transparent cells when skipEmptyCells is enabled', () async {
      // 1. Create a 2x1 sprite sheet with alpha channel where left half is filled and right half is 100% transparent
      final spriteSheet = img.Image(width: 100, height: 50, numChannels: 4);
      for (int y = 0; y < 50; y++) {
        for (int x = 0; x < 100; x++) {
          if (x < 50) {
            spriteSheet.setPixelRgba(x, y, 200, 100, 50, 255); // Opaque
          } else {
            spriteSheet.setPixelRgba(x, y, 0, 0, 0, 0); // Transparent
          }
        }
      }

      final sourceFile = File('${testDir.path}/sheet_with_empty.png');
      await sourceFile.writeAsBytes(img.encodePng(spriteSheet));

      final outputDir = Directory('${testDir.path}/output_skipped');

      const options = SpriteSplitOptions(
        columns: 2,
        rows: 1,
        namePrefix: 'token',
        skipEmptyCells: true,
      );

      final result = await SpriteSplitterService.splitSpriteSheet(
        sourceFile: sourceFile,
        outputDir: outputDir,
        options: options,
      );

      expect(result.success, isTrue);
      // Only 1 sprite should be saved because the 2nd cell is completely transparent
      expect(result.totalSlices, equals(1));
      expect(File('${outputDir.path}/token_1.png').existsSync(), isTrue);
      expect(File('${outputDir.path}/token_2.png').existsSync(), isFalse);
    });

    testWidgets('SpriteSheetSplitterDialog renders properly with presets and controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Create a dummy image synchronously so FakeAsync does not suspend
      final spriteSheet = img.Image(width: 120, height: 120, numChannels: 4);
      final dummyFile = File('${testDir.path}/dialog_test_sheet.png');
      dummyFile.writeAsBytesSync(img.encodePng(spriteSheet));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SpriteSheetSplitterDialog(
                gameName: 'Magic',
                initialFile: dummyFile,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Dividir Imagen en Sprites (Sprite Sheet Cutter)'), findsOneWidget);
      expect(find.text('Modo de División:'), findsOneWidget);
      expect(find.text('Cuadrícula (Cols × Filas)'), findsOneWidget);
      expect(find.text('✂️ Cortar y Guardar Sprites'), findsOneWidget);

      // Verify quick presets
      expect(find.text('2×2 (4)'), findsOneWidget);
      expect(find.text('3×3 (9)'), findsOneWidget);
      expect(find.text('4×4 (16)'), findsOneWidget);

      // Tap 4x4 preset
      await tester.tap(find.text('4×4 (16)'));
      await tester.pump();

      // Tap Cancel button
      expect(find.text('Cancelar'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
    });
  });
}
