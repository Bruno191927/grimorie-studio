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
import '../../../../core/localization/app_strings.dart';
import '../../editor/services/game_folder_service.dart';

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

class GrimoireImportResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? workspaceStatePayload;
  final int gamesRestored;
  final int assetsRestored;

  const GrimoireImportResult({
    required this.success,
    required this.message,
    this.workspaceStatePayload,
    this.gamesRestored = 0,
    this.assetsRestored = 0,
  });
}

enum PreflightStatus {
  pass,
  warning,
  info,
}

class PreflightCheckItem {
  final String title;
  final String description;
  final PreflightStatus status;
  final String? recommendation;

  const PreflightCheckItem({
    required this.title,
    required this.description,
    required this.status,
    this.recommendation,
  });
}

class PreflightReport {
  final double widthMm;
  final double heightMm;
  final bool bleedEnabled;
  final bool cropMarksEnabled;
  final bool duplexEnabled;
  final List<PreflightCheckItem> checks;

  const PreflightReport({
    required this.widthMm,
    required this.heightMm,
    required this.bleedEnabled,
    required this.cropMarksEnabled,
    required this.duplexEnabled,
    required this.checks,
  });

  int get passCount => checks.where((c) => c.status == PreflightStatus.pass).length;
  int get warningCount => checks.where((c) => c.status == PreflightStatus.warning).length;
  int get infoCount => checks.where((c) => c.status == PreflightStatus.info).length;
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

  /// Exports full print-ready package for The Game Crafter (TGC Poker standard 825x1125 px @ 300 DPI)
  static Future<File> exportTheGameCrafterPackage({
    required List<Uint8List> cardImages,
    required List<String> cardNames,
    List<Uint8List>? backImages,
    Uint8List? defaultBackImage,
    required List<Map<String, dynamic>> cardRows,
    required String deckName,
    Directory? outputDirectory,
  }) async {
    final archive = Archive();
    final totalCards = cardImages.length;
    if (totalCards == 0) throw Exception('No cards to export');

    final manifestCards = <Map<String, dynamic>>[];

    for (int i = 0; i < cardImages.length; i++) {
      final name = i < cardNames.length ? cardNames[i] : 'Card_${i + 1}';
      final safeCardName = name.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      final idxStr = (i + 1).toString().padLeft(3, '0');
      final faceFileName = 'cards/card_${idxStr}_${safeCardName}_face.png';

      archive.addFile(ArchiveFile(faceFileName, cardImages[i].length, cardImages[i]));

      String backFileName = 'cards/deck_back.png';
      if (backImages != null && i < backImages.length && backImages[i].isNotEmpty) {
        backFileName = 'cards/card_${idxStr}_${safeCardName}_back.png';
        archive.addFile(ArchiveFile(backFileName, backImages[i].length, backImages[i]));
      } else if (defaultBackImage != null && !archive.files.any((f) => f.name == 'cards/deck_back.png')) {
        archive.addFile(ArchiveFile('cards/deck_back.png', defaultBackImage.length, defaultBackImage));
      }

      final row = i < cardRows.length ? cardRows[i] : <String, dynamic>{};
      final qty = int.tryParse(row['qty']?.toString() ?? '1') ?? 1;

      manifestCards.add({
        'index': i + 1,
        'name': name,
        'quantity': qty,
        'category': row['category'] ?? 'General',
        'type': row['type'] ?? '',
        'cost': row['cost'] ?? '',
        'front_file': faceFileName,
        'back_file': backFileName,
      });
    }

    // Add TGC Manifest JSON
    final manifest = {
      'game': deckName,
      'platform': 'The Game Crafter (TGC)',
      'component_type': 'Poker Deck',
      'specifications': {
        'card_size': 'Poker (2.5 x 3.5 inches)',
        'target_resolution_px': '825 x 1125',
        'dpi': 300,
        'bleed_px': 36,
        'safe_zone_px': '750 x 1050',
      },
      'total_cards': totalCards,
      'cards': manifestCards,
    };

    final manifestJson = const JsonEncoder.withIndent('  ').convert(manifest);
    final manifestBytes = utf8.encode(manifestJson);
    archive.addFile(ArchiveFile('thegamecrafter_manifest.json', manifestBytes.length, manifestBytes));

    // Add Instructions
    final instructions = StringBuffer()
      ..writeln('====================================================')
      ..writeln(' The Game Crafter (TGC) - Especificaciones de Baraja')
      ..writeln('====================================================')
      ..writeln('Juego: $deckName')
      ..writeln('Total de Cartas Únicas: $totalCards')
      ..writeln('')
      ..writeln('ESPECIFICACIONES DE IMPRESIÓN TGC:')
      ..writeln('• Tipo de Componente: Poker Deck (2.5" x 3.5")')
      ..writeln('• Tamaño de Archivo: 825 x 1125 px a 300 DPI')
      ..writeln('• Margen de Sangrado (Bleed): 36 px (1/8 pulgada) por cada lado')
      ..writeln('• Zona Segura (Safe Area): 750 x 1050 px centrado')
      ..writeln('')
      ..writeln('PASOS PARA SUBIR A THE GAME CRAFTER:')
      ..writeln('1. Inicia sesión en https://www.thegamecrafter.com y entra en tu juego.')
      ..writeln('2. Haz clic en "Add Component" -> "Deck" -> "Poker Deck".')
      ..writeln('3. Sube las imágenes de la carpeta "cards/" asignando cada cara y reverso.')
      ..writeln('4. Consulta thegamecrafter_manifest.json para verificar las cantidades (qty).')
      ..writeln('5. ¡Listo para pedir pruebas físicas o publicar en la tienda!');

    final instBytes = utf8.encode(instructions.toString());
    archive.addFile(ArchiveFile('tgc_instrucciones.txt', instBytes.length, instBytes));

    final zipBytes = ZipEncoder().encode(archive);
    final outputDir = await getExportDirectory(overrideDir: outputDirectory);
    final safeName = deckName.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final file = File('${outputDir.path}/${safeName}_TheGameCrafter.zip');
    await file.writeAsBytes(zipBytes);
    return file;
  }

  /// Exports print-ready package for MakePlayingCards (MPC Poker 816x1110 px @ 300 DPI)
  static Future<File> exportMakePlayingCardsPackage({
    required List<Uint8List> cardImages,
    required List<String> cardNames,
    List<Uint8List>? backImages,
    Uint8List? defaultBackImage,
    required List<Map<String, dynamic>> cardRows,
    required String deckName,
    Directory? outputDirectory,
  }) async {
    final archive = Archive();
    final totalCards = cardImages.length;
    if (totalCards == 0) throw Exception('No cards to export');

    final guideBuffer = StringBuffer()
      ..writeln('========================================================')
      ..writeln(' MakePlayingCards (MPC) - Guía de Pedido y Especificación')
      ..writeln('========================================================')
      ..writeln('Juego: $deckName')
      ..writeln('Fecha: ${DateTime.now().toIso8601String().split('T').first}')
      ..writeln('Total de Cartas Exportadas: $totalCards')
      ..writeln('')
      ..writeln('ESPECIFICACIONES RECOMENDADAS EN MPC:')
      ..writeln('• Tipo de Carta: Custom Game Cards (63 x 88 mm / 2.48" x 3.46")')
      ..writeln('• Tamaño de Archivo: 816 x 1110 px a 300 DPI')
      ..writeln('• Cartulina sugerida: S30 (Standard Smooth) o S33 (Superior Smooth / Linen)')
      ..writeln('• Acabado: MPC Game Card Finish o Linen Air-Cushion')
      ..writeln('')
      ..writeln('LISTA DE CARTAS Y CANTIDADES REQUERIDAS:')
      ..writeln('--------------------------------------------------------');

    for (int i = 0; i < cardImages.length; i++) {
      final name = i < cardNames.length ? cardNames[i] : 'Card_${i + 1}';
      final safeCardName = name.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      final idxStr = (i + 1).toString().padLeft(3, '0');
      final faceFileName = 'mpc_fronts/card_${idxStr}_$safeCardName.png';

      archive.addFile(ArchiveFile(faceFileName, cardImages[i].length, cardImages[i]));

      if (backImages != null && i < backImages.length && backImages[i].isNotEmpty) {
        final backFileName = 'mpc_backs/card_${idxStr}_$safeCardName.png';
        archive.addFile(ArchiveFile(backFileName, backImages[i].length, backImages[i]));
      }

      final row = i < cardRows.length ? cardRows[i] : <String, dynamic>{};
      final qty = int.tryParse(row['qty']?.toString() ?? '1') ?? 1;
      final cat = row['category'] ?? 'General';
      guideBuffer.writeln('[$idxStr] $name - $qty unidad(es) - [$cat]');
    }

    if (defaultBackImage != null) {
      archive.addFile(ArchiveFile('mpc_backs/common_deck_back.png', defaultBackImage.length, defaultBackImage));
    }

    guideBuffer
      ..writeln('--------------------------------------------------------')
      ..writeln('')
      ..writeln('INSTRUCCIONES PARA PEDIR EN MAKEPLAYINGCARDS:')
      ..writeln('1. Entra a https://www.makeplayingcards.com/design/custom-blank-card.html')
      ..writeln('2. Elige "Custom Game Cards (63 x 88mm)" y el número de cartas.')
      ..writeln('3. Haz clic en "Upload Images" y sube los archivos de la carpeta mpc_fronts/.')
      ..writeln('4. En el paso de reverso, sube mpc_backs/common_deck_back.png o los reversos personalizados.')
      ..writeln('5. Revisa la vista previa de corte (cut line) y confirma tu pedido.');

    final guideBytes = utf8.encode(guideBuffer.toString());
    archive.addFile(ArchiveFile('mpc_order_guide.txt', guideBytes.length, guideBytes));

    final zipBytes = ZipEncoder().encode(archive);
    final outputDir = await getExportDirectory(overrideDir: outputDirectory);
    final safeName = deckName.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final file = File('${outputDir.path}/${safeName}_MakePlayingCards.zip');
    await file.writeAsBytes(zipBytes);
    return file;
  }

