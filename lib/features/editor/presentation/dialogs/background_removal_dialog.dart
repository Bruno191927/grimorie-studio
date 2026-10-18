import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../../../../core/theme/grimoire_theme.dart';
import '../../services/background_removal_service.dart';
import '../../services/game_folder_service.dart';
import '../providers/editor_provider.dart';

/// Painter that renders a classic transparency checkerboard pattern.
class TransparencyCheckerboardPainter extends CustomPainter {
  final double squareSize;
  final Color color1;
  final Color color2;

  const TransparencyCheckerboardPainter({
    this.squareSize = 10.0,
    this.color1 = const Color(0xFF1E2235),
    this.color2 = const Color(0xFF131522),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final col = (x / squareSize).floor();
        final row = (y / squareSize).floor();
        if ((col + row) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              y,
              math.min(squareSize, size.width - x),
              math.min(squareSize, size.height - y),
            ),
            paint2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dialog for removing image backgrounds with real-time transparency preview,
/// edge flood-fill protection, tolerance tuning, and automatic asset saving.
class BackgroundRemovalDialog extends ConsumerStatefulWidget {
  final File sourceImageFile;
  final String gameName;

  const BackgroundRemovalDialog({
    super.key,
    required this.sourceImageFile,
    required this.gameName,
  });

  static Future<File?> show(
    BuildContext context, {
    required File sourceImageFile,
    required String gameName,
  }) {
    return showDialog<File>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackgroundRemovalDialog(
        sourceImageFile: sourceImageFile,
        gameName: gameName,
      ),
    );
  }

  @override
  ConsumerState<BackgroundRemovalDialog> createState() => _BackgroundRemovalDialogState();
}

class _BackgroundRemovalDialogState extends ConsumerState<BackgroundRemovalDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  img.Image? _originalFullImage;
  img.Image? _previewSourceImage;
  Uint8List? _previewProcessedBytes;

  // Parameters
  double _tolerance = 0.20;
  double _feather = 0.08;
  bool _contiguousOnly = true;
  Color? _customKeyColor;
  Color _detectedBgColor = const Color(0xFFFFFFFF);
  bool _useAutoDetection = true;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await widget.sourceImageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('Formato de imagen no soportado o archivo corrupto.');
      }

      _originalFullImage = decoded;

      // Downsample for real-time 60fps preview if large
      const maxPreviewSize = 420;
      if (decoded.width > maxPreviewSize || decoded.height > maxPreviewSize) {
        if (decoded.width >= decoded.height) {
          _previewSourceImage = img.copyResize(decoded, width: maxPreviewSize);
        } else {
          _previewSourceImage = img.copyResize(decoded, height: maxPreviewSize);
        }
      } else {
        _previewSourceImage = decoded.clone();
      }

      _detectedBgColor = BackgroundRemovalService.detectBackgroundColor(_previewSourceImage!);

