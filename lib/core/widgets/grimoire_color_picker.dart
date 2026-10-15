import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/grimoire_theme.dart';

/// Interactive Photoshop/Figma-style Color Picker for Grimoire Studio.
/// Supports 2D Saturation-Value canvas, Hue slider, Alpha slider, Hex, RGB inputs,
/// and fantasy TCG color palettes.
class GrimoireColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final bool allowTransparent;
  final String? title;

  const GrimoireColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    this.allowTransparent = true,
    this.title,
  });

  @override
  State<GrimoireColorPicker> createState() => _GrimoireColorPickerState();
}

class _GrimoireColorPickerState extends State<GrimoireColorPicker> {
  late double _hue; // 0.0 - 360.0
  late double _saturation; // 0.0 - 1.0
  late double _value; // 0.0 - 1.0
  late double _alpha; // 0.0 - 1.0

  late TextEditingController _hexController;
  late TextEditingController _rController;
  late TextEditingController _gController;
  late TextEditingController _bController;

  bool _isUpdatingInternally = false;

  @override
  void initState() {
    super.initState();
    _initFromColor(widget.initialColor);

    _hexController = TextEditingController(text: _formatHex(_currentColor));
    _rController = TextEditingController(text: (_currentColor.r * 255).round().toString());
    _gController = TextEditingController(text: (_currentColor.g * 255).round().toString());
    _bController = TextEditingController(text: (_currentColor.b * 255).round().toString());
  }

  void _initFromColor(Color color) {
    _alpha = color.a;
    if (color == Colors.transparent || color.a == 0) {
      _hue = 0.0;
      _saturation = 0.0;
      _value = 0.0;
    } else {
      final hsv = HSVColor.fromColor(color.withValues(alpha: 1.0));
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
    }
  }

  Color get _currentColor {
    if (_alpha == 0 && widget.allowTransparent) {
      return Colors.transparent;
    }
    return HSVColor.fromAHSV(_alpha, _hue, _saturation, _value).toColor();
  }

