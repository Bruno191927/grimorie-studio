import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../editor/services/game_folder_service.dart';
import '../../export/services/export_service.dart';
import '../domain/models/rulebook_data.dart';

class RulebookService {
  /// Loads rulebook data for a game from disk, or initializes a new smart draft from [rows]
  static Future<RulebookData> loadRulebook(String gameName, List<Map<String, dynamic>> rows) async {
    try {
      final safeGame = GameFolderService.normalizeGameKey(gameName);
      final gamesDir = GameFolderService.getGamesRootDir();
      final rulebookFile = File('${gamesDir.path}/$safeGame/rulebook.json');

      if (await rulebookFile.exists()) {
        final content = await rulebookFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        return RulebookData.fromJson(json);
      }
    } catch (_) {}

    // Fallback: create smart initial draft
    final initial = RulebookData.initial(gameName: gameName, rows: rows);
    await saveRulebook(gameName, initial);
    return initial;
  }

  /// Persists rulebook data to the game's folder
  static Future<void> saveRulebook(String gameName, RulebookData data) async {
    try {
      final safeGame = GameFolderService.normalizeGameKey(gameName);
      final gamesDir = GameFolderService.getGamesRootDir();
      final gameDir = Directory('${gamesDir.path}/$safeGame');
      if (!await gameDir.exists()) {
        await gameDir.create(recursive: true);
      }
      final rulebookFile = File('${gameDir.path}/rulebook.json');
      const encoder = JsonEncoder.withIndent('  ');
      await rulebookFile.writeAsString(encoder.convert(data.toJson()));
    } catch (e) {
      // ignore
    }
  }

  /// Synchronizes components table with the live card database rows
  static RulebookData autoSyncComponents(RulebookData current, List<Map<String, dynamic>> rows) {
    final categoryCounts = <String, int>{};
    for (final r in rows) {
      final cat = (r['category'] ?? 'General').toString().trim();
      final qty = int.tryParse(r['qty']?.toString() ?? '1') ?? 1;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + qty;
    }

    final updatedComponents = <RulebookComponentItem>[];
    categoryCounts.forEach((cat, count) {
      final existing = current.components.where((c) => c.category.toLowerCase() == cat.toLowerCase()).firstOrNull;
      updatedComponents.add(RulebookComponentItem(
        name: existing != null && existing.name.isNotEmpty ? existing.name : 'Mazo de $cat',
        quantity: count,
        category: cat,
        description: existing != null && existing.description.isNotEmpty
            ? existing.description
            : '$count cartas de categoría $cat listas para jugar.',
      ));
    });

    // Retain custom non-card components like dice, tokens, counters
    for (final comp in current.components) {
      if (comp.category.toLowerCase() != 'carta' &&
          !categoryCounts.keys.any((k) => k.toLowerCase() == comp.category.toLowerCase())) {
        updatedComponents.add(comp);
      }
    }

    return current.copyWith(components: updatedComponents);
  }

  /// Generates and exports a clean, professional multi-page printable PDF booklet
  static Future<File> exportRulebookPdf(
    RulebookData data, {
    Directory? outputDirectory,
  }) async {
    final pdf = pw.Document();

    final themeData = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
    );

    // Color palette for Rulebook PDF
    const primaryDark = PdfColor.fromInt(0xFF1E1B4B);
    const accentGold = PdfColor.fromInt(0xFFD97706);
    const borderGray = PdfColor.fromInt(0xFFCBD5E1);
    const textGray = PdfColor.fromInt(0xFF334155);

