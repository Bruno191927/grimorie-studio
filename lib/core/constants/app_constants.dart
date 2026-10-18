class AppConstants {
  static const String appName = 'Grimoire Studio';
  static const String appVersion = '1.0.0';

  // Standard Card Sizes in Millimeters
  static const double pokerWidthMm = 63.5;
  static const double pokerHeightMm = 88.9;

  static const double bridgeWidthMm = 57.0;
  static const double bridgeHeightMm = 88.9;

  static const double tarotWidthMm = 70.0;
  static const double tarotHeightMm = 120.0;

  static const double squareWidthMm = 70.0;
  static const double squareHeightMm = 70.0;

  // DPI conversion constants
  // 1 inch = 25.4 mm
  // At 300 DPI, 1 mm = 300 / 25.4 ≈ 11.811 pixels
  static const double pixelsPerMmAt300Dpi = 300.0 / 25.4;

  // On-screen canvas base scale (approx 4 pixels per mm for smooth responsive display)
  static const double previewScale = 4.0;

  // Export pixel ratio for RepaintBoundary
  // Flutter canvas base resolution at previewScale multiplied by this ratio yields ~300 DPI
  static const double exportPixelRatio = 3.5;

  // AI Service Defaults
  static const String defaultComfyUiUrl = 'http://127.0.0.1:8188';
  static const String defaultOllamaUrl = 'http://127.0.0.1:11434';
}
