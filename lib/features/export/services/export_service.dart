import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:archive/archive.dart';
import '../../../../core/constants/app_constants.dart';

class ExportProgress {
  final int current;
  final int total;
  final String status;

  const ExportProgress({
    required this.current,
    required this.total,
    required this.status,
  });
}

class ExportService {
  /// Captures the RepaintBoundary designated by [boundaryKey] to a high-res PNG byte buffer
  /// Using pixelRatio = 3.5 for 300 DPI print quality
  static Future<Uint8List?> captureBoundaryToImage(
    GlobalKey boundaryKey, {
    double pixelRatio = AppConstants.exportPixelRatio,
  }) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Export error capturing boundary: $e');
      return null;
    }
  }

  /// Resolves export directory with safe fallback to system temporary directory
  static Future<Directory> getExportDirectory({Directory? overrideDir}) async {
    if (overrideDir != null) return overrideDir;
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Exports a list of card image byte buffers to a multi-page PDF ready for printing.
  /// Supports 3mm bleed margin, guillotine crop marks, and duplex front/back sequencing.
  static Future<File> exportCardsToPdf({
    required List<Uint8List> cardImages,
    Uint8List? backImage,
    required String fileName,
    bool includeBleedAndCropMarks = false,
    bool includeBacks = false,
    Directory? outputDirectory,
  }) async {
    final pdf = pw.Document();
    final backMemoryImage = backImage != null ? pw.MemoryImage(backImage) : null;

    if (!includeBleedAndCropMarks) {
      // Standard Trim Size Without Bleed (63.5 x 88.9 mm)
      final pageFormat = PdfPageFormat(
        AppConstants.pokerWidthMm * PdfPageFormat.mm,
        AppConstants.pokerHeightMm * PdfPageFormat.mm,
        marginAll: 0,
      );

      for (final bytes in cardImages) {
        final frontImage = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (context) => pw.Center(child: pw.Image(frontImage, fit: pw.BoxFit.contain)),
          ),
        );

        if (includeBacks && backMemoryImage != null) {
          pdf.addPage(
            pw.Page(
              pageFormat: pageFormat,
              build: (context) => pw.Center(child: pw.Image(backMemoryImage, fit: pw.BoxFit.contain)),
            ),
          );
        }
      }
    } else {
      // Professional Prepress: 3mm Bleed Margin + 8 Guillotine Vector Crop Marks
      // Card Trim: 63.5 x 88.9 mm. Bleed: 3mm. Crop Margin: 5mm.
      // Total Page: 79.5 x 104.9 mm.
      final pageFormat = PdfPageFormat(
        79.5 * PdfPageFormat.mm,
        104.9 * PdfPageFormat.mm,
        marginAll: 0,
      );

      for (final bytes in cardImages) {
        final frontImage = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (context) => _buildCardWithBleedAndCropMarks(frontImage),
          ),
        );

        if (includeBacks && backMemoryImage != null) {
          pdf.addPage(
            pw.Page(
              pageFormat: pageFormat,
              build: (context) => _buildCardWithBleedAndCropMarks(backMemoryImage),
            ),
          );
        }
      }
    }

    final outputDir = await getExportDirectory(overrideDir: outputDirectory);
    final file = File('${outputDir.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildCardWithBleedAndCropMarks(pw.ImageProvider image) {
    const margin = 5.0 * PdfPageFormat.mm;
    const bleed = 3.0 * PdfPageFormat.mm;
    const trimW = 63.5 * PdfPageFormat.mm;
    const trimH = 88.9 * PdfPageFormat.mm;
    const bleedW = (63.5 + 6.0) * PdfPageFormat.mm;
    const bleedH = (88.9 + 6.0) * PdfPageFormat.mm;

    const cropLength = 3.5 * PdfPageFormat.mm;
    const cropGap = 1.0 * PdfPageFormat.mm;
    const cropThick = 0.5;

    const trimLeft = margin + bleed;
    const trimRight = trimLeft + trimW;
    const trimTop = margin + bleed;
    const trimBottom = trimTop + trimH;

    return pw.Stack(
      children: [
        // Bleed Artwork Area
        pw.Positioned(
          left: margin,
          top: margin,
          child: pw.SizedBox(
            width: bleedW,
            height: bleedH,
            child: pw.Image(image, fit: pw.BoxFit.fill),
          ),
        ),

        // Guillotine Crop Marks (8 Vector Ticks outside trim)
        // 1. Top-Left Vertical
        pw.Positioned(
          left: trimLeft,
          top: trimTop - cropGap - cropLength,
          child: pw.Container(width: cropThick, height: cropLength, color: PdfColors.black),
        ),
        // 2. Top-Left Horizontal
        pw.Positioned(
          left: trimLeft - cropGap - cropLength,
          top: trimTop,
          child: pw.Container(width: cropLength, height: cropThick, color: PdfColors.black),
        ),

        // 3. Top-Right Vertical
        pw.Positioned(
          left: trimRight,
          top: trimTop - cropGap - cropLength,
          child: pw.Container(width: cropThick, height: cropLength, color: PdfColors.black),
        ),
        // 4. Top-Right Horizontal
        pw.Positioned(
          left: trimRight + cropGap,
          top: trimTop,
          child: pw.Container(width: cropLength, height: cropThick, color: PdfColors.black),
        ),

        // 5. Bottom-Left Vertical
        pw.Positioned(
          left: trimLeft,
          top: trimBottom + cropGap,
          child: pw.Container(width: cropThick, height: cropLength, color: PdfColors.black),
        ),
        // 6. Bottom-Left Horizontal
        pw.Positioned(
          left: trimLeft - cropGap - cropLength,
          top: trimBottom,
          child: pw.Container(width: cropLength, height: cropThick, color: PdfColors.black),
        ),

        // 7. Bottom-Right Vertical
        pw.Positioned(
          left: trimRight,
          top: trimBottom + cropGap,
          child: pw.Container(width: cropThick, height: cropLength, color: PdfColors.black),
        ),
        // 8. Bottom-Right Horizontal
        pw.Positioned(
          left: trimRight + cropGap,
          top: trimBottom,
          child: pw.Container(width: cropLength, height: cropThick, color: PdfColors.black),
        ),
      ],
    );
  }

  /// Exports cards to a Tabletop Simulator (TTS) custom deck ZIP archive
  /// containing the front sprite sheet, back sheet/single back, and import configuration.
  static Future<File> exportTabletopSimulatorDeck({
    required List<Uint8List> cardImages,
    Uint8List? backImage,
    required String deckName,
    int maxCols = 10,
    int maxRows = 7,
    Directory? outputDirectory,
  }) async {
    final archive = Archive();
    final totalCards = cardImages.length;
    if (totalCards == 0) throw Exception('No cards to export');

    // Calculate grid dimensions for TTS
    final int cols = totalCards <= maxCols ? totalCards : maxCols;
    final int rows = ((totalCards + cols - 1) ~/ cols).clamp(1, maxRows);

    // TTS Card size per cell (standard 400x560 px fits under 4096 texture limit for 10x7)
    const int cellW = 400;
    const int cellH = 560;
    final sheetW = cols * cellW;
    final sheetH = rows * cellH;

    // 1. Generate Front Sheet
    final frontSheetBytes = await _renderSpriteSheet(
      images: cardImages,
      cols: cols,
      rows: rows,
      cellW: cellW,
      cellH: cellH,
      sheetW: sheetW,
      sheetH: sheetH,
      fillHiddenSlotWithBack: backImage,
    );
    archive.addFile(ArchiveFile('TTS_Deck_Front.png', frontSheetBytes.length, frontSheetBytes));

    // 2. Generate Back Sheet and Single Back (if available)
    if (backImage != null) {
      archive.addFile(ArchiveFile('TTS_Card_Back_Single.png', backImage.length, backImage));

      // Generate matching grid back sheet
      final backList = List.generate(cols * rows, (_) => backImage);
      final backSheetBytes = await _renderSpriteSheet(
        images: backList,
        cols: cols,
        rows: rows,
        cellW: cellW,
        cellH: cellH,
        sheetW: sheetW,
        sheetH: sheetH,
      );
      archive.addFile(ArchiveFile('TTS_Deck_Back_Sheet.png', backSheetBytes.length, backSheetBytes));
    }

    // 3. Generate TTS Config Readme
    final configText = StringBuffer()
      ..writeln('====================================================')
      ..writeln(' Tabletop Simulator (TTS) Custom Deck Configuration')
      ..writeln('====================================================')
      ..writeln('Deck Name: $deckName')
      ..writeln('Total Cards: $totalCards')
      ..writeln('Grid Columns (Width): $cols')
      ..writeln('Grid Rows (Height): $rows')
      ..writeln('Sheet Resolution: ${sheetW}x$sheetH px')
      ..writeln('Hidden Card Index: ${cols * rows - 1}')
      ..writeln('')
      ..writeln('INSTRUCTIONS TO IMPORT INTO TABLETOP SIMULATOR:')
      ..writeln('1. In Tabletop Simulator, go to Objects -> Components -> Custom -> Deck.')
      ..writeln('2. Face: Select TTS_Deck_Front.png.')
      ..writeln('3. Back: Select TTS_Deck_Back_Sheet.png (or TTS_Card_Back_Single.png if Unique Back is unchecked).')
      ..writeln('4. Set Width to: $cols')
      ..writeln('5. Set Height to: $rows')
      ..writeln('6. Set Number of cards to: $totalCards')
      ..writeln('7. Check "Back is Hidden" if you want facedown cards concealed.')
      ..writeln('8. Click "Import".');

    final configBytes = utf8.encode(configText.toString());
    archive.addFile(ArchiveFile('TTS_Deck_Config.txt', configBytes.length, configBytes));

    final zipBytes = ZipEncoder().encode(archive);
    final outputDir = await getExportDirectory(overrideDir: outputDirectory);
    final safeName = deckName.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final file = File('${outputDir.path}/${safeName}_TTS_Deck.zip');
    await file.writeAsBytes(zipBytes);
    return file;
  }

  static Future<Uint8List> _renderSpriteSheet({
    required List<Uint8List> images,
    required int cols,
    required int rows,
    required int cellW,
    required int cellH,
    required int sheetW,
    required int sheetH,
    Uint8List? fillHiddenSlotWithBack,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Dark background
    final bgPaint = ui.Paint()..color = const ui.Color(0xFF0F111D);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, sheetW.toDouble(), sheetH.toDouble()), bgPaint);

    final totalSlots = cols * rows;
    for (int i = 0; i < images.length && i < totalSlots; i++) {
      final codec = await ui.instantiateImageCodec(images[i]);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final c = i % cols;
      final r = i ~/ cols;

      final dstRect = ui.Rect.fromLTWH(
        c * cellW.toDouble(),
        r * cellH.toDouble(),
        cellW.toDouble(),
        cellH.toDouble(),
      );
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dstRect,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    }

    // TTS Hidden card convention: Slot (totalSlots - 1)
    if (fillHiddenSlotWithBack != null && images.length < totalSlots) {
      final codec = await ui.instantiateImageCodec(fillHiddenSlotWithBack);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final lastSlot = totalSlots - 1;
      final c = lastSlot % cols;
      final r = lastSlot ~/ cols;
      final dstRect = ui.Rect.fromLTWH(
        c * cellW.toDouble(),
        r * cellH.toDouble(),
        cellW.toDouble(),
        cellH.toDouble(),
      );
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dstRect,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    }

    final picture = recorder.endRecording();
    final sheetImage = await picture.toImage(sheetW, sheetH);
    final byteData = await sheetImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Exports card image byte buffers into a ZIP file with high-res PNGs
  static Future<File> exportCardsToZip({
    required List<Uint8List> cardImages,
    required List<String> cardNames,
    Uint8List? backImage,
    required String zipName,
    Directory? outputDirectory,
  }) async {
    final archive = Archive();

    for (int i = 0; i < cardImages.length; i++) {
      final name = i < cardNames.length ? cardNames[i] : 'card_$i';
      final safeName = name.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      final file = ArchiveFile(
        '$safeName.png',
        cardImages[i].length,
        cardImages[i],
      );
      archive.addFile(file);
    }

    if (backImage != null) {
      archive.addFile(ArchiveFile('card_back.png', backImage.length, backImage));
    }

    final zipBytes = ZipEncoder().encode(archive);
    final outputDir = await getExportDirectory(overrideDir: outputDirectory);
    final file = File('${outputDir.path}/$zipName.zip');
    await file.writeAsBytes(zipBytes);
    return file;
  }
}