    // ==========================================
    // PAGE 1: PORTADA / COVER PAGE
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: themeData,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: accentGold, width: 2.5),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'MANUAL OFICIAL DE REGLAS',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: accentGold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      data.gameName.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                    if (data.subtitle.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        data.subtitle,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: textGray,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 14),
                    pw.Container(
                      width: 60,
                      height: 2,
                      color: accentGold,
                    ),
                  ],
                ),

                // Center Box with Metadata Badges
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF8FAFC),
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: borderGray, width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildPdfBadge('JUGADORES', data.targetPlayers, accentGold),
                      _buildPdfBadge('DURACIÓN', data.playTime, accentGold),
                      _buildPdfBadge('EDAD', data.ageRating, accentGold),
                    ],
                  ),
                ),

                // Introduction summary snippet
                if (data.introduction.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                    child: pw.Text(
                      data.introduction,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: textGray,
                        lineSpacing: 1.4,
                      ),
                      maxLines: 6,
                    ),
                  ),

                // Footer
                pw.Column(
                  children: [
                    pw.Text(
                      'Diseñado con Grimoire Studio • Versión ${data.version}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '© ${DateTime.now().year} ${data.author}. Todos los derechos reservados.',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // ==========================================
    // PAGE 2: COMPONENTES & OBJETIVO
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: themeData,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageHeader('OBJETIVO & COMPONENTES', data.gameName),
              pw.SizedBox(height: 10),

              // Objetivo
              if (data.objective.isNotEmpty) ...[
                pw.Text('OBJETIVO DEL JUEGO',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentGold)),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFFEF3C7),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: accentGold, width: 0.5),
                  ),
                  child: pw.Text(
                    data.objective,
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF78350F), lineSpacing: 1.3),
                  ),
                ),
                pw.SizedBox(height: 12),
              ],

              // Componentes
              pw.Text('CONTENIDO & COMPONENTES',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentGold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Cant.',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryDark)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Componente',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryDark)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Descripción / Función',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryDark)),
                      ),
                    ],
                  ),
                  ...data.components.map(
                    (c) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('${c.quantity}x',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accentGold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(c.name,
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textGray)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(c.description,
                              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              _buildPageFooter(2),
            ],
          );
        },
      ),
    );

    // ==========================================
    // PAGE 3: PREPARACIÓN & ANATOMÍA DE CARTA
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: themeData,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageHeader('PREPARACIÓN & ANATOMÍA', data.gameName),
              pw.SizedBox(height: 10),

              // Setup Steps
              pw.Text('PREPARACIÓN DE LA PARTIDA (SETUP)',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentGold)),
              pw.SizedBox(height: 6),
              ...data.setupSteps.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final step = entry.value;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 14,
                        height: 14,
                        decoration: const pw.BoxDecoration(
                          color: primaryDark,
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(
                          child: pw.Text('$idx',
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Text(step,
                            style: const pw.TextStyle(fontSize: 8, color: textGray, lineSpacing: 1.25)),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 10),

              // Card Anatomy
              pw.Text('ANATOMÍA DE UNA CARTA',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentGold)),
              pw.SizedBox(height: 6),
              ...data.cardAnatomy.entries.map((entry) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: '• ${entry.key}: ',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryDark),
                        ),
                        pw.TextSpan(
                          text: entry.value,
                          style: const pw.TextStyle(fontSize: 7.5, color: textGray),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              pw.Spacer(),
              _buildPageFooter(3),
            ],
          );
        },
      ),
    );

    // ==========================================
    // PAGE 4: FASES DEL TURNO & REGLAS
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: themeData,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageHeader('SECUENCIA DE TURNO & FASES', data.gameName),
              pw.SizedBox(height: 10),

              ...data.turnPhases.map((phase) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF8FAFC),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderGray, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: accentGold,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text('FASE ${phase.phaseNumber}',
                                style: pw.TextStyle(
                                    fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(phase.name,
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryDark)),
                        ],
                      ),
                      if (phase.shortSummary.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(phase.shortSummary,
                            style: pw.TextStyle(
                                fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: accentGold)),
                      ],
                      if (phase.details.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(phase.details,
                            style: const pw.TextStyle(fontSize: 8, color: textGray, lineSpacing: 1.25)),
                      ],
                    ],
                  ),
                );
              }),

              pw.Spacer(),
              _buildPageFooter(4),
            ],
          );
        },
      ),
    );

    // ==========================================
    // PAGE 5: GLOSARIO & FAQ
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: themeData,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageHeader('GLOSARIO & PREGUNTAS FRECUENTES', data.gameName),
              pw.SizedBox(height: 10),

              // Glossario
              if (data.glossary.isNotEmpty) ...[
                pw.Text('GLOSARIO DE TÉRMINOS & PALABRAS CLAVE',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentGold)),
                pw.SizedBox(height: 6),
                ...data.glossary.entries.map((entry) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: '• ${entry.key}: ',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryDark),
                          ),
                          pw.TextSpan(
                            text: entry.value,
                            style: const pw.TextStyle(fontSize: 7.5, color: textGray),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                pw.SizedBox(height: 10),
              ],

              // FAQ
              if (data.faqs.isNotEmpty) ...[
                pw.Text('PREGUNTAS FRECUENTES (FAQ)',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentGold)),
                pw.SizedBox(height: 6),
                ...data.faqs.map((faq) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFF1F5F9),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('P: ${faq.question}',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryDark)),
                        pw.SizedBox(height: 2),
                        pw.Text('R: ${faq.answer}',
                            style: const pw.TextStyle(fontSize: 7.5, color: textGray, lineSpacing: 1.2)),
                      ],
                    ),
                  );
                }),
              ],

              pw.Spacer(),
              _buildPageFooter(5),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final outDir = await ExportService.getExportDirectory(overrideDir: outputDirectory);
    final safeName = data.gameName.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final file = File('${outDir.path}/${safeName}_Manual_de_Reglas.pdf');
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  static pw.Widget _buildPdfBadge(String title, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  static pw.Widget _buildPageHeader(String title, String gameName) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFCBD5E1), width: 1.0)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title,
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E1B4B))),
          pw.Text(gameName,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildPageFooter(int pageNumber) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Grimoire Studio • Rulebook Builder',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          pw.Text('Página $pageNumber',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }
}