      _updatePreviewSync();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _triggerPreviewUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 60), () {
      _updatePreviewSync();
    });
  }

  void _updatePreviewSync() {
    if (_previewSourceImage == null) return;

    final targetColor = _useAutoDetection ? _detectedBgColor : (_customKeyColor ?? _detectedBgColor);
    final options = BackgroundRemovalOptions(
      keyColor: targetColor,
      tolerance: _tolerance,
      feather: _feather,
      contiguousOnly: _contiguousOnly,
    );

    final processed = BackgroundRemovalService.removeBackground(
      _previewSourceImage!,
      options: options,
    );

    final pngBytes = Uint8List.fromList(img.encodePng(processed));
    if (mounted) {
      setState(() {
        _previewProcessedBytes = pngBytes;
      });
    }
  }

  Future<void> _handleSaveAndAssign() async {
    if (_originalFullImage == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final targetColor = _useAutoDetection ? _detectedBgColor : (_customKeyColor ?? _detectedBgColor);

      // Process full-resolution image in compute / background
      final fullBytes = Uint8List.fromList(img.encodePng(_originalFullImage!));
      final resultBytes = await compute(_processImageInBackground, {
        'bytes': fullBytes,
        'keyColor': targetColor.toARGB32(),
        'tolerance': _tolerance,
        'feather': _feather,
        'contiguousOnly': _contiguousOnly,
      });

      // Save to game assets directory
      final assetsDir = GameFolderService.getGameAssetsDir(widget.gameName);
      if (!assetsDir.existsSync()) {
        assetsDir.createSync(recursive: true);
      }

      final baseName = widget.sourceImageFile.uri.pathSegments.last
          .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
          .replaceAll('_nobg', '');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outFileName = '${baseName}_nobg_$timestamp.png';
      final outFile = File('${assetsDir.path}/$outFileName');

      await outFile.writeAsBytes(resultBytes);

      // Assign to active card
      final relativePath = 'assets/$outFileName';
      await ref.read(editorProvider.notifier).assignAssetToActiveCard(relativePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GrimoireTheme.accentEmerald,
            content: Text('✓ Fondo eliminado y guardado en $relativePath'),
          ),
        );
        Navigator.of(context).pop(outFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GrimoireTheme.accentPink,
            content: Text('Error al procesar la imagen: $e'),
          ),
        );
      }
    }
  }

  static Uint8List _processImageInBackground(Map<String, dynamic> params) {
    final bytes = params['bytes'] as Uint8List;
    final keyColorValue = params['keyColor'] as int;
    final tolerance = params['tolerance'] as double;
    final feather = params['feather'] as double;
    final contiguousOnly = params['contiguousOnly'] as bool;

    return BackgroundRemovalService.removeBackgroundFromBytes(
      bytes,
      options: BackgroundRemovalOptions(
        keyColor: Color(keyColorValue),
        tolerance: tolerance,
        feather: feather,
        contiguousOnly: contiguousOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeKeyColor = _useAutoDetection ? _detectedBgColor : (_customKeyColor ?? _detectedBgColor);

    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Container(
        width: 820,
        height: 640,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentIndigo.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_fix_high, color: GrimoireTheme.accentIndigo, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quitar Fondo de Imagen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: GrimoireTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Genera transparencia alfa perfecta para cartas, personajes e iconos.',
                        style: TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: GrimoireTheme.borderSubtle, height: 24),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2, color: GrimoireTheme.accentIndigo),
                          SizedBox(height: 12),
                          Text('Analizando imagen y detectando fondo...', style: TextStyle(fontSize: 12, color: GrimoireTheme.textMuted)),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Text(
                            'Error: $_errorMessage',
                            style: const TextStyle(color: GrimoireTheme.accentPink),
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left: Split Comparison / Transparency View
                            Expanded(
                              flex: 5,
                              child: _buildPreviewArea(),
                            ),
                            const SizedBox(width: 20),

                            // Right: Controls & Presets
                            Expanded(
                              flex: 4,
                              child: _buildControlsArea(activeKeyColor),
                            ),
                          ],
                        ),
            ),
            const Divider(color: GrimoireTheme.borderSubtle, height: 24),

            // Footer Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GrimoireTheme.textSecondary,
                    side: const BorderSide(color: GrimoireTheme.borderSubtle),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GrimoireTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: Text(
                    _isSaving ? 'Procesando en alta resolución...' : 'Guardar y Asignar a la Carta',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isSaving || _isLoading || _previewProcessedBytes == null
                      ? null
                      : _handleSaveAndAssign,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Container(
      decoration: BoxDecoration(
        color: GrimoireTheme.surfacePanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Transparency checkerboard
          const CustomPaint(
            painter: TransparencyCheckerboardPainter(),
          ),

          // Processed image with alpha transparency
          if (_previewProcessedBytes != null)
            Center(
              child: Image.memory(
                _previewProcessedBytes!,
                fit: BoxFit.contain,
              ),
            ),

          // Overlay badge
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.opacity, color: GrimoireTheme.accentEmerald, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Previsualización Alfa',
                    style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsArea(Color activeKeyColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Modo de Detección de Fondo
          const Text(
            'COLOR A ELIMINAR',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: GrimoireTheme.textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),

          // Radio Selection: Auto vs Manual Presets
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _useAutoDetection = true;
                    });
                    _triggerPreviewUpdate();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _useAutoDetection
                          ? GrimoireTheme.accentIndigo.withValues(alpha: 0.2)
                          : GrimoireTheme.surfacePanel,
                      border: Border.all(
                        color: _useAutoDetection ? GrimoireTheme.accentIndigo : GrimoireTheme.borderSubtle,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: _useAutoDetection ? GrimoireTheme.accentIndigo : GrimoireTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Automático',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _useAutoDetection ? Colors.white : GrimoireTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _useAutoDetection = false;
                      _customKeyColor ??= const Color(0xFFFFFFFF);
                    });
                    _triggerPreviewUpdate();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: !_useAutoDetection
                          ? GrimoireTheme.accentIndigo.withValues(alpha: 0.2)
                          : GrimoireTheme.surfacePanel,
                      border: Border.all(
                        color: !_useAutoDetection ? GrimoireTheme.accentIndigo : GrimoireTheme.borderSubtle,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 13,
                          color: !_useAutoDetection ? GrimoireTheme.accentIndigo : GrimoireTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Personalizado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !_useAutoDetection ? Colors.white : GrimoireTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Color preview and presets
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GrimoireTheme.surfacePanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: activeKeyColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _useAutoDetection
                        ? 'Detectado de bordes: #RGB(${((activeKeyColor.r * 255).round().clamp(0, 255))}, ${((activeKeyColor.g * 255).round().clamp(0, 255))}, ${((activeKeyColor.b * 255).round().clamp(0, 255))})'
                        : 'Color clave: #RGB(${((activeKeyColor.r * 255).round().clamp(0, 255))}, ${((activeKeyColor.g * 255).round().clamp(0, 255))}, ${((activeKeyColor.b * 255).round().clamp(0, 255))})',
                    style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Preset color buttons if custom is chosen
          if (!_useAutoDetection) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildColorChip('Blanco', const Color(0xFFFFFFFF)),
                _buildColorChip('Negro', const Color(0xFF000000)),
                _buildColorChip('Verde Croma', const Color(0xFF00FF00)),
                _buildColorChip('Azul Croma', const Color(0xFF0000FF)),
                _buildColorChip('Gris Estudio', const Color(0xFF7F7F7F)),
              ],
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 16),
          const Divider(color: GrimoireTheme.borderSubtle, height: 1),
          const SizedBox(height: 16),

          // Section: Flood-fill Contiguous Protection
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GrimoireTheme.surfacePanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _contiguousOnly
                    ? GrimoireTheme.accentEmerald.withValues(alpha: 0.3)
                    : GrimoireTheme.borderSubtle,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _contiguousOnly,
                  activeColor: GrimoireTheme.accentEmerald,
                  onChanged: (val) {
                    setState(() {
                      _contiguousOnly = val ?? true;
                    });
                    _triggerPreviewUpdate();
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Proteger interior del personaje',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: GrimoireTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _contiguousOnly
                            ? 'Solo elimina el fondo conectado a los bordes exteriores. Los colores similares dentro del personaje (ojos, ropa) se conservan intactos.'
                            : 'Elimina todo el color en cualquier parte de la imagen (modo Chroma-Key global).',
                        style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: GrimoireTheme.borderSubtle, height: 1),
          const SizedBox(height: 16),

          // Section: Tolerance Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tolerancia de Color',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrimoireTheme.textPrimary),
              ),
              Text(
                '${(_tolerance * 100).round()}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrimoireTheme.accentIndigo),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: GrimoireTheme.accentIndigo,
              inactiveTrackColor: GrimoireTheme.surfacePanel,
              thumbColor: GrimoireTheme.accentIndigo,
              trackHeight: 3,
            ),
            child: Slider(
              value: _tolerance,
              min: 0.05,
              max: 0.70,
              divisions: 65,
              onChanged: (val) {
                setState(() => _tolerance = val);
                _triggerPreviewUpdate();
              },
            ),
          ),
          const Text(
            'Aumenta si quedan restos del fondo; reduce si se borran partes del personaje.',
            style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted),
          ),

          const SizedBox(height: 14),

          // Section: Feathering Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Suavizado de Bordes (Feathering)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrimoireTheme.textPrimary),
              ),
              Text(
                '${(_feather * 100).round()}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrimoireTheme.accentEmerald),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: GrimoireTheme.accentEmerald,
              inactiveTrackColor: GrimoireTheme.surfacePanel,
              thumbColor: GrimoireTheme.accentEmerald,
              trackHeight: 3,
            ),
            child: Slider(
              value: _feather,
              min: 0.0,
              max: 0.20,
              divisions: 20,
              onChanged: (val) {
                setState(() => _feather = val);
                _triggerPreviewUpdate();
              },
            ),
          ),
          const Text(
            'Crea un degradado alfa sutil en los bordes para eliminar recortes pixelados.',
            style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildColorChip(String label, Color color) {
    final isSelected = !_useAutoDetection && _customKeyColor?.toARGB32() == color.toARGB32();
    return InkWell(
      onTap: () {
        setState(() {
          _useAutoDetection = false;
          _customKeyColor = color;
        });
        _triggerPreviewUpdate();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? GrimoireTheme.accentIndigo.withValues(alpha: 0.2) : GrimoireTheme.surfacePanel,
          border: Border.all(
            color: isSelected ? GrimoireTheme.accentIndigo : GrimoireTheme.borderSubtle,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
