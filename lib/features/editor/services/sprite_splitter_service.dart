import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'background_removal_service.dart';

/// Configuration options for slicing a sprite sheet into individual sprites.
class SpriteSplitOptions {
  final int columns;
  final int rows;
  final int? spriteWidth;
  final int? spriteHeight;
  final int marginX;
  final int marginY;
  final int spacingX;
  final int spacingY;
  final String namePrefix;
  final bool skipEmptyCells;
  final bool autoTrimEdges;
  final bool autoRemoveBackground;

  const SpriteSplitOptions({
    this.columns = 2,
    this.rows = 2,
    this.spriteWidth,
    this.spriteHeight,
    this.marginX = 0,
    this.marginY = 0,
    this.spacingX = 0,
    this.spacingY = 0,
    this.namePrefix = 'sprite',
    this.skipEmptyCells = true,
    this.autoTrimEdges = false,
    this.autoRemoveBackground = false,
  });

  SpriteSplitOptions copyWith({
    int? columns,
    int? rows,
    int? spriteWidth,
    int? spriteHeight,
    int? marginX,
    int? marginY,
    int? spacingX,
    int? spacingY,
    String? namePrefix,
    bool? skipEmptyCells,
    bool? autoTrimEdges,
    bool? autoRemoveBackground,
  }) {
    return SpriteSplitOptions(
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      spriteWidth: spriteWidth ?? this.spriteWidth,
      spriteHeight: spriteHeight ?? this.spriteHeight,
      marginX: marginX ?? this.marginX,
      marginY: marginY ?? this.marginY,
      spacingX: spacingX ?? this.spacingX,
      spacingY: spacingY ?? this.spacingY,
      namePrefix: namePrefix ?? this.namePrefix,
      skipEmptyCells: skipEmptyCells ?? this.skipEmptyCells,
      autoTrimEdges: autoTrimEdges ?? this.autoTrimEdges,
      autoRemoveBackground: autoRemoveBackground ?? this.autoRemoveBackground,
    );
  }
}

/// Result of a sprite slicing operation.
class SpriteSplitResult {
  final bool success;
  final List<File> createdFiles;
  final String? errorMessage;
  final int totalSlices;

  const SpriteSplitResult({
    required this.success,
    this.createdFiles = const [],
    this.errorMessage,
    this.totalSlices = 0,
  });
}

/// Service providing high-speed slicing and extraction of sprites from sprite sheets.
class SpriteSplitterService {
  /// Slices an image sprite sheet into individual sprites and saves them into [outputDir].
  static Future<SpriteSplitResult> splitSpriteSheet({
    required File sourceFile,
    required Directory outputDir,
    required SpriteSplitOptions options,
    void Function(int current, int total)? onProgress,
  }) async {
    if (!await sourceFile.exists()) {
      return const SpriteSplitResult(
        success: false,
        errorMessage: 'El archivo de imagen no existe.',
      );
    }

    try {
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final bytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return const SpriteSplitResult(
          success: false,
          errorMessage: 'No se pudo decodificar la imagen seleccionada.',
        );
      }

      final imgWidth = decoded.width;
      final imgHeight = decoded.height;

      int cols = options.columns.clamp(1, 200);
      int rows = options.rows.clamp(1, 200);

      int cellW;
      int cellH;

      if (options.spriteWidth != null &&
          options.spriteWidth! > 0 &&
          options.spriteHeight != null &&
          options.spriteHeight! > 0) {
        cellW = options.spriteWidth!;
        cellH = options.spriteHeight!;
        final usableW = imgWidth - (options.marginX * 2);
        final usableH = imgHeight - (options.marginY * 2);
        cols = math.max(1, (usableW + options.spacingX) ~/ (cellW + options.spacingX));
        rows = math.max(1, (usableH + options.spacingY) ~/ (cellH + options.spacingY));
      } else {
        final totalSpacingX = (cols - 1) * options.spacingX;
        final totalSpacingY = (rows - 1) * options.spacingY;
        final usableW = imgWidth - (options.marginX * 2) - totalSpacingX;
        final usableH = imgHeight - (options.marginY * 2) - totalSpacingY;

        cellW = math.max(1, usableW ~/ cols);
        cellH = math.max(1, usableH ~/ rows);
      }

      final createdFiles = <File>[];
      final totalPossible = cols * rows;
      int processedCount = 0;
      int spriteNumber = 1;

      final sanitizedPrefix = options.namePrefix.trim().replaceAll(RegExp(r'[^\w\-]'), '_');
      final prefix = sanitizedPrefix.isNotEmpty ? sanitizedPrefix : 'sprite';

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final x = options.marginX + c * (cellW + options.spacingX);
          final y = options.marginY + r * (cellH + options.spacingY);

          if (x >= imgWidth || y >= imgHeight) continue;

          final w = math.min(cellW, imgWidth - x);
          final h = math.min(cellH, imgHeight - y);
          if (w <= 0 || h <= 0) continue;

          var cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);

