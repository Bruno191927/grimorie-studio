import 'package:flutter/material.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';

class TokenPreset {
  final String name;
  final String icon;
  final String type;
  final String attack;
  final String defense;
  final String cost;
  final int color;
  final String rules;

  const TokenPreset({
    required this.name,
    required this.icon,
    required this.type,
    this.attack = '0',
    this.defense = '0',
    this.cost = '0',
    required this.color,
    this.rules = 'Ficha generada para el campo de batalla.',
  });
}

class TokenSpawnerDialog extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onSpawnToken;

  const TokenSpawnerDialog({super.key, required this.onSpawnToken});

  static Future<void> show(BuildContext context, {required ValueChanged<Map<String, dynamic>> onSpawnToken}) {
    return showDialog(
      context: context,
      builder: (ctx) => TokenSpawnerDialog(onSpawnToken: onSpawnToken),
    );
  }

  @override
  State<TokenSpawnerDialog> createState() => _TokenSpawnerDialogState();
}

class _TokenSpawnerDialogState extends State<TokenSpawnerDialog> {
  final _nameController = TextEditingController(text: 'Ficha Soldado');
  final _atkController = TextEditingController(text: '1');
  final _defController = TextEditingController(text: '1');
  final _rulesController = TextEditingController(text: 'Ficha de criatura generada.');
  String _selectedEmoji = '⚔️';
  final Color _selectedColor = GrimoireTheme.accentPurple;

  static const List<TokenPreset> _presets = [
    TokenPreset(
      name: 'Soldado 1/1',
      icon: '⚔️',
      type: 'Ficha Criatura',
      attack: '1',
      defense: '1',
      color: 0xFFF59E0B,
      rules: 'Ficha de combate estándar.',
    ),
    TokenPreset(
      name: 'Goblin 1/1 Prisa',
      icon: '👺',
      type: 'Ficha Criatura',
      attack: '1',
      defense: '1',
      color: 0xFFDC2626,
      rules: 'Prisa (Puede atacar el turno en que entra).',
    ),
    TokenPreset(
      name: 'Lobo Feroz 2/2',
      icon: '🐺',
      type: 'Ficha Criatura',
      attack: '2',
      defense: '2',
      color: 0xFF10B981,
      rules: 'Cazador nocturno.',
    ),
    TokenPreset(
      name: 'Moneda de Tesoro',
      icon: '🪙',
      type: 'Ficha Artefacto',
      attack: '0',
      defense: '0',
      color: 0xFFEAB308,
      rules: 'Sacrificar: Agrega 1 maná de cualquier color.',
    ),
    TokenPreset(
      name: 'Muro Protector 0/4',
      icon: '🛡️',
      type: 'Ficha Muro',
      attack: '0',
      defense: '4',
      color: 0xFF6366F1,
      rules: 'Defensor (No puede atacar).',
    ),
    TokenPreset(
      name: 'Veneno / Herida',
      icon: '☠️',
      type: 'Ficha Estado',
      attack: '0',
      defense: '0',
      color: 0xFF84CC16,
      rules: 'Resta 1 punto de vida al inicio del turno.',
    ),
    TokenPreset(
      name: 'Pista / Secreto',
      icon: '🔍',
      type: 'Ficha Recurso',
      attack: '0',
      defense: '0',
      color: 0xFF06B6D4,
      rules: 'Paga 2 y sacrifica: Roba 1 carta.',
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _atkController.dispose();
    _defController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  void _spawnPreset(TokenPreset preset) {
    final tokenData = {
      'card_name': preset.name,
      'cost': preset.cost,
      'type': preset.type,
      'rarity': 'Ficha',
      'attack': preset.attack,
      'defense': preset.defense,
      'rules_text': preset.rules,
      'icon': preset.icon,
      'art_color': preset.color,
      'is_token': true,
      'game': 'Tokens',
    };
    widget.onSpawnToken(tokenData);
    Navigator.of(context).pop();
  }

  void _spawnCustom() {
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Ficha Personalizada';
    final tokenData = {
      'card_name': name,
      'cost': '0',
      'type': 'Ficha',
      'rarity': 'Ficha',
      'attack': _atkController.text.trim(),
      'defense': _defController.text.trim(),
      'rules_text': _rulesController.text.trim(),
      'icon': _selectedEmoji,
      'art_color': _selectedColor.toARGB32(),
      'is_token': true,
      'game': 'Tokens',
    };
    widget.onSpawnToken(tokenData);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.toll, color: GrimoireTheme.accentAmber, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Generador de Fichas y Tokens',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'FICHAS PREDEFINIDAS POPULARES',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textMuted),
              ),
              const SizedBox(height: 8),

              // Presets Grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _presets)
                    InkWell(
                      onTap: () => _spawnPreset(p),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 125,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(p.color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(p.color).withValues(alpha: 0.45)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(p.icon, style: const TextStyle(fontSize: 16)),
                                if (p.attack != '0' || p.defense != '0')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Color(p.color).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${p.attack}/${p.defense}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(p.color),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.name,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.type,
                              style: const TextStyle(fontSize: 9, color: GrimoireTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(color: GrimoireTheme.borderSubtle),
              const SizedBox(height: 10),

              // Custom Token Section
              const Text(
                'CREAR TOKEN PERSONALIZADO',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Token',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _atkController,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: '⚔️ ATK',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _defController,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: '🛡️ DEF',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _rulesController,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Efecto o Regla del Token',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),

              // Emoji and Color Quick Select
              Row(
                children: [
                  const Text('Icono: ', style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                  for (final emoji in ['⚔️', '🛡️', '🪙', '🐺', '🐉', '💀', '💎', '🦄'])
                    InkWell(
                      onTap: () => setState(() => _selectedEmoji = emoji),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _selectedEmoji == emoji ? GrimoireTheme.accentPurple.withValues(alpha: 0.3) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Generar en la Mesa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _spawnCustom,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
