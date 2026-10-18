import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../../../../core/theme/grimoire_theme.dart';
import '../../services/game_folder_service.dart';
import '../../services/sprite_splitter_service.dart';

class SpriteSheetSplitterDialog extends ConsumerStatefulWidget {
  final String gameName;
  final File? initialFile;

  const SpriteSheetSplitterDialog({
    super.key,
    required this.gameName,
    this.initialFile,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String gameName,
    File? initialFile,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SpriteSheetSplitterDialog(
        gameName: gameName,
        initialFile: initialFile,
      ),
    );
  }

  @override
  ConsumerState<SpriteSheetSplitterDialog> createState() => _SpriteSheetSplitterDialogState();
}

class _SpriteSheetSplitterDialogState extends ConsumerState<SpriteSheetSplitterDialog> {
  File? _currentFile;
  int? _imageWidth;
  int? _imageHeight;

  // Grid vs Fixed Size mode
  bool _isGridMode = true; // true = columns & rows, false = fixed px size

  int _columns = 3;
  int _rows = 3;
  int _fixedWidth = 128;
  int _fixedHeight = 128;

  int _marginX = 0;
  int _marginY = 0;
  int _spacingX = 0;
  int _spacingY = 0;

  late TextEditingController _prefixController;
  bool _skipEmptyCells = true;
  bool _autoTrimEdges = false;
  bool _autoRemoveBg = false;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _currentFile = widget.initialFile;
    String initialPrefix = 'sprite';
    if (_currentFile != null) {
      final name = _currentFile!.uri.pathSegments.last;
      initialPrefix = name.split('.').first;
    }
    _prefixController = TextEditingController(text: initialPrefix);