          // Check if cell is empty (all transparent or uniform background)
          if (options.skipEmptyCells && _isCellEmpty(cropped)) {
            processedCount++;
            onProgress?.call(processedCount, totalPossible);
            continue;
          }

          if (options.autoRemoveBackground) {
            try {
              const bgOpt = BackgroundRemovalOptions();
              cropped = BackgroundRemovalService.removeBackground(cropped, options: bgOpt);
            } catch (_) {}
          }

          if (options.autoTrimEdges) {
            try {
              cropped = _trimTransparentEdges(cropped);
            } catch (_) {}
          }

          final pngBytes = img.encodePng(cropped);
          final fileName = '${prefix}_$spriteNumber.png';
          final targetFile = File('${outputDir.path}/$fileName');
          await targetFile.writeAsBytes(pngBytes);
          createdFiles.add(targetFile);

          spriteNumber++;
          processedCount++;
          onProgress?.call(processedCount, totalPossible);
        }
      }

      return SpriteSplitResult(
        success: true,
        createdFiles: createdFiles,
        totalSlices: createdFiles.length,
      );
    } catch (e) {
      debugPrint('SpriteSplitterService error: $e');
      return SpriteSplitResult(
        success: false,
        errorMessage: 'Error dividiendo sprite sheet: $e',
      );
    }
  }

  /// Calculates the grid dimensions without slicing.
  static ({int cellWidth, int cellHeight, int totalCols, int totalRows}) calculateGrid({
    required int imageWidth,
    required int imageHeight,
    required SpriteSplitOptions options,
  }) {
    int cols = options.columns.clamp(1, 200);
    int rows = options.rows.clamp(1, 200);

    int cellW;
    int cellH;

    if (options.spriteWidth != null &&
        options.spriteWidth! > 0 &&
        options.spriteHeight != null &&
        options.spriteHeight! > 0) {
      cellW = options.spriteWidth!;
      cellH = options.spriteHeight!;
      final usableW = imageWidth - (options.marginX * 2);
      final usableH = imageHeight - (options.marginY * 2);
      cols = math.max(1, (usableW + options.spacingX) ~/ (cellW + options.spacingX));
      rows = math.max(1, (usableH + options.spacingY) ~/ (cellH + options.spacingY));
    } else {
      final totalSpacingX = (cols - 1) * options.spacingX;
      final totalSpacingY = (rows - 1) * options.spacingY;
      final usableW = imageWidth - (options.marginX * 2) - totalSpacingX;
      final usableH = imageHeight - (options.marginY * 2) - totalSpacingY;

      cellW = math.max(1, usableW ~/ cols);
      cellH = math.max(1, usableH ~/ rows);
    }

    return (
      cellWidth: cellW,
      cellHeight: cellH,
      totalCols: cols,
      totalRows: rows,
    );
  }

  static bool _isCellEmpty(img.Image image) {
    int visibleCount = 0;
    final totalPixels = image.width * image.height;
    if (totalPixels == 0) return true;

    // Check alpha channel
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        if (pixel.a > 15) {
          visibleCount++;
          // If more than 2% of pixels are non-transparent, it's not empty
          if (visibleCount > totalPixels * 0.02) {
            return false;
          }
        }
      }
    }
    return visibleCount <= (totalPixels * 0.02);
  }

  static img.Image _trimTransparentEdges(img.Image image) {
    int minX = image.width;
    int minY = image.height;
    int maxX = -1;
    int maxY = -1;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).a > 15) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < minX || maxY < minY) {
      return image; // Empty or all transparent
    }

    final trimW = (maxX - minX + 1);
    final trimH = (maxY - minY + 1);
    return img.copyCrop(image, x: minX, y: minY, width: trimW, height: trimH);
  }
}