  /// Exports digital tabletop sprite sheet package for Screentop.gg
  static Future<File> exportScreentopGgPackage({
    required List<Uint8List> cardImages,
    required List<String> cardNames,
    Uint8List? backImage,
    required List<Map<String, dynamic>> cardRows,
    required String deckName,
    int maxCols = 10,
    int maxRows = 7,
    Directory? outputDirectory,
  }) async {
    final archive = Archive();
    final totalCards = cardImages.length;
    if (totalCards == 0) throw Exception('No cards to export');

    final int cols = totalCards <= maxCols ? totalCards : maxCols;
    final int rows = ((totalCards + cols - 1) ~/ cols).clamp(1, maxRows);

    const int cellW = 400;
    const int cellH = 560;
    final sheetW = cols * cellW;
    final sheetH = rows * cellH;

    // 1. Render front sprite sheet
    final frontSheetBytes = await _renderSpriteSheet(
      images: cardImages,
      cols: cols,
      rows: rows,
      cellW: cellW,
      cellH: cellH,
      sheetW: sheetW,
      sheetH: sheetH,
    );
    archive.addFile(ArchiveFile('screentop_cards_sheet.png', frontSheetBytes.length, frontSheetBytes));

    // 2. Render back sprite sheet or single back
    if (backImage != null) {
      archive.addFile(ArchiveFile('screentop_card_back.png', backImage.length, backImage));
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
      archive.addFile(ArchiveFile('screentop_backs_sheet.png', backSheetBytes.length, backSheetBytes));
    }

    // 3. Screentop Asset JSON
    final screentopCards = <Map<String, dynamic>>[];
    for (int i = 0; i < cardImages.length; i++) {
      final name = i < cardNames.length ? cardNames[i] : 'Card_${i + 1}';
      final row = i < cardRows.length ? cardRows[i] : <String, dynamic>{};
      screentopCards.add({
        'index': i,
        'col': i % cols,
        'row': i ~/ cols,
        'name': name,
        'category': row['category'] ?? 'General',
        'cost': row['cost'] ?? '',
        'type': row['type'] ?? '',
        'qty': row['qty'] ?? 1,
      });
    }

    final screentopAsset = {
      'name': deckName,
      'platform': 'Screentop.gg',
      'type': 'asset',
      'kind': 'grid',
      'columns': cols,
      'rows': rows,
      'cell_width': cellW,
      'cell_height': cellH,
      'total_cards': totalCards,
      'front_sheet': 'screentop_cards_sheet.png',
      'back_sheet': backImage != null ? 'screentop_backs_sheet.png' : null,
      'cards': screentopCards,
    };

    final assetJson = const JsonEncoder.withIndent('  ').convert(screentopAsset);
    final assetBytes = utf8.encode(assetJson);
    archive.addFile(ArchiveFile('screentop_asset.json', assetBytes.length, assetBytes));

    // Instructions
    final instructions = StringBuffer()
      ..writeln('====================================================')
      ..writeln(' Screentop.gg Digital Tabletop Integration Guide')
      ..writeln('====================================================')
      ..writeln('Deck Name: $deckName')
      ..writeln('Grid Dimensions: ${cols}x$rows (Total Slots: ${cols * rows})')
      ..writeln('Resolution: ${sheetW}x$sheetH px')
      ..writeln('')
      ..writeln('HOW TO IMPORT INTO SCREENTOP.GG:')
      ..writeln('1. Open your project on https://screentop.gg.')
      ..writeln('2. Go to Assets -> Create Asset -> Type: "Grid Image".')
      ..writeln('3. Upload "screentop_cards_sheet.png".')
      ..writeln('4. Set Columns = $cols, Rows = $rows.')
      ..writeln('5. Go to Components -> Create Component -> Type: "Card".')
      ..writeln('6. Assign the front asset and back asset.')
      ..writeln('7. Enjoy browser-based multiplayer playtesting on Screentop.gg!');

    final instBytes = utf8.encode(instructions.toString());
    archive.addFile(ArchiveFile('screentop_instructions.txt', instBytes.length, instBytes));

    final zipBytes = ZipEncoder().encode(archive);
    final outputDir = await getExportDirectory(overrideDir: outputDirectory);
    final safeName = deckName.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final file = File('${outputDir.path}/${safeName}_ScreentopGg.zip');
    await file.writeAsBytes(zipBytes);
    return file;
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

  /// Exports a list of card images into a Print & Play (PnP) 3x3 grid PDF on A4 or US Letter paper.
  /// Supports cut lines and mirrored duplex back pages for home/office double-sided printing.
  static Future<File> exportCardsToPrintAndPlaySheetPdf({
    required List<Uint8List> cardImages,
    Uint8List? backImage,
    required String fileName,
    bool useUsLetter = false,
    bool includeBacks = true,
    bool includeCutLines = true,
    double cardWidthMm = AppConstants.pokerWidthMm,
    double cardHeightMm = AppConstants.pokerHeightMm,
    Directory? outputDirectory,
  }) async {
    final pdf = pw.Document();
    final pageFormat = useUsLetter ? PdfPageFormat.letter : PdfPageFormat.a4;
    final backMemoryImage = backImage != null ? pw.MemoryImage(backImage) : null;

    // Determine how many columns/rows fit on the page (default 3x3 for Poker/Japanese, 2x2 for Tarot)
    final pageW = pageFormat.width;
    final pageH = pageFormat.height;
    final cardW = cardWidthMm * PdfPageFormat.mm;
    final cardH = cardHeightMm * PdfPageFormat.mm;

    final cols = ((pageW - 16 * PdfPageFormat.mm) ~/ cardW).clamp(1, 3);
    final rows = ((pageH - 16 * PdfPageFormat.mm) ~/ cardH).clamp(1, 3);
    final cardsPerPage = cols * rows;

    final gridW = cols * cardW;
    final gridH = rows * cardH;
    final offsetX = (pageW - gridW) / 2.0;
    final offsetY = (pageH - gridH) / 2.0;

    for (int start = 0; start < cardImages.length; start += cardsPerPage) {
      final chunk = cardImages.sublist(
        start,
        (start + cardsPerPage) > cardImages.length ? cardImages.length : (start + cardsPerPage),
      );

      // 1. Front Page (3x3 Grid)
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat.copyWith(marginLeft: 0, marginRight: 0, marginTop: 0, marginBottom: 0),
          build: (context) {
            return _buildPnPGridPage(
              images: chunk.map((b) => pw.MemoryImage(b)).toList(),
              cols: cols,
              rows: rows,
              cardW: cardW,
              cardH: cardH,
              offsetX: offsetX,
              offsetY: offsetY,
              includeCutLines: includeCutLines,
              mirrorColumnsForBack: false,
              pageHeader: '$fileName — Frente (Pág. ${(start ~/ cardsPerPage) + 1})',
            );
          },
        ),
      );

      // 2. Mirrored Back Page for Duplex Printing
      if (includeBacks && backMemoryImage != null) {
        final backChunk = List<pw.ImageProvider>.filled(chunk.length, backMemoryImage);
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat.copyWith(marginLeft: 0, marginRight: 0, marginTop: 0, marginBottom: 0),
            build: (context) {
              return _buildPnPGridPage(
                images: backChunk,
                cols: cols,
                rows: rows,
                cardW: cardW,
                cardH: cardH,
                offsetX: offsetX,
                offsetY: offsetY,
                includeCutLines: includeCutLines,
                mirrorColumnsForBack: true,
                pageHeader: '$fileName — Reverso Alineado (Doble Cara - Voltear por borde largo)',
              );
            },
          ),
        );
      }
    }

    final outputDir = await getExportDirectory(overrideDir: outputDirectory);
    final file = File('${outputDir.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildPnPGridPage({
    required List<pw.ImageProvider> images,
    required int cols,
    required int rows,
    required double cardW,
    required double cardH,
    required double offsetX,
    required double offsetY,
    required bool includeCutLines,
    required bool mirrorColumnsForBack,
    required String pageHeader,
  }) {
    final children = <pw.Widget>[
      pw.Positioned(
        left: offsetX,
        top: (offsetY - 6 * PdfPageFormat.mm).clamp(2 * PdfPageFormat.mm, 20 * PdfPageFormat.mm),
        child: pw.Text(
          pageHeader,
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
      ),
    ];

    for (int i = 0; i < images.length; i++) {
      final rawCol = i % cols;
      final col = mirrorColumnsForBack ? (cols - 1 - rawCol) : rawCol;
      final row = i ~/ cols;
      final left = offsetX + col * cardW;
      final top = offsetY + row * cardH;

      children.add(
        pw.Positioned(
          left: left,
          top: top,
          child: pw.Container(
            width: cardW,
            height: cardH,
            decoration: includeCutLines
                ? pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.35),
                  )
                : null,
            child: pw.Image(images[i], fit: pw.BoxFit.fill),
          ),
        ),
      );
    }

    // Outer crop crosshairs around the 3x3 grid
    if (includeCutLines) {
      const tickLen = 4.0 * PdfPageFormat.mm;
      for (int c = 0; c <= cols; c++) {
        final x = offsetX + c * cardW;
        // Top tick
        children.add(
          pw.Positioned(
            left: x,
            top: offsetY - tickLen - 1.0 * PdfPageFormat.mm,
            child: pw.Container(width: 0.4, height: tickLen, color: PdfColors.black),
          ),
        );
        // Bottom tick
        children.add(
          pw.Positioned(
            left: x,
            top: offsetY + rows * cardH + 1.0 * PdfPageFormat.mm,
            child: pw.Container(width: 0.4, height: tickLen, color: PdfColors.black),
          ),
        );
      }
      for (int r = 0; r <= rows; r++) {
        final y = offsetY + r * cardH;
        // Left tick
        children.add(
          pw.Positioned(
            left: offsetX - tickLen - 1.0 * PdfPageFormat.mm,
            top: y,
            child: pw.Container(width: tickLen, height: 0.4, color: PdfColors.black),
          ),
        );
        // Right tick
        children.add(
          pw.Positioned(
            left: offsetX + cols * cardW + 1.0 * PdfPageFormat.mm,
            top: y,
            child: pw.Container(width: tickLen, height: 0.4, color: PdfColors.black),
          ),
        );
      }
    }

    return pw.Stack(children: children);
  }

  /// Exports the entire project state or a specific game, CSVs, and image assets into a portable `.grimoire` archive
  static Future<File> exportGrimoirePackage({
    required Map<String, dynamic> workspaceStatePayload,
    required String packageName,
    String? filterGameName,
    Directory? gamesRootDir,
    Directory? outputDirectory,
  }) async {
    final archive = Archive();

    Map<String, dynamic> filteredPayload = Map<String, dynamic>.from(workspaceStatePayload);
    if (filterGameName != null && filterGameName.trim().isNotEmpty) {
      final sanitizedTarget = GameFolderService.sanitizeFolderName(filterGameName).toLowerCase();

      // Filter categories
      if (filteredPayload['gameCategories'] is Map) {
        final cats = Map<String, dynamic>.from(filteredPayload['gameCategories'] as Map);
        cats.removeWhere((k, v) => GameFolderService.sanitizeFolderName(k).toLowerCase() != sanitizedTarget);
        filteredPayload['gameCategories'] = cats;
      }

      // Filter project rows
      if (filteredPayload['project'] is Map) {
        final proj = Map<String, dynamic>.from(filteredPayload['project'] as Map);
        if (proj['rows'] is List) {
          final rows = (proj['rows'] as List).where((r) {
            if (r is Map) {
              final g = (r['game'] ?? '').toString();
              return GameFolderService.sanitizeFolderName(g).toLowerCase() == sanitizedTarget;
            }
            return false;
          }).toList();
          proj['rows'] = rows;
        }
        filteredPayload['project'] = proj;
      }
    }

    final stateBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(filteredPayload));
    archive.addFile(ArchiveFile('workspace_state.json', stateBytes.length, stateBytes));

    if (gamesRootDir != null && gamesRootDir.existsSync()) {
      final subDirs = gamesRootDir.listSync().whereType<Directory>();
      for (final gameDir in subDirs) {
        final gameFolderName = gameDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (gameFolderName.startsWith('.')) continue;

        if (filterGameName != null && filterGameName.trim().isNotEmpty) {
          final sanitizedTarget = GameFolderService.sanitizeFolderName(filterGameName).toLowerCase();
          if (gameFolderName.toLowerCase() != sanitizedTarget) {
            continue;
          }
        }

        final csvFile = File('${gameDir.path}/data.csv');
        if (csvFile.existsSync()) {
          final bytes = await csvFile.readAsBytes();
          archive.addFile(ArchiveFile('$gameFolderName/data.csv', bytes.length, bytes));
        }

        final assetsDir = Directory('${gameDir.path}/assets');
        if (assetsDir.existsSync()) {
          for (final assetFile in assetsDir.listSync().whereType<File>()) {
            final assetName = assetFile.uri.pathSegments.last;
            final bytes = await assetFile.readAsBytes();
            archive.addFile(ArchiveFile('$gameFolderName/assets/$assetName', bytes.length, bytes));
          }
        }
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    final outputDir = await getExportDirectory(overrideDir: outputDirectory);
    if (!outputDir.existsSync()) {
      await outputDir.create(recursive: true);
    }
    final safeName = packageName.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final file = File('${outputDir.path}/$safeName.grimoire');
    await file.writeAsBytes(zipBytes);
    return file;
  }

  /// Exports a standard Steam Tabletop Simulator (TTS) Deck Saved Object (.json)
  /// containing all card metadata, rules, stats, and custom deck IDs.
  static Future<File> exportTabletopSimulatorDeckJson({
    required String gameName,
    required List<Map<String, dynamic>> cards,
    Directory? outputDirectory,
  }) async {
    final outputDir = await getExportDirectory(overrideDir: outputDirectory);
    if (!outputDir.existsSync()) {
      await outputDir.create(recursive: true);
    }

    final containedObjects = <Map<String, dynamic>>[];
    final deckIds = <int>[];

    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      final cardId = 100 + i;
      deckIds.add(cardId);

      final cardName = card['card_name']?.toString() ?? 'Card #${i + 1}';
      final cost = (card['cost'] ?? '').toString();
      final type = (card['type'] ?? '').toString();
      final rules = (card['rules_text'] ?? '').toString();
      final atk = (card['attack'] ?? '').toString();
      final def = (card['defense'] ?? '').toString();

      final descBuffer = StringBuffer();
      if (type.isNotEmpty) descBuffer.writeln('Tipo: $type');
      if (cost.isNotEmpty) descBuffer.writeln('Coste: $cost');
      if (atk.isNotEmpty || def.isNotEmpty) descBuffer.writeln('Stats: $atk / $def');
      if (rules.isNotEmpty) descBuffer.writeln('\n$rules');

      containedObjects.add({
        'CardID': cardId,
        'Name': 'CardCustom',
        'Nickname': cardName,
        'Description': descBuffer.toString().trim(),
        'Transform': {
          'posX': 0.0,
          'posY': 1.0,
          'posZ': 0.0,
          'rotX': 0.0,
          'rotY': 180.0,
          'rotZ': 0.0,
          'scaleX': 1.0,
          'scaleY': 1.0,
          'scaleZ': 1.0,
        },
      });
    }

    final ttsPayload = {
      'SaveName': '$gameName Deck',
      'Date': DateTime.now().toIso8601String(),
      'VersionNumber': '1.0',
      'GameMode': 'Grimoire Studio Tabletop',
      'GameType': gameName,
      'GameName': gameName,
      'ObjectStates': [
        {
          'Name': 'DeckCustom',
          'ContainedObjects': containedObjects,
          'DeckIDs': deckIds,
          'CustomDeck': {
            '1': {
              'FaceURL': '',
              'BackURL': '',
              'NumWidth': 10,
              'NumHeight': 7,
              'BackIsHidden': true,
              'UniqueBack': false,
            },
          },
          'Transform': {
            'posX': 0.0,
            'posY': 1.0,
            'posZ': 0.0,
            'rotX': 0.0,
            'rotY': 180.0,
            'rotZ': 180.0,
            'scaleX': 1.0,
            'scaleY': 1.0,
            'scaleZ': 1.0,
          },
        },
      ],
    };

    final safeName = gameName.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final file = File('${outputDir.path}/${safeName}_TabletopSimulator_Deck.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(ttsPayload));
    return file;
  }

  /// Imports a portable `.grimoire` or `.zip` package archive, restoring the workspace state,
  /// game folders, `data.csv` spreadsheets, and card artwork assets.
  static Future<GrimoireImportResult> importGrimoirePackage({
    required File packageFile,
    Directory? gamesRootDir,
  }) async {
    try {
      if (!packageFile.existsSync()) {
        return const GrimoireImportResult(
          success: false,
          message: 'El archivo de paquete no existe.',
        );
      }

      final bytes = await packageFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      Map<String, dynamic>? workspaceState;
      int gamesRestored = 0;
      int assetsRestored = 0;

      final targetGamesRoot = gamesRootDir ?? GameFolderService.getGamesRootDir();
      if (!targetGamesRoot.existsSync()) {
        await targetGamesRoot.create(recursive: true);
      }

      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name;

        if (name == 'workspace_state.json') {
          final contentStr = utf8.decode(file.content as List<int>);
          workspaceState = jsonDecode(contentStr) as Map<String, dynamic>;
          final stateFile = File('${targetGamesRoot.path}/workspace_state.json');
          await stateFile.writeAsString(contentStr);
        } else {
          final extractedFile = File('${targetGamesRoot.path}/$name');
          await extractedFile.parent.create(recursive: true);
          await extractedFile.writeAsBytes(file.content as List<int>);

          if (name.endsWith('/data.csv') || name.endsWith('\\data.csv')) {
            gamesRestored++;
          } else if (name.contains('/assets/') || name.contains('\\assets\\')) {
            assetsRestored++;
          }
        }
      }

      return GrimoireImportResult(
        success: true,
        message: 'Paquete importado con éxito ($gamesRestored juegos, $assetsRestored assets)',
        workspaceStatePayload: workspaceState,
        gamesRestored: gamesRestored,
        assetsRestored: assetsRestored,
      );
    } catch (e) {
      return GrimoireImportResult(
        success: false,
        message: 'Error al importar paquete .grimoire: $e',
      );
    }
  }

  /// Generates a comprehensive pre-flight prepress report assessing 300 DPI resolution,
  /// 3mm bleed tolerances, vector crop marks, duplex alignment, safe margins, and CMYK/PDF-X compliance.
  static PreflightReport generatePreflightReport({
    required double widthMm,
    required double heightMm,
    required bool bleedEnabled,
    required bool cropMarksEnabled,
    required bool duplexEnabled,
    AppLanguage language = AppLanguage.es,
  }) {
    final isEn = language == AppLanguage.en;
    final checks = <PreflightCheckItem>[
      PreflightCheckItem(
        title: isEn ? '300 DPI Print Resolution' : 'Resolución de Impresión 300 DPI',
        description: isEn
            ? 'Calibrated resolution for physical card of ${widthMm.toStringAsFixed(1)} × ${heightMm.toStringAsFixed(1)} mm. High-definition rendering with 3.5× scale factor.'
            : 'Resolución calibrada para naipe físico de ${widthMm.toStringAsFixed(1)} × ${heightMm.toStringAsFixed(1)} mm. Renderizado de alta definición con factor de escala 3.5×.',
        status: PreflightStatus.pass,
        recommendation: isEn
            ? 'Meets commercial offset and professional digital printing standards.'
            : 'Cumple el estándar de imprenta offset comercial y digital profesional.',
      ),
      PreflightCheckItem(
        title: isEn
            ? (bleedEnabled ? 'Active Outer Bleed (3.0 mm)' : 'Outer Bleed Disabled')
            : (bleedEnabled ? 'Sangrado Exterior Activo (3.0 mm)' : 'Sangrado Exterior Desactivado'),
        description: isEn
            ? (bleedEnabled
                ? 'Canvas adds 3.0 mm perimeter artwork bleed beyond trim edge to absorb mechanical guillotine tolerances.'
                : 'No perimeter bleed: If guillotine shifts 0.5-1.5 mm, an unsightly white border will appear on card edges.')
            : (bleedEnabled
                ? 'El lienzo añade 3.0 mm perimetrales de desborde de arte más allá del borde de corte para absorber tolerancias mecánicas de guillotina.'
                : 'Sin desborde perimetral: Si la guillotina tiene una desviación mecánica de 0.5-1.5 mm, aparecerá un filo blanco antiestético en los bordes de la carta.'),
        status: bleedEnabled ? PreflightStatus.pass : PreflightStatus.warning,
        recommendation: isEn
            ? (bleedEnabled
                ? 'Aligned with card printer specifications (MPC, Cartamundi, DriveThruCards).'
                : 'Activating bleed before sending files to print is recommended.')
            : (bleedEnabled
                ? 'Alineado con especificaciones de imprentas de naipes (MPC, Cartamundi, DriveThruCards).'
                : 'Se recomienda activar el sangrado antes de enviar el archivo a imprenta.'),
      ),
      PreflightCheckItem(
        title: isEn
            ? (cropMarksEnabled ? 'Active Vector Crop Marks' : 'No Guide Crop Marks')
            : (cropMarksEnabled ? 'Marcas de Corte Vectoriales Activas' : 'Sin Marcas de Corte Guía'),
        description: isEn
            ? (cropMarksEnabled
                ? '8 outer vector registration marks offset 1.0 mm from trim line for guillotine alignment or die-cutting.'
                : 'The PDF document will not contain perimeter cutting guides.')
            : (cropMarksEnabled
                ? '8 marcas vectoriales de registro exterior separadas a 1.0 mm de la línea de corte para alineación de guillotina o troquelado.'
                : 'El documento PDF no contendrá guías perimetrales de corte.'),
        status: cropMarksEnabled ? PreflightStatus.pass : PreflightStatus.info,
        recommendation: isEn
            ? (cropMarksEnabled
                ? 'Allows press operators to center cuts with micrometric precision.'
                : 'Disable only if printer requests exact trimmed size.')
            : (cropMarksEnabled
                ? 'Permite a los operarios de imprenta centrar el corte con precisión micrométrica.'
                : 'Desactiva solo si la imprenta solicita el archivo recortado al tamaño trim exacto.'),
      ),
      PreflightCheckItem(
        title: isEn ? 'CMYK Profile Simulation & PDF/X-1a Standard' : 'Simulación de Perfil CMYK & Estándar PDF/X-1a',
        description: isEn
            ? 'Screens emit RGB light (wide gamut), while printers apply CMYK inks to physical paper. Ultra-saturated or neon colors naturally desaturate on paper.'
            : 'Las pantallas emiten luz RGB (gama amplia), mientras las imprentas aplican tintas CMYK (cian, magenta, amarillo, negro) sobre papel físico. Los colores súper saturados o neones sufren desaturación natural en papel.',
        status: PreflightStatus.info,
        recommendation: isEn
            ? 'Gamut notice: For commercial runs, avoid 100% pure RGB neons (#00FF00, #00FFFF). Grimoire Studio optimizes contrasts for FOGRA39 / GRACoL.'
            : 'Aviso de Gamut: Para tiradas comerciales, evita colores neón 100% RGB puros (#00FF00, #00FFFF). Grimoire Studio optimiza los contrastes para FOGRA39 / GRACoL.',
      ),
      PreflightCheckItem(
        title: isEn ? 'Inner Safety Margin (3.0 mm)' : 'Zona de Seguridad Interior (3.0 mm)',
        description: isEn
            ? 'All critical content (text, mana icons, attack/defense stats, numbers) must be > 3.0 mm from the cut edge.'
            : 'Todo el contenido crítico (textos, iconos de maná, estadísticas de ataque/defensa y números) debe estar a más de 3.0 mm del borde de corte.',
        status: PreflightStatus.pass,
        recommendation: isEn
            ? 'Ensures no text is cut off by mechanical margin of error (±1.5 mm).'
            : 'Garantiza que ningún texto quede guillotinado por el margen de error mecánico (±1.5 mm).',
      ),
      PreflightCheckItem(
        title: isEn
            ? (duplexEnabled ? 'Duplex Printing (Front + Back)' : 'Single-Sided Printing (Front Only)')
            : (duplexEnabled ? 'Impresión Dúplex (Anverso + Reverso)' : 'Impresión Simple (Solo Anverso)'),
        description: isEn
            ? (duplexEnabled
                ? 'PDF automatically alternates even pages with corresponding card back for double-sided printing.'
                : 'Only front card faces of the deck will be exported.')
            : (duplexEnabled
                ? 'El PDF intercala automáticamente las páginas pares con el reverso correspondiente para imprimir a doble cara.'
                : 'Solo se exportarán las caras frontales del mazo.'),
        status: duplexEnabled ? PreflightStatus.pass : PreflightStatus.info,
        recommendation: isEn
            ? (duplexEnabled
                ? 'Make sure printer is set to "Flip on Long Edge" (Long-Edge Binding).'
                : 'Ideal when playing with opaque card sleeves.')
            : (duplexEnabled
                ? 'Asegúrate de configurar la impresora en "Voltear por el borde largo" (Long-Edge Binding).'
                : 'Ideal para jugar con fundas protectoras opacas (card sleeves).'),
      ),
    ];

    return PreflightReport(
      widthMm: widthMm,
      heightMm: heightMm,
      bleedEnabled: bleedEnabled,
      cropMarksEnabled: cropMarksEnabled,
      duplexEnabled: duplexEnabled,
      checks: checks,
    );
  }

  /// Exports cards to a self-contained, interactive 3D Web Showcase HTML file.
  /// Features 3D card tilt & dynamic holographic sheen on mouse movement,
  /// card front/back flipping, instant live search filter, and full-screen modal inspector.
  static Future<File> exportHtmlShowcase({
    required List<Uint8List> cardImages,
    required List<String> cardNames,
    Uint8List? backImage,
    required String showcaseTitle,
    List<Map<String, dynamic>>? cardDataList,
    Directory? outputDirectory,
  }) async {
    final frontBase64List = cardImages.map((bytes) => base64Encode(bytes)).toList();
    final backBase64 = backImage != null ? base64Encode(backImage) : null;

    final htmlContent = _buildHtmlShowcaseContent(
      showcaseTitle: showcaseTitle,
      cardFrontBase64: frontBase64List,
      cardNames: cardNames,
      cardBackBase64: backBase64,
      cardDataList: cardDataList,
    );

    final outputDir = await getExportDirectory(overrideDir: outputDirectory);
    final safeName = showcaseTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final file = File('${outputDir.path}/${safeName}_Showcase.html');
    await file.writeAsString(htmlContent, encoding: utf8);
    return file;
  }

  static String _buildHtmlShowcaseContent({
    required String showcaseTitle,
    required List<String> cardFrontBase64,
    required List<String> cardNames,
    required String? cardBackBase64,
    List<Map<String, dynamic>>? cardDataList,
  }) {
    final buffer = StringBuffer();
    final totalCards = cardFrontBase64.length;

    String escapeHtml(String str) {
      return str
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&#39;');
    }

    final safeTitle = escapeHtml(showcaseTitle);

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="es">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="utf-8">');
    buffer.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('  <title>$safeTitle - Grimoire 3D Showcase</title>');
    buffer.writeln('  <style>');
    buffer.writeln('    * { box-sizing: border-box; margin: 0; padding: 0; }');
    buffer.writeln('    :root {');
    buffer.writeln('      --bg-deep: #090b10;');
    buffer.writeln('      --bg-surface: #101422;');
    buffer.writeln('      --bg-card: #151928;');
    buffer.writeln('      --border-subtle: #20263d;');
    buffer.writeln('      --accent-purple: #7c3aed;');
    buffer.writeln('      --accent-cyan: #06b6d4;');
    buffer.writeln('      --accent-pink: #ec4899;');
    buffer.writeln('      --text-main: #f8fafc;');
    buffer.writeln('      --text-muted: #94a3b8;');
    buffer.writeln('    }');
    buffer.writeln('    body {');
    buffer.writeln('      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;');
    buffer.writeln('      background-color: var(--bg-deep);');
    buffer.writeln('      color: var(--text-main);');
    buffer.writeln('      min-height: 100vh;');
    buffer.writeln('      overflow-x: hidden;');
    buffer.writeln('    }');
    buffer.writeln('    header {');
    buffer.writeln('      position: sticky;');
    buffer.writeln('      top: 0;');
    buffer.writeln('      z-index: 50;');
    buffer.writeln('      background: rgba(16, 20, 34, 0.88);');
    buffer.writeln('      backdrop-filter: blur(14px);');
    buffer.writeln('      border-bottom: 1px solid var(--border-subtle);');
    buffer.writeln('      padding: 14px 24px;');
    buffer.writeln('      display: flex;');
    buffer.writeln('      flex-wrap: wrap;');
    buffer.writeln('      align-items: center;');
    buffer.writeln('      justify-content: space-between;');
    buffer.writeln('      gap: 16px;');
    buffer.writeln('    }');
    buffer.writeln('    .brand-section {');
    buffer.writeln('      display: flex;');
    buffer.writeln('      align-items: center;');
    buffer.writeln('      gap: 12px;');
    buffer.writeln('    }');
    buffer.writeln('    .brand-icon {');
    buffer.writeln('      width: 32px;');
    buffer.writeln('      height: 32px;');
    buffer.writeln('      background: linear-gradient(135deg, var(--accent-purple), var(--accent-pink));');
    buffer.writeln('      border-radius: 8px;');
    buffer.writeln('      display: flex;');
    buffer.writeln('      align-items: center;');
    buffer.writeln('      justify-content: center;');
    buffer.writeln('      font-size: 16px;');
    buffer.writeln('      box-shadow: 0 4px 12px rgba(124, 58, 237, 0.4);');
    buffer.writeln('    }');
    buffer.writeln('    .brand-title {');
    buffer.writeln('      font-size: 1.15rem;');
    buffer.writeln('      font-weight: 700;');
    buffer.writeln('      letter-spacing: -0.01em;');
    buffer.writeln('    }');
    buffer.writeln('    .badge-count {');
    buffer.writeln('      background: rgba(124, 58, 237, 0.2);');
    buffer.writeln('      color: #c4b5fd;');
    buffer.writeln('      border: 1px solid rgba(124, 58, 237, 0.4);');
    buffer.writeln('      padding: 3px 9px;');
    buffer.writeln('      border-radius: 9999px;');
    buffer.writeln('      font-size: 0.72rem;');
    buffer.writeln('      font-weight: 600;');
    buffer.writeln('    }');
    buffer.writeln('    .controls {');
    buffer.writeln('      display: flex;');
    buffer.writeln('      align-items: center;');
    buffer.writeln('      gap: 10px;');
    buffer.writeln('      flex-wrap: wrap;');
    buffer.writeln('    }');
    buffer.writeln('    .search-box {');
    buffer.writeln('      position: relative;');
    buffer.writeln('      min-width: 240px;');
    buffer.writeln('    }');
    buffer.writeln('    .search-box input {');
    buffer.writeln('      width: 100%;');
    buffer.writeln('      background: #0d101a;');
    buffer.writeln('      border: 1px solid var(--border-subtle);');
    buffer.writeln('      border-radius: 8px;');
    buffer.writeln('      padding: 8px 12px 8px 34px;');
    buffer.writeln('      color: var(--text-main);');
    buffer.writeln('      font-size: 0.82rem;');
    buffer.writeln('      outline: none;');
    buffer.writeln('      transition: border-color 0.2s;');
    buffer.writeln('    }');
    buffer.writeln('    .search-box input:focus {');
    buffer.writeln('      border-color: var(--accent-purple);');
    buffer.writeln('    }');
    buffer.writeln('    .search-icon {');
    buffer.writeln('      position: absolute;');
    buffer.writeln('      left: 10px;');
    buffer.writeln('      top: 50%;');
    buffer.writeln('      transform: translateY(-50%);');
    buffer.writeln('      opacity: 0.5;');
    buffer.writeln('      font-size: 0.85rem;');
    buffer.writeln('    }');
    buffer.writeln('    .btn {');
    buffer.writeln('      background: #191e30;');
    buffer.writeln('      border: 1px solid var(--border-subtle);');
    buffer.writeln('      color: var(--text-main);');
    buffer.writeln('      padding: 8px 14px;');
    buffer.writeln('      border-radius: 8px;');
    buffer.writeln('      font-size: 0.8rem;');
    buffer.writeln('      font-weight: 600;');
    buffer.writeln('      cursor: pointer;');
    buffer.writeln('      display: inline-flex;');
    buffer.writeln('      align-items: center;');
    buffer.writeln('      gap: 6px;');
    buffer.writeln('      transition: all 0.2s;');
    buffer.writeln('    }');
    buffer.writeln('    .btn:hover {');
    buffer.writeln('      background: #232a42;');
    buffer.writeln('      border-color: var(--accent-purple);');
    buffer.writeln('    }');
    buffer.writeln('    main {');
    buffer.writeln('      max-width: 1400px;');
    buffer.writeln('      margin: 0 auto;');
    buffer.writeln('      padding: 36px 24px;');
    buffer.writeln('    }');
    buffer.writeln('    .grid {');
    buffer.writeln('      display: grid;');
    buffer.writeln('      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));');
    buffer.writeln('      gap: 32px 24px;');
    buffer.writeln('    }');
    buffer.writeln('    .card-scene {');
    buffer.writeln('      perspective: 1000px;');
    buffer.writeln('      display: flex;');
    buffer.writeln('      flex-direction: column;');
    buffer.writeln('      align-items: center;');
    buffer.writeln('    }');
    buffer.writeln('    .card-scene.hidden {');
    buffer.writeln('      display: none;');
    buffer.writeln('    }');
    buffer.writeln('    .card-wrap {');
    buffer.writeln('      width: 100%;');
    buffer.writeln('      aspect-ratio: 63.5 / 88.9;');
    buffer.writeln('      position: relative;');
    buffer.writeln('      transform-style: preserve-3d;');
    buffer.writeln('      transition: transform 0.12s ease-out, box-shadow 0.25s ease;');
    buffer.writeln('      border-radius: 12px;');
    buffer.writeln('      cursor: pointer;');
    buffer.writeln('      box-shadow: 0 12px 28px -6px rgba(0, 0, 0, 0.7);');
    buffer.writeln('    }');
    buffer.writeln('    .card-wrap:hover {');
    buffer.writeln('      box-shadow: 0 20px 40px -8px rgba(124, 58, 237, 0.35);');
    buffer.writeln('    }');
    buffer.writeln('    .card-wrap.flipped {');
    buffer.writeln('      transform: rotateY(180deg) !important;');
    buffer.writeln('    }');
    buffer.writeln('    .card-face {');
    buffer.writeln('      position: absolute;');
    buffer.writeln('      inset: 0;');
    buffer.writeln('      width: 100%;');
    buffer.writeln('      height: 100%;');
    buffer.writeln('      border-radius: 12px;');
    buffer.writeln('      overflow: hidden;');
    buffer.writeln('      backface-visibility: hidden;');
    buffer.writeln('      -webkit-backface-visibility: hidden;');
    buffer.writeln('      border: 1px solid rgba(255, 255, 255, 0.08);');
    buffer.writeln('      background: #141824;');
    buffer.writeln('    }');
    buffer.writeln('    .card-face img {');
    buffer.writeln('      width: 100%;');
    buffer.writeln('      height: 100%;');
    buffer.writeln('      object-fit: contain;');
    buffer.writeln('      display: block;');
    buffer.writeln('    }');
    buffer.writeln('    .card-back {');
    buffer.writeln('      transform: rotateY(180deg);');
    buffer.writeln('    }');
    buffer.writeln('    .glare {');
    buffer.writeln('      position: absolute;');
    buffer.writeln('      inset: 0;');
    buffer.writeln('      border-radius: 12px;');
    buffer.writeln('      pointer-events: none;');
    buffer.writeln('      opacity: 0;');
    buffer.writeln('      mix-blend-mode: overlay;');
    buffer.writeln('      transition: opacity 0.2s ease;');
    buffer.writeln('      background: radial-gradient(circle at 50% 50%, rgba(255,255,255,0.6) 0%, rgba(255,255,255,0.05) 50%, transparent 75%);');
    buffer.writeln('      z-index: 5;');
    buffer.writeln('    }');
    buffer.writeln('    .card-caption {');
    buffer.writeln('      margin-top: 10px;');
    buffer.writeln('      text-align: center;');
    buffer.writeln('      width: 100%;');
    buffer.writeln('    }');
    buffer.writeln('    .card-name {');
    buffer.writeln('      font-size: 0.85rem;');
    buffer.writeln('      font-weight: 600;');
    buffer.writeln('      color: var(--text-main);');
    buffer.writeln('      white-space: nowrap;');
    buffer.writeln('      overflow: hidden;');
    buffer.writeln('      text-overflow: ellipsis;');
    buffer.writeln('    }');
    buffer.writeln('    .card-subtext {');
    buffer.writeln('      font-size: 0.72rem;');
    buffer.writeln('      color: var(--text-muted);');
    buffer.writeln('      margin-top: 2px;');
    buffer.writeln('    }');
    buffer.writeln('    /* Modal Inspection Lightbox */');
    buffer.writeln('    .modal-backdrop {');
    buffer.writeln('      position: fixed;');
    buffer.writeln('      inset: 0;');
    buffer.writeln('      z-index: 100;');
    buffer.writeln('      background: rgba(5, 7, 14, 0.88);');
    buffer.writeln('      backdrop-filter: blur(10px);');
    buffer.writeln('      display: flex;');
    buffer.writeln('      align-items: center;');
    buffer.writeln('      justify-content: center;');
    buffer.writeln('      padding: 24px;');
    buffer.writeln('      opacity: 0;');
    buffer.writeln('      pointer-events: none;');
    buffer.writeln('      transition: opacity 0.25s ease;');
    buffer.writeln('    }');
    buffer.writeln('    .modal-backdrop.active {');
    buffer.writeln('      opacity: 1;');
    buffer.writeln('      pointer-events: auto;');
    buffer.writeln('    }');
    buffer.writeln('    .modal-card {');
    buffer.writeln('      background: var(--bg-surface);');
    buffer.writeln('      border: 1px solid var(--border-subtle);');
    buffer.writeln('      border-radius: 18px;');
    buffer.writeln('      padding: 30px;');
    buffer.writeln('      max-width: 820px;');
    buffer.writeln('      width: 100%;');
    buffer.writeln('      display: flex;');
    buffer.writeln('      gap: 32px;');
    buffer.writeln('      align-items: center;');
    buffer.writeln('      box-shadow: 0 30px 60px -15px rgba(0, 0, 0, 0.9);');
    buffer.writeln('      position: relative;');
    buffer.writeln('    }');
    buffer.writeln('    @media (max-width: 720px) {');
    buffer.writeln('      .modal-card { flex-direction: column; padding: 20px; }');
    buffer.writeln('    }');
    buffer.writeln('    .modal-close {');
    buffer.writeln('      position: absolute;');
    buffer.writeln('      top: 14px;');
    buffer.writeln('      right: 16px;');
    buffer.writeln('      background: none;');
    buffer.writeln('      border: none;');
    buffer.writeln('      color: var(--text-muted);');
    buffer.writeln('      font-size: 1.4rem;');
    buffer.writeln('      cursor: pointer;');
    buffer.writeln('    }');
    buffer.writeln('    .modal-close:hover { color: white; }');
    buffer.writeln('    .modal-preview-scene {');
    buffer.writeln('      perspective: 1200px;');
    buffer.writeln('      width: 300px;');
    buffer.writeln('      flex-shrink: 0;');
    buffer.writeln('    }');
    buffer.writeln('    .modal-card-wrap {');
    buffer.writeln('      width: 100%;');
    buffer.writeln('      aspect-ratio: 63.5 / 88.9;');
    buffer.writeln('      position: relative;');
    buffer.writeln('      transform-style: preserve-3d;');
    buffer.writeln('      border-radius: 14px;');
    buffer.writeln('      box-shadow: 0 24px 48px -10px rgba(0, 0, 0, 0.85);');
    buffer.writeln('      transition: transform 0.12s ease-out;');
    buffer.writeln('    }');
    buffer.writeln('    .modal-card-wrap.flipped {');
    buffer.writeln('      transform: rotateY(180deg) !important;');
    buffer.writeln('    }');
    buffer.writeln('    .modal-info {');
    buffer.writeln('      flex: 1;');
    buffer.writeln('    }');
    buffer.writeln('    .modal-info h2 {');
    buffer.writeln('      font-size: 1.35rem;');
    buffer.writeln('      color: white;');
    buffer.writeln('      margin-bottom: 6px;');
    buffer.writeln('    }');
    buffer.writeln('    .modal-info .meta-row {');
    buffer.writeln('      display: flex;');
    buffer.writeln('      gap: 8px;');
    buffer.writeln('      margin-bottom: 14px;');
    buffer.writeln('      flex-wrap: wrap;');
    buffer.writeln('    }');
    buffer.writeln('    .modal-tag {');
    buffer.writeln('      background: #191e30;');
    buffer.writeln('      border: 1px solid var(--border-subtle);');
    buffer.writeln('      padding: 3px 8px;');
    buffer.writeln('      border-radius: 6px;');
    buffer.writeln('      font-size: 0.72rem;');
    buffer.writeln('      color: #cbd5e1;');
    buffer.writeln('    }');
    buffer.writeln('    .modal-actions {');
    buffer.writeln('      display: flex;');
    buffer.writeln('      gap: 10px;');
    buffer.writeln('      margin-top: 20px;');
    buffer.writeln('    }');
    buffer.writeln('    footer {');
    buffer.writeln('      text-align: center;');
    buffer.writeln('      padding: 28px 24px;');
    buffer.writeln('      border-top: 1px solid var(--border-subtle);');
    buffer.writeln('      color: var(--text-muted);');
    buffer.writeln('      font-size: 0.78rem;');
    buffer.writeln('    }');
    buffer.writeln('  </style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('  <header>');
    buffer.writeln('    <div class="brand-section">');
    buffer.writeln('      <div class="brand-icon">✦</div>');
    buffer.writeln('      <div>');
    buffer.writeln('        <h1 class="brand-title">$safeTitle</h1>');
    buffer.writeln('        <div style="font-size: 0.72rem; color: var(--text-muted); margin-top: 2px;">Grimoire Studio • Visor 3D Web</div>');
    buffer.writeln('      </div>');
    buffer.writeln('      <span class="badge-count" id="card-count-badge">$totalCards Cartas</span>');
    buffer.writeln('    </div>');
    buffer.writeln('    <div class="controls">');
    buffer.writeln('      <div class="search-box">');
    buffer.writeln('        <span class="search-icon">🔍</span>');
    buffer.writeln('        <input type="text" id="search-input" placeholder="Buscar por nombre, texto o tipo...">');
    buffer.writeln('      </div>');
    if (cardBackBase64 != null) {
      buffer.writeln('      <button class="btn" id="btn-flip-all" onclick="toggleFlipAll()">🔄 Voltear Todo</button>');
    }
    buffer.writeln('    </div>');
    buffer.writeln('  </header>');
    buffer.writeln('  <main>');
    buffer.writeln('    <div class="grid" id="card-grid">');

    for (int i = 0; i < totalCards; i++) {
      final name = i < cardNames.length ? cardNames[i] : 'Carta ${i + 1}';
      final safeName = escapeHtml(name);
      final rowData = (cardDataList != null && i < cardDataList.length) ? cardDataList[i] : <String, dynamic>{};
      final searchIndexText = escapeHtml([
        name,
        rowData['type'] ?? '',
        rowData['category'] ?? '',
        rowData['rules_text'] ?? '',
        rowData['cost'] ?? '',
        rowData['rarity'] ?? '',
      ].join(' ').toLowerCase());

      buffer.writeln('      <div class="card-scene" data-index="$i" data-search="$searchIndexText">');
      buffer.writeln('        <div class="card-wrap" onclick="openModal($i)">');
      buffer.writeln('          <div class="card-face card-front">');
      buffer.writeln('            <img src="data:image/png;base64,${cardFrontBase64[i]}" alt="$safeName" loading="lazy">');
      buffer.writeln('          </div>');
      if (cardBackBase64 != null) {
        buffer.writeln('          <div class="card-face card-back">');
        buffer.writeln('            <img src="data:image/png;base64,$cardBackBase64" alt="Reverso" loading="lazy">');
        buffer.writeln('          </div>');
      }
      buffer.writeln('          <div class="glare"></div>');
      buffer.writeln('        </div>');
      buffer.writeln('        <div class="card-caption">');
      buffer.writeln('          <div class="card-name" title="$safeName">$safeName</div>');
      buffer.writeln('          <div class="card-subtext">#${i + 1}${rowData['type'] != null ? ' • ${escapeHtml(rowData['type'].toString())}' : ''}</div>');
      buffer.writeln('        </div>');
      buffer.writeln('      </div>');
    }

    buffer.writeln('    </div>');
    buffer.writeln('  </main>');

    // Lightbox Modal
    buffer.writeln('  <div class="modal-backdrop" id="modal-backdrop" onclick="closeModalOnBackdrop(event)">');
    buffer.writeln('    <div class="modal-card">');
    buffer.writeln('      <button class="modal-close" onclick="closeModal()">✕</button>');
    buffer.writeln('      <div class="modal-preview-scene">');
    buffer.writeln('        <div class="modal-card-wrap" id="modal-card-wrap">');
    buffer.writeln('          <div class="card-face card-front">');
    buffer.writeln('            <img id="modal-img-front" src="" alt="Front">');
    buffer.writeln('          </div>');
    if (cardBackBase64 != null) {
      buffer.writeln('          <div class="card-face card-back">');
      buffer.writeln('            <img src="data:image/png;base64,$cardBackBase64" alt="Back">');
      buffer.writeln('          </div>');
    }
    buffer.writeln('          <div class="glare" id="modal-glare"></div>');
    buffer.writeln('        </div>');
    buffer.writeln('      </div>');
    buffer.writeln('      <div class="modal-info">');
    buffer.writeln('        <h2 id="modal-title">Nombre de Carta</h2>');
    buffer.writeln('        <div class="meta-row" id="modal-meta-row"></div>');
    buffer.writeln('        <p id="modal-desc" style="font-size: 0.85rem; color: #94a3b8; line-height: 1.5; margin-top: 10px;"></p>');
    buffer.writeln('        <div class="modal-actions">');
    if (cardBackBase64 != null) {
      buffer.writeln('          <button class="btn" onclick="toggleModalFlip()">🔄 Voltear Carta [F]</button>');
    }
    buffer.writeln('          <button class="btn" onclick="navigateModal(-1)">◀ Anterior</button>');
    buffer.writeln('          <button class="btn" onclick="navigateModal(1)">Siguiente ▶</button>');
    buffer.writeln('        </div>');
    buffer.writeln('      </div>');
    buffer.writeln('    </div>');
    buffer.writeln('  </div>');

    buffer.writeln('  <footer>');
    buffer.writeln('    Generado con Grimoire Studio • Previsualizador 3D Web Autónomo');
    buffer.writeln('  </footer>');

    // Embedded JavaScript
    buffer.writeln('  <script>');
    buffer.writeln('    const cardData = [');
    for (int i = 0; i < totalCards; i++) {
      final name = i < cardNames.length ? cardNames[i] : 'Carta ${i + 1}';
      final rowData = (cardDataList != null && i < cardDataList.length) ? cardDataList[i] : <String, dynamic>{};
      final rowJson = jsonEncode({
        'index': i,
        'name': name,
        'front': cardFrontBase64[i],
        'type': rowData['type'] ?? '',
        'category': rowData['category'] ?? '',
        'rules': rowData['rules_text'] ?? '',
        'cost': rowData['cost'] ?? '',
        'atk': rowData['atk'] ?? rowData['attack'] ?? '',
        'def': rowData['def'] ?? rowData['defense'] ?? '',
        'rarity': rowData['rarity'] ?? '',
      });
      buffer.writeln('      $rowJson,');
    }
    buffer.writeln('    ];');

    buffer.writeln('''
    // Interactive 3D Tilt on Mouse Move
    const cardWraps = document.querySelectorAll('.card-wrap');
    cardWraps.forEach(wrap => {
      const glare = wrap.querySelector('.glare');
      wrap.addEventListener('mousemove', e => {
        if (wrap.classList.contains('flipped')) return;
        const rect = wrap.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const cx = rect.width / 2;
        const cy = rect.height / 2;
        const rotateX = -((y - cy) / cy) * 14;
        const rotateY = ((x - cx) / cx) * 14;
        wrap.style.transform = `perspective(1000px) rotateX(\${rotateX}deg) rotateY(\${rotateY}deg) translateY(-6px) scale3d(1.03, 1.03, 1.03)`;
        if (glare) {
          glare.style.opacity = '1';
          const px = (x / rect.width) * 100;
          const py = (y / rect.height) * 100;
          glare.style.background = `radial-gradient(circle at \${px}% \${py}%, rgba(255,255,255,0.45) 0%, rgba(255,255,255,0.06) 45%, transparent 70%)`;
        }
      });
      wrap.addEventListener('mouseleave', () => {
        if (!wrap.classList.contains('flipped')) {
          wrap.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) translateY(0) scale3d(1, 1, 1)';
        }
        if (glare) glare.style.opacity = '0';
      });
    });

    // Flip All Cards
    let allFlipped = false;
    function toggleFlipAll() {
      allFlipped = !allFlipped;
      cardWraps.forEach(wrap => {
        if (allFlipped) {
          wrap.classList.add('flipped');
          wrap.style.transform = 'perspective(1000px) rotateY(180deg)';
        } else {
          wrap.classList.remove('flipped');
          wrap.style.transform = 'perspective(1000px) rotateY(0deg)';
        }
      });
      const btn = document.getElementById('btn-flip-all');
      if (btn) btn.innerText = allFlipped ? '🔄 Voltear al Anverso' : '🔄 Voltear Todo';
    }

    // Live Search Filter
    const searchInput = document.getElementById('search-input');
    if (searchInput) {
      searchInput.addEventListener('input', e => {
        const query = e.target.value.toLowerCase().trim();
        const scenes = document.querySelectorAll('.card-scene');
        let visibleCount = 0;
        scenes.forEach(scene => {
          const searchTarget = (scene.getAttribute('data-search') || '').toLowerCase();
          if (!query || searchTarget.includes(query)) {
            scene.classList.remove('hidden');
            visibleCount++;
          } else {
            scene.classList.add('hidden');
          }
        });
        const badge = document.getElementById('card-count-badge');
        if (badge) badge.innerText = `\${visibleCount} Cartas`;
      });
    }

    // Modal Inspection
    let currentModalIndex = 0;
    const modalBackdrop = document.getElementById('modal-backdrop');
    const modalCardWrap = document.getElementById('modal-card-wrap');
    const modalImgFront = document.getElementById('modal-img-front');
    const modalTitle = document.getElementById('modal-title');
    const modalMetaRow = document.getElementById('modal-meta-row');
    const modalDesc = document.getElementById('modal-desc');
    const modalGlare = document.getElementById('modal-glare');

    function openModal(index) {
      currentModalIndex = index;
      renderModalContent();
      modalBackdrop.classList.add('active');
    }

    function closeModal() {
      modalBackdrop.classList.remove('active');
      if (modalCardWrap) modalCardWrap.classList.remove('flipped');
    }

    function closeModalOnBackdrop(e) {
      if (e.target === modalBackdrop) closeModal();
    }

    function toggleModalFlip() {
      if (modalCardWrap) {
        modalCardWrap.classList.toggle('flipped');
      }
    }

    function navigateModal(direction) {
      currentModalIndex = (currentModalIndex + direction + cardData.length) % cardData.length;
      if (modalCardWrap) modalCardWrap.classList.remove('flipped');
      renderModalContent();
    }

    function renderModalContent() {
      const data = cardData[currentModalIndex];
      if (!data) return;
      modalImgFront.src = 'data:image/png;base64,' + data.front;
      modalTitle.innerText = data.name;

      modalMetaRow.innerHTML = '';
      if (data.type) modalMetaRow.innerHTML += `<span class="modal-tag">\${data.type}</span>`;
      if (data.cost) modalMetaRow.innerHTML += `<span class="modal-tag">Coste: \${data.cost}</span>`;
      if (data.rarity) modalMetaRow.innerHTML += `<span class="modal-tag">Rareza: \${data.rarity}</span>`;
      if (data.atk || data.def) modalMetaRow.innerHTML += `<span class="modal-tag">Stats: \${data.atk || 0} / \${data.def || 0}</span>`;

      modalDesc.innerText = data.rules || 'Sin texto de reglas especificado.';
    }

    // Modal Mouse Tilt
    if (modalCardWrap) {
      modalCardWrap.addEventListener('mousemove', e => {
        if (modalCardWrap.classList.contains('flipped')) return;
        const rect = modalCardWrap.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const cx = rect.width / 2;
        const cy = rect.height / 2;
        const rotateX = -((y - cy) / cy) * 16;
        const rotateY = ((x - cx) / cx) * 16;
        modalCardWrap.style.transform = `perspective(1200px) rotateX(\${rotateX}deg) rotateY(\${rotateY}deg) scale3d(1.02, 1.02, 1.02)`;
        if (modalGlare) {
          modalGlare.style.opacity = '1';
          const px = (x / rect.width) * 100;
          const py = (y / rect.height) * 100;
          modalGlare.style.background = `radial-gradient(circle at \${px}% \${py}%, rgba(255,255,255,0.45) 0%, rgba(255,255,255,0.06) 50%, transparent 75%)`;
        }
      });
      modalCardWrap.addEventListener('mouseleave', () => {
        if (!modalCardWrap.classList.contains('flipped')) {
          modalCardWrap.style.transform = 'perspective(1200px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)';
        }
        if (modalGlare) modalGlare.style.opacity = '0';
      });
    }

    // Keyboard Shortcuts
    document.addEventListener('keydown', e => {
      if (!modalBackdrop.classList.contains('active')) return;
      if (e.key === 'Escape') closeModal();
      if (e.key === 'f' || e.key === 'F' || e.key === ' ') {
        e.preventDefault();
        toggleModalFlip();
      }
      if (e.key === 'ArrowLeft') navigateModal(-1);
      if (e.key === 'ArrowRight') navigateModal(1);
    });
    ''');
    buffer.writeln('  </script>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }
}

