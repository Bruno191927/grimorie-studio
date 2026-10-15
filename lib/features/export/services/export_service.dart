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

  /// Exports a list of card image byte buffers to a multi-page PDF ready for printing
  static Future<File> exportCardsToPdf({
    required List<Uint8List> cardImages,
    required String fileName,
  }) async {
    final pdf = pw.Document();

    for (final bytes in cardImages) {
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            AppConstants.pokerWidthMm * PdfPageFormat.mm,
            AppConstants.pokerHeightMm * PdfPageFormat.mm,
            marginAll: 0,
          ),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final file = File('${outputDir.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Exports card image byte buffers into a ZIP file with high-res PNGs
  static Future<File> exportCardsToZip({
    required List<Uint8List> cardImages,
    required List<String> cardNames,
    required String zipName,
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

    final zipBytes = ZipEncoder().encode(archive);
    final outputDir = await getApplicationDocumentsDirectory();
    final file = File('${outputDir.path}/$zipName.zip');
    await file.writeAsBytes(zipBytes);
    return file;
  }
}
