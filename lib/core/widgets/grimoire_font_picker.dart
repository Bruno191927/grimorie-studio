import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/grimoire_theme.dart';

class FontOptionItem {
  final String family;
  final String category;
  final String sampleTag;
  final bool isSystemFont;

  const FontOptionItem({
    required this.family,
    required this.category,
    required this.sampleTag,
    this.isSystemFont = false,
  });
}

class GrimoireFontHelper {
  static const Set<String> _systemFonts = {
    'Segoe UI',
    'Arial',
    'Georgia',
    'Times New Roman',
    'Impact',
    'Verdana',
    'Trebuchet MS',
    'Palatino Linotype',
    'Courier New',
    'Consolas',
    'Comic Sans MS',
    'Tahoma',
    'Garamond',
    'monospace',
    'serif',
    'sans-serif',
  };

  static const List<FontOptionItem> curatedFonts = [
    // Modern & TCG UI
    FontOptionItem(family: 'Inter', category: 'Moderna & TCG', sampleTag: 'Estándar UI'),
    FontOptionItem(family: 'Montserrat', category: 'Moderna & TCG', sampleTag: 'Títulos Limpios'),
    FontOptionItem(family: 'Oswald', category: 'Moderna & TCG', sampleTag: 'Compacta & Fuerte'),
    FontOptionItem(family: 'Bebas Neue', category: 'Moderna & TCG', sampleTag: 'Impacto Alto'),
    FontOptionItem(family: 'Teko', category: 'Moderna & TCG', sampleTag: 'Stats & Números'),
    FontOptionItem(family: 'Rajdhani', category: 'Moderna & TCG', sampleTag: 'Táctica TCG'),
    FontOptionItem(family: 'Anton', category: 'Moderna & TCG', sampleTag: 'Póster Bold'),
    FontOptionItem(family: 'Poppins', category: 'Moderna & TCG', sampleTag: 'Geométrica'),
    FontOptionItem(family: 'Roboto', category: 'Moderna & TCG', sampleTag: 'Reglas Claras'),

    // Fantasy, RPG & Medieval
    FontOptionItem(family: 'Cinzel', category: 'Fantasía & RPG', sampleTag: 'Épica Clásica'),
    FontOptionItem(family: 'Cinzel Decorative', category: 'Fantasía & RPG', sampleTag: 'Reliquia Mítica'),
    FontOptionItem(family: 'MedievalSharp', category: 'Fantasía & RPG', sampleTag: 'Grimorio Medieval'),
    FontOptionItem(family: 'Uncial Antiqua', category: 'Fantasía & RPG', sampleTag: 'Pergamino Celta'),
    FontOptionItem(family: 'Almendra', category: 'Fantasía & RPG', sampleTag: 'Gótica Fantasía'),
    FontOptionItem(family: 'IM Fell English SC', category: 'Fantasía & RPG', sampleTag: 'Libro Antiguo'),
    FontOptionItem(family: 'Playfair Display', category: 'Fantasía & RPG', sampleTag: 'Nobleza & Magia'),
    FontOptionItem(family: 'EB Garamond', category: 'Fantasía & RPG', sampleTag: 'Lore & Crónicas'),
    FontOptionItem(family: 'Cormorant Garamond', category: 'Fantasía & RPG', sampleTag: 'Elegante Serif'),
    FontOptionItem(family: 'Merriweather', category: 'Fantasía & RPG', sampleTag: 'Lectura Clásica'),

    // Sci-Fi & Cyberpunk
    FontOptionItem(family: 'Orbitron', category: 'Sci-Fi & Cyber', sampleTag: 'Mecha & Espacio'),
    FontOptionItem(family: 'Chakra Petch', category: 'Sci-Fi & Cyber', sampleTag: 'Cyberpunk HUD'),
    FontOptionItem(family: 'Audiowide', category: 'Sci-Fi & Cyber', sampleTag: 'Futurista Neon'),
    FontOptionItem(family: 'Exo 2', category: 'Sci-Fi & Cyber', sampleTag: 'Nave Espacial'),
    FontOptionItem(family: 'Share Tech Mono', category: 'Sci-Fi & Cyber', sampleTag: 'Terminal Hacker'),
    FontOptionItem(family: 'Space Grotesk', category: 'Sci-Fi & Cyber', sampleTag: 'Sci-Fi Limpia'),

    // Comic, Display & Stylized
    FontOptionItem(family: 'Bangers', category: 'Cómic & Display', sampleTag: 'Acción / Cómic'),
    FontOptionItem(family: 'Permanent Marker', category: 'Cómic & Display', sampleTag: 'Trazo Marcador'),
    FontOptionItem(family: 'Creepster', category: 'Cómic & Display', sampleTag: 'Terror / Zombies'),
    FontOptionItem(family: 'Pacifico', category: 'Cómic & Display', sampleTag: 'Kawaii / Script'),
    FontOptionItem(family: 'Lobster', category: 'Cómic & Display', sampleTag: 'Clásica Curva'),
    FontOptionItem(family: 'Caveat', category: 'Cómic & Display', sampleTag: 'Nota Manuscrita'),
    FontOptionItem(family: 'Press Start 2P', category: 'Cómic & Display', sampleTag: 'Pixel Art 8-Bit'),
    FontOptionItem(family: 'VT323', category: 'Cómic & Display', sampleTag: 'Retro Arcade'),

    // System Fonts (Offline Instant)
    FontOptionItem(family: 'Segoe UI', category: 'Sistema (PC)', sampleTag: 'Windows Nativa', isSystemFont: true),
    FontOptionItem(family: 'Georgia', category: 'Sistema (PC)', sampleTag: 'Serif Clásica', isSystemFont: true),
    FontOptionItem(family: 'Times New Roman', category: 'Sistema (PC)', sampleTag: 'Tradicional TCG', isSystemFont: true),
    FontOptionItem(family: 'Impact', category: 'Sistema (PC)', sampleTag: 'Titular Pesado', isSystemFont: true),
    FontOptionItem(family: 'Trebuchet MS', category: 'Sistema (PC)', sampleTag: 'Humanista', isSystemFont: true),
    FontOptionItem(family: 'Palatino Linotype', category: 'Sistema (PC)', sampleTag: 'Literaria', isSystemFont: true),
    FontOptionItem(family: 'Verdana', category: 'Sistema (PC)', sampleTag: 'Alta Legibilidad', isSystemFont: true),
    FontOptionItem(family: 'Consolas', category: 'Sistema (PC)', sampleTag: 'Monoespaciada', isSystemFont: true),
    FontOptionItem(family: 'Comic Sans MS', category: 'Sistema (PC)', sampleTag: 'Casual / Humor', isSystemFont: true),
  ];

