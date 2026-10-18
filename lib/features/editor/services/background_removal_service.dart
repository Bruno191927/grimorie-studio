import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart' show Color;
import 'package:image/image.dart' as img;

/// Configuration options for background removal processing.
class BackgroundRemovalOptions {
  /// Target color to remove. If null, automatically detected from image corners/borders.
  final Color? keyColor;

  /// Tolerance for color match (0.0 = exact match, 1.0 = match everything).
  /// Typical values are 0.15 to 0.35.
  final double tolerance;

  /// Soft transition margin for edge feathering (0.0 to 0.2).
  /// Smooths out jagged cutouts.
  final double feather;

  /// If true, only removes background connected to the outer borders (flood-fill).
  /// This prevents removing colors inside the subject (e.g. white shirt or eyes).
  final bool contiguousOnly;

  const BackgroundRemovalOptions({
    this.keyColor,
    this.tolerance = 0.20,
    this.feather = 0.08,
    this.contiguousOnly = true,
  });

  BackgroundRemovalOptions copyWith({
    Color? keyColor,
    double? tolerance,
    double? feather,
    bool? contiguousOnly,
  }) {
    return BackgroundRemovalOptions(
      keyColor: keyColor ?? this.keyColor,
      tolerance: tolerance ?? this.tolerance,
      feather: feather ?? this.feather,
      contiguousOnly: contiguousOnly ?? this.contiguousOnly,
    );
  }
}

/// Service providing local, high-performance background removal and transparency creation.
class BackgroundRemovalService {
  static const double _maxColorDistance = 441.6729559300637; // sqrt(255^2 * 3)

  /// Automatically detects the dominant background color by sampling image corners and borders.
  static Color detectBackgroundColor(img.Image image) {
    final width = image.width;
    final height = image.height;
    if (width <= 0 || height <= 0) return const Color(0xFFFFFFFF);

    final samples = <List<int>>[];

    void addSample(int x, int y) {
      if (x >= 0 && x < width && y >= 0 && y < height) {
        final pixel = image.getPixel(x, y);
        samples.add([pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()]);
      }
    }

    // 1. Four corners
    addSample(0, 0);
    addSample(width - 1, 0);
    addSample(0, height - 1);
    addSample(width - 1, height - 1);

    // 2. Extra border points
    final stepX = max(1, width ~/ 8);
    final stepY = max(1, height ~/ 8);

    for (int x = stepX; x < width - 1; x += stepX) {
      addSample(x, 0);
      addSample(x, height - 1);
    }
    for (int y = stepY; y < height - 1; y += stepY) {
      addSample(0, y);
      addSample(width - 1, y);
    }

    if (samples.isEmpty) return const Color(0xFFFFFFFF);

    // Median or mean of border samples
    int sumR = 0, sumG = 0, sumB = 0;
    for (final s in samples) {
      sumR += s[0];
      sumG += s[1];
      sumB += s[2];
    }

    final avgR = (sumR / samples.length).round().clamp(0, 255);
    final avgG = (sumG / samples.length).round().clamp(0, 255);
    final avgB = (sumB / samples.length).round().clamp(0, 255);

    return Color.fromARGB(255, avgR, avgG, avgB);
  }

  /// Removes the background from raw image bytes (PNG, JPEG, WEBP) and returns PNG bytes with alpha transparency.
  static Uint8List removeBackgroundFromBytes(
    Uint8List inputBytes, {
    BackgroundRemovalOptions options = const BackgroundRemovalOptions(),
  }) {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw ArgumentError('No se pudo decodificar la imagen proporcionada.');
    }

