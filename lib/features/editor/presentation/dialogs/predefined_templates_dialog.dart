import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/card_template.dart';
import '../../models/card_project.dart';
import '../providers/editor_provider.dart';
import '../widgets/card_renderer_widget.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/widgets/grimoire_toast.dart';

enum PredefinedTemplateAction {
  replaceActive,
  createAsNew,
}

class PredefinedTemplatesDialog extends ConsumerStatefulWidget {
  final String? initialSelectedId;
  final bool showModeSelector;
  final String? gameName;
  final void Function(CardTemplate template, PredefinedTemplateAction action)? onTemplateSelected;

  const PredefinedTemplatesDialog({
    super.key,
    this.initialSelectedId,
    this.showModeSelector = true,
    this.gameName,
    this.onTemplateSelected,
  });

  static Future<CardTemplate?> show(
    BuildContext context, {
    String? initialSelectedId,
    bool showModeSelector = true,
    String? gameName,
    void Function(CardTemplate template, PredefinedTemplateAction action)? onTemplateSelected,
  }) {
    return showDialog<CardTemplate>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PredefinedTemplatesDialog(
        initialSelectedId: initialSelectedId,
        showModeSelector: showModeSelector,
        gameName: gameName,
        onTemplateSelected: onTemplateSelected,
      ),
    );
  }

  @override
  ConsumerState<PredefinedTemplatesDialog> createState() => _PredefinedTemplatesDialogState();
}

class _PredefinedTemplatesDialogState extends ConsumerState<PredefinedTemplatesDialog> {
  late String _selectedPresetId;
  PredefinedTemplateAction _action = PredefinedTemplateAction.replaceActive;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedPresetId = widget.initialSelectedId ?? 'default';
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applySelection(PredefinedPresetInfo preset) {
    const uuid = Uuid();
    final effectiveGame = widget.gameName ??
        (ref.read(editorProvider).project.activeRow['game'] ?? 'Juego').toString();
    final cleanGame = effectiveGame.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

    final templateId = _action == PredefinedTemplateAction.replaceActive
        ? ref.read(editorProvider).project.activeTemplate.id
        : 'tpl_${cleanGame}_${preset.id}_${uuid.v4().substring(0, 6)}';

    final templateName = _action == PredefinedTemplateAction.replaceActive
        ? ref.read(editorProvider).project.activeTemplate.name
        : '$effectiveGame ${preset.name}';

    final createdTemplate = preset.builder(
      id: templateId,
      name: templateName,
    );

    if (widget.onTemplateSelected != null) {
      widget.onTemplateSelected!(createdTemplate, _action);
      Navigator.of(context).pop(createdTemplate);
      return;
    }

    final notifier = ref.read(editorProvider.notifier);
    if (_action == PredefinedTemplateAction.replaceActive) {
      notifier.replaceActiveTemplateLayers(
        layers: createdTemplate.layers,
        backLayers: createdTemplate.backLayers,
        backgroundColor: createdTemplate.backgroundColor,
        backBackgroundColor: createdTemplate.backBackgroundColor,
        cornerRadius: createdTemplate.cornerRadius,
      );
      GrimoireToast.success(
        context,
        'Plantilla "${preset.name}" aplicada a la carta activa.',
      );
    } else {
      notifier.addCustomTemplate(createdTemplate, setAsActive: true);
      GrimoireToast.success(
        context,
        'Nueva plantilla "${createdTemplate.name}" agregada con éxito.',
      );
    }

    Navigator.of(context).pop(createdTemplate);
  }

  @override
  Widget build(BuildContext context) {
    final presets = CardTemplate.predefinedPresets;
    final selectedPreset = presets.firstWhere(
      (p) => p.id == _selectedPresetId,
      orElse: () => presets.first,
    );

    return Dialog(
      backgroundColor: GrimoireTheme.surfacePanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 960,
          maxHeight: 680,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: GrimoireTheme.accentPurple.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.style_outlined,
                      size: 24,
                      color: GrimoireTheme.accentPurple,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.tr('add_predefined_template'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ref.tr('add_predefined_template_desc'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: GrimoireTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: GrimoireTheme.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: ref.tr('cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Horizontal Presets Cards Carousel / Row (Matching User Sketch in Image 2)
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    itemCount: presets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      final isSelected = preset.id == _selectedPresetId;
                      return _buildPresetCard(preset, isSelected);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: GrimoireTheme.borderSubtle, height: 1),
              const SizedBox(height: 14),

              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 10,
                spacing: 12,
                children: [
                  // Mode Selector (Replace Active vs Create As New)
                  if (widget.showModeSelector) ...[
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F111D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GrimoireTheme.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionSegment(
                            title: ref.tr('apply_to_current_card'),
                            action: PredefinedTemplateAction.replaceActive,
                            icon: Icons.check_circle_outline,
                          ),
                          _buildActionSegment(
                            title: ref.tr('create_as_new_template'),
                            action: PredefinedTemplateAction.createAsNew,
                            icon: Icons.add_box_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: Text(
                          ref.tr('cancel'),
                          style: const TextStyle(color: GrimoireTheme.textMuted, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        key: const Key('btn_confirm_predefined_template'),
                        onPressed: () => _applySelection(selectedPreset),
                        icon: const Icon(Icons.done_all, size: 16),
                        label: Text(
                          ref.tr('use_template'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GrimoireTheme.accentPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionSegment({
    required String title,
    required PredefinedTemplateAction action,
    required IconData icon,
  }) {
    final isSelected = _action == action;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _action = action),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? GrimoireTheme.accentPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : GrimoireTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : GrimoireTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetCard(PredefinedPresetInfo preset, bool isSelected) {
    // Generate an instance of the preset for live preview
    final previewTemplate = preset.builder(id: 'preview_${preset.id}', name: preset.name);

    return InkWell(
      onTap: () {
        setState(() => _selectedPresetId = preset.id);
      },
      onDoubleTap: () {
        setState(() => _selectedPresetId = preset.id);
        _applySelection(preset);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 195,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? GrimoireTheme.accentPurple.withValues(alpha: 0.12)
              : const Color(0xFF101322),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Preview Area (scaled CardRendererWidget)
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: previewTemplate.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: GrimoireTheme.borderSubtle.withValues(alpha: 0.5),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: 254,
                            height: 355.6,
                            child: CardRendererWidget(
                              template: previewTemplate,
                              cardData: {
                                'card_name': preset.isDefault ? 'Título Carta' : preset.name,
                                'rules_text': preset.isDefault
                                    ? 'Descripción de la habilidad especial encima del shape.'
                                    : preset.description,
                                'cost': '3',
                                'type': 'Criatura',
                                'atk': '4 / 3',
                              },
                              side: CardSide.front,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Badge on top right (e.g. "Default", "TCG", etc.)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: preset.isDefault
                            ? GrimoireTheme.accentEmerald
                            : preset.accentColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        preset.badge,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Selection Checkmark Overlay
                  if (isSelected)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: GrimoireTheme.accentPurple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Preset Title & Icon
            Row(
              children: [
                Icon(
                  preset.icon,
                  size: 15,
                  color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),

            // Short Description
            Text(
              preset.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: GrimoireTheme.textMuted,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
