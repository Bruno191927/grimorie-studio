import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:image/image.dart' as img;
import '../../../../core/theme/grimoire_theme.dart';
import '../../models/playtest_models.dart';
import '../../services/playmat_service.dart';

class CustomPlaymatDialog extends StatefulWidget {
  final String gameName;
  final CustomPlaymatConfig initialConfig;
  final Function(CustomPlaymatConfig) onApply;

  const CustomPlaymatDialog({
    super.key,
    required this.gameName,
    required this.initialConfig,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required String gameName,
    required CustomPlaymatConfig initialConfig,
    required Function(CustomPlaymatConfig) onApply,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CustomPlaymatDialog(
        gameName: gameName,
        initialConfig: initialConfig,
        onApply: onApply,
      ),
    );
  }

  @override
  State<CustomPlaymatDialog> createState() => _CustomPlaymatDialogState();
}

class _CustomPlaymatDialogState extends State<CustomPlaymatDialog> {
  late bool _isEnabled;
  String? _imagePath;
  late BoxFit _fit;
  late double _overlayDim;
  late bool _showDivisionLines;
  late double _divisionLinesOpacity;
  late double _tableWidth;
  late double _tableHeight;
  bool _isDragging = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialConfig.isEnabled;
    _imagePath = widget.initialConfig.imagePath;
    _fit = widget.initialConfig.fit;
    _overlayDim = widget.initialConfig.overlayDim;
    _showDivisionLines = widget.initialConfig.showDivisionLines;
    _divisionLinesOpacity = widget.initialConfig.divisionLinesOpacity;
    _tableWidth = widget.initialConfig.tableWidth;
    _tableHeight = widget.initialConfig.tableHeight;
  }

  Future<void> _pickImage() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
      );

      if (files.isNotEmpty) {
        final path = files.first.path;
        if (path != null) {
          _processSelectedImagePath(path);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error al seleccionar imagen: $e'),
          ),
        );
      }
    }
  }

  Future<void> _processSelectedImagePath(String sourcePath) async {
    setState(() {
      _imagePath = sourcePath;
      _isEnabled = true;
    });

    // Auto-detectar aspecto si es posible
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null && mounted) {
        final imgW = decoded.width.toDouble();
        final imgH = decoded.height.toDouble();
        if (imgW > 0 && imgH > 0) {
          // Ajustar proporcionalmente tomando 2200 de referencia
          final ratio = imgW / imgH;
          double newW = 2200.0;
          double newH = (2200.0 / ratio).clamp(1000.0, 3000.0);
          setState(() {
            _tableWidth = newW;
            _tableHeight = newH;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    String? finalPath = _imagePath;
    if (_imagePath != null && _imagePath!.isNotEmpty) {
      // Importar de forma segura dentro de la carpeta del juego
      final imported = await PlaymatService.importPlaymatImage(widget.gameName, _imagePath!);
      if (imported != null) {
        finalPath = imported;
      }
    }

    final newConfig = CustomPlaymatConfig(
      isEnabled: _isEnabled && finalPath != null,
      imagePath: finalPath,
      fit: _fit,
      overlayDim: _overlayDim,
      showDivisionLines: _showDivisionLines,
      divisionLinesOpacity: _divisionLinesOpacity,
      tableWidth: _tableWidth,
      tableHeight: _tableHeight,
    );

    await PlaymatService.saveConfig(widget.gameName, newConfig);

    if (mounted) {
      widget.onApply(newConfig);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GrimoireTheme.accentPurple,
          content: Text('Mesa de juego personalizada aplicada y guardada.'),
        ),
      );
    }
  }

  void _handleReset() {
    setState(() {
      _isEnabled = false;
      _imagePath = null;
      _fit = BoxFit.cover;
      _overlayDim = 0.2;
      _showDivisionLines = true;
      _divisionLinesOpacity = 0.7;
      _tableWidth = 2200.0;
      _tableHeight = 1400.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasValidImage = _imagePath != null && File(_imagePath!).existsSync();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 820,
        constraints: const BoxConstraints(maxHeight: 780),
        decoration: BoxDecoration(
          color: const Color(0xFF111422),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF171A2E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.table_bar, color: GrimoireTheme.accentPurple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mesa de Juego Personalizada (Tapete / Playmat)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Juego: ${widget.gameName.isEmpty || widget.gameName == "All" ? "Global / General" : widget.gameName}',
                          style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isEnabled,
                    activeThumbColor: GrimoireTheme.accentPurple,
                    onChanged: (val) {
                      setState(() {
                        _isEnabled = val;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: GrimoireTheme.textMuted, size: 20),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: DropTarget(
                onDragEntered: (_) => setState(() => _isDragging = true),
                onDragExited: (_) => setState(() => _isDragging = false),
                onDragDone: (detail) {
                  setState(() => _isDragging = false);
                  if (detail.files.isNotEmpty) {
                    final first = detail.files.first;
                    _processSelectedImagePath(first.path);
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Interactive Preview & Upload zone
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'VISTA PREVIA DEL TAPETE',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: GrimoireTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: _buildPreviewCanvas(hasValidImage),
                            ),
                            const SizedBox(height: 12),
                            // Upload Button / Drag target bar
                            _buildUploadZone(hasValidImage),
                          ],
                        ),
                      ),
                    ),

                    // Divider
                    const VerticalDivider(width: 1, color: GrimoireTheme.borderSubtle),

                    // Right Column: Controls & Settings
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CONFIGURACIÓN VISUAL',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: GrimoireTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Fit Mode Selector
                            const Text(
                              'Ajuste de la Imagen',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            SegmentedButton<BoxFit>(
                              segments: const [
                                ButtonSegment(
                                  value: BoxFit.cover,
                                  label: Text('Cover', style: TextStyle(fontSize: 11)),
                                  tooltip: 'Rellenar recortando excedente',
                                ),
                                ButtonSegment(
                                  value: BoxFit.contain,
                                  label: Text('Contain', style: TextStyle(fontSize: 11)),
                                  tooltip: 'Ajustar completa sin recortar',
                                ),
                                ButtonSegment(
                                  value: BoxFit.fill,
                                  label: Text('Estirar', style: TextStyle(fontSize: 11)),
                                  tooltip: 'Estirar a proporciones de la mesa',
                                ),
                              ],
                              selected: {_fit},
                              onSelectionChanged: (set) {
                                setState(() => _fit = set.first);
                              },
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return GrimoireTheme.accentPurple;
                                  }
                                  return GrimoireTheme.surfacePanel;
                                }),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Dimming Overlay Slider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Oscurecimiento (Tinte)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                                Text(
                                  '${(_overlayDim * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: GrimoireTheme.accentPurple,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Atenúa el fondo para que las cartas y texto resalten mejor.',
                              style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                            ),
                            Slider(
                              value: _overlayDim,
                              min: 0.0,
                              max: 0.8,
                              divisions: 16,
                              activeColor: GrimoireTheme.accentPurple,
                              inactiveColor: GrimoireTheme.surfaceElevated,
                              onChanged: (val) => setState(() => _overlayDim = val),
                            ),

                            const SizedBox(height: 12),

                            // Division Lines Switch & Opacity
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Líneas de división de mesa',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                                Switch(
                                  value: _showDivisionLines,
                                  activeThumbColor: GrimoireTheme.accentPurple,
                                  onChanged: (val) => setState(() => _showDivisionLines = val),
                                ),
                              ],
                            ),
                            if (_showDivisionLines) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Opacidad de líneas',
                                    style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                                  ),
                                  Text(
                                    '${(_divisionLinesOpacity * 100).toInt()}%',
                                    style: const TextStyle(fontSize: 10.5, color: GrimoireTheme.accentPurple),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _divisionLinesOpacity,
                                min: 0.1,
                                max: 1.0,
                                divisions: 9,
                                activeColor: GrimoireTheme.accentPurple,
                                inactiveColor: GrimoireTheme.surfaceElevated,
                                onChanged: (val) => setState(() => _divisionLinesOpacity = val),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Table Dimensions Presets
                            const Text(
                              'Dimensiones del Lienzo',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildDimensionChip('Estándar TCG (2200x1400)', 2200.0, 1400.0),
                                _buildDimensionChip('Duelo Extendido (2200x2000)', 2200.0, 2000.0),
                                _buildDimensionChip('Tablero Cuadrado (2000x2000)', 2000.0, 2000.0),
                              ],
                            ),

                            const SizedBox(height: 12),
                            Text(
                              'Tamaño actual: ${_tableWidth.toInt()} × ${_tableHeight.toInt()} px',
                              style: const TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF171A2E),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: GrimoireTheme.borderSubtle)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Restablecer'),
                    onPressed: _handleReset,
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: GrimoireTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Guardar y Aplicar'),
                    onPressed: _isSaving ? null : _handleSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCanvas(bool hasValidImage) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDragging ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
          width: _isDragging ? 2.0 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: AspectRatio(
          aspectRatio: _tableWidth / _tableHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Playmat Image or Placeholder
              if (hasValidImage && _isEnabled)
                Image.file(
                  File(_imagePath!),
                  fit: _fit,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                )
              else
                _buildPlaceholder(),

              // Dimming Overlay
              if (_isEnabled && hasValidImage && _overlayDim > 0)
                Container(
                  color: Colors.black.withValues(alpha: _overlayDim),
                ),

              // Mock Division Lines
              if (_showDivisionLines)
                Opacity(
                  opacity: _divisionLinesOpacity,
                  child: CustomPaint(
                    painter: _MockDivisionPainter(),
                  ),
                ),

              // Sample Card in Preview
              Center(
                child: Container(
                  width: 55,
                  height: 77,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2338),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: GrimoireTheme.accentPurple, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.style, size: 16, color: GrimoireTheme.accentPurple),
                      SizedBox(height: 2),
                      Text('Carta', style: TextStyle(fontSize: 8, color: Colors.white70)),
                    ],
                  ),
                ),
              ),

              if (_isDragging)
                Container(
                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.35),
                  child: const Center(
                    child: Text(
                      'Suelta la imagen aquí',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            Color(0xFF16152B),
            Color(0xFF0D0E1A),
            Color(0xFF080912),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 36, color: GrimoireTheme.textMuted.withValues(alpha: 0.6)),
            const SizedBox(height: 6),
            const Text(
              'Sin imagen personalizada cargada\n(Usa el botón abajo o arrastra un archivo)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadZone(bool hasValidImage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: GrimoireTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasValidImage
                      ? File(_imagePath!).uri.pathSegments.last
                      : 'Arrastra una imagen o selecciónala desde tu equipo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: hasValidImage ? FontWeight.bold : FontWeight.normal,
                    color: hasValidImage ? Colors.white : GrimoireTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Formatos soportados: PNG, JPG, WEBP, BMP',
                  style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasValidImage) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              tooltip: 'Quitar imagen',
              onPressed: () {
                setState(() {
                  _imagePath = null;
                });
              },
            ),
            const SizedBox(width: 4),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GrimoireTheme.surfacePanel,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.folder_open, size: 16),
            label: Text(hasValidImage ? 'Cambiar' : 'Examinar...'),
            onPressed: _pickImage,
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionChip(String label, double w, double h) {
    final isSelected = (_tableWidth - w).abs() < 1 && (_tableHeight - h).abs() < 1;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10.5)),
      selected: isSelected,
      selectedColor: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
      backgroundColor: GrimoireTheme.surfacePanel,
      side: BorderSide(color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle),
      onSelected: (val) {
        if (val) {
          setState(() {
            _tableWidth = w;
            _tableHeight = h;
          });
        }
      },
    );
  }
}

class _MockDivisionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x408B5CF6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Horizontal center line
    final cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), linePaint);

    // Center circle
    final center = Offset(size.width / 2, cy);
    canvas.drawCircle(center, 18, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
