import 'package:flutter/material.dart';

enum TableDivisionMode {
  none,          // 1 Jugador (Solitario / Abierto)
  duel,          // 2 Jugadores (Duelo Frente a Frente)
  twoSideBySide, // 2 Jugadores (Lado a Lado)
  threeRadial,   // 3 Jugadores (Radial 120°)
  fourCross,     // 4 Jugadores (4 Cuadrantes)
  sixRadial,     // 6 Jugadores (Radial 60° - Hexagonal)
  eightRadial,   // 8 Jugadores (Radial 45° - Octagonal)
}

extension TableDivisionModeExt on TableDivisionMode {
  String get label {
    switch (this) {
      case TableDivisionMode.none:
        return '1 Jugador (Solitario)';
      case TableDivisionMode.duel:
        return '2 Jugadores (Duelo Frente a Frente)';
      case TableDivisionMode.twoSideBySide:
        return '2 Jugadores (Lado a Lado)';
      case TableDivisionMode.threeRadial:
        return '3 Jugadores (Radial 120°)';
      case TableDivisionMode.fourCross:
        return '4 Jugadores (4 Cuadrantes)';
      case TableDivisionMode.sixRadial:
        return '6 Jugadores (Radial 60° - Hexagonal)';
      case TableDivisionMode.eightRadial:
        return '8 Jugadores (Radial 45° - Octagonal)';
    }
  }

  String get shortLabel {
    switch (this) {
      case TableDivisionMode.none:
        return '1 Jugador';
      case TableDivisionMode.duel:
        return '2J Duelo';
      case TableDivisionMode.twoSideBySide:
        return '2J Lado a Lado';
      case TableDivisionMode.threeRadial:
        return '3J Radial';
      case TableDivisionMode.fourCross:
        return '4J Cuadrantes';
      case TableDivisionMode.sixRadial:
        return '6J Hexagonal';
      case TableDivisionMode.eightRadial:
        return '8J Octagonal';
    }
  }

  IconData get icon {
    switch (this) {
      case TableDivisionMode.none:
        return Icons.person_outline;
      case TableDivisionMode.duel:
        return Icons.sports_kabaddi;
      case TableDivisionMode.twoSideBySide:
        return Icons.view_column_outlined;
      case TableDivisionMode.threeRadial:
        return Icons.change_history;
      case TableDivisionMode.fourCross:
        return Icons.grid_view;
      case TableDivisionMode.sixRadial:
        return Icons.hexagon_outlined;
      case TableDivisionMode.eightRadial:
        return Icons.stars_outlined;
    }
  }

  int get playerCount {
    switch (this) {
      case TableDivisionMode.none:
        return 1;
      case TableDivisionMode.duel:
      case TableDivisionMode.twoSideBySide:
        return 2;
      case TableDivisionMode.threeRadial:
        return 3;
      case TableDivisionMode.fourCross:
        return 4;
      case TableDivisionMode.sixRadial:
        return 6;
      case TableDivisionMode.eightRadial:
        return 8;
    }
  }
}

enum PlaytestCardRotation {
  normal,   // 0 deg
  tapped,   // 90 deg
  inverted, // 180 deg
}

class PlaytestCard {
  final String id;
  final Map<String, dynamic> data;
  Offset position;
  bool isTapped;
  int rotationDegrees; // 0, 90, 180
  int counters; // +1/+1
  int damageCounters;
  int energyCounters;
  int poisonCounters;
  bool isFaceDown;
  bool isToken;
  String? note;
  int ownerPlayer; // 1: Player 1 (Bottom), 2: Player 2 (Top)

  PlaytestCard({
    required this.id,
    required this.data,
    required this.position,
    this.isTapped = false,
    this.rotationDegrees = 0,
    this.counters = 0,
    this.damageCounters = 0,
    this.energyCounters = 0,
    this.poisonCounters = 0,
    this.isFaceDown = false,
    this.isToken = false,
    this.note,
    this.ownerPlayer = 1,
  });

  void toggleTap() {
    isTapped = !isTapped;
    rotationDegrees = isTapped ? 90 : 0;
  }

  double get rotationAngle {
    if (rotationDegrees == 90 || (isTapped && rotationDegrees == 0)) {
      return 1.5708; // 90 deg in radians
    } else if (rotationDegrees == 180) {
      return 3.14159; // 180 deg
    }
    return 0;
  }
}

class PlaymatTheme {
  final String id;
  final String name;
  final String icon;
  final BoxDecoration decoration;
  final Color accentColor;
  final Color gridLineColor;
  final Color duelLineColor;

  const PlaymatTheme({
    required this.id,
    required this.name,
    required this.icon,
    required this.decoration,
    required this.accentColor,
    required this.gridLineColor,
    required this.duelLineColor,
  });

  static List<PlaymatTheme> get presets => [
        PlaymatTheme(
          id: 'mystic_violet',
          name: 'Neopreno Místico',
          icon: '🔮',
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
          accentColor: Color(0xFF8B5CF6),
          gridLineColor: Color(0x158B5CF6),
          duelLineColor: Color(0x408B5CF6),
        ),
        PlaymatTheme(
          id: 'casino_felt',
          name: 'Fieltro Casino Royale',
          icon: '♠️',
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.1,
              colors: [
                Color(0xFF064E3B),
                Color(0xFF042F24),
                Color(0xFF021B14),
              ],
            ),
          ),
          accentColor: Color(0xFF10B981),
          gridLineColor: Color(0x1510B981),
          duelLineColor: Color(0x4010B981),
        ),
        PlaymatTheme(
          id: 'tavern_wood',
          name: 'Taberna Rústica',
          icon: '🪵',
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2E1C12),
                Color(0xFF1F120A),
                Color(0xFF140A05),
              ],
            ),
          ),
          accentColor: Color(0xFFF59E0B),
          gridLineColor: Color(0x15F59E0B),
          duelLineColor: Color(0x40F59E0B),
        ),
        PlaymatTheme(
          id: 'cyber_grid',
          name: 'Cyber Void',
          icon: '⚡',
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.3,
              colors: [
                Color(0xFF0A1B2E),
                Color(0xFF06101D),
                Color(0xFF03070E),
              ],
            ),
          ),
          accentColor: Color(0xFF06B6D4),
          gridLineColor: Color(0x1806B6D4),
          duelLineColor: Color(0x4506B6D4),
        ),
      ];
}

enum BattleLogType {
  general,
  turn,
  draw,
  play,
  combat,
  dice,
  life,
  token,
}

class BattleLogEntry {
  final DateTime timestamp;
  final String message;
  final BattleLogType type;
  final int player; // 1 or 2

  const BattleLogEntry({
    required this.timestamp,
    required this.message,
    this.type = BattleLogType.general,
    this.player = 1,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
