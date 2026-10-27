import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../editor/models/card_template.dart';
import '../../../editor/models/card_project.dart';
import '../../../editor/presentation/providers/editor_provider.dart';
import '../../../editor/presentation/widgets/card_renderer_widget.dart';
import '../../../editor/services/game_folder_service.dart';
import '../../services/export_service.dart';

enum ExportFormat {
  printAndPlaySheet,
  pdfPrint,
  htmlShowcase,
  tabletopSimulator,
  pngZip,
  grimoirePackage,
  theGameCrafter,
  makePlayingCards,
  screentopGg,
}

class ExportOptionsDialog extends ConsumerStatefulWidget {
  final GlobalKey repaintBoundaryKey;
  final String? filterGame;

  const ExportOptionsDialog({
    super.key,
    required this.repaintBoundaryKey,
    this.filterGame,
  });

  static Future<void> show(
    BuildContext context, {
    required GlobalKey repaintBoundaryKey,
    String? filterGame,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExportOptionsDialog(
        repaintBoundaryKey: repaintBoundaryKey,
        filterGame: filterGame,
      ),
    );
  }

  @override
  ConsumerState<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends ConsumerState<ExportOptionsDialog> {
  ExportFormat _selectedFormat = ExportFormat.pdfPrint;
  bool _includeBleed = true;
  bool _includeCropMarks = true;
  bool _includeBacks = true;
  bool _useUsLetter = false;
  bool _respectQuantityColumn = true;
  bool _onlyDefinitiveCards = false;
  bool _isProcessing = false;
  String _statusMessage = '';
  double _progress = 0.0;

  // Embedded off-stage RepaintBoundary inside the dialog so batch export works from ANY tab!
  final GlobalKey _dialogRenderBoundaryKey = GlobalKey();
  Map<String, dynamic> _currentRenderingRow = const {};
  CardSide _currentRenderingSide = CardSide.front;
  CardTemplate? _currentRenderingTemplate;

  Future<void> _runExport() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Preparando exportación...';
      _progress = 0.05;
    });

    final editorNotifier = ref.read(editorProvider.notifier);
    final editorState = ref.read(editorProvider);
    final project = editorState.project;
    final allRows = project.rows;

    try {
      // Handle .grimoire Package Export directly without rendering images
      if (_selectedFormat == ExportFormat.grimoirePackage) {
        setState(() {
          _statusMessage = 'Empaquetando proyecto .grimoire (Plantillas, CSVs y Assets)...';
          _progress = 0.5;
        });

        final payload = <String, dynamic>{
          'version': 1,
          'savedAt': DateTime.now().toIso8601String(),
          'project': project.toJson(),
          'gameCategories': editorState.gameCategories.map(
            (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()),
          ),
          'deletedGames': editorState.deletedGames.toList(),
        };

        final pkgFile = await ExportService.exportGrimoirePackage(
          workspaceStatePayload: payload,
          packageName: widget.filterGame ?? project.name,
          gamesRootDir: GameFolderService.getGamesRootDir(),
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GrimoireTheme.accentEmerald,
              duration: const Duration(seconds: 5),
              content: Text('Paquete .grimoire exportado:\n${pkgFile.path}'),
            ),
          );
        }
        return;
      }

      // Filter rows if specified
      final targetRows = widget.filterGame == null || widget.filterGame == 'All'
          ? allRows
          : allRows.where((r) => (r['game'] ?? '').toString().toLowerCase() == widget.filterGame!.toLowerCase()).toList();
      var rowsToRender = targetRows.isEmpty ? allRows : targetRows;
      if (_onlyDefinitiveCards) {
        final defOnly = rowsToRender
            .where((r) => (r['card_status'] ?? 'Definitiva').toString().toLowerCase() != 'muestra')
            .toList();
        if (defOnly.isNotEmpty) {
          rowsToRender = defOnly;
        }
      }

      final cardImages = <Uint8List>[];
      final expandedCardNames = <String>[];
      Uint8List? backImageBytes;

      // 1. Capture Back Face using the dialog's dedicated RepaintBoundary
      if (_includeBacks ||
          _selectedFormat == ExportFormat.tabletopSimulator ||
          _selectedFormat == ExportFormat.theGameCrafter ||
          _selectedFormat == ExportFormat.makePlayingCards ||
          _selectedFormat == ExportFormat.screentopGg) {
        setState(() {
          _statusMessage = 'Renderizando reverso de carta (300 DPI)...';
          _currentRenderingRow = rowsToRender.isNotEmpty ? rowsToRender.first : {};
          _currentRenderingTemplate = rowsToRender.isNotEmpty
              ? editorNotifier.resolveTemplateForRow(rowsToRender.first)
              : project.activeTemplate;
          _currentRenderingSide = CardSide.back;
          _progress = 0.15;
        });

        await WidgetsBinding.instance.endOfFrame;
        await Future.delayed(const Duration(milliseconds: 60));
        backImageBytes = await ExportService.captureBoundaryToImage(_dialogRenderBoundaryKey) ??
            await ExportService.captureBoundaryToImage(widget.repaintBoundaryKey);
      }

      // 2. Capture Each Card Front Face (respecting `qty` / `quantity` column if enabled)
      for (int i = 0; i < rowsToRender.length; i++) {
        final row = rowsToRender[i];
        final resolvedTpl = editorNotifier.resolveTemplateForRow(row);

        setState(() {
          _currentRenderingRow = row;
          _currentRenderingTemplate = resolvedTpl;
          _currentRenderingSide = CardSide.front;
          _statusMessage = 'Renderizando carta ${i + 1} de ${rowsToRender.length} (${row['card_name'] ?? 'Card'})...';
          _progress = 0.2 + (0.55 * (i + 1) / rowsToRender.length);
        });

        await WidgetsBinding.instance.endOfFrame;
        await Future.delayed(const Duration(milliseconds: 50));

        final img = await ExportService.captureBoundaryToImage(_dialogRenderBoundaryKey) ??
            await ExportService.captureBoundaryToImage(widget.repaintBoundaryKey);

        if (img != null) {
          int copies = 1;
          if (_respectQuantityColumn) {
            final rawQty = (row['qty'] ?? row['quantity'] ?? '1').toString().trim();
            copies = (int.tryParse(rawQty) ?? 1).clamp(1, 20);
          }
          final baseName = (row['card_name'] ?? 'card_${i + 1}').toString();
          for (int c = 0; c < copies; c++) {
            cardImages.add(img);
            expandedCardNames.add(copies > 1 ? '${baseName}_${c + 1}' : baseName);
          }
        }
      }

      if (cardImages.isEmpty) {
        throw Exception('No se pudieron renderizar las imágenes de las cartas.');
      }

      // 3. Perform Output Operation
      setState(() {
        _statusMessage = 'Generando archivo final (${cardImages.length} cartas)...';
        _progress = 0.85;
      });

      final deckName = widget.filterGame ?? 'Grimoire_Deck';
      String resultPath = '';

      switch (_selectedFormat) {
        case ExportFormat.printAndPlaySheet:
          final pnpFile = await ExportService.exportCardsToPrintAndPlaySheetPdf(
            cardImages: cardImages,
            backImage: _includeBacks ? backImageBytes : null,
            fileName: '${deckName}_PnP_3x3_${_useUsLetter ? 'Letter' : 'A4'}',
            useUsLetter: _useUsLetter,
            includeBacks: _includeBacks,
            includeCutLines: _includeCropMarks,
            cardWidthMm: project.widthMm,
            cardHeightMm: project.heightMm,
          );
          resultPath = pnpFile.path;
          break;

        case ExportFormat.pdfPrint:
          final pdfFile = await ExportService.exportCardsToPdf(
            cardImages: cardImages,
            backImage: _includeBacks ? backImageBytes : null,
            fileName: '${deckName}_Print_Ready',
            includeBleedAndCropMarks: _includeBleed || _includeCropMarks,
            includeBacks: _includeBacks,
          );
          resultPath = pdfFile.path;
          break;

        case ExportFormat.htmlShowcase:
          final htmlFile = await ExportService.exportHtmlShowcase(
            cardImages: cardImages,
            cardNames: expandedCardNames,
            backImage: _includeBacks ? backImageBytes : null,
            showcaseTitle: deckName,
            cardDataList: rowsToRender,
          );
          resultPath = htmlFile.path;
          break;

        case ExportFormat.tabletopSimulator:
          final ttsFile = await ExportService.exportTabletopSimulatorDeck(
            cardImages: cardImages,
            backImage: backImageBytes,
            deckName: deckName,
          );
          resultPath = ttsFile.path;
          break;

        case ExportFormat.pngZip:
          final zipFile = await ExportService.exportCardsToZip(
            cardImages: cardImages,
            cardNames: expandedCardNames,
            backImage: _includeBacks ? backImageBytes : null,
            zipName: '${deckName}_PNG_Cards',
          );
          resultPath = zipFile.path;
          break;

        case ExportFormat.theGameCrafter:
          final tgcFile = await ExportService.exportTheGameCrafterPackage(
            cardImages: cardImages,
            cardNames: expandedCardNames,
            defaultBackImage: backImageBytes,
            cardRows: rowsToRender,
            deckName: deckName,
          );
          resultPath = tgcFile.path;
          break;

        case ExportFormat.makePlayingCards:
          final mpcFile = await ExportService.exportMakePlayingCardsPackage(
            cardImages: cardImages,
            cardNames: expandedCardNames,
            defaultBackImage: backImageBytes,
            cardRows: rowsToRender,
            deckName: deckName,
          );
          resultPath = mpcFile.path;
          break;

        case ExportFormat.screentopGg:
          final screentopFile = await ExportService.exportScreentopGgPackage(
            cardImages: cardImages,
            cardNames: expandedCardNames,
            backImage: backImageBytes,
            cardRows: rowsToRender,
            deckName: deckName,
          );
          resultPath = screentopFile.path;
          break;

        case ExportFormat.grimoirePackage:
          break;
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GrimoireTheme.accentEmerald,
            duration: const Duration(seconds: 5),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${ref.tr('export_success')} (${cardImages.length} cartas)\n$resultPath',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GrimoireTheme.accentPink,
            content: Text('${ref.tr('export_failed')}: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final project = editorState.project;
    final activeTpl = _currentRenderingTemplate ?? project.activeTemplate;
    final activeRow = _currentRenderingRow.isNotEmpty ? _currentRenderingRow : project.activeRow;
    final cardWidth = project.widthMm * 4.0;
    final cardHeight = project.heightMm * 4.0;

    return Dialog(
      backgroundColor: GrimoireTheme.surfacePanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hidden / Behind-Dialog 300 DPI Render Surface (Always mounted & painted even from Gallery/DB/Playtest tabs)
          Positioned(
            left: -9999,
            top: -9999,
            child: RepaintBoundary(
              key: _dialogRenderBoundaryKey,
              child: CardRendererWidget(
                template: activeTpl,
                cardData: activeRow,
                side: _currentRenderingSide,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                showGrid: false,
              ),
            ),
          ),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            child: SingleChildScrollView(
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
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.print_outlined, color: GrimoireTheme.accentPurple, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.tr('export_options_title'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.filterGame != null && widget.filterGame != 'All'
                                  ? 'Mazo: ${widget.filterGame}'
                                  : 'Todas las cartas del proyecto (${project.widthMm.toStringAsFixed(1)}×${project.heightMm.toStringAsFixed(1)} mm)',
                              style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (!_isProcessing)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: GrimoireTheme.textMuted),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Format Selector Tabs
                  Text(
                    ref.tr('export_format'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFormatTab(
                        format: ExportFormat.printAndPlaySheet,
                        title: ref.tr('format_print_and_play'),
                        icon: Icons.grid_view_rounded,
                        color: GrimoireTheme.accentPink,
                      ),
                      const SizedBox(width: 6),
                      _buildFormatTab(
                        format: ExportFormat.pdfPrint,
                        title: ref.tr('format_pdf_print'),
                        icon: Icons.picture_as_pdf,
                        color: GrimoireTheme.accentPurple,
                      ),
                      const SizedBox(width: 6),
                      _buildFormatTab(
                        format: ExportFormat.htmlShowcase,
                        title: ref.tr('format_web_3d'),
                        icon: Icons.view_in_ar,
                        color: GrimoireTheme.accentCyan,
                      ),
                      const SizedBox(width: 6),
                      _buildFormatTab(
                        format: ExportFormat.theGameCrafter,
                        title: 'TGC (825x1125)',
                        icon: Icons.precision_manufacturing_outlined,
                        color: const Color(0xFFF97316),
                      ),
                      const SizedBox(width: 6),
                      _buildFormatTab(
                        format: ExportFormat.makePlayingCards,
                        title: 'MPC (816x1110)',
                        icon: Icons.print_outlined,
                        color: const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 6),
                      _buildFormatTab(
                        format: ExportFormat.screentopGg,
                        title: 'Screentop.gg',
                        icon: Icons.grid_view_rounded,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      _buildFormatTab(
                        format: ExportFormat.tabletopSimulator,
                        title: ref.tr('format_tts'),
                        icon: Icons.casino,
                        color: GrimoireTheme.accentIndigo,
                      ),
                      const SizedBox(width: 6),
                      _buildFormatTab(
                        format: ExportFormat.pngZip,
                        title: ref.tr('format_png_zip'),
                        icon: Icons.folder_zip,
                        color: GrimoireTheme.accentEmerald,
                      ),
                      const SizedBox(width: 6),
                      _buildFormatTab(
                        format: ExportFormat.grimoirePackage,
                        title: '.grimoire',
                        icon: Icons.inventory_2_outlined,
                        color: GrimoireTheme.accentAmber,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Dynamic Options Based on Format
                  if (_selectedFormat == ExportFormat.printAndPlaySheet) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaperChoiceChip(
                            label: 'Hoja A4 (210 × 297 mm)',
                            selected: !_useUsLetter,
                            onTap: () => setState(() => _useUsLetter = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPaperChoiceChip(
                            label: 'US Letter (8.5 × 11 in)',
                            selected: _useUsLetter,
                            onTap: () => setState(() => _useUsLetter = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSwitchOption(
                      title: ref.tr('crop_guides_3x3'),
                      description: ref.tr('crop_guides_3x3_desc'),
                      value: _includeCropMarks,
                      icon: Icons.crop,
                      onChanged: _isProcessing ? null : (v) => setState(() => _includeCropMarks = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: ref.tr('option_include_backs'),
                      description: ref.tr('option_include_backs_desc'),
                      value: _includeBacks,
                      icon: Icons.flip,
                      onChanged: _isProcessing ? null : (v) => setState(() => _includeBacks = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: ref.tr('multiply_by_qty'),
                      description: ref.tr('multiply_by_qty_desc'),
                      value: _respectQuantityColumn,
                      icon: Icons.copy_all,
                      onChanged: _isProcessing ? null : (v) => setState(() => _respectQuantityColumn = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: 'Solo cartas definitivas',
                      description: 'Omite cartas de muestra o presets para imprimir solo tu mazo final',
                      value: _onlyDefinitiveCards,
                      icon: Icons.filter_alt_outlined,
                      onChanged: _isProcessing ? null : (v) => setState(() => _onlyDefinitiveCards = v),
                    ),
                  ] else if (_selectedFormat == ExportFormat.pdfPrint) ...[
                    _buildSwitchOption(
                      title: ref.tr('option_bleed'),
                      description: ref.tr('option_bleed_desc'),
                      value: _includeBleed,
                      icon: Icons.aspect_ratio,
                      onChanged: _isProcessing ? null : (v) => setState(() => _includeBleed = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: ref.tr('option_crop_marks'),
                      description: ref.tr('option_crop_marks_desc'),
                      value: _includeCropMarks,
                      icon: Icons.crop,
                      onChanged: _isProcessing ? null : (v) => setState(() => _includeCropMarks = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: ref.tr('option_include_backs'),
                      description: ref.tr('option_include_backs_desc'),
                      value: _includeBacks,
                      icon: Icons.flip,
                      onChanged: _isProcessing ? null : (v) => setState(() => _includeBacks = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: 'Solo cartas definitivas',
                      description: 'Omite cartas de muestra o presets para imprimir solo tu mazo final',
                      value: _onlyDefinitiveCards,
                      icon: Icons.filter_alt_outlined,
                      onChanged: _isProcessing ? null : (v) => setState(() => _onlyDefinitiveCards = v),
                    ),
                    const SizedBox(height: 12),
                    _buildPreflightChecklist(project),
                  ] else if (_selectedFormat == ExportFormat.htmlShowcase) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1A28),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GrimoireTheme.accentCyan.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.view_in_ar, size: 16, color: GrimoireTheme.accentCyan),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ref.tr('interactive_web_3d_viewer'),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ref.tr('interactive_web_3d_viewer_desc'),
                            style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 14, color: GrimoireTheme.accentCyan),
                                  SizedBox(width: 6),
                                  Text('Tilt 3D & Holographic Sheen', style: TextStyle(fontSize: 11, color: Colors.white)),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, size: 14, color: GrimoireTheme.accentCyan),
                                  const SizedBox(width: 6),
                                  Text(ref.tr('flip_front_back'), style: const TextStyle(fontSize: 11, color: Colors.white)),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, size: 14, color: GrimoireTheme.accentCyan),
                                  const SizedBox(width: 6),
                                  Text(ref.tr('live_search'), style: const TextStyle(fontSize: 11, color: Colors.white)),
                                ],
                              ),
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 14, color: GrimoireTheme.accentCyan),
                                  SizedBox(width: 6),
                                  Text('100% Offline', style: TextStyle(fontSize: 11, color: Colors.white)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: ref.tr('option_include_backs'),
                      description: ref.tr('option_include_backs_desc'),
                      value: _includeBacks,
                      icon: Icons.flip,
                      onChanged: _isProcessing ? null : (v) => setState(() => _includeBacks = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: ref.tr('multiply_by_qty'),
                      description: ref.tr('multiply_by_qty_desc'),
                      value: _respectQuantityColumn,
                      icon: Icons.copy_all,
                      onChanged: _isProcessing ? null : (v) => setState(() => _respectQuantityColumn = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: 'Solo cartas definitivas',
                      description: 'Omite cartas de muestra o presets para imprimir solo tu mazo final',
                      value: _onlyDefinitiveCards,
                      icon: Icons.filter_alt_outlined,
                      onChanged: _isProcessing ? null : (v) => setState(() => _onlyDefinitiveCards = v),
                    ),
                  ] else if (_selectedFormat == ExportFormat.theGameCrafter) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A130D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.precision_manufacturing_outlined, color: Color(0xFFF97316), size: 18),
                              SizedBox(width: 8),
                              Text('The Game Crafter (TGC) - Especificación Poker', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Genera imágenes a 825 x 1125 px @ 300 DPI con 36px de sangrado (bleed) exacto para cartas Poker de The Game Crafter, junto con el manifiesto thegamecrafter_manifest.json y guía paso a paso.',
                            style: TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: ref.tr('multiply_by_qty'),
                      description: ref.tr('multiply_by_qty_desc'),
                      value: _respectQuantityColumn,
                      icon: Icons.copy_all,
                      onChanged: _isProcessing ? null : (v) => setState(() => _respectQuantityColumn = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: 'Solo cartas definitivas',
                      description: 'Omite cartas de muestra o presets',
                      value: _onlyDefinitiveCards,
                      icon: Icons.verified_outlined,
                      onChanged: _isProcessing ? null : (v) => setState(() => _onlyDefinitiveCards = v),
                    ),
                  ] else if (_selectedFormat == ExportFormat.makePlayingCards) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1929),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.print_outlined, color: Color(0xFF38BDF8), size: 18),
                              SizedBox(width: 8),
                              Text('MakePlayingCards (MPC) - Poker 63x88mm', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Exporta las cartas a 816 x 1110 px @ 300 DPI en carpetas frontales y traseras, con archivo mpc_order_guide.txt listo para importar en el creador masivo de MPC.',
                            style: TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: ref.tr('multiply_by_qty'),
                      description: ref.tr('multiply_by_qty_desc'),
                      value: _respectQuantityColumn,
                      icon: Icons.copy_all,
                      onChanged: _isProcessing ? null : (v) => setState(() => _respectQuantityColumn = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: 'Solo cartas definitivas',
                      description: 'Omite cartas de muestra o presets',
                      value: _onlyDefinitiveCards,
                      icon: Icons.verified_outlined,
                      onChanged: _isProcessing ? null : (v) => setState(() => _onlyDefinitiveCards = v),
                    ),
                  ] else if (_selectedFormat == ExportFormat.screentopGg) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF092318),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.grid_view_rounded, color: Color(0xFF10B981), size: 18),
                              SizedBox(width: 8),
                              Text('Screentop.gg - Hojas Sprite & Descriptor JSON', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Genera sprite sheets en cuadrícula (grid) optimizadas para el navegador, reversos comunes y screentop_asset.json para crear componentes de carta en Screentop.gg al instante.',
                            style: TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: ref.tr('multiply_by_qty'),
                      description: ref.tr('multiply_by_qty_desc'),
                      value: _respectQuantityColumn,
                      icon: Icons.copy_all,
                      onChanged: _isProcessing ? null : (v) => setState(() => _respectQuantityColumn = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: 'Solo cartas definitivas',
                      description: 'Omite cartas de muestra o presets',
                      value: _onlyDefinitiveCards,
                      icon: Icons.verified_outlined,
                      onChanged: _isProcessing ? null : (v) => setState(() => _onlyDefinitiveCards = v),
                    ),
                  ] else if (_selectedFormat == ExportFormat.tabletopSimulator) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16182E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, size: 16, color: GrimoireTheme.accentIndigo),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ref.tr('tts_ready_title'),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ref.tr('tts_deck_info'),
                            style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, size: 14, color: GrimoireTheme.accentEmerald),
                                  const SizedBox(width: 6),
                                  Text(ref.tr('tts_front_sheet'), style: const TextStyle(fontSize: 11, color: Colors.white)),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, size: 14, color: GrimoireTheme.accentEmerald),
                                  const SizedBox(width: 6),
                                  Text(ref.tr('tts_back_sheet'), style: const TextStyle(fontSize: 11, color: Colors.white)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: ref.tr('multiply_by_qty'),
                      description: ref.tr('multiply_by_qty_desc'),
                      value: _respectQuantityColumn,
                      icon: Icons.copy_all,
                      onChanged: _isProcessing ? null : (v) => setState(() => _respectQuantityColumn = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchOption(
                      title: 'Solo cartas definitivas',
                      description: 'Omite cartas de muestra o presets para imprimir solo tu mazo final',
                      value: _onlyDefinitiveCards,
                      icon: Icons.filter_alt_outlined,
                      onChanged: _isProcessing ? null : (v) => setState(() => _onlyDefinitiveCards = v),
                    ),
                  ] else if (_selectedFormat == ExportFormat.grimoirePackage) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1810),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GrimoireTheme.accentAmber.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 16, color: GrimoireTheme.accentAmber),
                              const SizedBox(width: 8),
                              Text(
                                ref.tr('portable_project_pkg'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ref.tr('portable_project_pkg_desc'),
                            style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    _buildSwitchOption(
                      title: ref.tr('option_include_backs'),
                      description: ref.tr('option_include_backs_desc'),
                      value: _includeBacks,
                      icon: Icons.flip,
                      onChanged: _isProcessing ? null : (v) => setState(() => _includeBacks = v),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Progress Bar if running
                  if (_isProcessing) ...[
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: const Color(0xFF10121E),
                      valueColor: const AlwaysStoppedAnimation(GrimoireTheme.accentPurple),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                        child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GrimoireTheme.accentPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isProcessing ? null : _runExport,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.file_download_outlined, size: 16),
                        label: Text(
                          _isProcessing ? ref.tr('exporting') : ref.tr('btn_start_export'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isProcessing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? GrimoireTheme.accentPink.withValues(alpha: 0.18) : const Color(0xFF111320),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? GrimoireTheme.accentPink : GrimoireTheme.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 15,
              color: selected ? GrimoireTheme.accentPink : GrimoireTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.white : GrimoireTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatTab({
    required ExportFormat format,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedFormat == format;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _isProcessing ? null : () => setState(() => _selectedFormat = format),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.18) : const Color(0xFF131524),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : GrimoireTheme.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? color : GrimoireTheme.textMuted),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : GrimoireTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchOption({
    required String title,
    required String description,
    required bool value,
    required IconData icon,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF111320),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: value ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: GrimoireTheme.accentPurple,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPreflightChecklist(CardProject project) {
    final report = ExportService.generatePreflightReport(
      widthMm: project.widthMm,
      heightMm: project.heightMm,
      bleedEnabled: _includeBleed,
      cropMarksEnabled: _includeCropMarks,
      duplexEnabled: _includeBacks,
      language: ref.watch(localeProvider),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101426),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: report.warningCount > 0
              ? GrimoireTheme.accentAmber.withValues(alpha: 0.5)
              : GrimoireTheme.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                report.warningCount > 0 ? Icons.warning_amber_rounded : Icons.verified_outlined,
                size: 16,
                color: report.warningCount > 0 ? GrimoireTheme.accentAmber : GrimoireTheme.accentEmerald,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ref.tr('preflight_checklist_title'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (report.warningCount > 0 ? GrimoireTheme.accentAmber : GrimoireTheme.accentEmerald)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (report.warningCount > 0 ? GrimoireTheme.accentAmber : GrimoireTheme.accentEmerald)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  report.warningCount > 0 ? '${report.warningCount} ${ref.tr('preflight_warnings')}' : ref.tr('preflight_ready'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: report.warningCount > 0 ? GrimoireTheme.accentAmber : GrimoireTheme.accentEmerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...report.checks.map((item) {
            final Color iconColor;
            final IconData iconData;
            switch (item.status) {
              case PreflightStatus.pass:
                iconColor = GrimoireTheme.accentEmerald;
                iconData = Icons.check_circle_rounded;
                break;
              case PreflightStatus.warning:
                iconColor = GrimoireTheme.accentAmber;
                iconData = Icons.warning_rounded;
                break;
              case PreflightStatus.info:
                iconColor = GrimoireTheme.accentCyan;
                iconData = Icons.info_outline;
                break;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(iconData, size: 12, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                        Text(
                          item.description,
                          style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted, height: 1.25),
                        ),
                        if (item.recommendation != null)
                          Text(
                            '💡 ${item.recommendation!}',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: iconColor.withValues(alpha: 0.9),
                              height: 1.25,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