    final processed = removeBackground(decoded, options: options);
    return Uint8List.fromList(img.encodePng(processed));
  }

  /// Core background removal algorithm on an `img.Image`.
  static img.Image removeBackground(
    img.Image source, {
    BackgroundRemovalOptions options = const BackgroundRemovalOptions(),
  }) {
    // Ensure image has an alpha channel (RGBA 4-channel)
    final image = source.numChannels == 4 ? source.clone() : source.convert(numChannels: 4);
    final width = image.width;
    final height = image.height;

    final targetColor = options.keyColor ?? detectBackgroundColor(image);
    final targetR = (targetColor.r * 255.0).round().clamp(0, 255);
    final targetG = (targetColor.g * 255.0).round().clamp(0, 255);
    final targetB = (targetColor.b * 255.0).round().clamp(0, 255);

    final tolerance = options.tolerance.clamp(0.01, 1.0);
    final feather = options.feather.clamp(0.0, 0.5);
    final maxTolerance = tolerance + feather;

    // Helper: calculate normalized Euclidean color distance
    double calcDistance(num r, num g, num b) {
      final dr = r - targetR;
      final dg = g - targetG;
      final db = b - targetB;
      return sqrt(dr * dr + dg * dg + db * db) / _maxColorDistance;
    }

    if (!options.contiguousOnly) {
      // Global chroma-key / color distance replacement
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = image.getPixel(x, y);
          final dist = calcDistance(pixel.r, pixel.g, pixel.b);

          if (dist <= tolerance) {
            image.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 0);
          } else if (dist < maxTolerance && feather > 0) {
            final t = (dist - tolerance) / feather;
            final newAlpha = (t * (pixel.a / 255.0) * 255).round().clamp(0, 255);
            image.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, newAlpha);
          }
        }
      }
      return image;
    }

    // Contiguous Flood-Fill from outer borders (BFS)
    // 0 = unvisited, 1 = background visited, 2 = edge feather visited
    final visited = Uint8List(width * height);
    final queue = Queue<int>();

    // Seed outer borders
    void checkAndEnqueue(int x, int y) {
      final idx = y * width + x;
      if (visited[idx] != 0) return;

      final pixel = image.getPixel(x, y);
      final dist = calcDistance(pixel.r, pixel.g, pixel.b);

      if (dist <= maxTolerance) {
        visited[idx] = dist <= tolerance ? 1 : 2;
        queue.add(idx);
      }
    }

    // Top and Bottom borders
    for (int x = 0; x < width; x++) {
      checkAndEnqueue(x, 0);
      checkAndEnqueue(x, height - 1);
    }
    // Left and Right borders
    for (int y = 0; y < height; y++) {
      checkAndEnqueue(0, y);
      checkAndEnqueue(width - 1, y);
    }

    // Process BFS queue
    while (queue.isNotEmpty) {
      final currentIdx = queue.removeFirst();
      final cx = currentIdx % width;
      final cy = currentIdx ~/ width;
      final currentType = visited[currentIdx];

      // If this is a feather edge (type 2), don't propagate further into subject
      if (currentType == 2) continue;

      // 4-neighborhood
      final neighbors = [
        if (cx > 0) currentIdx - 1,
        if (cx < width - 1) currentIdx + 1,
        if (cy > 0) currentIdx - width,
        if (cy < height - 1) currentIdx + width,
      ];

      for (final nIdx in neighbors) {
        if (visited[nIdx] == 0) {
          final nx = nIdx % width;
          final ny = nIdx ~/ width;
          final pixel = image.getPixel(nx, ny);
          final dist = calcDistance(pixel.r, pixel.g, pixel.b);

          if (dist <= maxTolerance) {
            visited[nIdx] = dist <= tolerance ? 1 : 2;
            queue.add(nIdx);
          }
        }
      }
    }

    // Apply transparency based on visited map
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = y * width + x;
        final mark = visited[idx];
        if (mark == 1) {
          final pixel = image.getPixel(x, y);
          image.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 0);
        } else if (mark == 2) {
          final pixel = image.getPixel(x, y);
          final dist = calcDistance(pixel.r, pixel.g, pixel.b);
          if (dist <= tolerance) {
            image.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 0);
          } else if (dist < maxTolerance && feather > 0) {
            final t = (dist - tolerance) / feather;
            final newAlpha = (t * (pixel.a / 255.0) * 255).round().clamp(0, 255);
            image.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, newAlpha);
          }
        }
      }
    }

    return image;
  }

  /// Processes an image file, saves the transparent result to [outputFile] or generates a `_nobg.png` sibling file.
  static Future<File> removeBackgroundFromFile(
    File inputFile, {
    File? outputFile,
    BackgroundRemovalOptions options = const BackgroundRemovalOptions(),
  }) async {
    if (!await inputFile.exists()) {
      throw ArgumentError('El archivo de entrada no existe: ${inputFile.path}');
    }

    final bytes = await inputFile.readAsBytes();
    final resultBytes = removeBackgroundFromBytes(bytes, options: options);

    final target = outputFile ??
        File('${inputFile.parent.path}/${inputFile.uri.pathSegments.last.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}_nobg.png');

    await target.writeAsBytes(resultBytes);
    return target;
  }
}