    if (_currentFile != null) {
      _loadImageInfo(_currentFile!);
    } else {
      _loadFirstAvailableAsset();
    }
  }

  @override
  void dispose() {
    _prefixController.dispose();
    super.dispose();
  }

  void _loadFirstAvailableAsset() {
    final assets = GameFolderService.listGameAssetImages(widget.gameName);
    if (assets.isNotEmpty) {
      _currentFile = assets.first;
      final name = _currentFile!.uri.pathSegments.last;
      _prefixController.text = name.split('.').first;
      _loadImageInfo(_currentFile!);
    }
  }

  void _loadImageInfo(File file) {
    try {
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          _imageWidth = decoded.width;
          _imageHeight = decoded.height;
          if (_fixedWidth > _imageWidth!) {
            _fixedWidth = (_imageWidth! / _columns).round();
          }
          if (_fixedHeight > _imageHeight!) {
            _fixedHeight = (_imageHeight! / _rows).round();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _pickExternalImage() async {
    try {
      final res = await FilePicker.pickFiles(
        dialogTitle: 'Selecciona una imagen o Sprite Sheet',
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (res.isNotEmpty && res.first.path != null) {
        final f = File(res.first.path!);
        setState(() {
          _currentFile = f;
          final name = f.uri.pathSegments.last;
          _prefixController.text = name.split('.').first;
        });
        _loadImageInfo(f);
      }
    } catch (_) {}
  }

  Future<void> _handleSplit() async {
    if (_currentFile == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'Iniciando corte de sprites...';
    });

    final targetDir = GameFolderService.getGameAssetsDir(widget.gameName);

    final options = SpriteSplitOptions(
      columns: _isGridMode ? _columns : 1,
      rows: _isGridMode ? _rows : 1,
      spriteWidth: _isGridMode ? null : _fixedWidth,
      spriteHeight: _isGridMode ? null : _fixedHeight,
      marginX: _marginX,
      marginY: _marginY,
      spacingX: _spacingX,
      spacingY: _spacingY,
      namePrefix: _prefixController.text.trim().isNotEmpty ? _prefixController.text.trim() : 'sprite',
      skipEmptyCells: _skipEmptyCells,
      autoTrimEdges: _autoTrimEdges,
      autoRemoveBackground: _autoRemoveBg,
    );

    final result = await SpriteSplitterService.splitSpriteSheet(
      sourceFile: _currentFile!,
      outputDir: targetDir,
      options: options,
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            _progress = total > 0 ? (current / total) : 0.0;
            _statusMessage = 'Cortando sprite $current de $total...';
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GrimoireTheme.accentEmerald,
            content: Text(
              '¡${result.totalSlices} sprites extraídos y guardados en assets/${widget.gameName}!',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(result.errorMessage ?? 'Error al dividir sprites.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assets = GameFolderService.listGameAssetImages(widget.gameName);

    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Container(
        width: 960,
        height: 680,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.grid_goldenratio, size: 22, color: GrimoireTheme.accentPurple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dividir Imagen en Sprites (Sprite Sheet Cutter)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Extrae iconos, fichas, marcos o personajes individuales y agrégalos a los assets de "${widget.gameName}".',
                        style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                if (!_isProcessing)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: GrimoireTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
            const Divider(color: GrimoireTheme.borderSubtle, height: 24),

            // Content Area (Two Columns: Left Preview, Right Settings)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Side: Interactive Preview with Grid
                  Expanded(
                    flex: 11,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0F1B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GrimoireTheme.borderSubtle),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Source selector toolbar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            color: const Color(0xFF141729),
                            child: Row(
                              children: [
                                const Icon(Icons.image, size: 14, color: GrimoireTheme.accentEmerald),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _currentFile != null &&
                                              assets.any((a) => a.path == _currentFile!.path)
                                          ? _currentFile!.path
                                          : null,
                                      hint: Text(
                                        _currentFile != null
                                            ? _currentFile!.uri.pathSegments.last
                                            : 'Seleccionar imagen...',
                                        style: const TextStyle(fontSize: 11, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF1E2238),
                                      style: const TextStyle(fontSize: 11, color: Colors.white),
                                      items: assets.map((a) {
                                        final name = a.uri.pathSegments.last;
                                        return DropdownMenuItem(
                                          value: a.path,
                                          child: Text(name, overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: _isProcessing
                                          ? null
                                          : (val) {
                                              if (val != null) {
                                                final f = File(val);
                                                setState(() {
                                                  _currentFile = f;
                                                  _prefixController.text =
                                                      f.uri.pathSegments.last.split('.').first;
                                                });
                                                _loadImageInfo(f);
                                              }
                                            },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: GrimoireTheme.accentEmerald,
                                    side: const BorderSide(color: GrimoireTheme.accentEmerald, width: 0.8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.folder_open, size: 12),
                                  label: const Text('Examinar...', style: TextStyle(fontSize: 10)),
                                  onPressed: _isProcessing ? null : _pickExternalImage,
                                ),
                              ],
                            ),
                          ),

                          // Visualizer Canvas
                          Expanded(
                            child: (_imageWidth != null && _imageHeight != null)
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: LayoutBuilder(
                                        builder: (ctx, constraints) {
                                          return _buildInteractiveGridPreview(constraints);
                                        },
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Text(
                                      'Selecciona o sube una imagen para ver la cuadrícula.',
                                      style: TextStyle(color: GrimoireTheme.textMuted, fontSize: 12),
                                    ),
                                  ),
                          ),

                          // Bottom Image Info Bar
                          if (_imageWidth != null && _imageHeight != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              color: const Color(0xFF141729),
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Resolución: $_imageWidth × $_imageHeight px',
                                    style: const TextStyle(fontSize: 10.5, color: GrimoireTheme.textSecondary),
                                  ),
                                  _buildCalculatedSpriteSizeBadge(),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right Side: Settings & Controls
                  Expanded(
                    flex: 9,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mode Selector
                          const Text(
                            'Modo de División:',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isGridMode = true),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _isGridMode
                                          ? GrimoireTheme.accentPurple.withValues(alpha: 0.25)
                                          : const Color(0xFF151828),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _isGridMode ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                                        width: _isGridMode ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Cuadrícula (Cols × Filas)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _isGridMode ? Colors.white : GrimoireTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isGridMode = false),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !_isGridMode
                                          ? GrimoireTheme.accentPurple.withValues(alpha: 0.25)
                                          : const Color(0xFF151828),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: !_isGridMode ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                                        width: !_isGridMode ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Tamaño Fijo (Px)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: !_isGridMode ? Colors.white : GrimoireTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Mode A: Columns & Rows
                          if (_isGridMode) ...[
                            // Quick Presets
                            const Text(
                              'Plantillas Rápidas:',
                              style: TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildPresetChip(2, 2, '2×2 (4)'),
                                _buildPresetChip(3, 3, '3×3 (9)'),
                                _buildPresetChip(4, 4, '4×4 (16)'),
                                _buildPresetChip(5, 5, '5×5 (25)'),
                                _buildPresetChip(6, 4, '6×4 (24)'),
                                _buildPresetChip(8, 8, '8×8 (64)'),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildNumberSpinner(
                                    label: 'Columnas',
                                    value: _columns,
                                    min: 1,
                                    max: 32,
                                    onChanged: (v) => setState(() => _columns = v),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildNumberSpinner(
                                    label: 'Filas',
                                    value: _rows,
                                    min: 1,
                                    max: 32,
                                    onChanged: (v) => setState(() => _rows = v),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Mode B: Fixed Pixel Size
                            Row(
                              children: [
                                Expanded(
                                  child: _buildNumberSpinner(
                                    label: 'Ancho Sprite (px)',
                                    value: _fixedWidth,
                                    min: 8,
                                    max: 2048,
                                    step: 16,
                                    onChanged: (v) => setState(() => _fixedWidth = v),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildNumberSpinner(
                                    label: 'Alto Sprite (px)',
                                    value: _fixedHeight,
                                    min: 8,
                                    max: 2048,
                                    step: 16,
                                    onChanged: (v) => setState(() => _fixedHeight = v),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Margins and Spacing
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131627),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GrimoireTheme.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Margen & Espaciado (Opcional):',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildNumberSpinner(
                                        label: 'Margen X (px)',
                                        value: _marginX,
                                        min: 0,
                                        max: 200,
                                        onChanged: (v) => setState(() => _marginX = v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildNumberSpinner(
                                        label: 'Margen Y (px)',
                                        value: _marginY,
                                        min: 0,
                                        max: 200,
                                        onChanged: (v) => setState(() => _marginY = v),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildNumberSpinner(
                                        label: 'Separación X (px)',
                                        value: _spacingX,
                                        min: 0,
                                        max: 100,
                                        onChanged: (v) => setState(() => _spacingX = v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildNumberSpinner(
                                        label: 'Separación Y (px)',
                                        value: _spacingY,
                                        min: 0,
                                        max: 100,
                                        onChanged: (v) => setState(() => _spacingY = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Naming Prefix
                          const Text(
                            'Prefijo de Nombres de Archivo:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _prefixController,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'ej. icono, gema, ficha...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              suffixText: '_1.png, _2.png...',
                              suffixStyle: const TextStyle(color: GrimoireTheme.textMuted, fontSize: 11),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),

                          const SizedBox(height: 10),

                          // Toggles
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Omitir celdas vacías / transparentes', style: TextStyle(fontSize: 11, color: Colors.white)),
                            subtitle: const Text('No genera sprites para espacios sin píxeles visibles', style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted)),
                            value: _skipEmptyCells,
                            activeColor: GrimoireTheme.accentPurple,
                            onChanged: _isProcessing ? null : (v) => setState(() => _skipEmptyCells = v ?? true),
                          ),

                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Recortar bordes transparentes (Auto-Trim)', style: TextStyle(fontSize: 11, color: Colors.white)),
                            subtitle: const Text('Ajusta el sprite al contenido visible de cada celda', style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted)),
                            value: _autoTrimEdges,
                            activeColor: GrimoireTheme.accentPurple,
                            onChanged: _isProcessing ? null : (v) => setState(() => _autoTrimEdges = v ?? false),
                          ),

                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Row(
                              children: [
                                Icon(Icons.auto_fix_high, size: 13, color: GrimoireTheme.accentEmerald),
                                SizedBox(width: 4),
                                Text('Quitar fondo automáticamente', style: TextStyle(fontSize: 11, color: Colors.white)),
                              ],
                            ),
                            subtitle: const Text('Añade transparencia alfa a sprites con fondo sólido', style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted)),
                            value: _autoRemoveBg,
                            activeColor: GrimoireTheme.accentEmerald,
                            onChanged: _isProcessing ? null : (v) => setState(() => _autoRemoveBg = v ?? false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Progress Bar if running
            if (_isProcessing) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: const Color(0xFF10121E),
                valueColor: const AlwaysStoppedAnimation(GrimoireTheme.accentPurple),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFFD8B4FE)),
              ),
              const SizedBox(height: 6),
            ],

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: GrimoireTheme.textMuted)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GrimoireTheme.accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.content_cut, size: 16),
                  label: const Text('✂️ Cortar y Guardar Sprites', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: (_isProcessing || _imageWidth == null) ? null : _handleSplit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(int cols, int rows, String label) {
    final isSelected = _isGridMode && _columns == cols && _rows == rows;
    return InkWell(
      onTap: () => setState(() {
        _isGridMode = true;
        _columns = cols;
        _rows = rows;
      }),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? GrimoireTheme.accentPurple.withValues(alpha: 0.3) : const Color(0xFF1A1D30),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFFE9D5FF) : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildNumberSpinner({
    required String label,
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted)),
        const SizedBox(height: 3),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D30),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.remove, size: 14, color: Colors.white70),
                onPressed: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$value',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.add, size: 14, color: Colors.white70),
                onPressed: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatedSpriteSizeBadge() {
    if (_imageWidth == null || _imageHeight == null) return const SizedBox.shrink();

    final options = SpriteSplitOptions(
      columns: _isGridMode ? _columns : 1,
      rows: _isGridMode ? _rows : 1,
      spriteWidth: _isGridMode ? null : _fixedWidth,
      spriteHeight: _isGridMode ? null : _fixedHeight,
      marginX: _marginX,
      marginY: _marginY,
      spacingX: _spacingX,
      spacingY: _spacingY,
    );

    final grid = SpriteSplitterService.calculateGrid(
      imageWidth: _imageWidth!,
      imageHeight: _imageHeight!,
      options: options,
    );

    final totalSprites = grid.totalCols * grid.totalRows;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$totalSprites sprites (~${grid.cellWidth}×${grid.cellHeight} px c/u)',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE9D5FF)),
      ),
    );
  }

  Widget _buildInteractiveGridPreview(BoxConstraints constraints) {
    if (_currentFile == null || _imageWidth == null || _imageHeight == null) {
      return const SizedBox.shrink();
    }

    final imgW = _imageWidth!.toDouble();
    final imgH = _imageHeight!.toDouble();

    // Fit inside available viewport
    final scaleX = constraints.maxWidth / imgW;
    final scaleY = constraints.maxHeight / imgH;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.01, 1.0);

    final viewW = imgW * scale;
    final viewH = imgH * scale;

    final options = SpriteSplitOptions(
      columns: _isGridMode ? _columns : 1,
      rows: _isGridMode ? _rows : 1,
      spriteWidth: _isGridMode ? null : _fixedWidth,
      spriteHeight: _isGridMode ? null : _fixedHeight,
      marginX: _marginX,
      marginY: _marginY,
      spacingX: _spacingX,
      spacingY: _spacingY,
    );

    final grid = SpriteSplitterService.calculateGrid(
      imageWidth: _imageWidth!,
      imageHeight: _imageHeight!,
      options: options,
    );

    return SizedBox(
      width: viewW,
      height: viewH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Checkerboard transparency background
          CustomPaint(
            painter: _CheckerboardPainter(),
          ),

          // Render Image
          Image.file(
            _currentFile!,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),

          // Overlay Grid
          CustomPaint(
            painter: _GridOverlayPainter(
              imageWidth: imgW,
              imageHeight: imgH,
              cols: grid.totalCols,
              rows: grid.totalRows,
              cellW: grid.cellWidth.toDouble(),
              cellH: grid.cellHeight.toDouble(),
              marginX: _marginX.toDouble(),
              marginY: _marginY.toDouble(),
              spacingX: _spacingX.toDouble(),
              spacingY: _spacingY.toDouble(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridOverlayPainter extends CustomPainter {
  final double imageWidth;
  final double imageHeight;
  final int cols;
  final int rows;
  final double cellW;
  final double cellH;
  final double marginX;
  final double marginY;
  final double spacingX;
  final double spacingY;

  _GridOverlayPainter({
    required this.imageWidth,
    required this.imageHeight,
    required this.cols,
    required this.rows,
    required this.cellW,
    required this.cellH,
    required this.marginX,
    required this.marginY,
    required this.spacingX,
    required this.spacingY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    final borderPaint = Paint()
      ..color = const Color(0xFF8B5CF6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    int spriteIndex = 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final x = marginX + c * (cellW + spacingX);
        final y = marginY + r * (cellH + spacingY);

        if (x >= imageWidth || y >= imageHeight) continue;

        final w = (x + cellW > imageWidth) ? (imageWidth - x) : cellW;
        final h = (y + cellH > imageHeight) ? (imageHeight - y) : cellH;

        final rect = Rect.fromLTWH(
          x * scaleX,
          y * scaleY,
          w * scaleX,
          h * scaleY,
        );

        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, borderPaint);

        // Draw sprite index badge in cell
        if (rect.width > 22 && rect.height > 16) {
          final textSpan = TextSpan(
            text: '#$spriteIndex',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 3),
              ],
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          )..layout();

          textPainter.paint(canvas, Offset(rect.left + 3, rect.top + 3));
        }

        spriteIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridOverlayPainter oldDelegate) {
    return oldDelegate.cols != cols ||
        oldDelegate.rows != rows ||
        oldDelegate.cellW != cellW ||
        oldDelegate.cellH != cellH ||
        oldDelegate.marginX != marginX ||
        oldDelegate.marginY != marginY ||
        oldDelegate.spacingX != spacingX ||
        oldDelegate.spacingY != spacingY;
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const squareSize = 12.0;
    final paint1 = Paint()..color = const Color(0xFF1E2235);
    final paint2 = Paint()..color = const Color(0xFF141724);

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEven = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        final rect = Rect.fromLTWH(x, y, squareSize, squareSize);
        canvas.drawRect(rect, isEven ? paint1 : paint2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