  String _formatHex(Color color) {
    if (color == Colors.transparent || color.a == 0) return '#00000000';
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  void _syncControllers() {
    if (_isUpdatingInternally) return;
    _isUpdatingInternally = true;
    final c = _currentColor;
    _hexController.text = _formatHex(c);
    _rController.text = (c.r * 255).round().toString();
    _gController.text = (c.g * 255).round().toString();
    _bController.text = (c.b * 255).round().toString();
    _isUpdatingInternally = false;
  }

  void _notifyColorChange() {
    _syncControllers();
    widget.onColorChanged(_currentColor);
  }

  void _updateSatVal(Offset localPos, Size size) {
    setState(() {
      _saturation = (localPos.dx / size.width).clamp(0.0, 1.0);
      _value = (1.0 - (localPos.dy / size.height)).clamp(0.0, 1.0);
      if (_alpha == 0) _alpha = 1.0;
    });
    _notifyColorChange();
  }

  void _updateHue(double localX, double width) {
    setState(() {
      _hue = ((localX / width) * 360.0).clamp(0.0, 360.0);
      if (_hue >= 360.0) _hue = 0.0;
      if (_alpha == 0) _alpha = 1.0;
    });
    _notifyColorChange();
  }

  void _updateAlpha(double localX, double width) {
    setState(() {
      _alpha = (localX / width).clamp(0.0, 1.0);
    });
    _notifyColorChange();
  }

  void _applyColor(Color color) {
    setState(() {
      _initFromColor(color);
    });
    _notifyColorChange();
  }

  void _handleHexSubmitted(String val) {
    var clean = val.trim().replaceAll('#', '');
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    if (clean.length == 8) {
      final parsedInt = int.tryParse(clean, radix: 16);
      if (parsedInt != null) {
        _applyColor(Color(parsedInt));
      }
    }
  }

  void _handleRgbSubmitted() {
    final r = int.tryParse(_rController.text)?.clamp(0, 255) ?? 0;
    final g = int.tryParse(_gController.text)?.clamp(0, 255) ?? 0;
    final b = int.tryParse(_bController.text)?.clamp(0, 255) ?? 0;
    final a = (_alpha * 255).round().clamp(0, 255);
    _applyColor(Color.fromARGB(a, r, g, b));
  }

  @override
  void dispose() {
    _hexController.dispose();
    _rController.dispose();
    _gController.dispose();
    _bController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pureHueColor = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();
    final currentColor = _currentColor;
    final isTransparent = currentColor == Colors.transparent || currentColor.a == 0;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Title
          if (widget.title != null) ...[
            Row(
              children: [
                const Icon(Icons.palette_outlined, size: 16, color: GrimoireTheme.accentPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.surfacePanel,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GrimoireTheme.borderSubtle),
                  ),
                  child: Text(
                    isTransparent ? 'Transparente' : '${(currentColor.a * 100).toInt()}% Opacidad',
                    style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // 2D Saturation-Value Canvas
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 135,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  final thumbX = (_saturation * width).clamp(0.0, width);
                  final thumbY = ((1.0 - _value) * height).clamp(0.0, height);

                  return GestureDetector(
                    onPanDown: (d) => _updateSatVal(d.localPosition, Size(width, height)),
                    onPanUpdate: (d) => _updateSatVal(d.localPosition, Size(width, height)),
                    child: Stack(
                      children: [
                        // Base pure hue
                        Container(color: pureHueColor),

                        // Horizontal White -> Transparent gradient (Saturation)
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white, Colors.transparent],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),

                        // Vertical Transparent -> Black gradient (Value)
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),

                        // Drag Thumb
                        Positioned(
                          left: thumbX - 9,
                          top: thumbY - 9,
                          child: IgnorePointer(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentColor.withValues(alpha: 1.0),
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Rainbow Hue Slider
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 18,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final thumbX = ((_hue / 360.0) * width).clamp(0.0, width);

                  return GestureDetector(
                    onPanDown: (d) => _updateHue(d.localPosition.dx, width),
                    onPanUpdate: (d) => _updateHue(d.localPosition.dx, width),
                    child: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFF0000),
                                Color(0xFFFFFF00),
                                Color(0xFF00FF00),
                                Color(0xFF00FFFF),
                                Color(0xFF0000FF),
                                Color(0xFFFF00FF),
                                Color(0xFFFF0000),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: thumbX - 8,
                          top: 1,
                          child: IgnorePointer(
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: pureHueColor,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 3),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Opacity / Alpha Slider
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 18,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final thumbX = (_alpha * width).clamp(0.0, width);

                  return GestureDetector(
                    onPanDown: (d) => _updateAlpha(d.localPosition.dx, width),
                    onPanUpdate: (d) => _updateAlpha(d.localPosition.dx, width),
                    child: Stack(
                      children: [
                        // Checkerboard / Dark base
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1E30),
                            border: Border.all(color: GrimoireTheme.borderSubtle),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        // Opacity Gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                currentColor.withValues(alpha: 0.0),
                                currentColor.withValues(alpha: 1.0),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Positioned(
                          left: thumbX - 8,
                          top: 1,
                          child: IgnorePointer(
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentColor,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 3),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Comparison Banner (Original vs New)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF141727),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _applyColor(widget.initialColor),
                  borderRadius: BorderRadius.circular(4),
                  child: Tooltip(
                    message: 'Clic para restaurar color original',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: widget.initialColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: widget.initialColor.a == 0
                              ? const Icon(Icons.block, size: 12, color: Colors.redAccent)
                              : null,
                        ),
                        const SizedBox(width: 4),
                        const Text('Prev', style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 12, color: GrimoireTheme.textMuted),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: currentColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white70),
                      ),
                      child: isTransparent
                          ? const Icon(Icons.block, size: 12, color: Colors.redAccent)
                          : null,
                    ),
                    const SizedBox(width: 4),
                    const Text('Nuevo', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Text(
                  _formatHex(currentColor),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE9D5FF),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  icon: const Icon(Icons.copy, size: 12, color: GrimoireTheme.textMuted),
                  tooltip: 'Copiar Hex',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _formatHex(currentColor)));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // HEX & RGB Inputs
          Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _hexController,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.tag, size: 13, color: GrimoireTheme.accentPurple),
                      prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      labelText: 'Hex',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      isDense: true,
                    ),
                    onSubmitted: _handleHexSubmitted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _rController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'R',
                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleRgbSubmitted(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _gController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'G',
                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleRgbSubmitted(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _bController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'B',
                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleRgbSubmitted(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Palette Swatches & Quick Fantasy Themes
          const Text(
            'PALETAS DE COLOR RECOMENDADAS:',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: GrimoireTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Grimoire Studio Palette
              _buildSwatch(const Color(0xFF0C0E17), 'Obsidian'),
              _buildSwatch(const Color(0xFF1E2337), 'Midnight Navy'),
              _buildSwatch(const Color(0xFF2E1065), 'Arcane Violet'),
              _buildSwatch(const Color(0xFF1E1B4B), 'Mystic Indigo'),
              _buildSwatch(const Color(0xFF064E3B), 'Abyssal Emerald'),
              _buildSwatch(const Color(0xFF450A0A), 'Dragon Crimson'),
              _buildSwatch(const Color(0xFF451A03), 'Ancient Amber'),
              _buildSwatch(const Color(0xFFF59E0B), 'Mítico Dorado'),
              _buildSwatch(const Color(0xFF3B82F6), 'Zafiro Mágico'),
              _buildSwatch(const Color(0xFFEC4899), 'Rosa Neón'),
              _buildSwatch(const Color(0xFF10B981), 'Esmeralda Vital'),
              _buildSwatch(const Color(0xFF06B6D4), 'Hielo Glacial'),
              _buildSwatch(const Color(0xFFF8FAFC), 'Blanco Celestial'),
              _buildSwatch(const Color(0xFF000000), 'Negro Absoluto'),
              if (widget.allowTransparent)
                _buildSwatch(Colors.transparent, 'Transparente'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwatch(Color col, String label) {
    final isSelected = col.toARGB32() == _currentColor.toARGB32();
    final isTrans = col.a == 0;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => _applyColor(col),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: col,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? GrimoireTheme.accentPurple : Colors.white24,
              width: isSelected ? 2.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.6),
                      blurRadius: 6,
                    )
                  ]
                : null,
          ),
          child: isTrans
              ? const Icon(Icons.block, size: 14, color: Colors.redAccent)
              : isSelected
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: ThemeData.estimateBrightnessForColor(col) == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    )
                  : null,
        ),
      ),
    );
  }
}