  static List<String> get categories => const [
        'Todas',
        'Fantasía & RPG',
        'Moderna & TCG',
        'Sci-Fi & Cyber',
        'Cómic & Display',
        'Sistema (PC)',
      ];

  /// Resolves a [TextStyle] for any Google Font or local system font safely.
  static TextStyle resolveTextStyle({
    required String fontFamily,
    required double fontSize,
    bool isBold = false,
    bool isItalic = false,
    Color color = Colors.white,
    double letterSpacing = 0.2,
  }) {
    final trimmed = fontFamily.trim().isEmpty ? 'Inter' : fontFamily.trim();
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      color: color,
      letterSpacing: letterSpacing,
    );

    if (_systemFonts.contains(trimmed) || Platform.environment.containsKey('FLUTTER_TEST')) {
      return baseStyle.copyWith(fontFamily: trimmed);
    }

    try {
      return GoogleFonts.getFont(
        trimmed,
        textStyle: baseStyle,
      );
    } catch (_) {
      return baseStyle.copyWith(fontFamily: trimmed);
    }
  }
}

class GrimoireFontPickerDialog extends StatefulWidget {
  final String currentFontFamily;
  final String sampleText;
  final ValueChanged<String>? onLiveChanged;

  const GrimoireFontPickerDialog({
    super.key,
    required this.currentFontFamily,
    this.sampleText = 'Grimoire Studio • 123',
    this.onLiveChanged,
  });

