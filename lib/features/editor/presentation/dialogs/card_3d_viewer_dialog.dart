import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../models/card_template.dart';
import '../widgets/card_renderer_widget.dart';

class Card3DViewerDialog extends StatefulWidget {
  final CardTemplate template;
  final Map<String, dynamic> cardData;
  final double widthMm;
  final double heightMm;

  const Card3DViewerDialog({
    super.key,
    required this.template,
    required this.cardData,
    this.widthMm = 63.5,
    this.heightMm = 88.9,
  });

  @override
  State<Card3DViewerDialog> createState() => _Card3DViewerDialogState();
}

class _Card3DViewerDialogState extends State<Card3DViewerDialog>
    with TickerProviderStateMixin {
  // 3D Tilt angles
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  // Effects state
  bool _enableFoil = true;
  double _foilIntensity = 0.65;
  bool _enableLinen = true;
  double _linenOpacity = 0.35;
  bool _autoShowcase = false;

  // Flip Animation state
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _isBackSide = false;

  // Showcase animation controller
  late final AnimationController _showcaseController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    )..addListener(() {
        setState(() {
          _isBackSide = _flipAnimation.value > (math.pi / 2);
        });
      });

    _showcaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addListener(() {
        if (_autoShowcase) {
          final t = _showcaseController.value * 2 * math.pi;
          setState(() {
            _tiltY = math.sin(t) * 0.28;
            _tiltX = math.cos(t * 2) * 0.14;
          });
        }
      });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _showcaseController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  void _toggleShowcase() {
    setState(() {
      _autoShowcase = !_autoShowcase;
      if (_autoShowcase) {
        _showcaseController.repeat();
      } else {
        _showcaseController.stop();
        _tiltX = 0.0;
        _tiltY = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardW = (widget.widthMm * 4.6).clamp(240.0, 360.0);
    final cardH = cardW * (widget.heightMm / widget.widthMm);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0E17).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                blurRadius: 32,
                spreadRadius: 4,
              ),
              const BoxShadow(color: Colors.black87, blurRadius: 40),
            ],
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(context),
              const Divider(height: 1, color: Colors.white12),

              // Interactive 3D Showcase Area
              Expanded(
                child: MouseRegion(
                  onHover: (event) {
                    if (!_autoShowcase) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final size = box.size;
                        final center = Offset(size.width / 2, size.height / 2);
                        final local = event.localPosition;
                        final normX = ((local.dx - center.dx) / (size.width / 2)).clamp(-1.0, 1.0);
                        final normY = ((local.dy - center.dy) / (size.height / 2)).clamp(-1.0, 1.0);
                        setState(() {
                          _tiltY = normX * 0.42; // Yaw
                          _tiltX = -normY * 0.42; // Pitch
                        });
                      }
                    }
                  },
                  onExit: (_) {
                    if (!_autoShowcase) {
                      setState(() {
                        _tiltX = 0;
                        _tiltY = 0;
                      });
                    }
                  },
                  child: Center(
                    child: _buildInteractiveCard(cardW, cardH),
                  ),
                ),
              ),

              const Divider(height: 1, color: Colors.white12),
              // Controls Toolbar
              _buildControlsBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cardName = widget.cardData['card_name']?.toString() ?? 'Carta';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.view_in_ar, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inspección 3D & Acabados • $cardName',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.widthMm.toStringAsFixed(1)} x ${widget.heightMm.toStringAsFixed(1)} mm • Mueve el ratón para inclinar en 3D',
                style: const TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: GrimoireTheme.textMuted, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCard(double cardW, double cardH) {
    // 3D perspective matrix
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0014) // Perspective depth
      ..rotateX(_tiltX)
      ..rotateY(_tiltY + _flipAnimation.value);

    // Calculate dynamic lighting & foil gradient alignment based on tilt
    final lightAlignment = Alignment(
      (_tiltY * 3.0).clamp(-1.0, 1.0),
      (-_tiltX * 3.0).clamp(-1.0, 1.0),
    );

    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, _) {
        return Transform(
          transform: transform,
          alignment: FractionalOffset.center,
          child: Container(
            width: cardW,
            height: cardH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.template.cornerRadius + 2),
              boxShadow: [
                // Simulated 3D Card Thickness & Ground Shadow
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 36,
                  offset: Offset(_tiltY * 40, -_tiltX * 40 + 20),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: Offset(_tiltY * 20, -_tiltX * 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.template.cornerRadius),
              child: Stack(
                children: [
                  // 1. The Core Card Renderer (Front or Back)
                  if (!_isBackSide)
                    CardRendererWidget(
                      template: widget.template,
                      cardData: widget.cardData,
                      side: CardSide.front,
                      cardWidth: cardW,
                      cardHeight: cardH,
                    )
                  else
                    // Invert horizontally so back is not mirrored
                    Transform(
                      transform: Matrix4.identity()..rotateY(math.pi),
                      alignment: FractionalOffset.center,
                      child: CardRendererWidget(
                        template: widget.template,
                        cardData: widget.cardData,
                        side: CardSide.back,
                        cardWidth: cardW,
                        cardHeight: cardH,
                      ),
                    ),

                  // 2. Holographic Foil Sheen Layer
                  if (_enableFoil)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: lightAlignment,
                              end: Alignment(-lightAlignment.x, -lightAlignment.y),
                              colors: [
                                Colors.transparent,
                                const Color(0x66FF0055).withValues(alpha: 0.25 * _foilIntensity),
                                const Color(0x889900FF).withValues(alpha: 0.35 * _foilIntensity),
                                const Color(0xAA00DDFF).withValues(alpha: 0.45 * _foilIntensity),
                                const Color(0xAA00FF99).withValues(alpha: 0.35 * _foilIntensity),
                                const Color(0x88FFAA00).withValues(alpha: 0.30 * _foilIntensity),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0],
                            ),
                            backgroundBlendMode: BlendMode.colorDodge,
                          ),
                        ),
                      ),
                    ),

                  // 3. Specular Light Glare Spot
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: lightAlignment,
                            radius: 0.9,
                            colors: [
                              Colors.white.withValues(alpha: 0.28 * (_enableFoil ? _foilIntensity : 0.4)),
                              Colors.white.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                          backgroundBlendMode: BlendMode.screen,
                        ),
                      ),
                    ),
                  ),

                  // 4. Linen Cardstock Texture Overlay
                  if (_enableLinen)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _LinenTexturePainter(opacity: _linenOpacity),
                        ),
                      ),
                    ),

                  // 5. Card Border Rim / Bevel Highlight
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(widget.template.cornerRadius),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF0F111D),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          // Flip Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GrimoireTheme.accentPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.flip_to_back, size: 16),
            label: Text(_isBackSide ? 'Ver Frente' : 'Voltear Dorso'),
            onPressed: _toggleFlip,
          ),
          const SizedBox(width: 16),
          const VerticalDivider(width: 1, color: Colors.white12),
          const SizedBox(width: 16),

          // Foil Finish Toggle & Slider
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => setState(() => _enableFoil = !_enableFoil),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: _enableFoil ? const Color(0xFF06B6D4) : GrimoireTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Foil / Holo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _enableFoil ? Colors.white : GrimoireTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_enableFoil) ...[
                SizedBox(
                  width: 90,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    ),
                    child: Slider(
                      value: _foilIntensity,
                      min: 0.1,
                      max: 1.0,
                      activeColor: const Color(0xFF06B6D4),
                      onChanged: (val) => setState(() => _foilIntensity = val),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(width: 14),

          // Linen Cardstock Toggle & Slider
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => setState(() => _enableLinen = !_enableLinen),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_on,
                        size: 16,
                        color: _enableLinen ? const Color(0xFFF59E0B) : GrimoireTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Textura Lino',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _enableLinen ? Colors.white : GrimoireTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_enableLinen) ...[
                SizedBox(
                  width: 90,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    ),
                    child: Slider(
                      value: _linenOpacity,
                      min: 0.1,
                      max: 0.7,
                      activeColor: const Color(0xFFF59E0B),
                      onChanged: (val) => setState(() => _linenOpacity = val),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 14),

          // Auto-Showcase Toggle
          InkWell(
            onTap: _toggleShowcase,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _autoShowcase
                    ? GrimoireTheme.accentPurple.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _autoShowcase
                      ? GrimoireTheme.accentPurple
                      : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _autoShowcase ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 16,
                    color: _autoShowcase ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Auto Giro',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _autoShowcase ? Colors.white : GrimoireTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Close
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: GrimoireTheme.textMuted)),
          ),
        ],
      ),
    ),
  );
  }
}

/// Custom painter that creates authentic cross-hatch linen texture
/// reproducing premium casino/board game cardstock (Bicycle air-cushion / Cartamundi B9).
class _LinenTexturePainter extends CustomPainter {
  final double opacity;

  const _LinenTexturePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12 * opacity)
      ..strokeWidth = 0.55;

    final darkPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18 * opacity)
      ..strokeWidth = 0.55;

    const step = 2.4; // fine weave pitch

    // Horizontal threads
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (y ~/ step) % 2 == 0 ? lightPaint : darkPaint);
    }

    // Vertical threads
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (x ~/ step) % 2 == 0 ? lightPaint : darkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinenTexturePainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