/// Modal Dialog that hosts the GrimoireColorPicker with live card updates
class GrimoireColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color>? onLiveChanged;
  final bool allowTransparent;
  final String? title;

  const GrimoireColorPickerDialog({
    super.key,
    required this.initialColor,
    this.onLiveChanged,
    this.allowTransparent = true,
    this.title,
  });

  static Future<Color?> show(
    BuildContext context, {
    required Color initialColor,
    ValueChanged<Color>? onLiveChanged,
    bool allowTransparent = true,
    String? title,
  }) {
    return showDialog<Color>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => GrimoireColorPickerDialog(
        initialColor: initialColor,
        onLiveChanged: onLiveChanged,
        allowTransparent: allowTransparent,
        title: title,
      ),
    );
  }

  @override
  State<GrimoireColorPickerDialog> createState() => _GrimoireColorPickerDialogState();
}

class _GrimoireColorPickerDialogState extends State<GrimoireColorPickerDialog> {
  late Color _pickedColor;

  @override
  void initState() {
    super.initState();
    _pickedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 410,
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 620),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GrimoireTheme.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: GrimoireColorPicker(
                  initialColor: widget.initialColor,
                  title: widget.title ?? 'Selector de Color',
                  allowTransparent: widget.allowTransparent,
                  onColorChanged: (c) {
                    setState(() => _pickedColor = c);
                    widget.onLiveChanged?.call(c);
                  },
                ),
              ),
            ),

            // Dialog Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: GrimoireTheme.borderSubtle)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      // Revert live change if canceled
                      widget.onLiveChanged?.call(widget.initialColor);
                      Navigator.of(context).pop(null);
                    },
                    child: const Text('Cancelar', style: TextStyle(color: GrimoireTheme.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, size: 15),
                    label: const Text('Aplicar Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Navigator.of(context).pop(_pickedColor);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
