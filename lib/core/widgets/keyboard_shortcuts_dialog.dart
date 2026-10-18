import 'package:flutter/material.dart';
import '../theme/grimoire_theme.dart';

/// Interactive modal dialog displaying keyboard shortcuts and workflow productivity tips.
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const KeyboardShortcutsDialog(),
    );
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
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.keyboard_outlined, color: GrimoireTheme.accentPurple, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Atajos de Teclado & Flujo Rápido',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Aumenta tu velocidad de diseño en Grimoire Studio',
                        style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
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

            // Content
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('NAVEGACIÓN GLOBAL', [
                      _buildShortcutRow('Ctrl + K', 'Búsqueda rápida de cartas (Spotlight)'),
                      _buildShortcutRow('Ctrl + 1', 'Ir a la Galería de Cartas'),
                      _buildShortcutRow('Ctrl + 2', 'Ir al Editor de Diseño'),
                      _buildShortcutRow('Ctrl + 3', 'Ir a la Base de Datos & CSV'),
                      _buildShortcutRow('Ctrl + 4', 'Ir a la Mesa de Playtest Virtual'),
                      _buildShortcutRow('Ctrl + /', 'Abrir esta guía de atajos'),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection('EDICIÓN & PROYECTO', [
                      _buildShortcutRow('Ctrl + S', 'Guardar proyecto activo y exportar CSV'),
                      _buildShortcutRow('Ctrl + E', 'Exportar mazo a 300 DPI / PDF para imprenta'),
                      _buildShortcutRow('Ctrl + O', 'Importar paquete .grimoire o zip'),
                      _buildShortcutRow('Ctrl + Z', 'Deshacer último cambio de capa'),
                      _buildShortcutRow('Ctrl + Y', 'Rehacer cambio'),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection('LIENZO & CAPAS', [
                      _buildShortcutRow('Supr / Backspace', 'Eliminar capa seleccionada'),
                      _buildShortcutRow('Flecha Izq / Der', 'Cambiar a carta anterior / siguiente'),
                      _buildShortcutRow('Ctrl + Shift + B', 'Alternar guías de corte y sangrado (3mm)'),
                      _buildShortcutRow('Rueda del Ratón', 'Zoom in / Zoom out en el lienzo'),
                      _buildShortcutRow('Espacio + Arrastre', 'Desplazar lienzo (Pan)'),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection('MESA DE PLAYTEST', [
                      _buildShortcutRow('Arrastrar carta', 'Jugar carta al campo de batalla'),
                      _buildShortcutRow('Doble clic en carta', 'Girar / Agotar carta (Tap / Untap 90°)'),
                      _buildShortcutRow('Clic derecho en mazo', 'Robar 1 carta a la mano'),
                    ]),
                  ],
                ),
              ),
            ),
            const Divider(color: GrimoireTheme.borderSubtle, height: 24),

            // Footer
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GrimoireTheme.accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: GrimoireTheme.accentPurple,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: GrimoireTheme.surfacePanel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildShortcutRow(String keys, String description) {
    final keyParts = keys.split(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 11.5, color: GrimoireTheme.textPrimary),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final part in keyParts)
                if (part == '+')
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('+', style: TextStyle(color: GrimoireTheme.textMuted, fontSize: 11)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F243A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF333B58)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(0, 1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      part,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE2E8F0),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
