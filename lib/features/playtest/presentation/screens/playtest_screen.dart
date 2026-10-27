import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/widgets/card_renderer_widget.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';
import 'package:grimoire_studio/features/export/services/export_service.dart';
import '../../models/playtest_models.dart';
import '../dialogs/token_spawner_dialog.dart';
import 'dart:io';
import '../dialogs/playtest_analytics_dialog.dart';
import '../dialogs/custom_playmat_dialog.dart';
import '../../services/playmat_service.dart';
import '../widgets/battle_log_panel.dart';
import 'package:grimoire_studio/features/editor/presentation/dialogs/card_3d_viewer_dialog.dart';

class PlaytestScreen extends ConsumerStatefulWidget {
  const PlaytestScreen({super.key});

  @override
  ConsumerState<PlaytestScreen> createState() => _PlaytestScreenState();
}

class _PlaytestScreenState extends ConsumerState<PlaytestScreen> {
  // Battlefield Cards
  final List<PlaytestCard> _battlefield = [];

  // Table Division & Multi-Player State
  TableDivisionMode _divisionMode = TableDivisionMode.none;
  final Map<int, int> _playerLifes = {
    1: 20, 2: 20, 3: 20, 4: 20, 5: 20, 6: 20, 7: 20, 8: 20,
  };
  final Map<int, int> _playerManas = {
    1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1,
  };

  // Pan & Zoom State
  final TransformationController _transformationController = TransformationController();
  final GlobalKey _matKey = GlobalKey();
  double _currentZoom = 1.0;
  Size? _lastViewportSize;
  bool _initialViewFitted = false;

  // Player 1 (Bottom)
  final List<Map<String, dynamic>> _hand = [];
  final List<Map<String, dynamic>> _graveyard = [];
  final List<Map<String, dynamic>> _drawPile = [];
  int _playerLife = 20;
  int _playerMana = 1;

  // Player 2 / Duel Mode (Top)
  bool _isDuelMode = false;
  int _activePlayer = 1; // 1: J1, 2: J2
  final List<Map<String, dynamic>> _p2Hand = [];
  final List<Map<String, dynamic>> _p2Graveyard = [];
  final List<Map<String, dynamic>> _p2DrawPile = [];
  int _p2Life = 20;
  int _p2Mana = 1;
  bool _p2HandVisible = true;

  // General Playtest State
  int _turn = 1;
  String _selectedGame = 'All';
  String? _lastRoll;
  final List<String> _rollHistory = [];

  // Theme & Battle Log
  PlaymatTheme _currentTheme = PlaymatTheme.presets.first;
  CustomPlaymatConfig _customPlaymatConfig = const CustomPlaymatConfig();

  double get _effectiveTableWidth => (_customPlaymatConfig.isEnabled && _customPlaymatConfig.imagePath != null)
      ? _customPlaymatConfig.tableWidth
      : 2200.0;
  double get _effectiveTableHeight => (_customPlaymatConfig.isEnabled && _customPlaymatConfig.imagePath != null)
      ? _customPlaymatConfig.tableHeight
      : 1400.0;
  final List<BattleLogEntry> _battleLogs = [];
  bool _showBattleLog = false;
  bool? _userShowCombatStats; // null = auto-detect based on cards in game

  // Preview overlay state
  Map<String, dynamic>? _previewCardData;

  String? _lastActiveGame;

  /// Automatically detect whether the current game uses combat stats (power/toughness/attack/defense)
  bool get _effectiveShowCombatStats {
    if (_userShowCombatStats != null) return _userShowCombatStats!;
    
    // Auto-detect based on cards in battlefield
    for (final card in _battlefield) {
      if (_cardHasCombatStats(card, checkOverride: false)) return true;
    }

    // Also inspect current hands or deck if battlefield is empty
    for (final cardData in [..._hand, ..._p2Hand, ..._drawPile]) {
      if (_mapHasCombatStats(cardData)) return true;
    }
    
    return false;
  }

  /// Check if raw card data has combat keys
  static bool _mapHasCombatStats(Map<String, dynamic> data) {
    const combatKeys = [
      'attack', 'defense', 'ataque', 'defensa', 'atk', 'def', 
      'power', 'toughness', 'fuerza', 'resistencia', 'hp', 'vida'
    ];
    for (final key in combatKeys) {
      if (data.containsKey(key)) {
        final val = data[key]?.toString().trim() ?? '';
        if (val.isNotEmpty && val != '0' && val != '-') return true;
      }
    }
    return false;
  }

  /// Check if a single card has combat-oriented attributes
  bool _cardHasCombatStats(PlaytestCard card, {bool checkOverride = true}) {
    if (checkOverride && _userShowCombatStats != null) {
      return _userShowCombatStats!;
    }
    return _mapHasCombatStats(card.data);
  }

  static const List<Color> _playerColors = [
    Color(0xFF8B5CF6), // J1: Púrpura / Violeta
    Color(0xFF06B6D4), // J2: Cyan / Azul cielo
    Color(0xFF10B981), // J3: Esmeralda / Verde
    Color(0xFFF59E0B), // J4: Ámbar / Naranja
    Color(0xFFEC4899), // J5: Rosa / Magenta
    Color(0xFF3B82F6), // J6: Azul royal
    Color(0xFF14B8A6), // J7: Teal / Turquesa
    Color(0xFFEF4444), // J8: Rojo coral
  ];

  Color _getPlayerColor(int player) {
    if (player < 1) return _playerColors[0];
    return _playerColors[(player - 1) % _playerColors.length];
  }

  void _zoom(double factor, {Offset? focalPoint}) {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.25, 3.5);
    final effectiveFactor = newScale / currentScale;
    if ((effectiveFactor - 1.0).abs() < 0.001) return;

    final focal = focalPoint ?? Offset(
      (_lastViewportSize?.width ?? 1200) / 2,
      (_lastViewportSize?.height ?? 800) / 2,
    );

    final translation = Matrix4.translationValues(focal.dx, focal.dy, 0.0) *
        Matrix4.diagonal3Values(effectiveFactor, effectiveFactor, 1.0) *
        Matrix4.translationValues(-focal.dx, -focal.dy, 0.0);

