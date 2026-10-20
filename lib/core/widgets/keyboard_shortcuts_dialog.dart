import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/grimoire_theme.dart';
import '../localization/locale_provider.dart';

/// Interactive modal dialog displaying keyboard shortcuts and workflow productivity tips.
class KeyboardShortcutsDialog extends ConsumerWidget {
  const KeyboardShortcutsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const KeyboardShortcutsDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.tr('shortcuts_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        ref.tr('shortcuts_subtitle'),
                        style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
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
                    _buildSection(ref.tr('nav_global_section'), [
                      _buildShortcutRow('Ctrl + K', ref.tr('shortcut_spotlight')),
                      _buildShortcutRow('Ctrl + 1', ref.tr('shortcut_gallery')),
                      _buildShortcutRow('Ctrl + 2', ref.tr('shortcut_editor')),
                      _buildShortcutRow('Ctrl + 3', ref.tr('shortcut_database')),
                      _buildShortcutRow('Ctrl + 4', ref.tr('shortcut_playtest')),
                      _buildShortcutRow('Ctrl + /', ref.tr('shortcut_help')),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection(ref.tr('edit_project_section'), [
                      _buildShortcutRow('Ctrl + S', ref.tr('shortcut_save_export')),
                      _buildShortcutRow('Ctrl + E', ref.tr('shortcut_export_300dpi')),
                      _buildShortcutRow('Ctrl + O', ref.tr('shortcut_import_pkg')),
                      _buildShortcutRow('Ctrl + Z', ref.tr('shortcut_undo')),
                      _buildShortcutRow('Ctrl + Y', ref.tr('shortcut_redo')),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection(ref.tr('canvas_layers_section'), [
                      _buildShortcutRow('Supr / Backspace', ref.tr('shortcut_delete_layer')),
                      _buildShortcutRow('Flecha / Arrow', ref.tr('shortcut_prev_next_card')),
                      _buildShortcutRow('Ctrl + Shift + B', ref.tr('shortcut_toggle_guides')),
                      _buildShortcutRow('Scroll / Wheel', ref.tr('shortcut_zoom')),
                      _buildShortcutRow('Space + Drag', ref.tr('shortcut_pan')),
                    ]),
                    const SizedBox(height: 16),

                    _buildSection(ref.tr('playtest_section'), [
                      _buildShortcutRow('Drag card', ref.tr('shortcut_play_card')),
                      _buildShortcutRow('Double click', ref.tr('shortcut_tap_card')),
                      _buildShortcutRow('Right click deck', ref.tr('shortcut_draw_card')),
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
                child: Text(ref.tr('close'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