  static Future<String?> show(
    BuildContext context, {
    required String currentFontFamily,
    String sampleText = 'Grimoire Studio • 123',
    ValueChanged<String>? onLiveChanged,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => GrimoireFontPickerDialog(
        currentFontFamily: currentFontFamily,
        sampleText: sampleText,
        onLiveChanged: onLiveChanged,
      ),
    );
  }

  @override
  State<GrimoireFontPickerDialog> createState() => _GrimoireFontPickerDialogState();
}

class _GrimoireFontPickerDialogState extends State<GrimoireFontPickerDialog> {
  late String _selectedFont;
  late TextEditingController _searchController;
  String _selectedCategory = 'Todas';
  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedFont = widget.currentFontFamily.isEmpty ? 'Inter' : widget.currentFontFamily;
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _selectFont(String family) {
    setState(() => _selectedFont = family);
    widget.onLiveChanged?.call(family);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = GrimoireFontHelper.curatedFonts.where((f) {
      final matchesCat = _selectedCategory == 'Todas' || f.category == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          f.family.toLowerCase().contains(query) ||
          f.sampleTag.toLowerCase().contains(query) ||
          f.category.toLowerCase().contains(query);
      return matchesCat && matchesQuery;
    }).toList();

    final previewText = widget.sampleText.trim().isEmpty
        ? 'El Dragón de Cristal • +5 ATK'
        : widget.sampleText;

    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.accentIndigo.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.font_download_outlined, color: GrimoireTheme.accentIndigo, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selector de Tipografía (Google Fonts & Sistema)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Elige una fuente curada para cartas o escribe el nombre de cualquier tipografía.',
                              style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Live Preview Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0D16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'VISTA PREVIA EN VIVO:',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: GrimoireTheme.textMuted, letterSpacing: 0.7),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _selectedFont,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE9D5FF), fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    previewText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GrimoireFontHelper.resolveTextStyle(
                      fontFamily: _selectedFont,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search / Custom Font Input
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar fuente o escribir cualquier tipografía (ej. Cinzel, Bebas Neue, Arial)...',
                        prefixIcon: const Icon(Icons.search, size: 16, color: GrimoireTheme.accentPurple),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14, color: GrimoireTheme.textMuted),
                                onPressed: () => setState(() => _searchController.clear()),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (val) => setState(() {}),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _selectFont(val.trim());
                        }
                      },
                    ),
                  ),
                ),
                if (_searchController.text.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GrimoireTheme.accentEmerald,
                      side: const BorderSide(color: GrimoireTheme.accentEmerald),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.check, size: 14),
                    label: Text(
                      'Usar "${_searchController.text.trim()}"',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _selectFont(_searchController.text.trim()),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: GrimoireFontHelper.categories.map((cat) {
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? Colors.white : GrimoireTheme.textSecondary,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: GrimoireTheme.accentPurple,
                      backgroundColor: const Color(0xFF141828),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // Font List
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF101320),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GrimoireTheme.borderSubtle),
                ),
                child: ListView.separated(
                  controller: _listScrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    final isSelected = item.family.toLowerCase() == _selectedFont.toLowerCase();

                    return InkWell(
                      onTap: () => _selectFont(item.family),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? GrimoireTheme.accentPurple.withValues(alpha: 0.18)
                              : const Color(0xFF15192B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 16,
                              color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.family,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.category} • ${item.sampleTag}',
                                    style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 5,
                              child: Text(
                                previewText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: GrimoireFontHelper.resolveTextStyle(
                                  fontFamily: item.family,
                                  fontSize: 15,
                                  color: isSelected ? const Color(0xFFE9D5FF) : GrimoireTheme.textSecondary,
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
            ),
            const SizedBox(height: 16),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: GrimoireTheme.textMuted)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GrimoireTheme.accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('Aplicar "$_selectedFont"', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(context, _selectedFont),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