    _transformationController.value = translation * currentMatrix;
  }

  void _setZoom(double targetScale) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final factor = targetScale / (currentScale > 0 ? currentScale : 1.0);
    _zoom(factor);
  }

  void _resetView({Size? viewportSize}) {
    final vpSize = viewportSize ?? _lastViewportSize;
    if (vpSize == null || vpSize.width <= 0 || vpSize.height <= 0) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    final double tableWidth = _effectiveTableWidth;
    final double tableHeight = _effectiveTableHeight;

    final scaleX = vpSize.width / tableWidth;
    final scaleY = vpSize.height / tableHeight;
    final scale = math.min(scaleX, scaleY).clamp(0.32, 1.2) * 0.94;

    final tx = (vpSize.width - tableWidth * scale) / 2;
    final ty = (vpSize.height - tableHeight * scale) / 2;

    _transformationController.value = Matrix4.translationValues(tx, ty, 0.0) *
        Matrix4.diagonal3Values(scale, scale, 1.0);
  }

  List<PlayerZoneSpec> _getPlayerZones(double w, double h) {
    final center = Offset(w / 2, h / 2);
    switch (_divisionMode) {
      case TableDivisionMode.none:
        return [];
      case TableDivisionMode.duel:
        final pz = ref.tr('player_zone');
        return [
          PlayerZoneSpec(player: 1, position: Offset(center.dx, h - 180), label: '$pz 1'),
          PlayerZoneSpec(player: 2, position: Offset(center.dx, 180), label: '$pz 2'),
        ];
      case TableDivisionMode.twoSideBySide:
        final pz = ref.tr('player_zone');
        return [
          PlayerZoneSpec(player: 1, position: Offset(w * 0.25, center.dy), label: '$pz 1'),
          PlayerZoneSpec(player: 2, position: Offset(w * 0.75, center.dy), label: '$pz 2'),
        ];
      case TableDivisionMode.threeRadial:
        final pz = ref.tr('player_zone');
        return [
          PlayerZoneSpec(player: 1, position: Offset(center.dx, h - 180), label: '$pz 1'),
          PlayerZoneSpec(player: 2, position: Offset(w * 0.28, h * 0.30), label: '$pz 2'),
          PlayerZoneSpec(player: 3, position: Offset(w * 0.72, h * 0.30), label: '$pz 3'),
        ];
      case TableDivisionMode.fourCross:
        final pz = ref.tr('player_zone');
        return [
          PlayerZoneSpec(player: 1, position: Offset(w * 0.26, h * 0.78), label: '$pz 1'),
          PlayerZoneSpec(player: 2, position: Offset(w * 0.26, h * 0.22), label: '$pz 2'),
          PlayerZoneSpec(player: 3, position: Offset(w * 0.74, h * 0.22), label: '$pz 3'),
          PlayerZoneSpec(player: 4, position: Offset(w * 0.74, h * 0.78), label: '$pz 4'),
        ];
      case TableDivisionMode.sixRadial:
        const double r = 520.0;
        final pz = ref.tr('player_zone');
        return [
          PlayerZoneSpec(player: 1, position: Offset(center.dx, center.dy + 480), label: '$pz 1'),
          PlayerZoneSpec(player: 2, position: Offset(center.dx + r * 0.866, center.dy + r * 0.5), label: '$pz 2'),
          PlayerZoneSpec(player: 3, position: Offset(center.dx + r * 0.866, center.dy - r * 0.5), label: '$pz 3'),
          PlayerZoneSpec(player: 4, position: Offset(center.dx, center.dy - 480), label: '$pz 4'),
          PlayerZoneSpec(player: 5, position: Offset(center.dx - r * 0.866, center.dy - r * 0.5), label: '$pz 5'),
          PlayerZoneSpec(player: 6, position: Offset(center.dx - r * 0.866, center.dy + r * 0.5), label: '$pz 6'),
        ];
      case TableDivisionMode.eightRadial:
        const double r = 520.0;
        final pz = ref.tr('player_zone');
        final list = <PlayerZoneSpec>[];
        for (int i = 0; i < 8; i++) {
          final angle = (22.5 + i * 45.0) * math.pi / 180.0;
          list.add(
            PlayerZoneSpec(
              player: i + 1,
              position: Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle)),
              label: '$pz ${i + 1}',
            ),
          );
        }
        return list;
    }
  }

  Widget _buildCenterHub(Offset center) {
    final isDuel = _divisionMode == TableDivisionMode.duel;
    return Positioned(
      left: center.dx - 140,
      top: center.dy - 55,
      width: 280,
      height: 110,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F111D).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _currentTheme.accentColor.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _currentTheme.accentColor.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDuel ? Icons.sports_kabaddi : Icons.table_restaurant,
                      size: 16,
                      color: _currentTheme.accentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isDuel ? ref.tr('combat_line') : ref.tr('common_area'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: _currentTheme.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isDuel ? 'J1 (Abajo) vs J2 (Arriba)' : '${_divisionMode.label} • Centro',
                  style: const TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerZoneBadge(PlayerZoneSpec zone) {
    final playerNumber = zone.player;
    final isCurrentActive = _activePlayer == playerNumber;
    final color = _getPlayerColor(playerNumber);
    final life = _playerLifes[playerNumber] ?? 20;

    return Positioned(
      left: zone.position.dx - 85,
      top: zone.position.dy - 35,
      child: InkWell(
        onTap: () {
          setState(() {
            _activePlayer = playerNumber;
            _addLog('Turno asignado a J$playerNumber', type: BattleLogType.turn, player: playerNumber);
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 170,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F111D).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentActive ? color : color.withValues(alpha: 0.35),
              width: isCurrentActive ? 2.0 : 1.0,
            ),
            boxShadow: isCurrentActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    const BoxShadow(color: Colors.black45, blurRadius: 6),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'J$playerNumber',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      zone.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isCurrentActive ? Colors.white : GrimoireTheme.textMuted,
                      ),
                    ),
                  ),
                  if (isCurrentActive) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        final newLife = life - 1;
                        _playerLifes[playerNumber] = newLife;
                        if (playerNumber == 1) _playerLife = newLife;
                        if (playerNumber == 2) _p2Life = newLife;
                        _addLog('J$playerNumber vida: $newLife', type: BattleLogType.life, player: playerNumber);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.remove, size: 11, color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '♥ $life',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        final newLife = life + 1;
                        _playerLifes[playerNumber] = newLife;
                        if (playerNumber == 1) _playerLife = newLife;
                        if (playerNumber == 2) _p2Life = newLife;
                        _addLog('J$playerNumber vida: $newLife', type: BattleLogType.life, player: playerNumber);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.add, size: 11, color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControlsHUD() {
    final zoomPercentage = (_currentZoom * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111D).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GrimoireTheme.borderSubtle),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pan Hint Tooltip
          Tooltip(
            message: ref.tr('table_controls_tooltip'),
            child: const Icon(Icons.pan_tool_alt_outlined, size: 14, color: GrimoireTheme.textMuted),
          ),
          const SizedBox(width: 6),
          const SizedBox(height: 14, child: VerticalDivider(width: 1, color: GrimoireTheme.borderSubtle)),
          const SizedBox(width: 4),

          // Zoom Out
          IconButton(
            tooltip: '${ref.tr('zoom_out')} (-)',
            icon: const Icon(Icons.remove, size: 15, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: () => _zoom(0.85),
          ),

          // Current Zoom Percentage (click to reset to 100%)
          Tooltip(
            message: ref.tr('zoom_reset'),
            child: InkWell(
              onTap: () => _setZoom(1.0),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '$zoomPercentage%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrimoireTheme.accentPurple),
                ),
              ),
            ),
          ),

          // Zoom In
          IconButton(
            tooltip: '${ref.tr('zoom_in')} (+)',
            icon: const Icon(Icons.add, size: 15, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: () => _zoom(1.18),
          ),

          const SizedBox(width: 4),
          const SizedBox(height: 14, child: VerticalDivider(width: 1, color: GrimoireTheme.borderSubtle)),
          const SizedBox(width: 4),

          // Fit / Center Table Button
          IconButton(
            tooltip: ref.tr('fit_table'),
            icon: const Icon(Icons.fit_screen_outlined, size: 15, color: GrimoireTheme.accentEmerald),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: _resetView,
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
    final activeGame = ref.read(editorProvider).project.activeRow['game']?.toString().trim();
    if (activeGame != null && activeGame.isNotEmpty) {
      _selectedGame = activeGame;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeckAndHand();
      _loadPlaymatConfig();
    });
  }

  Future<void> _loadPlaymatConfig() async {
    final loaded = await PlaymatService.loadConfig(_selectedGame);
    if (loaded != null && mounted) {
      setState(() {
        _customPlaymatConfig = loaded;
      });
    }
  }

  void _openCustomPlaymatDialog() {
    CustomPlaymatDialog.show(
      context,
      gameName: _selectedGame,
      initialConfig: _customPlaymatConfig,
      onApply: (CustomPlaymatConfig newConfig) {
        setState(() {
          _customPlaymatConfig = newConfig;
        });
        _addLog(newConfig.isEnabled
            ? 'Mesa de juego personalizada aplicada.'
            : 'Mesa personalizada desactivada (usando tema predeterminado).');
      },
    );
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentZoom).abs() > 0.01 && mounted) {
      setState(() => _currentZoom = scale);
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _addLog(String message, {BattleLogType type = BattleLogType.general, int? player}) {
    setState(() {
      _battleLogs.add(
        BattleLogEntry(
          timestamp: DateTime.now(),
          message: message,
          type: type,
          player: player ?? (_isDuelMode ? _activePlayer : 1),
        ),
      );
      if (_battleLogs.length > 200) {
        _battleLogs.removeAt(0);
      }
    });
  }

  List<Map<String, dynamic>> _getGameCards() {
    final rows = ref.read(editorProvider).project.rows;
    if (_selectedGame == 'All') return rows;
    final filtered = rows.where((r) => (r['game'] ?? '').toString() == _selectedGame).toList();
    return filtered.isNotEmpty ? filtered : rows;
  }

  void _initDeckAndHand() {
    final baseCards = _getGameCards();
    final List<Map<String, dynamic>> fullDeck = [];
    for (final c in baseCards) {
      final rawQty = (c['qty'] ?? c['quantity'] ?? '1').toString().trim();
      final copies = (int.tryParse(rawQty) ?? 1).clamp(1, 10);
      for (int i = 0; i < copies; i++) {
        fullDeck.add(Map<String, dynamic>.from(c));
      }
    }

    fullDeck.shuffle(math.Random());

    setState(() {
      _battlefield.clear();
      _graveyard.clear();
      _hand.clear();
      _drawPile.clear();
      _drawPile.addAll(fullDeck);
      _turn = 1;
      _activePlayer = 1;
      _playerMana = 1;
      _playerLife = 20;

      final initialHand = _drawPile.take(math.min(5, _drawPile.length)).toList();
      _drawPile.removeRange(0, initialHand.length);
      _hand.addAll(initialHand);

      // Player 2 init
      _p2Hand.clear();
      _p2Graveyard.clear();
      _p2DrawPile.clear();
      _p2Life = 20;
      _p2Mana = 1;
      final fullDeck2 = List<Map<String, dynamic>>.from(fullDeck)..shuffle(math.Random());
      _p2DrawPile.addAll(fullDeck2);
      final p2InitialHand = _p2DrawPile.take(math.min(5, _p2DrawPile.length)).toList();
      _p2DrawPile.removeRange(0, p2InitialHand.length);
      _p2Hand.addAll(p2InitialHand);

      // Reset all multiplayer player stats
      _playerLifes[1] = 20;
      _playerLifes[2] = 20;
      _playerManas[1] = 1;
      _playerManas[2] = 1;
      for (int i = 3; i <= 8; i++) {
        _playerLifes[i] = 20;
        _playerManas[i] = 1;
      }

      _addLog('Partida iniciada. Mazo preparado con ${_drawPile.length} cartas.', type: BattleLogType.turn);
    });
  }

  void _shuffleDrawPile({int player = 1}) {
    setState(() {
      if (player == 1) {
        _drawPile.shuffle(math.Random());
      } else {
        _p2DrawPile.shuffle(math.Random());
      }
      _addLog('J$player barajó su mazo.', type: BattleLogType.general, player: player);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GrimoireTheme.surfaceElevated,
        duration: const Duration(milliseconds: 1400),
        content: Text('Mazo de J$player barajado con éxito.', style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  void _mulligan({int player = 1}) {
    final targetPile = player == 1 ? _drawPile : _p2DrawPile;
    final targetHand = player == 1 ? _hand : _p2Hand;

    final allCards = [...targetHand, ...targetPile];
    allCards.shuffle(math.Random());
    setState(() {
      targetPile.clear();
      targetPile.addAll(allCards);
      targetHand.clear();
      final newHand = targetPile.take(math.min(5, targetPile.length)).toList();
      targetPile.removeRange(0, newHand.length);
      targetHand.addAll(newHand);
      _addLog('J$player realizó Mulligan (mano reseteada a 5 cartas).', type: BattleLogType.turn, player: player);
    });
  }

  void _drawCard({int player = 1}) {
    final pile = player == 1 ? _drawPile : _p2DrawPile;
    final hand = player == 1 ? _hand : _p2Hand;

    if (pile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GrimoireTheme.accentPink,
          duration: const Duration(milliseconds: 1500),
          content: Text('¡El mazo de J$player está vacío!', style: const TextStyle(fontSize: 12)),
        ),
      );
      return;
    }
    setState(() {
      final card = pile.removeAt(0);
      hand.add(card);
      _addLog('J$player roba "${card['card_name'] ?? 'Carta'}"', type: BattleLogType.draw, player: player);
    });
  }

  void _playCardToBattlefield(Map<String, dynamic> cardData, Offset position, {int player = 1}) {
    setState(() {
      if (player == 1) {
        _hand.remove(cardData);
      } else {
        _p2Hand.remove(cardData);
      }
      _battlefield.add(
        PlaytestCard(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          data: cardData,
          position: position,
          ownerPlayer: player,
          isToken: cardData['is_token'] == true,
        ),
      );
      _addLog('J$player jugó "${cardData['card_name'] ?? 'Carta'}" al campo', type: BattleLogType.play, player: player);
    });
  }

  void _sendBattlefieldCardToGraveyard(PlaytestCard card) {
    setState(() {
      _battlefield.remove(card);
      if (card.ownerPlayer == 1) {
        _graveyard.add(card.data);
      } else {
        _p2Graveyard.add(card.data);
      }
      _addLog('"${card.data['card_name']}" enviada al cementerio de J${card.ownerPlayer}', type: BattleLogType.general, player: card.ownerPlayer);
    });
  }

  void _sendHandCardToGraveyard(Map<String, dynamic> cardData, {int player = 1}) {
    setState(() {
      if (player == 1) {
        _hand.remove(cardData);
        _graveyard.add(cardData);
      } else {
        _p2Hand.remove(cardData);
        _p2Graveyard.add(cardData);
      }
      _addLog('J$player descartó "${cardData['card_name']}"', type: BattleLogType.general, player: player);
    });
  }

  void _toggleCardFaceDown(PlaytestCard card) {
    setState(() {
      card.isFaceDown = !card.isFaceDown;
      _addLog(
        card.isFaceDown
            ? 'J${card.ownerPlayer} colocó una carta boca abajo (Face-Down)'
            : 'J${card.ownerPlayer} reveló boca arriba: "${card.data['card_name']}"',
        type: BattleLogType.general,
        player: card.ownerPlayer,
      );
    });
  }

  void _rotateCard(PlaytestCard card) {
    setState(() {
      card.rotationDegrees = (card.rotationDegrees + 90) % 360;
      card.isTapped = card.rotationDegrees == 90;
      _addLog('Carta girada a ${card.rotationDegrees}°', type: BattleLogType.combat, player: card.ownerPlayer);
    });
  }

  void _showAddNoteDialog(PlaytestCard card) {
    final controller = TextEditingController(text: card.note ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        title: const Text('Nota en Carta', style: TextStyle(fontSize: 14, color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: const InputDecoration(hintText: 'Ej: Congelado hasta turno 3 / +2 Ataque temporal'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => card.note = null);
              Navigator.pop(ctx);
            },
            child: const Text('Borrar Nota', style: TextStyle(color: GrimoireTheme.accentPink)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
            onPressed: () {
              setState(() => card.note = controller.text.trim().isEmpty ? null : controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _openGraveyardDialog({int player = 1}) {
    final targetGraveyard = player == 1 ? _graveyard : _p2Graveyard;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: GrimoireTheme.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.delete_sweep_outlined, color: Color(0xFFF43F5E), size: 22),
                const SizedBox(width: 8),
                Text(
                  'Cementerio / Descarte - J$player (${targetGraveyard.length})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                if (targetGraveyard.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        final pile = player == 1 ? _drawPile : _p2DrawPile;
                        pile.addAll(targetGraveyard);
                        targetGraveyard.clear();
                        pile.shuffle(math.Random());
                        _addLog('J$player recuperó todo el cementerio y barajó el mazo.', type: BattleLogType.turn, player: player);
                      });
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.shuffle, size: 14, color: GrimoireTheme.accentPurple),
                    label: const Text('Devolver Todo y Barajar', style: TextStyle(fontSize: 11, color: GrimoireTheme.accentPurple)),
                  ),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 380,
              child: targetGraveyard.isEmpty
                  ? const Center(
                      child: Text('El cementerio está vacío.', style: TextStyle(color: GrimoireTheme.textMuted, fontSize: 13)),
                    )
                  : ListView.separated(
                      itemCount: targetGraveyard.length,
                      separatorBuilder: (_, _) => const Divider(height: 8, color: Colors.white10),
                      itemBuilder: (ctx, idx) {
                        final cardData = targetGraveyard[idx];
                        final cardName = cardData['card_name']?.toString() ?? 'Carta #${idx + 1}';
                        return ListTile(
                          dense: true,
                          leading: SizedBox(
                            width: 32,
                            height: 44,
                            child: _buildRealisticMiniCard(cardData),
                          ),
                          title: Text(
                            cardName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          subtitle: Text(
                            cardData['rules_text']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Revivir al Campo',
                                icon: const Icon(Icons.pan_tool_alt_outlined, size: 16, color: GrimoireTheme.accentEmerald),
                                onPressed: () {
                                  setState(() {
                                    targetGraveyard.removeAt(idx);
                                    _battlefield.add(
                                      PlaytestCard(
                                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                                        data: cardData,
                                        position: Offset(1100, player == 1 ? 950 : 450),
                                        ownerPlayer: player,
                                      ),
                                    );
                                    _addLog('"$cardName" revivida al campo por J$player', type: BattleLogType.play, player: player);
                                  });
                                  setDialogState(() {});
                                },
                              ),
                              IconButton(
                                tooltip: 'Devolver a la Mano',
                                icon: const Icon(Icons.back_hand_outlined, size: 16, color: GrimoireTheme.accentCyan),
                                onPressed: () {
                                  setState(() {
                                    targetGraveyard.removeAt(idx);
                                    if (player == 1) {
                                      _hand.add(cardData);
                                    } else {
                                      _p2Hand.add(cardData);
                                    }
                                    _addLog('"$cardName" devuelta a la mano de J$player', type: BattleLogType.draw, player: player);
                                  });
                                  setDialogState(() {});
                                },
                              ),
                              IconButton(
                                tooltip: 'Poner al Tope del Mazo',
                                icon: const Icon(Icons.vertical_align_top, size: 16, color: Color(0xFFF59E0B)),
                                onPressed: () {
                                  setState(() {
                                    targetGraveyard.removeAt(idx);
                                    final pile = player == 1 ? _drawPile : _p2DrawPile;
                                    pile.insert(0, cardData);
                                    _addLog('"$cardName" puesta al tope del mazo de J$player', type: BattleLogType.general, player: player);
                                  });
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar', style: TextStyle(color: GrimoireTheme.textMuted)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCardCounterDialog(PlaytestCard card) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: GrimoireTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.tune, color: GrimoireTheme.accentPurple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Contadores • ${card.data['card_name'] ?? 'Carta'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCounterRow(
                  icon: Icons.shield_outlined,
                  label: '+1/+1 Contadores',
                  color: GrimoireTheme.accentEmerald,
                  value: card.counters,
                  onDec: () {
                    setState(() => card.counters--);
                    setDialogState(() {});
                  },
                  onInc: () {
                    setState(() => card.counters++);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 10),
                _buildCounterRow(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Daño Recibido (💥)',
                  color: const Color(0xFFDC2626),
                  value: card.damageCounters,
                  onDec: () {
                    if (card.damageCounters > 0) {
                      setState(() => card.damageCounters--);
                      setDialogState(() {});
                    }
                  },
                  onInc: () {
                    setState(() => card.damageCounters++);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 10),
                _buildCounterRow(
                  icon: Icons.bolt,
                  label: 'Energía / Cargas (⚡)',
                  color: const Color(0xFFF59E0B),
                  value: card.energyCounters,
                  onDec: () {
                    if (card.energyCounters > 0) {
                      setState(() => card.energyCounters--);
                      setDialogState(() {});
                    }
                  },
                  onInc: () {
                    setState(() => card.energyCounters++);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 10),
                _buildCounterRow(
                  icon: Icons.coronavirus_outlined,
                  label: 'Veneno / Toxina (☠️)',
                  color: const Color(0xFFA855F7),
                  value: card.poisonCounters,
                  onDec: () {
                    if (card.poisonCounters > 0) {
                      setState(() => card.poisonCounters--);
                      setDialogState(() {});
                    }
                  },
                  onInc: () {
                    setState(() => card.poisonCounters++);
                    setDialogState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  card.counters = 0;
                  card.damageCounters = 0;
                  card.energyCounters = 0;
                  card.poisonCounters = 0;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Limpiar Todo', style: TextStyle(color: GrimoireTheme.accentPink)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterRow({
    required IconData icon,
    required String label,
    required Color color,
    required int value,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: GrimoireTheme.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.remove, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            style: IconButton.styleFrom(backgroundColor: Colors.white10),
            onPressed: onDec,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                '$value',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            style: IconButton.styleFrom(backgroundColor: Colors.white10),
            onPressed: onInc,
          ),
        ],
      ),
    );
  }

  void _handleNextTurn() {
    setState(() {
      final playerCount = _divisionMode.playerCount;
      if (playerCount > 1) {
        _activePlayer = (_activePlayer % playerCount) + 1;
        if (_activePlayer == 1) _turn++;

        _playerManas[_activePlayer] = _turn;
        _playerMana = _playerManas[1] ?? _turn;
        _p2Mana = _playerManas[2] ?? _turn;

        for (final c in _battlefield.where((c) => c.ownerPlayer == _activePlayer)) {
          c.rotationDegrees = 0;
          c.isTapped = false;
        }

        if (_activePlayer == 1) {
          _drawCard(player: 1);
        } else if (_activePlayer == 2) {
          _drawCard(player: 2);
        }
        _addLog('--- Turno $_turn: Jugador $_activePlayer ---', type: BattleLogType.turn, player: _activePlayer);
      } else {
        _turn++;
        _playerMana = _turn;
        for (final c in _battlefield) {
          c.rotationDegrees = 0;
          c.isTapped = false;
        }
        _drawCard(player: 1);
        _addLog('--- Turno $_turn iniciado ---', type: BattleLogType.turn, player: 1);
      }
    });
  }

  Future<void> _handleExportTts() async {
    final cards = _getGameCards();
    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cartas para exportar a Tabletop Simulator.')),
      );
      return;
    }
    try {
      final file = await ExportService.exportTabletopSimulatorDeckJson(
        gameName: _selectedGame == 'All' ? 'Grimoire_Deck' : _selectedGame,
        cards: cards,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GrimoireTheme.accentEmerald,
            content: Text('Exportado a Tabletop Simulator: ${file.path.split('\\').last}'),
          ),
        );
        _addLog('Mazo exportado a Tabletop Simulator (.json)', type: BattleLogType.general);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Error al exportar a TTS: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRow = ref.watch(editorProvider).project.activeRow;
    final activeGame = (activeRow['game'] ?? '').toString().trim();
    if (activeGame.isNotEmpty && activeGame != _lastActiveGame) {
      _lastActiveGame = activeGame;
      _selectedGame = activeGame;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initDeckAndHand();
          _loadPlaymatConfig();
        }
      });
    }

    final allRows = ref.watch(editorProvider).project.rows;
    final availableGames = <String>{'All'};
    for (final r in allRows) {
      final g = (r['game'] ?? '').toString().trim();
      if (g.isNotEmpty) availableGames.add(g);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090C13),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Top Header Toolbar (Fully scrollable horizontally without AppBar constraint limits)
            Container(
              height: 52,
              decoration: const BoxDecoration(
                color: GrimoireTheme.surfacePanel,
                border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Title & Icon
                    const Icon(Icons.casino_outlined, color: GrimoireTheme.accentPurple, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      ref.tr('playtest_title'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 12),

                    // Game filter dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: GrimoireTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GrimoireTheme.borderSubtle),
                      ),
                      child: DropdownButton<String>(
                        value: availableGames.contains(_selectedGame) ? _selectedGame : 'All',
                        dropdownColor: GrimoireTheme.surfaceElevated,
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.arrow_drop_down, color: GrimoireTheme.accentPurple, size: 18),
                        items: [
                          for (final g in availableGames)
                            DropdownMenuItem(
                              value: g,
                              child: Text(g == 'All' ? ref.tr('all_games') : g),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedGame = val);
                            _initDeckAndHand();
                            _loadPlaymatConfig();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SizedBox(height: 20, child: VerticalDivider(width: 1, color: GrimoireTheme.borderSubtle)),
                    const SizedBox(width: 12),

                    // Duel Mode Toggle Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isDuelMode ? GrimoireTheme.accentPurple.withValues(alpha: 0.25) : GrimoireTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _isDuelMode ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sports_martial_arts, size: 14, color: _isDuelMode ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            _isDuelMode ? ref.tr('duel_mode') : ref.tr('solo_mode'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isDuelMode ? Colors.white : GrimoireTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Switch(
                            value: _isDuelMode,
                            activeTrackColor: GrimoireTheme.accentPurple,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) {
                              setState(() {
                                _isDuelMode = val;
                                _divisionMode = val ? TableDivisionMode.duel : TableDivisionMode.none;
                                if (!val && _activePlayer > 1) _activePlayer = 1;
                                _addLog(val ? 'Modo Duelo J1 vs J2 activado' : 'Modo Solitario activado', type: BattleLogType.turn);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Table Division Mode Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _divisionMode != TableDivisionMode.none && _divisionMode != TableDivisionMode.duel
                            ? GrimoireTheme.accentPurple.withValues(alpha: 0.18)
                            : GrimoireTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _divisionMode != TableDivisionMode.none && _divisionMode != TableDivisionMode.duel
                              ? GrimoireTheme.accentPurple
                              : GrimoireTheme.borderSubtle,
                        ),
                      ),
                      child: PopupMenuButton<TableDivisionMode>(
                        tooltip: ref.tr('divide_table_tooltip'),
                        color: GrimoireTheme.surfaceElevated,
                        elevation: 8,
                        constraints: const BoxConstraints(minWidth: 280, maxWidth: 340),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: GrimoireTheme.borderSubtle),
                        ),
                        onSelected: (mode) {
                          setState(() {
                            _divisionMode = mode;
                            _isDuelMode = (mode == TableDivisionMode.duel);
                            if (_activePlayer > mode.playerCount) {
                              _activePlayer = 1;
                            }
                            _addLog('Mesa dividida en: ${mode.label}', type: BattleLogType.turn);
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_divisionMode.icon, size: 14, color: GrimoireTheme.accentPurple),
                            const SizedBox(width: 6),
                            Text(
                              _divisionMode.label,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16, color: GrimoireTheme.accentPurple),
                          ],
                        ),
                        itemBuilder: (ctx) => [
                          for (final mode in TableDivisionMode.values)
                            PopupMenuItem(
                              value: mode,
                              child: Row(
                                children: [
                                  Icon(
                                    mode.icon,
                                    size: 16,
                                    color: _divisionMode == mode ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      mode.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _divisionMode == mode ? FontWeight.bold : FontWeight.normal,
                                        color: _divisionMode == mode ? GrimoireTheme.accentPurple : Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (_divisionMode == mode) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check, size: 14, color: GrimoireTheme.accentPurple),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Multi-player Active Player Selector Chips
                    if (_divisionMode.playerCount > 1) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GrimoireTheme.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int p = 1; p <= _divisionMode.playerCount; p++)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _activePlayer = p;
                                      _addLog('Acciones y turno asignados a Jugador $p', type: BattleLogType.turn, player: p);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _activePlayer == p ? _getPlayerColor(p) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'J$p',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _activePlayer == p ? Colors.white : GrimoireTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Next Turn Button (Prominently placed so it is immediately reachable without scrolling)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GrimoireTheme.accentPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.refresh, size: 13),
                      label: Text(_divisionMode.playerCount > 1 ? 'Siguiente Turno ($_turn - J$_activePlayer)' : '${ref.tr('next_turn')} ($_turn)'),
                      onPressed: _handleNextTurn,
                    ),
                    const SizedBox(width: 8),

                    // Spawn Token Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEAB308)),
                        foregroundColor: const Color(0xFFFEF08A),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: const Size(0, 30),
                      ),
                      icon: const Icon(Icons.toll, size: 13, color: Color(0xFFEAB308)),
                      label: Text(ref.tr('tokens'), style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        TokenSpawnerDialog.show(
                          context,
                          onSpawnToken: (tokenData) {
                            _playCardToBattlefield(tokenData, const Offset(200, 150), player: _activePlayer);
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 6),

                    // Analytics & Mulligan Lab Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: GrimoireTheme.accentPurple),
                        foregroundColor: const Color(0xFFE9D5FF),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: const Size(0, 30),
                      ),
                      icon: const Icon(Icons.analytics_outlined, size: 13, color: GrimoireTheme.accentPurple),
                      label: Text(ref.tr('analytics'), style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        PlaytestAnalyticsDialog.show(
                          context,
                          deckCards: _getGameCards(),
                          gameName: _selectedGame == 'All' ? 'Grimoire Deck' : _selectedGame,
                        );
                      },
                    ),
                    const SizedBox(width: 6),

                    // Custom Playmat Direct Action Button
                    IconButton(
                      tooltip: (_customPlaymatConfig.isEnabled && _customPlaymatConfig.imagePath != null)
                          ? 'Mesa Personalizada Activa • Clic para configurar o cambiar'
                          : 'Subir Mesa de Juego Personalizada (Tapete)',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.table_bar,
                            size: 18,
                            color: (_customPlaymatConfig.isEnabled && _customPlaymatConfig.imagePath != null)
                                ? GrimoireTheme.accentPurple
                                : GrimoireTheme.textMuted,
                          ),
                          if (_customPlaymatConfig.isEnabled && _customPlaymatConfig.imagePath != null)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: GrimoireTheme.accentPurple,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: _openCustomPlaymatDialog,
                    ),
                    const SizedBox(width: 4),

                    // Playmat Theme Selector Popup
                    PopupMenuButton<dynamic>(
                      tooltip: 'Cambiar Tapete de Juego',
                      color: GrimoireTheme.surfaceElevated,
                      icon: Text(_currentTheme.icon, style: const TextStyle(fontSize: 16)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onSelected: (val) {
                        if (val is PlaymatTheme) {
                          setState(() {
                            _currentTheme = val;
                            if (_customPlaymatConfig.isEnabled) {
                              _customPlaymatConfig = _customPlaymatConfig.copyWith(isEnabled: false);
                            }
                          });
                          _addLog('Tapete cambiado a "${val.name}"');
                        } else if (val == 'custom_playmat') {
                          _openCustomPlaymatDialog();
                        }
                      },
                      itemBuilder: (ctx) => [
                        for (final theme in PlaymatTheme.presets)
                          PopupMenuItem(
                            value: theme,
                            child: Row(
                              children: [
                                Text(theme.icon, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Text(theme.name, style: const TextStyle(fontSize: 12, color: Colors.white)),
                              ],
                            ),
                          ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'custom_playmat',
                          child: Row(
                            children: [
                              Icon(Icons.table_bar, size: 16, color: GrimoireTheme.accentPurple),
                              SizedBox(width: 8),
                              Text('Personalizar Mesa (Subir Imagen)...', style: TextStyle(fontSize: 12, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),

                    // Battle Log Toggle Button
                    IconButton(
                      tooltip: 'Historial de Partida (Battle Log)',
                      icon: Icon(
                        Icons.history_edu,
                        size: 18,
                        color: _showBattleLog ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                      ),
                      onPressed: () => setState(() => _showBattleLog = !_showBattleLog),
                    ),
                    const SizedBox(width: 6),

                    // Combat Stats Mode Toggle Button (🛡️ / 💥)
                    IconButton(
                      tooltip: _effectiveShowCombatStats
                          ? 'Modo Combate activo (🛡️/💥) • Clic para ocultar en juegos sin combate'
                          : 'Juego sin Combate • Clic para activar contadores de combate',
                      icon: Icon(
                        _effectiveShowCombatStats ? Icons.shield : Icons.shield_outlined,
                        size: 18,
                        color: _effectiveShowCombatStats ? GrimoireTheme.accentEmerald : GrimoireTheme.textMuted,
                      ),
                      onPressed: () {
                        setState(() {
                          _userShowCombatStats = !_effectiveShowCombatStats;
                        });
                        _addLog(_userShowCombatStats!
                            ? 'Modo Combate activado (🛡️ y 💥 visibles)'
                            : 'Modo Sin Combate activado (🛡️ y 💥 ocultos)');
                      },
                    ),
                    const SizedBox(width: 6),

                    // Tabletop Simulator Export Button
                    IconButton(
                      tooltip: 'Exportar a Tabletop Simulator (.json)',
                      icon: const Icon(Icons.table_restaurant, size: 18, color: Color(0xFF38BDF8)),
                      onPressed: _handleExportTts,
                    ),
                    const SizedBox(width: 8),

                    // Shuffle Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: GrimoireTheme.borderSubtle),
                        foregroundColor: const Color(0xFFE9D5FF),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: const Size(0, 30),
                      ),
                      icon: const Icon(Icons.shuffle, size: 13, color: GrimoireTheme.accentIndigo),
                      label: const Text('Barajar', style: TextStyle(fontSize: 11)),
                      onPressed: () => _shuffleDrawPile(player: _activePlayer),
                    ),
                    const SizedBox(width: 6),

                    // Mulligan Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: GrimoireTheme.borderSubtle),
                        foregroundColor: const Color(0xFFE9D5FF),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: const Size(0, 30),
                      ),
                      icon: const Icon(Icons.restart_alt, size: 13, color: GrimoireTheme.accentAmber),
                      label: const Text('Mulligan', style: TextStyle(fontSize: 11)),
                      onPressed: () => _mulligan(player: _activePlayer),
                    ),
                    const SizedBox(width: 6),

                    // Dice Roller Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: GrimoireTheme.borderSubtle),
                        foregroundColor: const Color(0xFFE9D5FF),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: const Size(0, 30),
                      ),
                      icon: const Icon(Icons.casino_outlined, size: 13, color: GrimoireTheme.accentEmerald),
                      label: Text(_lastRoll != null ? 'Dado: ' : 'Dados', style: const TextStyle(fontSize: 11)),
                      onPressed: _showDiceDialog,
                    ),
                    const SizedBox(width: 6),

                    // Search Deck (Tutor) Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: GrimoireTheme.borderSubtle),
                        foregroundColor: const Color(0xFFE9D5FF),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: const Size(0, 30),
                      ),
                      icon: const Icon(Icons.manage_search_outlined, size: 14, color: Color(0xFF38BDF8)),
                      label: const Text('Tutor Mazo', style: TextStyle(fontSize: 11)),
                      onPressed: () => _showDeckSearchDialog(player: _activePlayer),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            // Main Playmat & Overlays
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                    // Opponent Player 2 Dock (Duel Mode Only)
                    if (_isDuelMode) _buildPlayer2TopBar(),

                    // Battlefield Mat Area with Zoom, Pan, and Table Division
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _lastViewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                          if (!_initialViewFitted && constraints.maxWidth > 0 && constraints.maxHeight > 0) {
                            _initialViewFitted = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _resetView();
                            });
                          }

                          final double tableWidth = _effectiveTableWidth;
                          final double tableHeight = _effectiveTableHeight;

                          return Stack(
                            children: [
                              // Interactive Battlefield Canvas with Mouse Wheel Zoom Listener
                              Listener(
                                onPointerSignal: (event) {
                                  if (event is PointerScrollEvent) {
                                    final zoomFactor = event.scrollDelta.dy < 0 ? 1.12 : 0.89;
                                    _zoom(zoomFactor, focalPoint: event.localPosition);
                                  }
                                },
                                child: DragTarget<Map<String, dynamic>>(
                                  key: _matKey,
                                  onAcceptWithDetails: (details) {
                                    final RenderBox? renderBox = _matKey.currentContext?.findRenderObject() as RenderBox?;
                                    if (renderBox != null) {
                                      final localPos = renderBox.globalToLocal(details.offset);
                                      final scenePos = _transformationController.toScene(localPos);
                                      final clampedPos = Offset(
                                        scenePos.dx.clamp(20.0, tableWidth - 140.0),
                                        scenePos.dy.clamp(20.0, tableHeight - 180.0),
                                      );
                                      _playCardToBattlefield(details.data, clampedPos, player: _activePlayer);
                                    } else {
                                      _playCardToBattlefield(details.data, details.offset, player: _activePlayer);
                                    }
                                  },
                                  builder: (context, candidateData, rejectedData) {
                                    final hasCustomImage = _customPlaymatConfig.isEnabled &&
                                        _customPlaymatConfig.imagePath != null &&
                                        File(_customPlaymatConfig.imagePath!).existsSync();

                                    return InteractiveViewer(
                                      transformationController: _transformationController,
                                      minScale: 0.25,
                                      maxScale: 3.5,
                                      boundaryMargin: const EdgeInsets.all(2000),
                                      constrained: false,
                                      child: Container(
                                        width: tableWidth,
                                        height: tableHeight,
                                        decoration: hasCustomImage
                                            ? BoxDecoration(
                                                color: const Color(0xFF0F111D),
                                                image: DecorationImage(
                                                  image: FileImage(File(_customPlaymatConfig.imagePath!)),
                                                  fit: _customPlaymatConfig.fit,
                                                ),
                                              )
                                            : _currentTheme.decoration,
                                        child: Stack(
                                          children: [
                                            // Dimming Overlay for custom playmat
                                            if (hasCustomImage && _customPlaymatConfig.overlayDim > 0)
                                              Positioned.fill(
                                                child: Container(
                                                  color: Colors.black.withValues(alpha: _customPlaymatConfig.overlayDim),
                                                ),
                                              ),

                                            // Table Division Lines Painter
                                            if (!hasCustomImage || _customPlaymatConfig.showDivisionLines)
                                              Positioned.fill(
                                                child: Opacity(
                                                  opacity: hasCustomImage ? _customPlaymatConfig.divisionLinesOpacity : 1.0,
                                                  child: CustomPaint(
                                                    painter: TableDivisionPainter(
                                                      mode: _divisionMode,
                                                      theme: _currentTheme,
                                                      activePlayer: _activePlayer,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                            // Center Hub Badge / Info
                                            if (_divisionMode != TableDivisionMode.none)
                                              _buildCenterHub(Offset(tableWidth / 2, tableHeight / 2)),

                                            // Center Watermark when single player
                                            if (_divisionMode == TableDivisionMode.none)
                                              Center(
                                                child: Opacity(
                                                  opacity: 0.16,
                                                  child: Text(
                                                    '${ref.tr('battlefield_zone')}\n${ref.tr('drag_hint')}\n(Doble clic para girar · F para voltear boca abajo · Clic derecho para zoom)',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                      letterSpacing: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                            // Player Zone Badges
                                            for (final zone in _getPlayerZones(tableWidth, tableHeight))
                                              _buildPlayerZoneBadge(zone),

                                            // Placed cards on battlefield
                                            for (final card in _battlefield)
                                              Positioned(
                                                left: card.position.dx,
                                                top: card.position.dy,
                                                child: GestureDetector(
                                                  onPanUpdate: (details) {
                                                    final currentScale = _transformationController.value.getMaxScaleOnAxis();
                                                    final factor = currentScale > 0.05 ? currentScale : 1.0;
                                                    setState(() {
                                                      card.position += details.delta / factor;
                                                    });
                                                  },
                                                  onDoubleTap: () => _rotateCard(card),
                                                  onSecondaryTap: () {
                                                    setState(() {
                                                      _previewCardData = card.data;
                                                    });
                                                  },
                                                  child: Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      Transform.rotate(
                                                        angle: card.rotationAngle,
                                                        child: _buildRealisticMiniCard(
                                                          card.data,
                                                          isTapped: card.isTapped,
                                                          isFaceDown: card.isFaceDown,
                                                          isToken: card.isToken,
                                                        ),
                                                      ),

                                                      // Player Owner Badge
                                                      if (_isDuelMode || _divisionMode.playerCount > 1)
                                                        Positioned(
                                                          left: -4,
                                                          top: -4,
                                                          child: PopupMenuButton<int>(
                                                            tooltip: 'Asignar a jugador',
                                                            padding: EdgeInsets.zero,
                                                            color: GrimoireTheme.surfaceElevated,
                                                            constraints: const BoxConstraints(minWidth: 100),
                                                            onSelected: (newOwner) {
                                                              setState(() {
                                                                card.ownerPlayer = newOwner;
                                                                _addLog('Carta "${card.data['card_name']}" asignada a J$newOwner', player: newOwner);
                                                              });
                                                            },
                                                            itemBuilder: (ctx) => [
                                                              for (int p = 1; p <= _divisionMode.playerCount; p++)
                                                                PopupMenuItem(
                                                                  value: p,
                                                                  height: 28,
                                                                  child: Row(
                                                                    children: [
                                                                      Container(
                                                                        width: 10,
                                                                        height: 10,
                                                                        decoration: BoxDecoration(
                                                                          color: _getPlayerColor(p),
                                                                          shape: BoxShape.circle,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(width: 6),
                                                                      Text('Jugador $p', style: const TextStyle(fontSize: 11)),
                                                                    ],
                                                                  ),
                                                                ),
                                                            ],
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                              decoration: BoxDecoration(
                                                                color: _getPlayerColor(card.ownerPlayer),
                                                                borderRadius: BorderRadius.circular(4),
                                                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2)],
                                                              ),
                                                              child: Text(
                                                                'J${card.ownerPlayer}',
                                                                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      // Top Actions: Tap/Rotate 90°, Counters, 3D Inspect, Flip, and Close (Graveyard)
                                                      Positioned(
                                                        right: -6,
                                                        top: -6,
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            // Tap / Untap 90 deg button
                                                            Tooltip(
                                                              message: card.isTapped ? 'Enderezar (0°)' : 'Girar / Tapear (90°)',
                                                              child: InkWell(
                                                                onTap: () {
                                                                  setState(() {
                                                                    card.toggleTap();
                                                                    _addLog(
                                                                      card.isTapped
                                                                          ? 'J${card.ownerPlayer} giró (tapped) "${card.data['card_name'] ?? 'Carta'}"'
                                                                          : 'J${card.ownerPlayer} enderezó (untapped) "${card.data['card_name'] ?? 'Carta'}"',
                                                                      type: BattleLogType.combat,
                                                                      player: card.ownerPlayer,
                                                                    );
                                                                  });
                                                                },
                                                                child: Container(
                                                                  padding: const EdgeInsets.all(3),
                                                                  margin: const EdgeInsets.only(right: 3),
                                                                  decoration: BoxDecoration(
                                                                    color: card.isTapped ? const Color(0xFFD97706) : const Color(0xFF1F2937),
                                                                    shape: BoxShape.circle,
                                                                    border: Border.all(color: card.isTapped ? const Color(0xFFF59E0B) : Colors.white24),
                                                                  ),
                                                                  child: Icon(Icons.sync, size: 10, color: card.isTapped ? Colors.white : const Color(0xFFE5E7EB)),
                                                                ),
                                                              ),
                                                            ),
                                                            // Counters dialog button
                                                            Tooltip(
                                                              message: 'Gestionar Contadores (+1/+1, Daño, Cargas, Veneno)',
                                                              child: InkWell(
                                                                onTap: () => _showCardCounterDialog(card),
                                                                child: Container(
                                                                  padding: const EdgeInsets.all(3),
                                                                  margin: const EdgeInsets.only(right: 3),
                                                                  decoration: const BoxDecoration(
                                                                    color: Color(0xFF4F46E5),
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                  child: const Icon(Icons.tune, size: 10, color: Colors.white),
                                                                ),
                                                              ),
                                                            ),
                                                            // 3D Inspector button
                                                            Tooltip(
                                                              message: 'Inspeccionar 3D / Foil',
                                                              child: InkWell(
                                                                onTap: () {
                                                                  final tpl = ref.read(editorProvider.notifier).resolveTemplateForRow(card.data);
                                                                  final proj = ref.read(editorProvider).project;
                                                                  showDialog(
                                                                    context: context,
                                                                    builder: (_) => Card3DViewerDialog(
                                                                      template: tpl,
                                                                      cardData: card.data,
                                                                      widthMm: proj.widthMm,
                                                                      heightMm: proj.heightMm,
                                                                    ),
                                                                  );
                                                                },
                                                                child: Container(
                                                                  padding: const EdgeInsets.all(3),
                                                                  margin: const EdgeInsets.only(right: 3),
                                                                  decoration: const BoxDecoration(
                                                                    color: Color(0xFF0E7490),
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                  child: const Icon(Icons.view_in_ar, size: 10, color: Colors.white),
                                                                ),
                                                              ),
                                                            ),
                                                            // Flip Face-Down Button
                                                            InkWell(
                                                              onTap: () => _toggleCardFaceDown(card),
                                                              child: Container(
                                                                padding: const EdgeInsets.all(3),
                                                                margin: const EdgeInsets.only(right: 3),
                                                                decoration: BoxDecoration(
                                                                  color: card.isFaceDown ? GrimoireTheme.accentPurple : const Color(0xFF1F2937),
                                                                  shape: BoxShape.circle,
                                                                  border: Border.all(color: Colors.white24),
                                                                ),
                                                                child: const Icon(Icons.flip_to_back, size: 10, color: Colors.white),
                                                              ),
                                                            ),
                                                            // Send to Graveyard button
                                                            InkWell(
                                                              onTap: () => _sendBattlefieldCardToGraveyard(card),
                                                              child: Container(
                                                                padding: const EdgeInsets.all(3),
                                                                decoration: const BoxDecoration(
                                                                  color: Color(0xFF991B1B),
                                                                  shape: BoxShape.circle,
                                                                ),
                                                                child: const Icon(Icons.close, size: 10, color: Colors.white),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                      // Note Badge on card
                                                      if (card.note != null && card.note!.isNotEmpty)
                                                        Positioned(
                                                          left: 4,
                                                          top: 14,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFFEF08A),
                                                              borderRadius: BorderRadius.circular(4),
                                                              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                                                            ),
                                                            child: ConstrainedBox(
                                                              constraints: const BoxConstraints(maxWidth: 80),
                                                              child: Text(
                                                                card.note!,
                                                                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.black87),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                      if (_cardHasCombatStats(card)) ...[
                                                        // Counter Badge (+1/+1 tokens)
                                                        Positioned(
                                                          left: 2,
                                                          bottom: -8,
                                                          child: Tooltip(
                                                            message: 'Contadores (+1/+1) • Clic izq: +1 | Clic dcho: -1',
                                                            child: InkWell(
                                                              onTap: () {
                                                                setState(() => card.counters++);
                                                                _addLog('J${card.ownerPlayer} contador en "${card.data['card_name']}": ${card.counters}');
                                                              },
                                                              onSecondaryTap: () => setState(() => card.counters--),
                                                              child: Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: card.counters != 0 ? GrimoireTheme.accentEmerald : GrimoireTheme.surfaceElevated,
                                                                  borderRadius: BorderRadius.circular(8),
                                                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                                                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const Icon(Icons.shield_outlined, size: 10, color: Colors.white),
                                                                    const SizedBox(width: 2),
                                                                    Text(
                                                                      card.counters >= 0 ? '+${card.counters}' : '${card.counters}',
                                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                        // Damage Counter Badge (💥)
                                                        Positioned(
                                                          right: 2,
                                                          bottom: -8,
                                                          child: Tooltip(
                                                            message: 'Daño recibido • Clic izq: +1 | Clic dcho: -1',
                                                            child: InkWell(
                                                              onTap: () {
                                                                setState(() => card.damageCounters++);
                                                                _addLog('J${card.ownerPlayer} daño en "${card.data['card_name']}": ${card.damageCounters}', type: BattleLogType.combat);
                                                              },
                                                              onSecondaryTap: () => setState(() => card.damageCounters = math.max(0, card.damageCounters - 1)),
                                                              child: Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: card.damageCounters > 0 ? const Color(0xFFDC2626) : GrimoireTheme.surfaceElevated,
                                                                  borderRadius: BorderRadius.circular(8),
                                                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                                                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const Text('💥', style: TextStyle(fontSize: 9)),
                                                                    const SizedBox(width: 2),
                                                                    Text(
                                                                      '${card.damageCounters}',
                                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ] else if (card.counters != 0) ...[
                                                        // Generic Token Badge for non-combat cards (only visible when counters != 0)
                                                        Positioned(
                                                          left: 2,
                                                          bottom: -8,
                                                          child: Tooltip(
                                                            message: 'Fichas / Contadores • Clic izq: +1 | Clic dcho: -1',
                                                            child: InkWell(
                                                              onTap: () {
                                                                setState(() => card.counters++);
                                                                _addLog('J${card.ownerPlayer} ficha en "${card.data['card_name']}": ${card.counters}');
                                                              },
                                                              onSecondaryTap: () => setState(() => card.counters--),
                                                              child: Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: GrimoireTheme.accentEmerald,
                                                                  borderRadius: BorderRadius.circular(8),
                                                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                                                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const Icon(Icons.token_outlined, size: 10, color: Colors.white),
                                                                    const SizedBox(width: 2),
                                                                    Text(
                                                                      card.counters >= 0 ? '+${card.counters}' : '${card.counters}',
                                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],

                                                      // Energy / Charge Badge (⚡)
                                                      if (card.energyCounters > 0)
                                                        Positioned(
                                                          left: 36,
                                                          bottom: -8,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFD97706),
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                                              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Icon(Icons.bolt, size: 10, color: Colors.white),
                                                                const SizedBox(width: 2),
                                                                Text(
                                                                  '${card.energyCounters}',
                                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),

                                                      // Poison Badge (☠️)
                                                      if (card.poisonCounters > 0)
                                                        Positioned(
                                                          right: 36,
                                                          bottom: -8,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF7E22CE),
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                                              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Text('☠️', style: TextStyle(fontSize: 8.5)),
                                                                const SizedBox(width: 2),
                                                                Text(
                                                                  '${card.poisonCounters}',
                                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),

                                                      // Note button in center-bottom
                                                      Positioned(
                                                        left: 38,
                                                        bottom: -8,
                                                        child: InkWell(
                                                          onTap: () => _showAddNoteDialog(card),
                                                          child: Container(
                                                            padding: const EdgeInsets.all(2.5),
                                                            decoration: BoxDecoration(
                                                              color: card.note != null ? const Color(0xFFEAB308) : const Color(0xFF1E2235),
                                                              shape: BoxShape.circle,
                                                              border: Border.all(color: Colors.white24),
                                                            ),
                                                            child: const Icon(Icons.edit_note, size: 10, color: Colors.white),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Floating Zoom and Viewport HUD Controls
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: _buildZoomControlsHUD(),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Bottom Dock: Player 1 (Draw Pile | Graveyard | Hand Zone | Resources)
                    _buildPlayer1BottomBar(),
                  ],
                ),
              ),

              // Collapsible Battle Log Panel
              if (_showBattleLog)
                BattleLogPanel(
                  logs: _battleLogs,
                  onClear: () => setState(() => _battleLogs.clear()),
                  onClose: () => setState(() => _showBattleLog = false),
                ),
            ],
          ),

          // Zoomed Card Preview Modal Overlay
          if (_previewCardData != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _previewCardData = null),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: GrimoireTheme.accentPurple.withValues(alpha: 0.4),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Builder(
                              builder: (context) {
                                final tpl = ref.read(editorProvider.notifier).resolveTemplateForRow(_previewCardData!);
                                return CardRendererWidget(
                                  template: tpl,
                                  cardData: _previewCardData!,
                                  cardWidth: 280,
                                  cardHeight: 392,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Haz clic en cualquier parte para cerrar la vista previa',
                          style: TextStyle(color: GrimoireTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),
);
  }

  Widget _buildPlayer2TopBar() {
    return Container(
      height: 120,
      decoration: const BoxDecoration(
        color: Color(0xFF101422),
        border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          // P2 Label and Life/Mana
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ref.tr('player_2'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF67E8F9))),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('❤️ $_p2Life', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    InkWell(
                      onTap: () {
                        setState(() => _p2Life--);
                        _addLog('J2 Vida: $_p2Life', type: BattleLogType.life, player: 2);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        child: Icon(Icons.remove, size: 10, color: GrimoireTheme.accentPink),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _p2Life++);
                        _addLog('J2 Vida: $_p2Life', type: BattleLogType.life, player: 2);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        child: Icon(Icons.add, size: 10, color: GrimoireTheme.accentEmerald),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('💎 $_p2Mana', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF93C5FD))),
                    InkWell(
                      onTap: () => setState(() => _p2Mana = math.max(0, _p2Mana - 1)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        child: Icon(Icons.remove, size: 10, color: GrimoireTheme.accentIndigo),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _p2Mana++),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        child: Icon(Icons.add, size: 10, color: GrimoireTheme.accentIndigo),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // P2 Draw Deck Pile
          Container(
            width: 60,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF161F30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF06B6D4)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: InkWell(
                    onTap: () => _drawCard(player: 2),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.layers, color: Color(0xFF06B6D4), size: 18),
                        Text('${_p2DrawPile.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Text('Mazo J2', style: TextStyle(fontSize: 8, color: GrimoireTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Tooltip(
                    message: ref.tr('shuffle_deck'),
                    child: InkWell(
                      onTap: () => _shuffleDrawPile(player: 2),
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.shuffle, size: 10, color: Color(0xFF06B6D4)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // P2 Graveyard
          DragTarget<Map<String, dynamic>>(
            onAcceptWithDetails: (details) {
              _sendHandCardToGraveyard(details.data, player: 2);
            },
            builder: (context, candidate, _) {
              return Tooltip(
                message: 'Ver Cementerio / Descarte J2 (Clic para abrir)',
                child: InkWell(
                  onTap: () => _openGraveyardDialog(player: 2),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 60,
                    height: 90,
                    decoration: BoxDecoration(
                      color: candidate.isNotEmpty ? const Color(0xFF3B1219) : const Color(0xFF13111C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: candidate.isNotEmpty ? GrimoireTheme.accentPink : const Color(0xFF332A45)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_sweep_outlined, color: Color(0xFFF43F5E), size: 18),
                        Text('${_p2Graveyard.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Text('Descarte', style: TextStyle(fontSize: 8, color: GrimoireTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          const VerticalDivider(width: 1),
          const SizedBox(width: 12),

          // P2 Hand Zone
          IconButton(
            icon: Icon(_p2HandVisible ? Icons.visibility : Icons.visibility_off, size: 16, color: GrimoireTheme.textMuted),
            tooltip: _p2HandVisible ? 'Ocultar Mano de J2' : 'Mostrar Mano de J2',
            onPressed: () => setState(() => _p2HandVisible = !_p2HandVisible),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _p2Hand.isEmpty
                ? const Center(child: Text('Mano de J2 vacía', style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _p2Hand.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cardData = _p2Hand[index];
                      if (!_p2HandVisible) {
                        return _buildCardBackMini();
                      }
                      return Draggable<Map<String, dynamic>>(
                        data: cardData,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _buildRealisticMiniCard(cardData, elevation: 14),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _buildRealisticMiniCard(cardData),
                        ),
                        child: _buildRealisticMiniCard(cardData),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer1BottomBar() {
    return Container(
      height: 165,
      decoration: const BoxDecoration(
        color: GrimoireTheme.surfacePanel,
        border: Border(top: BorderSide(color: GrimoireTheme.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Player 1 Resources / Life / Mana Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: GrimoireTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_isDuelMode ? ref.tr('player_1') : ref.tr('resources'),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.accentPurple)),
                const SizedBox(height: 6),
                // Mana Counter
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💎 ', style: TextStyle(fontSize: 11)),
                    IconButton(
                      icon: const Icon(Icons.remove, size: 12, color: GrimoireTheme.accentIndigo),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _playerMana = math.max(0, _playerMana - 1)),
                    ),
                    const SizedBox(width: 2),
                    Text('$_playerMana', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: const Icon(Icons.add, size: 12, color: GrimoireTheme.accentIndigo),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _playerMana++),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Life Counter
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('❤️ ', style: TextStyle(fontSize: 11)),
                    IconButton(
                      icon: const Icon(Icons.remove, size: 12, color: GrimoireTheme.accentPink),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() => _playerLife--);
                        _addLog('J1 Vida: $_playerLife', type: BattleLogType.life, player: 1);
                      },
                    ),
                    const SizedBox(width: 2),
                    Text('$_playerLife', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: const Icon(Icons.add, size: 12, color: GrimoireTheme.accentEmerald),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() => _playerLife++);
                        _addLog('J1 Vida: $_playerLife', type: BattleLogType.life, player: 1);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Draw Deck Pile
          Container(
            width: 80,
            height: 140,
            decoration: BoxDecoration(
              color: GrimoireTheme.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GrimoireTheme.accentPurple),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: InkWell(
                    onTap: () => _drawCard(player: 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.layers, color: GrimoireTheme.accentPurple, size: 26),
                        const SizedBox(height: 4),
                        Text('${_drawPile.length}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(ref.tr('draw'), style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Tooltip(
                    message: ref.tr('shuffle_deck'),
                    child: InkWell(
                      onTap: () => _shuffleDrawPile(player: 1),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.shuffle, size: 12, color: GrimoireTheme.accentPurple),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Graveyard / Discard Zone
          DragTarget<Map<String, dynamic>>(
            onAcceptWithDetails: (details) {
              _sendHandCardToGraveyard(details.data, player: 1);
            },
            builder: (context, candidate, _) {
              return Tooltip(
                message: 'Ver Cementerio / Descarte J1 (Clic para abrir)',
                child: InkWell(
                  onTap: () => _openGraveyardDialog(player: 1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 80,
                    height: 140,
                    decoration: BoxDecoration(
                      color: candidate.isNotEmpty ? const Color(0xFF3B1219) : const Color(0xFF13111C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: candidate.isNotEmpty ? GrimoireTheme.accentPink : const Color(0xFF332A45),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_sweep_outlined, color: Color(0xFFF43F5E), size: 24),
                        const SizedBox(height: 4),
                        Text('${_graveyard.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('Cementerio', style: TextStyle(fontSize: 9, color: GrimoireTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 14),
          const VerticalDivider(width: 1),
          const SizedBox(width: 14),

          // Player Hand
          Expanded(
            child: _hand.isEmpty
                ? Center(
                    child: Text(ref.tr('hand_empty'),
                        style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted)),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _hand.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final cardData = _hand[index];
                      return Draggable<Map<String, dynamic>>(
                        data: cardData,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _buildRealisticMiniCard(cardData, elevation: 14),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _buildRealisticMiniCard(cardData),
                        ),
                        child: GestureDetector(
                          onSecondaryTap: () {
                            setState(() {
                              _previewCardData = cardData;
                            });
                          },
                          child: _buildRealisticMiniCard(cardData),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBackMini() {
    return Container(
      width: 65,
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E17),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF06B6D4), width: 1),
          ),
          child: const Center(
            child: Icon(Icons.auto_awesome, size: 12, color: Color(0xFF06B6D4)),
          ),
        ),
      ),
    );
  }

  Widget _buildRealisticMiniCard(
    Map<String, dynamic> data, {
    bool isTapped = false,
    bool isFaceDown = false,
    bool isToken = false,
    double elevation = 2,
  }) {
    if (isFaceDown) {
      return Container(
        width: 95,
        height: 133,
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E17),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: GrimoireTheme.accentPurple, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: elevation * 2,
              offset: Offset(0, elevation),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                      const Color(0xFF0C0E17),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, size: 16, color: GrimoireTheme.accentPurple),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'GRIMOIRE',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: Color(0xFFE9D5FF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final tpl = ref.read(editorProvider.notifier).resolveTemplateForRow(data);

    return Tooltip(
      message: '${data['card_name'] ?? 'Card'} • Clic derecho para ampliar',
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        width: 95,
        height: 133,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isTapped
                ? GrimoireTheme.accentAmber
                : (isToken ? const Color(0xFFEAB308) : GrimoireTheme.borderStrong),
            width: isTapped || isToken ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: elevation * 2,
              offset: Offset(0, elevation),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: FittedBox(
            fit: BoxFit.fill,
            child: CardRendererWidget(
              template: tpl,
              cardData: data,
              cardWidth: 254,
              cardHeight: 355.6,
            ),
          ),
        ),
      ),
    );
  }

  void _rollDie(int sides, String label) {
    final rand = math.Random();
    final result = rand.nextInt(sides) + 1;
    final log = '$label -> $result';
    setState(() {
      _lastRoll = '$result ($label)';
      _rollHistory.insert(0, log);
      if (_rollHistory.length > 8) _rollHistory.removeLast();
      _addLog('Tirada de $label: ¡$result!', type: BattleLogType.dice);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GrimoireTheme.surfaceElevated,
        duration: const Duration(milliseconds: 1600),
        content: Text('🎲 Tirada de $label: ¡$result!',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
      ),
    );
  }

  void _flipCoin() {
    final rand = math.Random();
    final isHeads = rand.nextBool();
    final result = isHeads ? 'Cara' : 'Cruz';
    final log = 'Moneda -> $result';
    setState(() {
      _lastRoll = result;
      _rollHistory.insert(0, log);
      if (_rollHistory.length > 8) _rollHistory.removeLast();
      _addLog('Lanzamiento de Moneda: ¡$result!', type: BattleLogType.dice);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GrimoireTheme.surfaceElevated,
        duration: const Duration(milliseconds: 1600),
        content: Text('🪙 Lanzamiento de Moneda: ¡$result!',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
      ),
    );
  }

  void _showDiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: GrimoireTheme.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.casino_outlined, color: GrimoireTheme.accentEmerald, size: 20),
                SizedBox(width: 8),
                Text('Lanzador de Dados y Azar', style: TextStyle(fontSize: 14, color: Colors.white)),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecciona qué dado o moneda lanzar:', style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple, minimumSize: const Size(90, 36)),
                        icon: const Icon(Icons.casino, size: 14),
                        label: const Text('1d6', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _rollDie(6, '1d6');
                          setDialogState(() {});
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentIndigo, minimumSize: const Size(90, 36)),
                        icon: const Icon(Icons.casino, size: 14),
                        label: const Text('2d6', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          final r = (math.Random().nextInt(6) + 1) + (math.Random().nextInt(6) + 1);
                          final log = '2d6 -> $r';
                          setState(() {
                            _lastRoll = '$r (2d6)';
                            _rollHistory.insert(0, log);
                            if (_rollHistory.length > 8) _rollHistory.removeLast();
                            _addLog('Tirada de 2d6: ¡$r!', type: BattleLogType.dice);
                          });
                          setDialogState(() {});
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentEmerald, minimumSize: const Size(90, 36)),
                        icon: const Icon(Icons.change_history, size: 14),
                        label: const Text('1d20', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _rollDie(20, '1d20');
                          setDialogState(() {});
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentAmber, minimumSize: const Size(90, 36)),
                        icon: const Icon(Icons.percent, size: 14),
                        label: const Text('1d100', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _rollDie(100, '1d100');
                          setDialogState(() {});
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E), minimumSize: const Size(90, 36)),
                        icon: const Icon(Icons.circle_outlined, size: 14),
                        label: const Text('Moneda', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _flipCoin();
                          setDialogState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: GrimoireTheme.borderSubtle),
                  const SizedBox(height: 6),
                  const Text('Historial de tiradas recientes:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Container(
                    height: 100,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.bgCanvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GrimoireTheme.borderSubtle),
                    ),
                    child: _rollHistory.isEmpty
                        ? const Center(child: Text('Sin tiradas aún', style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)))
                        : ListView.builder(
                            itemCount: _rollHistory.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('• ${_rollHistory[i]}', style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0))),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeckSearchDialog({int player = 1}) {
    String searchFilter = '';
    final targetPile = player == 1 ? _drawPile : _p2DrawPile;
    final targetHand = player == 1 ? _hand : _p2Hand;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredCards = targetPile.where((c) {
            final name = (c['card_name'] ?? '').toString().toLowerCase();
            final type = (c['type'] ?? '').toString().toLowerCase();
            final q = searchFilter.toLowerCase();
            return q.isEmpty || name.contains(q) || type.contains(q);
          }).toList();

          return AlertDialog(
            backgroundColor: GrimoireTheme.surfaceElevated,
            title: Row(
              children: [
                const Icon(Icons.manage_search_outlined, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 8),
                Text('Tutor: Buscar en Mazo J$player (${targetPile.length} restantes)',
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Filtrar cartas en el mazo por nombre o tipo...',
                      hintStyle: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 16, color: GrimoireTheme.textMuted),
                      filled: true,
                      fillColor: GrimoireTheme.bgCanvas,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrimoireTheme.borderSubtle)),
                    ),
                    onChanged: (val) {
                      setDialogState(() => searchFilter = val.trim());
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredCards.isEmpty
                        ? const Center(child: Text('No hay cartas coincidentes en el mazo.', style: TextStyle(color: GrimoireTheme.textMuted, fontSize: 12)))
                        : ListView.separated(
                            itemCount: filteredCards.length,
                            separatorBuilder: (_, _) => const Divider(color: GrimoireTheme.borderSubtle, height: 1),
                            itemBuilder: (context, idx) {
                              final card = filteredCards[idx];
                              final cardName = card['card_name'] ?? 'Card';
                              final cardType = card['type'] ?? '';
                              final cardCost = card['cost'] ?? '';

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                leading: const Icon(Icons.style_outlined, color: GrimoireTheme.accentPurple, size: 20),
                                title: Text(
                                  cardName.toString(),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                subtitle: Text(
                                  '$cardType ${cardCost.toString().isNotEmpty ? '• Coste: $cardCost' : ''}',
                                  style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: const Size(0, 28),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          targetPile.remove(card);
                                          targetHand.add(card);
                                          _addLog('J$player buscó "$cardName" y la añadió a su mano.', type: BattleLogType.draw, player: player);
                                        });
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: GrimoireTheme.accentEmerald,
                                            content: Text('"$cardName" añadida a la mano de J$player.'),
                                          ),
                                        );
                                      },
                                      child: const Text('A la Mano', style: TextStyle(fontSize: 10)),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: GrimoireTheme.accentPurple,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: const Size(0, 28),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          targetPile.remove(card);
                                          _playCardToBattlefield(card, const Offset(150, 100), player: player);
                                        });
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: GrimoireTheme.accentPurple,
                                            content: Text('"$cardName" puesta en el campo de batalla.'),
                                          ),
                                        );
                                      },
                                      child: const Text('Al Campo', style: TextStyle(fontSize: 10)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _shuffleDrawPile(player: player);
                  Navigator.pop(ctx);
                },
                child: const Text('Barajar Mazo y Cerrar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.surfacePanel),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PlayerZoneSpec {
  final int player;
  final Offset position;
  final String label;

  const PlayerZoneSpec({
    required this.player,
    required this.position,
    required this.label,
  });
}

class TableDivisionPainter extends CustomPainter {
  final TableDivisionMode mode;
  final PlaymatTheme theme;
  final int activePlayer;

  TableDivisionPainter({
    required this.mode,
    required this.theme,
    required this.activePlayer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == TableDivisionMode.none) return;

    final center = Offset(size.width / 2, size.height / 2);
    final double centerRadius = math.min(size.width, size.height) * 0.09;

    final linePaint = Paint()
      ..color = theme.duelLineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = theme.accentColor.withValues(alpha: 0.25)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final hubFillPaint = Paint()
      ..color = const Color(0xFF0F111D).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final hubBorderPaint = Paint()
      ..color = theme.accentColor.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    void drawRay(double angleRad) {
      final dir = Offset(math.cos(angleRad), math.sin(angleRad));
      final pStart = center + dir * centerRadius;
      final double maxDist = math.max(size.width, size.height) * 1.5;
      final pEnd = center + dir * maxDist;
      canvas.drawLine(pStart, pEnd, glowPaint);
      canvas.drawLine(pStart, pEnd, linePaint);
    }

    switch (mode) {
      case TableDivisionMode.none:
        break;

      case TableDivisionMode.duel:
        final pStartL = Offset(0, center.dy);
        final pEndL = Offset(center.dx - centerRadius, center.dy);
        final pStartR = Offset(center.dx + centerRadius, center.dy);
        final pEndR = Offset(size.width, center.dy);
        canvas.drawLine(pStartL, pEndL, glowPaint);
        canvas.drawLine(pStartL, pEndL, linePaint);
        canvas.drawLine(pStartR, pEndR, glowPaint);
        canvas.drawLine(pStartR, pEndR, linePaint);
        break;

      case TableDivisionMode.twoSideBySide:
        final pStartT = Offset(center.dx, 0);
        final pEndT = Offset(center.dx, center.dy - centerRadius);
        final pStartB = Offset(center.dx, center.dy + centerRadius);
        final pEndB = Offset(center.dx, size.height);
        canvas.drawLine(pStartT, pEndT, glowPaint);
        canvas.drawLine(pStartT, pEndT, linePaint);
        canvas.drawLine(pStartB, pEndB, glowPaint);
        canvas.drawLine(pStartB, pEndB, linePaint);
        break;

      case TableDivisionMode.fourCross:
        // Horizontal
        canvas.drawLine(Offset(0, center.dy), Offset(center.dx - centerRadius, center.dy), glowPaint);
        canvas.drawLine(Offset(0, center.dy), Offset(center.dx - centerRadius, center.dy), linePaint);
        canvas.drawLine(Offset(center.dx + centerRadius, center.dy), Offset(size.width, center.dy), glowPaint);
        canvas.drawLine(Offset(center.dx + centerRadius, center.dy), Offset(size.width, center.dy), linePaint);
        // Vertical
        canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, center.dy - centerRadius), glowPaint);
        canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, center.dy - centerRadius), linePaint);
        canvas.drawLine(Offset(center.dx, center.dy + centerRadius), Offset(center.dx, size.height), glowPaint);
        canvas.drawLine(Offset(center.dx, center.dy + centerRadius), Offset(center.dx, size.height), linePaint);
        break;

      case TableDivisionMode.threeRadial:
        drawRay(-math.pi / 2);
        drawRay(math.pi / 6);
        drawRay(5 * math.pi / 6);
        break;

      case TableDivisionMode.sixRadial:
        for (int i = 0; i < 6; i++) {
          drawRay(i * math.pi / 3);
        }
        break;

      case TableDivisionMode.eightRadial:
        for (int i = 0; i < 8; i++) {
          drawRay(i * math.pi / 4);
        }
        break;
    }

    // Central Hub circle
    canvas.drawCircle(center, centerRadius, hubFillPaint);
    canvas.drawCircle(center, centerRadius, hubBorderPaint);
    canvas.drawCircle(center, centerRadius + 5, Paint()
      ..color = theme.accentColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant TableDivisionPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.theme != theme ||
        oldDelegate.activePlayer != activePlayer;
  }
}
