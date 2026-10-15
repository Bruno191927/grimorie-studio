import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../editor/models/card_template.dart';
import '../../../editor/presentation/providers/editor_provider.dart';
import '../../services/export_service.dart';

enum ExportFormat {
  pdfPrint,
  tabletopSimulator,
  pngZip,
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
  bool _isProcessing = false;
  String _statusMessage = '';
  double _progress = 0.0;

  Future<void> _runExport() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Preparando cartas...';
      _progress = 0.05;
    });

    final editorNotifier = ref.read(editorProvider.notifier);
    final initialSide = ref.read(editorProvider).currentSide;
    final initialRowIndex = ref.read(editorProvider).project.activeRowIndex;
    final allRows = ref.read(editorProvider).project.rows;

    // Filter rows if specified
    final targetRows = widget.filterGame == null || widget.filterGame == 'All'
        ? allRows
        : allRows.where((r) => (r['game'] ?? '').toString().toLowerCase() == widget.filterGame!.toLowerCase()).toList();

    final cardImages = <Uint8List>[];
    Uint8List? backImageBytes;

    try {
      // 1. Capture Back Face (if requested)
      if (_includeBacks || _selectedFormat == ExportFormat.tabletopSimulator) {
        setState(() {
          _statusMessage = 'Renderizando reverso de carta (Back Face)...';
          _progress = 0.15;
        });

        editorNotifier.switchSide(CardSide.back);
        await Future.delayed(const Duration(milliseconds: 120));
        backImageBytes = await ExportService.captureBoundaryToImage(widget.repaintBoundaryKey);
      }

      // 2. Capture Each Card Front Face
      editorNotifier.switchSide(CardSide.front);
      await Future.delayed(const Duration(milliseconds: 80));

      final rowsToRender = targetRows.isEmpty ? allRows : targetRows;
      for (int i = 0; i < rowsToRender.length; i++) {
        final rowIndexInAll = allRows.indexOf(rowsToRender[i]);
        if (rowIndexInAll != -1) {
          editorNotifier.setActiveRow(rowIndexInAll);
          await Future.delayed(const Duration(milliseconds: 80));
        }

        setState(() {
          _statusMessage = 'Renderizando carta ${i + 1} de ${rowsToRender.length}...';
          _progress = 0.2 + (0.5 * (i + 1) / rowsToRender.length);
        });

        final img = await ExportService.captureBoundaryToImage(widget.repaintBoundaryKey);
        if (img != null) {
          cardImages.add(img);
        }
      }

      if (cardImages.isEmpty) {
        throw Exception('No se pudieron renderizar las imágenes de las cartas.');
      }

      // 3. Perform Output Operation
      setState(() {
        _statusMessage = 'Comprimiendo y generando archivos finales...';
        _progress = 0.85;
      });

      final deckName = widget.filterGame ?? 'Grimoire_Deck';

      String resultPath = '';
      switch (_selectedFormat) {
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

        case ExportFormat.tabletopSimulator:
          final ttsFile = await ExportService.exportTabletopSimulatorDeck(
            cardImages: cardImages,
            backImage: backImageBytes,
            deckName: deckName,
          );
          resultPath = ttsFile.path;
          break;

        case ExportFormat.pngZip:
          final cardNames = rowsToRender.map((r) => r['card_name']?.toString() ?? 'card').toList();
          final zipFile = await ExportService.exportCardsToZip(
            cardImages: cardImages,
            cardNames: cardNames,
            backImage: _includeBacks ? backImageBytes : null,
            zipName: '${deckName}_PNG_Cards',
          );
          resultPath = zipFile.path;
          break;
      }

      // Restore original state
      editorNotifier.switchSide(initialSide);
      editorNotifier.setActiveRow(initialRowIndex);

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
                    '${ref.tr('export_success')}\n$resultPath',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      // Restore original state on error
      editorNotifier.switchSide(initialSide);
      editorNotifier.setActiveRow(initialRowIndex);

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
    return Dialog(
      backgroundColor: GrimoireTheme.surfacePanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
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
                              : 'Todas las cartas del proyecto',
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
              const SizedBox(height: 20),

              // Format Selector Tabs
              Text(
                ref.tr('export_format'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFormatTab(
                    format: ExportFormat.pdfPrint,
                    title: 'PDF Imprenta',
                    icon: Icons.picture_as_pdf,
                    color: GrimoireTheme.accentPurple,
                  ),
                  const SizedBox(width: 8),
                  _buildFormatTab(
                    format: ExportFormat.tabletopSimulator,
                    title: 'TTS Sprite Sheet',
                    icon: Icons.casino,
                    color: GrimoireTheme.accentIndigo,
                  ),
                  const SizedBox(width: 8),
                  _buildFormatTab(
                    format: ExportFormat.pngZip,
                    title: 'PNG Individual',
                    icon: Icons.folder_zip,
                    color: GrimoireTheme.accentEmerald,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Dynamic Options Based on Format
              if (_selectedFormat == ExportFormat.pdfPrint) ...[
                _buildSwitchOption(
                  title: ref.tr('option_bleed'),
                  description: ref.tr('option_bleed_desc'),
                  value: _includeBleed,
                  icon: Icons.aspect_ratio,
                  onChanged: _isProcessing ? null : (v) => setState(() => _includeBleed = v),
                ),
                const SizedBox(height: 10),
                _buildSwitchOption(
                  title: ref.tr('option_crop_marks'),
                  description: ref.tr('option_crop_marks_desc'),
                  value: _includeCropMarks,
                  icon: Icons.crop,
                  onChanged: _isProcessing ? null : (v) => setState(() => _includeCropMarks = v),
                ),
                const SizedBox(height: 10),
                _buildSwitchOption(
                  title: ref.tr('option_include_backs'),
                  description: ref.tr('option_include_backs_desc'),
                  value: _includeBacks,
                  icon: Icons.flip,
                  onChanged: _isProcessing ? null : (v) => setState(() => _includeBacks = v),
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
                        children: const [
                          Icon(Icons.auto_awesome, size: 16, color: GrimoireTheme.accentIndigo),
                          SizedBox(width: 8),
                          Text(
                            'Tabletop Simulator (TTS) Ready',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ref.tr('tts_deck_info'),
                        style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: const [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 14, color: GrimoireTheme.accentEmerald),
                              SizedBox(width: 6),
                              Text('Hoja Frontal (Grid hasta 10x7)', style: TextStyle(fontSize: 11, color: Colors.white)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 14, color: GrimoireTheme.accentEmerald),
                              SizedBox(width: 6),
                              Text('Hoja de Reverso & Config TXT', style: TextStyle(fontSize: 11, color: Colors.white)),
                            ],
                          ),
                        ],
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

              const SizedBox(height: 20),

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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
              Icon(icon, size: 20, color: isSelected ? color : GrimoireTheme.textMuted),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
}
