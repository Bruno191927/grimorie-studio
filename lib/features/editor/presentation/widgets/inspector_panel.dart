import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/layer_item.dart';
import '../../models/game_category.dart';
import '../../services/game_folder_service.dart';
import '../../utils/shape_path_builder.dart';
import '../providers/editor_provider.dart';
import 'custom_shape_builder_dialog.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/widgets/grimoire_color_picker.dart';
import '../../../../core/widgets/grimoire_font_picker.dart';
import 'package:grimoire_studio/features/ai_generator/presentation/widgets/ai_prompt_dialog.dart';
import '../dialogs/background_removal_dialog.dart';
import '../dialogs/sprite_sheet_splitter_dialog.dart';
import '../dialogs/card_3d_viewer_dialog.dart';
import '../dialogs/asset_folder_dialogs.dart';
import '../dialogs/layer_delete_dialog.dart';
import '../../models/card_dimension_presets.dart';
import '../../models/card_project.dart';

class InspectorPanel extends ConsumerWidget {
  final Widget? bottomAction;

  const InspectorPanel({super.key, this.bottomAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final selectedLayer = editorState.selectedLayer;

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: GrimoireTheme.surfacePanel,
        border: Border(
          left: BorderSide(color: GrimoireTheme.borderSubtle),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: editorState.selectedLayerIds.length > 1
                ? _buildMultiLayerInspector(context, ref, editorState)
                : (selectedLayer != null
                    ? (selectedLayer.type == LayerType.image
                        ? _buildImageInspector(context, ref, selectedLayer)
                        : _buildLayerInspector(context, ref, selectedLayer))
                    : (editorState.selectedAssetPath != null
                        ? AssetInspectorWidget(
                            assetPath: editorState.selectedAssetPath!,
                            gameName: (editorState.project.rows.isNotEmpty
                                    ? editorState.project.activeRow['game']
                                    : null)?.toString() ??
                                'Magic',
                          )
                        : _buildProjectSettings(context, ref, editorState))),
          ),
          ?bottomAction,
        ],
      ),
    );
  }

  Widget _buildProjectSettings(BuildContext context, WidgetRef ref, EditorState state) {
    final project = state.project;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          ref.tr('project_card_settings'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        _buildActiveCardCategorySection(context, ref, state),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          project.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GrimoireTheme.accentPurple),
        ),
        const SizedBox(height: 10),
        _buildCardDimensionSection(context, ref, project),
        _buildInfoRow(ref.tr('dpi_target'), '300 DPI Print-Ready'),
        _buildInfoRow(ref.tr('database_rows'), '${project.rows.length} cards'),
        _buildInfoRow(ref.tr('active_template'), project.activeTemplate.name),
        const SizedBox(height: 16),
        _buildSectionHeader(ref.tr('card_background_settings')),
        const SizedBox(height: 10),
        _buildColorPickerSection(
          context,
          ref,
          title: ref.tr('shape_fill_color'),
          currentColor: project.activeTemplate.getBackgroundColor(state.currentSide),
          onChanged: (newColor) {
            ref.read(editorProvider.notifier).updateBackgroundColor(newColor);
            final bgLayer = project.activeTemplate
                .getLayers(state.currentSide)
                .where((l) => l.type == LayerType.background || l.name.toLowerCase().contains('background'))
                .firstOrNull;
            if (bgLayer != null) {
              ref.read(editorProvider.notifier).updateLayer(
                bgLayer.copyWith(
                  shapeColor: newColor,
                  borderColor: Colors.transparent,
                  borderWidth: 0,
                ),
              );
            }
          },
          allowTransparent: false,
        ),
        const SizedBox(height: 12),
        _buildCornerRadiusSelector(
          context,
          ref,
          currentRadius: project.activeTemplate.cornerRadius,
          onChanged: (newRadius) {
            ref.read(editorProvider.notifier).updateCornerRadius(newRadius);
            final bgLayer = project.activeTemplate
                .getLayers(state.currentSide)
                .where((l) => l.type == LayerType.background || l.name.toLowerCase().contains('background'))
                .firstOrNull;
            if (bgLayer != null) {
              ref.read(editorProvider.notifier).updateLayer(bgLayer.copyWith(borderRadius: newRadius));
            }
          },
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          ref.tr('select_layer_hint'),
          style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted, height: 1.4),
        ),
        const SizedBox(height: 16),
        _buildLocalImageAssetsSection(context, ref, state, null),
      ],
    );
  }

  Widget _buildCardDimensionSection(BuildContext context, WidgetRef ref, CardProject project) {
    final currentPreset = CardDimensionPreset.match(project.widthMm, project.heightMm);

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GrimoireTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.aspect_ratio, size: 14, color: GrimoireTheme.accentPurple),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ref.tr('print_size_presets'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: GrimoireTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentPreset?.id ?? 'custom',
                isExpanded: true,
                dropdownColor: GrimoireTheme.surfaceElevated,
                style: const TextStyle(fontSize: 11, color: Colors.white),
                items: [
                  for (final p in CardDimensionPreset.standardPresets)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name} (${p.widthMm} x ${p.heightMm} mm)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const DropdownMenuItem(
                    value: 'custom',
                    child: Text('Personalizado (mm)'),
                  ),
                ],
                onChanged: (val) {
                  if (val == null || val == 'custom') return;
                  final selected = CardDimensionPreset.standardPresets.firstWhere((p) => p.id == val);
                  ref.read(editorProvider.notifier).updateCardDimensions(selected.widthMm, selected.heightMm);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ancho (mm)', style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted)),
                    const SizedBox(height: 3),
                    TextFormField(
                      key: ValueKey('w_${project.widthMm}'),
                      initialValue: project.widthMm.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onFieldSubmitted: (v) {
                        final val = double.tryParse(v);
                        if (val != null && val >= 20 && val <= 300) {
                          ref.read(editorProvider.notifier).updateCardDimensions(val, project.heightMm);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Alto (mm)', style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted)),
                    const SizedBox(height: 3),
                    TextFormField(
                      key: ValueKey('h_${project.heightMm}'),
                      initialValue: project.heightMm.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onFieldSubmitted: (v) {
                        final val = double.tryParse(v);
                        if (val != null && val >= 20 && val <= 300) {
                          ref.read(editorProvider.notifier).updateCardDimensions(project.widthMm, val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: GrimoireTheme.accentCyan,
                side: BorderSide(color: GrimoireTheme.accentCyan.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.view_in_ar, size: 14),
              label: const Text('Inspeccionar en 3D / Foil', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => Card3DViewerDialog(
                    template: project.activeTemplate,
                    cardData: project.activeRow,
                    widthMm: project.widthMm,
                    heightMm: project.heightMm,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCardCategorySection(BuildContext context, WidgetRef ref, EditorState state) {
    if (state.project.rows.isEmpty) return const SizedBox.shrink();

    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? 'Magic').toString();
    final cardName = (activeRow['card_name'] ?? 'Carta').toString();
    final activeCategory = (activeRow['category'] ?? '').toString();
    final gameCategories = ref.read(editorProvider.notifier).getCategoriesForGame(gameName);

    final matchingCategory = gameCategories.firstWhere(
      (c) => c.name.toLowerCase() == activeCategory.toLowerCase(),
      orElse: () => GameCategory(
        id: '',
        name: activeCategory.isNotEmpty ? activeCategory : ref.tr('no_category'),
        icon: '🏷️',
      ),
    );

    final catColor = matchingCategory.defaultColor != 0
        ? Color(matchingCategory.defaultColor)
        : GrimoireTheme.accentPurple;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141226),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: catColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(matchingCategory.icon.isNotEmpty ? matchingCategory.icon : '🏷️', style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cardName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$gameName • ${activeCategory.isNotEmpty ? activeCategory : ref.tr('no_category')}',
                      style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(ref.tr('select_category'), style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: GrimoireTheme.bgCanvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: DropdownButton<String>(
              value: gameCategories.any((c) => c.name.toLowerCase() == activeCategory.toLowerCase())
                  ? matchingCategory.name
                  : '',
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: GrimoireTheme.surfaceElevated,
              style: const TextStyle(fontSize: 12, color: Colors.white),
              items: [
                DropdownMenuItem<String>(
                  value: '',
                  child: Row(
                    children: [
                      const Icon(Icons.block, size: 14, color: GrimoireTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(ref.tr('no_category'), style: const TextStyle(color: GrimoireTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                for (final cat in gameCategories)
                  DropdownMenuItem<String>(
                    value: cat.name,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Color(cat.defaultColor),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(cat.icon, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cat.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (chosen) {
                if (chosen != null && chosen != activeCategory) {
                  ref.read(editorProvider.notifier).setCategoryForActiveCard(chosen);
                }
              },
            ),
          ),
          if (matchingCategory.id.isNotEmpty && matchingCategory.name != ref.tr('no_category')) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildModelBadge(ref.tr('include_cost'), matchingCategory.hasCost ? (matchingCategory.defaultCost.isNotEmpty ? matchingCategory.defaultCost : 'Sí') : 'No', matchingCategory.hasCost),
                _buildModelBadge(ref.tr('include_combat_stats'), matchingCategory.hasCombatStats ? '${matchingCategory.defaultAttack}/${matchingCategory.defaultDefense}' : 'No', matchingCategory.hasCombatStats),
                _buildModelBadge(ref.tr('include_rarity'), matchingCategory.hasRarity ? (matchingCategory.defaultRarity.isNotEmpty ? matchingCategory.defaultRarity : 'Sí') : 'No', matchingCategory.hasRarity),
                _buildModelBadge(ref.tr('include_rules'), matchingCategory.hasRules ? 'Sí' : 'No', matchingCategory.hasRules),
              ],
            ),
            if (matchingCategory.customFields.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: matchingCategory.customFields.entries.map((e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentIndigo.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.3)),
                  ),
                  child: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 9, color: Color(0xFFC7D2FE))),
                )).toList(),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: catColor.withValues(alpha: 0.25),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: catColor.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.flash_on, size: 14),
                label: Text(
                  ref.tr('apply_category_model'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  ref.read(editorProvider.notifier).applyCategoryModelToActiveCard(matchingCategory);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: GrimoireTheme.accentEmerald,
                      content: Text(ref.tr('apply_model_toast')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: GrimoireTheme.borderSubtle),
          const SizedBox(height: 10),

          // Controles de Modelo Predefinido (para el juego y para la categoría)
          _buildPresetModelSection(context, ref, state, activeRow, gameName, activeCategory),
        ],
      ),
    );
  }

  Widget _buildPresetModelSection(
    BuildContext context,
    WidgetRef ref,
    EditorState state,
    Map<String, dynamic> activeRow,
    String gameName,
    String activeCategory,
  ) {
    final notifier = ref.read(editorProvider.notifier);
    final isCatDefault = notifier.isRowCategoryDefault(activeRow);
    final isGameDefault = notifier.isRowGameDefault(activeRow);
    final hasCategory = activeCategory.isNotEmpty && activeCategory != ref.tr('no_category');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
            SizedBox(width: 5),
            Text(
              'Modelos Predefinidos',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Define esta carta como molde para que las próximas cartas que crees salgan con este mismo diseño.',
          style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted, height: 1.3),
        ),
        const SizedBox(height: 8),

        // 1. Control de Categoría (si tiene categoría asignada)
        if (hasCategory) ...[
          if (isCatDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentEmerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 15, color: GrimoireTheme.accentEmerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Predefinida para "$activeCategory"',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA7F3D0)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Nuevas cartas de esta categoría usarán este molde',
                          style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      notifier.unmarkActiveCardAsCategoryDefault();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF374151),
                          content: Text('Carta desmarcada como predefinida de "$activeCategory".'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 14, color: GrimoireTheme.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('btn_mark_category_default'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GrimoireTheme.accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size.fromHeight(34),
                ),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: Text(
                  'Marcar como predefinido para "$activeCategory"',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                onPressed: () {
                  notifier.markActiveCardAsCategoryDefault();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: GrimoireTheme.accentEmerald,
                      content: Text('¡Esta carta ahora es el modelo predefinido para "$activeCategory"!'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 6),
        ],

        // 2. Control de Juego General
        if (isGameDefault)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, size: 15, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Predefinida para $gameName',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFDE68A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Molde base para nuevas cartas del juego',
                        style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    notifier.unmarkActiveCardAsGameDefault();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF374151),
                        content: Text('Carta desmarcada como predefinida de $gameName.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: GrimoireTheme.textMuted),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('btn_mark_game_default'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFBBF24),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size.fromHeight(34),
              ),
              icon: const Icon(Icons.star_outline, size: 14),
              label: Text(
                'Marcar como predefinido para $gameName',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              onPressed: () {
                notifier.markActiveCardAsGameDefault();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFD97706),
                    content: Text('¡Esta carta ahora es el modelo predefinido general para "$gameName"!'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildModelBadge(String label, String value, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isEnabled ? const Color(0xFF1E1B4B) : const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isEnabled ? GrimoireTheme.accentIndigo.withValues(alpha: 0.4) : Colors.white12,
        ),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
          color: isEnabled ? const Color(0xFFA5B4FC) : GrimoireTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildLayerInspector(BuildContext context, WidgetRef ref, LayerItem layer) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          layer.type == LayerType.text
                              ? Icons.title
                              : (layer.type == LayerType.shape ? Icons.interests_outlined : Icons.wallpaper_outlined),
                          size: 16,
                          color: GrimoireTheme.accentPurple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ref.tr('layer_settings'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${layer.name} • ${_getLayerTypeLabel(layer.type)}',
                      style: const TextStyle(fontSize: 10, color: GrimoireTheme.accentPurple, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (layer.type != LayerType.background)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: GrimoireTheme.accentPink),
                tooltip: ref.tr('delete_layer'),
                onPressed: () {
                  LayerDeleteDialog.show(context: context, ref: ref, layer: layer);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Geometry Section (Background layers are fixed to full card size)
        if (layer.type == LayerType.background)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF141226),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GrimoireTheme.accentPink.withValues(alpha: 0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.wallpaper_outlined, size: 16, color: GrimoireTheme.accentPink),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Capa exclusiva de Fondo Completo (cubre toda la carta automáticamente)',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFFFBCFE8), height: 1.3),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _buildAlignmentToolbar(context, ref, ref.watch(editorProvider)),
          _buildSectionHeader(ref.tr('transform_geometry')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNumberInput('X', layer.x, (val) {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(x: val));
                }, keyPrefix: layer.id),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput('Y', layer.y, (val) {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(y: val));
                }, keyPrefix: layer.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNumberInput(ref.tr('width'), layer.width, (val) {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(width: val));
                }, keyPrefix: layer.id),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput(ref.tr('height'), layer.height, (val) {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(height: val));
                }, keyPrefix: layer.id),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),
        _buildSectionHeader(ref.tr('databinding_token')),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('binding_${layer.id}'),
          initialValue: layer.bindingKey,
          style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: ref.tr('variable_key'),
            hintText: ref.tr('variable_key_hint'),
            isDense: true,
          ),
          onChanged: (val) {
            ref.read(editorProvider.notifier).updateLayer(layer.copyWith(bindingKey: val.trim()));
          },
        ),

        // ============================================================
        // 1. BACKGROUND LAYER INSPECTOR (Solid, Gradient, Full Image)
        // ============================================================
        if (layer.type == LayerType.background) ...[
          const SizedBox(height: 16),
          _buildSectionHeader('ESTILO DE FONDO (BACKGROUND)'),
          const SizedBox(height: 8),
          _buildBackgroundFillModeSelector(context, ref, layer),
          const SizedBox(height: 12),

          if (layer.fillMode == LayerFillMode.solid) ...[
            _buildColorPickerSection(
              context,
              ref,
              title: 'Color Sólido de Fondo',
              currentColor: layer.shapeColor,
              onChanged: (newColor) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(shapeColor: newColor));
                ref.read(editorProvider.notifier).updateBackgroundColor(newColor);
              },
              allowTransparent: false,
            ),
          ],

          if (layer.fillMode == LayerFillMode.gradient) ...[
            _buildGradientInspectorControls(context, ref, layer),
          ],

          if (layer.fillMode == LayerFillMode.image) ...[
            _buildImageFitSelector(context, ref, layer),
            const SizedBox(height: 12),
            _buildLayerAssetPickerSection(context, ref, layer),
          ],

          const SizedBox(height: 12),
          _buildCornerRadiusSelector(
            context,
            ref,
            currentRadius: layer.borderRadius,
            onChanged: (newRadius) {
              ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderRadius: newRadius));
              ref.read(editorProvider.notifier).updateCornerRadius(newRadius);
            },
          ),
          const SizedBox(height: 12),
          _buildColorPickerSection(
            context,
            ref,
            title: ref.tr('border_color'),
            currentColor: layer.borderColor,
            onChanged: (newColor) {
              ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderColor: newColor));
            },
            allowTransparent: true,
          ),
          const SizedBox(height: 12),
          _buildBorderWidthSelector(
            context,
            ref,
            currentWidth: layer.borderWidth,
            onChanged: (newWidth) {
              ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderWidth: newWidth));
            },
          ),
        ],

        // ============================================================
        // 2. TEXT LAYER INSPECTOR (Any Typography / Font Picker)
        // ============================================================
        if (layer.type == LayerType.text) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(ref.tr('typography_style')),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('text_${layer.id}'),
            initialValue: layer.text,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              labelText: ref.tr('static_template_text'),
              hintText: ref.tr('static_text_hint'),
              isDense: true,
            ),
            onChanged: (val) {
              ref.read(editorProvider.notifier).updateLayer(layer.copyWith(text: val));
            },
          ),
          const SizedBox(height: 12),

          // Typography / Font Selector Card
          _buildTypographySelectorSection(context, ref, layer),
          const SizedBox(height: 10),

          // Font Size + Bold + Italic + Alignment
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildNumberInput(ref.tr('font_size'), layer.fontSize, (val) {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(fontSize: val));
                }, keyPrefix: layer.id),
              ),
              const SizedBox(width: 6),
              _buildToggleIconButton(
                icon: Icons.format_bold,
                tooltip: 'Negrita (Bold)',
                isActive: layer.isBold,
                onTap: () {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(isBold: !layer.isBold));
                },
              ),
              const SizedBox(width: 4),
              _buildToggleIconButton(
                icon: Icons.format_italic,
                tooltip: 'Cursiva (Italic)',
                isActive: layer.isItalic,
                onTap: () {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(isItalic: !layer.isItalic));
                },
              ),
              const SizedBox(width: 4),
              _buildToggleIconButton(
                icon: Icons.format_align_left,
                tooltip: 'Alinear Izquierda',
                isActive: layer.textAlign == TextAlign.left,
                onTap: () {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(textAlign: TextAlign.left));
                },
              ),
              const SizedBox(width: 4),
              _buildToggleIconButton(
                icon: Icons.format_align_center,
                tooltip: 'Centrar',
                isActive: layer.textAlign == TextAlign.center,
                onTap: () {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(textAlign: TextAlign.center));
                },
              ),
              const SizedBox(width: 4),
              _buildToggleIconButton(
                icon: Icons.format_align_right,
                tooltip: 'Alinear Derecha',
                isActive: layer.textAlign == TextAlign.right,
                onTap: () {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(textAlign: TextAlign.right));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildColorPickerSection(
            context,
            ref,
            title: ref.tr('text_color'),
            currentColor: layer.fontColor,
            onChanged: (newColor) {
              ref.read(editorProvider.notifier).updateLayer(layer.copyWith(fontColor: newColor));
            },
            allowTransparent: false,
          ),
        ],

        // ============================================================
        // 3. SHAPE / FRAME LAYER INSPECTOR (Presets + Custom Shape Builder)
        // ============================================================
        if (layer.type == LayerType.shape) ...[
          const SizedBox(height: 16),
          _buildSectionHeader('GEOMETRÍA Y DESARROLLO DE FORMA'),
          const SizedBox(height: 10),
          _buildShapePresetSelectorSection(context, ref, layer),
          const SizedBox(height: 16),

          _buildSectionHeader(ref.tr('shape_border_appearance')),
          const SizedBox(height: 10),

          // Fill mode toggle for Shape (Solid vs Gradient)
          _buildShapeFillModeToggle(context, ref, layer),
          const SizedBox(height: 10),

          if (layer.fillMode == LayerFillMode.gradient)
            _buildGradientInspectorControls(context, ref, layer)
          else
            _buildColorPickerSection(
              context,
              ref,
              title: ref.tr('shape_fill_color'),
              currentColor: layer.shapeColor,
              onChanged: (newColor) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(shapeColor: newColor));
                if (layer.name.toLowerCase().contains('background')) {
                  ref.read(editorProvider.notifier).updateBackgroundColor(newColor);
                }
              },
              allowTransparent: true,
            ),
          const SizedBox(height: 12),

          // Corner Radius / Vertex Smoothing
          _buildCornerRadiusSelector(
            context,
            ref,
            currentRadius: layer.borderRadius,
            onChanged: (newRadius) {
              ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderRadius: newRadius));
              if (layer.name.toLowerCase().contains('background')) {
                ref.read(editorProvider.notifier).updateCornerRadius(newRadius);
              }
            },
          ),
          const SizedBox(height: 12),

          // Border Color
          _buildColorPickerSection(
            context,
            ref,
            title: ref.tr('border_color'),
            currentColor: layer.borderColor,
            onChanged: (newColor) {
              ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderColor: newColor));
            },
            allowTransparent: true,
          ),
          const SizedBox(height: 12),

          // Border Width
          _buildBorderWidthSelector(
            context,
            ref,
            currentWidth: layer.borderWidth,
            onChanged: (newWidth) {
              ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderWidth: newWidth));
            },
          ),
        ],

        // Smart Tokens / Conditional Rules Section
        const SizedBox(height: 16),
        _buildSectionHeader(ref.tr('smart_tokens_rules')),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('rule_${layer.id}'),
          initialValue: layer.conditionalRules['condition']?.toString() ?? '',
          style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: ref.tr('rule_expression'),
            hintText: ref.tr('rule_expression_hint'),
            isDense: true,
          ),
          onChanged: (val) {
            final rules = Map<String, dynamic>.from(layer.conditionalRules);
            rules['condition'] = val.trim();
            ref.read(editorProvider.notifier).updateLayer(layer.copyWith(conditionalRules: rules));
          },
        ),

        // AI Art Generation Trigger (For Background layers in image mode)
        if (layer.type == LayerType.background && layer.fillMode == LayerFillMode.image) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(ref.tr('generative_ai_art')),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GrimoireTheme.accentPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text(ref.tr('generate_ai_for_layer'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AiPromptDialog(layerId: layer.id),
              );
            },
          ),
        ],
      ],
    );
  }

  // ============================================================
  // DEDICATED IMAGE INSPECTOR ("Ajustes de Imagen")
  // ============================================================
  Widget _buildImageInspector(BuildContext context, WidgetRef ref, LayerItem layer) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.accentEmerald.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.image_outlined, size: 16, color: GrimoireTheme.accentEmerald),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ref.tr('image_settings'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${layer.name} • CAPA DE IMAGEN',
                      style: const TextStyle(fontSize: 10, color: GrimoireTheme.accentEmerald, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: GrimoireTheme.accentPink),
              tooltip: ref.tr('delete_layer'),
              onPressed: () {
                LayerDeleteDialog.show(context: context, ref: ref, layer: layer);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 1. ASSET / IMAGEN SECTION
        _buildSectionHeader(ref.tr('image_origin_source')),
        const SizedBox(height: 8),
        _buildLayerAssetPickerSection(context, ref, layer),
        const SizedBox(height: 16),

        // 2. HERRAMIENTAS DE IA Y RETOQUE
        _buildSectionHeader(ref.tr('ai_tools_retouch')),
        const SizedBox(height: 8),
        _buildImageAiToolsSection(context, ref, layer),
        const SizedBox(height: 16),

        // 3. APARIENCIA Y ESCALA DE IMAGEN
        _buildSectionHeader(ref.tr('image_appearance_scale')),
        const SizedBox(height: 8),
        _buildImageFitSelector(context, ref, layer),
        const SizedBox(height: 12),

        // Opacidad
        _buildOpacitySlider(context, ref, layer),
        const SizedBox(height: 12),

        // Radio de Esquinas (Border Radius)
        _buildCornerRadiusSelector(
          context,
          ref,
          currentRadius: layer.borderRadius,
          onChanged: (newRadius) {
            ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderRadius: newRadius));
          },
        ),
        const SizedBox(height: 12),

        // Color de Borde
        _buildColorPickerSection(
          context,
          ref,
          title: ref.tr('border_color'),
          currentColor: layer.borderColor,
          onChanged: (newColor) {
            ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderColor: newColor));
          },
          allowTransparent: true,
        ),
        const SizedBox(height: 12),

        // Grosor de Borde
        _buildBorderWidthSelector(
          context,
          ref,
          currentWidth: layer.borderWidth,
          onChanged: (newWidth) {
            ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderWidth: newWidth));
          },
        ),
        const SizedBox(height: 16),

        // 4. GEOMETRÍA Y POSICIÓN
        _buildAlignmentToolbar(context, ref, ref.watch(editorProvider)),
        _buildSectionHeader(ref.tr('transform_geometry')),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildNumberInput('X', layer.x, (val) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(x: val));
              }, keyPrefix: layer.id),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumberInput('Y', layer.y, (val) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(y: val));
              }, keyPrefix: layer.id),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildNumberInput(ref.tr('width'), layer.width, (val) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(width: val));
              }, keyPrefix: layer.id),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumberInput(ref.tr('height'), layer.height, (val) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(height: val));
              }, keyPrefix: layer.id),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 5. DATABINDING TOKEN
        _buildSectionHeader(ref.tr('databinding_token')),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('binding_${layer.id}'),
          initialValue: layer.bindingKey,
          style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: ref.tr('variable_key'),
            hintText: 'ej. art_url, icon_path',
            isDense: true,
          ),
          onChanged: (val) {
            ref.read(editorProvider.notifier).updateLayer(layer.copyWith(bindingKey: val.trim()));
          },
        ),
        const SizedBox(height: 16),

        // Smart Tokens / Rules
        _buildSectionHeader(ref.tr('smart_tokens_rules')),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('rule_${layer.id}'),
          initialValue: layer.conditionalRules['condition']?.toString() ?? '',
          style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: ref.tr('rule_expression'),
            hintText: ref.tr('rule_expression_hint'),
            isDense: true,
          ),
          onChanged: (val) {
            final rules = Map<String, dynamic>.from(layer.conditionalRules);
            rules['condition'] = val.trim();
            ref.read(editorProvider.notifier).updateLayer(layer.copyWith(conditionalRules: rules));
          },
        ),
      ],
    );
  }

  // --- Image AI Tools (Generate with AI & Background Removal) ---
  Widget _buildImageAiToolsSection(BuildContext context, WidgetRef ref, LayerItem layer) {
    final editorState = ref.watch(editorProvider);
    final activeRow = editorState.project.rows.isNotEmpty ? editorState.project.activeRow : <String, dynamic>{};
    final gameName = (activeRow['game'] ?? 'Magic').toString();

    // Check if image file exists for background removal
    File? resolvedImage;
    if (layer.imagePath != null && File(layer.imagePath!).existsSync()) {
      resolvedImage = File(layer.imagePath!);
    } else if (layer.bindingKey.isNotEmpty && activeRow.containsKey(layer.bindingKey)) {
      resolvedImage = GameFolderService.resolveCardImageFile(gameName, activeRow[layer.bindingKey]?.toString());
    }

    final hasImage = resolvedImage != null && resolvedImage.existsSync();

    return Column(
      children: [
        // AI Generation Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GrimoireTheme.accentPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text(
              ref.tr('generate_ai_for_layer'),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AiPromptDialog(layerId: layer.id),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Background Removal Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasImage ? const Color(0xFF1E1B4B) : const Color(0xFF141724),
              foregroundColor: hasImage ? const Color(0xFFC7D2FE) : GrimoireTheme.textMuted,
              side: BorderSide(
                color: hasImage ? GrimoireTheme.accentIndigo.withValues(alpha: 0.5) : Colors.white12,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(
              Icons.blur_linear_outlined,
              size: 16,
              color: hasImage ? const Color(0xFFA5B4FC) : GrimoireTheme.textMuted,
            ),
            label: const Text(
              'Quitar Fondo con IA (RMBG)',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
            onPressed: hasImage
                ? () async {
                    final processedFile = await BackgroundRemovalDialog.show(
                      context,
                      sourceImageFile: resolvedImage!,
                      gameName: gameName,
                    );
                    if (processedFile != null && processedFile.existsSync()) {
                      ref.read(editorProvider.notifier).updateLayer(
                        layer.copyWith(imagePath: processedFile.path),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: GrimoireTheme.accentEmerald,
                            content: Text('¡Fondo eliminado y asignado a la capa con éxito!'),
                          ),
                        );
                      }
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }

  // --- Opacity Slider ---
  Widget _buildOpacitySlider(BuildContext context, WidgetRef ref, LayerItem layer) {
    final opacityVal = (layer.opacity * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ref.tr('image_opacity'),
              style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
            ),
            Text(
              '$opacityVal%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: GrimoireTheme.accentEmerald,
            inactiveTrackColor: const Color(0xFF1F2438),
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: layer.opacity.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (val) {
              ref.read(editorProvider.notifier).updateLayer(layer.copyWith(opacity: val));
            },
          ),
        ),
      ],
    );
  }

  String _getLayerTypeLabel(LayerType type) {
    switch (type) {
      case LayerType.background:
        return 'CAPA DE FONDO COMPLETO (BACKGROUND)';
      case LayerType.shape:
        return 'CAPA DE FORMA / MARCO GEOMÉTRICO';
      case LayerType.text:
        return 'CAPA DE TEXTO Y TIPOGRAFÍA';
      case LayerType.image:
        return 'CAPA DE IMAGEN / ILUSTRACIÓN';
    }
  }

  Widget _buildToggleIconButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isActive
                ? GrimoireTheme.accentPurple.withValues(alpha: 0.3)
                : const Color(0xFF141726),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
            ),
          ),
          child: Icon(
            icon,
            size: 15,
            color: isActive ? Colors.white : GrimoireTheme.textMuted,
          ),
        ),
      ),
    );
  }

  // --- Background Fill Mode Selector (Solid / Gradient / Full Image) ---
  Widget _buildBackgroundFillModeSelector(BuildContext context, WidgetRef ref, LayerItem layer) {
    final modes = [
      (LayerFillMode.solid, 'Color Sólido', Icons.palette_outlined),
      (LayerFillMode.gradient, 'Gradiente', Icons.gradient),
      (LayerFillMode.image, 'Imagen', Icons.image_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Row(
        children: modes.map((item) {
          final isSelected = layer.fillMode == item.$1;
          return Expanded(
            child: InkWell(
              onTap: () {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(fillMode: item.$1));
              },
              borderRadius: BorderRadius.circular(7),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? GrimoireTheme.accentPurple : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.$3,
                      size: 13,
                      color: isSelected ? Colors.white : GrimoireTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.$2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : GrimoireTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Shape Fill Mode Toggle (Solid vs Gradient) ---
  Widget _buildShapeFillModeToggle(BuildContext context, WidgetRef ref, LayerItem layer) {
    final isGradient = layer.fillMode == LayerFillMode.gradient;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(fillMode: LayerFillMode.solid));
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: !isGradient ? GrimoireTheme.accentPurple : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.format_color_fill, size: 13, color: !isGradient ? Colors.white : GrimoireTheme.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Color Sólido',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: !isGradient ? FontWeight.bold : FontWeight.normal,
                          color: !isGradient ? Colors.white : GrimoireTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(fillMode: LayerFillMode.gradient));
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: isGradient ? GrimoireTheme.accentPurple : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.gradient, size: 13, color: isGradient ? Colors.white : GrimoireTheme.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Gradiente Estilizado',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isGradient ? FontWeight.bold : FontWeight.normal,
                          color: isGradient ? Colors.white : GrimoireTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Gradient Inspector Controls (Presets, Linear/Radial/Sweep, Angle, 2/3 Color Stops) ---
  Widget _buildGradientInspectorControls(BuildContext context, WidgetRef ref, LayerItem layer) {
    final gradientTypes = [
      (LayerGradientType.linear, 'Lineal', Icons.linear_scale),
      (LayerGradientType.radial, 'Radial', Icons.blur_circular),
      (LayerGradientType.sweep, 'Barrido', Icons.track_changes),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F111D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preajustes de Gradiente',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ShapePathBuilder.gradientPresets.map((preset) {
                  return InkWell(
                    onTap: () {
                      ref.read(editorProvider.notifier).updateLayer(
                        layer.copyWith(
                          fillMode: LayerFillMode.gradient,
                          gradientType: preset.type,
                          shapeColor: preset.startColor,
                          gradientEndColor: preset.endColor,
                          gradientMiddleColor: preset.middleColor ?? preset.endColor,
                          useThreeStopGradient: preset.middleColor != null,
                          gradientAngle: preset.angle,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: preset.middleColor != null
                              ? [preset.startColor, preset.middleColor!, preset.endColor]
                              : [preset.startColor, preset.endColor],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        preset.name,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Gradient Type Selector
              const Text(
                'Tipo de Gradiente',
                style: TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
              ),
              const SizedBox(height: 6),
              Row(
                children: gradientTypes.map((gt) {
                  final isSelected = layer.gradientType == gt.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        onTap: () {
                          ref.read(editorProvider.notifier).updateLayer(layer.copyWith(gradientType: gt.$1));
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? GrimoireTheme.accentPurple.withValues(alpha: 0.3)
                                : const Color(0xFF161928),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(gt.$3, size: 12, color: isSelected ? Colors.white : GrimoireTheme.textMuted),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  gt.$2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (layer.gradientType != LayerGradientType.radial) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Ángulo de Dirección',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
                      ),
                    ),
                    Text(
                      '${layer.gradientAngle.toInt()}°',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: GrimoireTheme.accentPurple,
                    inactiveTrackColor: const Color(0xFF222638),
                    thumbColor: GrimoireTheme.accentPurple,
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: layer.gradientAngle.clamp(0.0, 360.0),
                    min: 0.0,
                    max: 360.0,
                    onChanged: (val) {
                      ref.read(editorProvider.notifier).updateLayer(layer.copyWith(gradientAngle: val));
                    },
                  ),
                ),
              ],

              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Gradiente de 3 Colores (Parada Intermedia)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                  Switch(
                    activeThumbColor: GrimoireTheme.accentPurple,
                    value: layer.useThreeStopGradient,
                    onChanged: (val) {
                      ref.read(editorProvider.notifier).updateLayer(layer.copyWith(useThreeStopGradient: val));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildColorPickerSection(
          context,
          ref,
          title: 'Color Inicial del Gradiente (1)',
          currentColor: layer.shapeColor,
          onChanged: (col) {
            ref.read(editorProvider.notifier).updateLayer(layer.copyWith(shapeColor: col));
          },
          allowTransparent: true,
        ),
        if (layer.useThreeStopGradient) ...[
          const SizedBox(height: 10),
          _buildColorPickerSection(
            context,
            ref,
            title: 'Color Intermedio del Gradiente (2)',
            currentColor: layer.gradientMiddleColor,
            onChanged: (col) {
              ref.read(editorProvider.notifier).updateLayer(layer.copyWith(gradientMiddleColor: col));
            },
            allowTransparent: true,
          ),
        ],
        const SizedBox(height: 10),
        _buildColorPickerSection(
          context,
          ref,
          title: 'Color Final del Gradiente (${layer.useThreeStopGradient ? '3' : '2'})',
          currentColor: layer.gradientEndColor,
          onChanged: (col) {
            ref.read(editorProvider.notifier).updateLayer(layer.copyWith(gradientEndColor: col));
          },
          allowTransparent: true,
        ),
      ],
    );
  }

  // --- Image Fit Selector for Background & Image layers ---
  Widget _buildImageFitSelector(BuildContext context, WidgetRef ref, LayerItem layer) {
    final fits = [
      (BoxFit.cover, 'Cubrir (Cover)'),
      (BoxFit.contain, 'Contener (Contain)'),
      (BoxFit.fill, 'Estirar (Fill)'),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Modo de Ajuste de Imagen Completa',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            children: fits.map((f) {
              final isSelected = layer.imageFit == f.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () {
                      ref.read(editorProvider.notifier).updateLayer(layer.copyWith(imageFit: f.$1));
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? GrimoireTheme.accentEmerald.withValues(alpha: 0.25)
                            : const Color(0xFF161928),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? GrimoireTheme.accentEmerald : GrimoireTheme.borderSubtle,
                        ),
                      ),
                      child: Text(
                        f.$2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- Shape Preset Selector + Custom Shape Builder Trigger ---
  Widget _buildShapePresetSelectorSection(BuildContext context, WidgetRef ref, LayerItem layer) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Seleccionar Forma / Marco',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ShapePathBuilder.getPresetLabel(layer.shapePreset),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: GrimoireTheme.accentAmber),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ShapePreset.values.map((preset) {
              final isSelected = layer.shapePreset == preset;
              return InkWell(
                onTap: () {
                  final updatedPoints = preset == ShapePreset.custom && layer.customPoints.length < 3
                      ? ShapePathBuilder.getPresetNormalizedPoints(ShapePreset.hexagon)
                      : layer.customPoints;
                  ref.read(editorProvider.notifier).updateLayer(
                    layer.copyWith(
                      shapePreset: preset,
                      customPoints: updatedPoints,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? GrimoireTheme.accentPurple.withValues(alpha: 0.3)
                        : const Color(0xFF161928),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CustomPaint(
                          painter: _MiniShapePreviewPainter(
                            preset: preset,
                            color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          ShapePathBuilder.getPresetLabel(preset),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Custom Shape Builder Button ("Desarrollo de Forma Personalizada")
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E1065),
                foregroundColor: Colors.white,
                side: const BorderSide(color: GrimoireTheme.accentPurple, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.polyline_outlined, size: 16, color: Color(0xFFE9D5FF)),
              label: const Text(
                'Desarrollo de Forma Personalizada (Editor de Nodos)',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final result = await CustomShapeBuilderDialog.show(
                  context,
                  layer: layer,
                );
                if (result != null) {
                  ref.read(editorProvider.notifier).updateLayer(
                    layer.copyWith(
                      shapePreset: result.shapePreset,
                      customPoints: result.customPoints,
                      closeCustomPath: result.closeCustomPath,
                      borderRadius: result.borderRadius,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Typography / Font Picker Section ---
  Widget _buildTypographySelectorSection(BuildContext context, WidgetRef ref, LayerItem layer) {
    final quickFonts = [
      'Cinzel',
      'MedievalSharp',
      'Playfair Display',
      'Inter',
      'Montserrat',
      'Orbitron',
      'Bangers',
      'JetBrains Mono',
      'Georgia',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.font_download_outlined, size: 14, color: GrimoireTheme.accentIndigo),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tipografía / Fuente',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                  foregroundColor: const Color(0xFFE9D5FF),
                ),
                icon: const Icon(Icons.manage_search, size: 14),
                label: const Text('Catálogo Completo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final chosenFont = await GrimoireFontPickerDialog.show(
                    context,
                    currentFontFamily: layer.fontFamily,
                    sampleText: layer.text.isNotEmpty ? layer.text : 'Grimoire Chronicles',
                  );
                  if (chosenFont != null && chosenFont.isNotEmpty) {
                    ref.read(editorProvider.notifier).updateLayer(layer.copyWith(fontFamily: chosenFont));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Active font preview button
          InkWell(
            onTap: () async {
              final chosenFont = await GrimoireFontPickerDialog.show(
                context,
                currentFontFamily: layer.fontFamily,
                sampleText: layer.text.isNotEmpty ? layer.text : 'Grimoire Chronicles',
              );
              if (chosenFont != null && chosenFont.isNotEmpty) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(fontFamily: chosenFont));
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161928),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          layer.fontFamily,
                          style: GrimoireFontHelper.resolveTextStyle(
                            fontFamily: layer.fontFamily,
                            fontSize: 14,
                            isBold: true,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Clic para explorar +40 fuentes o escribir cualquier fuente',
                          style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.unfold_more, size: 16, color: GrimoireTheme.accentPurple),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Quick font chips
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: quickFonts.map((f) {
              final isSelected = layer.fontFamily.toLowerCase() == f.toLowerCase();
              return InkWell(
                onTap: () {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(fontFamily: f));
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? GrimoireTheme.accentPurple.withValues(alpha: 0.35)
                        : const Color(0xFF141726),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                    ),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerAssetPickerSection(BuildContext context, WidgetRef ref, LayerItem layer) {
    final editorState = ref.watch(editorProvider);
    final activeRow = editorState.project.rows.isNotEmpty ? editorState.project.activeRow : <String, dynamic>{};
    final gameName = (activeRow['game'] ?? 'Magic').toString();

    // Resolve current layer image file
    File? currentImgFile;
    if (layer.imagePath != null && File(layer.imagePath!).existsSync()) {
      currentImgFile = File(layer.imagePath!);
    } else if (layer.bindingKey.isNotEmpty && activeRow.containsKey(layer.bindingKey)) {
      final bindingVal = activeRow[layer.bindingKey]?.toString();
      currentImgFile = GameFolderService.resolveCardImageFile(gameName, bindingVal);
    }

    final availableAssets = GameFolderService.listGameAssetImages(gameName);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121524),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.photo_library_outlined, size: 15, color: GrimoireTheme.accentPurple),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layer.type == LayerType.background ? 'ARTE DE FONDO' : 'ARTE DE LA CAPA',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'games/$gameName/assets/',
                      style: const TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (currentImgFile != null)
                Tooltip(
                  message: 'Quitar imagen de esta capa',
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    icon: const Icon(Icons.clear, size: 16, color: Colors.redAccent),
                    onPressed: () {
                      ref.read(editorProvider.notifier).removeAssetFromLayer(layer.id);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Drag & Drop Target Dropzone / Current Asset Preview
          DragTarget<String>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) {
              final assetRelativePath = details.data;
              ref.read(editorProvider.notifier).assignAssetToLayer(layer.id, assetRelativePath);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: GrimoireTheme.accentEmerald,
                  duration: const Duration(milliseconds: 1400),
                  content: Text('Asset asignado a "${layer.name}": ${assetRelativePath.split('/').last}'),
                ),
              );
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered = candidateData.isNotEmpty;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isHovered
                      ? GrimoireTheme.accentEmerald.withValues(alpha: 0.15)
                      : const Color(0xFF0C0E1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isHovered
                        ? GrimoireTheme.accentEmerald
                        : (currentImgFile != null ? GrimoireTheme.accentPurple.withValues(alpha: 0.4) : Colors.white12),
                    width: isHovered ? 2.0 : 1.0,
                  ),
                ),
                child: currentImgFile != null
                    ? Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              currentImgFile,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentImgFile.uri.pathSegments.last,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '✓ Asignada • Arrastra otra imagen para reemplazar',
                                  style: TextStyle(fontSize: 9, color: GrimoireTheme.accentEmerald),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isHovered ? Icons.file_download_done : Icons.add_photo_alternate_outlined,
                            size: 28,
                            color: isHovered ? GrimoireTheme.accentEmerald : GrimoireTheme.textMuted,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isHovered ? '¡Suelta para asignar aquí!' : 'Sin imagen asignada',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isHovered ? GrimoireTheme.accentEmerald : Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Arrastra un asset aquí o elígelo abajo',
                            style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted),
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Action 1: "Escoger desde Assets" (Modal with Grid)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                foregroundColor: Colors.white,
                side: const BorderSide(color: GrimoireTheme.accentPurple),
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.collections_outlined, size: 15, color: GrimoireTheme.accentPurple),
              label: Text(
                'Escoger desde Assets (${availableAssets.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                _showAssetPickerModal(context, ref, gameName, layer);
              },
            ),
          ),
          const SizedBox(height: 6),

          // Action 2 & 3: "Subir Imagen desde PC" & "Quitar Fondo"
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GrimoireTheme.borderSubtle),
                    foregroundColor: const Color(0xFFE2E8F0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.upload_file, size: 14),
                  label: const Text('Subir Imagen', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final files = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
                    );
                    if (files.isNotEmpty && files.first.path != null) {
                      final relPath = await ref.read(editorProvider.notifier).uploadImageToGameAssets(files.first.path!);
                      if (context.mounted && relPath != null) {
                        ref.read(editorProvider.notifier).assignAssetToLayer(layer.id, relPath);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: GrimoireTheme.accentEmerald,
                            content: Text('Imagen guardada y asignada a la capa: ${relPath.split('/').last}'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              if (currentImgFile != null && currentImgFile.existsSync()) ...[
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    foregroundColor: const Color(0xFFA5B4FC),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.auto_fix_high, size: 14),
                  label: const Text('Sin Fondo', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    BackgroundRemovalDialog.show(
                      context,
                      sourceImageFile: currentImgFile!,
                      gameName: gameName,
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAssetPickerModal(BuildContext context, WidgetRef ref, String gameName, LayerItem layer) {
    final assets = GameFolderService.listGameAssetImages(gameName);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: GrimoireTheme.surfacePanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        child: Container(
          width: 520,
          height: 480,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.collections_outlined, color: GrimoireTheme.accentPurple, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Seleccionar Asset para "${layer.name}"',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Haz clic en cualquier imagen de games/$gameName/assets/ para asignarla directamente a esta capa.',
                style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: assets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_not_supported_outlined, size: 40, color: GrimoireTheme.textMuted),
                            const SizedBox(height: 10),
                            const Text('No hay assets de imagen en este juego.', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
                              icon: const Icon(Icons.upload_file, size: 16),
                              label: const Text('Subir Imagen desde PC'),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final files = await FilePicker.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
                                );
                                if (files.isNotEmpty && files.first.path != null) {
                                  final relPath = await ref.read(editorProvider.notifier).uploadImageToGameAssets(files.first.path!);
                                  if (relPath != null) {
                                    ref.read(editorProvider.notifier).assignAssetToLayer(layer.id, relPath);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: assets.length,
                        itemBuilder: (c, idx) {
                          final file = assets[idx];
                          final fileName = file.uri.pathSegments.last;
                          final relUrl = 'assets/$fileName';
                          final isCurrent = layer.imagePath != null &&
                              (layer.imagePath == file.path || layer.imagePath!.endsWith(fileName));

                          return InkWell(
                            onTap: () {
                              ref.read(editorProvider.notifier).assignAssetToLayer(layer.id, relUrl);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: GrimoireTheme.accentEmerald,
                                  duration: const Duration(milliseconds: 1400),
                                  content: Text('Asset asignado a "${layer.name}": $fileName'),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF141728),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCurrent ? GrimoireTheme.accentEmerald : GrimoireTheme.borderSubtle,
                                  width: isCurrent ? 2.5 : 1.0,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(file, fit: BoxFit.cover),
                                  if (isCurrent)
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: GrimoireTheme.accentEmerald,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('ACTUAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                      color: Colors.black87,
                                      child: Text(
                                        fileName,
                                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalImageAssetsSection(BuildContext context, WidgetRef ref, EditorState state, LayerItem? layer) {
    final activeRow = state.project.activeRow;
    final gameName = (activeRow['game'] ?? 'Magic').toString();
    final cardName = (activeRow['card_name'] ?? 'Carta').toString();
    final artUrl = activeRow['art_url']?.toString() ?? '';
    final artFile = GameFolderService.resolveCardImageFile(gameName, artUrl);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121524),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library_outlined, size: 16, color: GrimoireTheme.accentPurple),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ref.tr('image_assets_section')} • $cardName',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'games/$gameName/assets/',
                      style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Current image status & preview
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0D17),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2337),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: artFile != null && artFile.existsSync()
                      ? Image.file(artFile, fit: BoxFit.cover)
                      : Center(
                          child: Text(activeRow['icon']?.toString() ?? '🖼️', style: const TextStyle(fontSize: 24)),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artUrl.isNotEmpty ? artUrl : ref.tr('no_local_asset'),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: artFile != null ? const Color(0xFFA7F3D0) : GrimoireTheme.textMuted,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artFile != null ? '✓ Guardada en assets/' : 'Sin archivo local',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: artFile != null ? GrimoireTheme.accentEmerald : GrimoireTheme.accentAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Button 1: Subir Imagen desde PC
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GrimoireTheme.accentEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.upload_file, size: 16),
              label: Text(
                ref.tr('upload_local_image'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final files = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
                );
                if (files.isNotEmpty) {
                  final paths = files.map((f) => f.path).whereType<String>().toList();
                  if (paths.isNotEmpty) {
                    final uploaded = await ref.read(editorProvider.notifier).uploadMultipleImagesToGameAssets(paths);
                    if (context.mounted && uploaded.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: GrimoireTheme.accentEmerald,
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            uploaded.length == 1
                                ? 'Imagen guardada con éxito en games/$gameName/${uploaded.first}'
                                : '${uploaded.length} imágenes guardadas con éxito en assets de $gameName',
                          ),
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ),

          // Button: Quitar Fondo (Transparencia)
          if (artFile != null && artFile.existsSync()) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4338CA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.auto_fix_high, size: 15),
                label: const Text(
                  'Quitar Fondo (Transparencia)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  BackgroundRemovalDialog.show(
                    context,
                    sourceImageFile: artFile,
                    gameName: gameName,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 6),

          // Button 2 & 3: Explorar assets / Abrir en Explorer
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.5)),
                    backgroundColor: const Color(0xFF16182E),
                    foregroundColor: const Color(0xFFE0E7FF),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 13, color: GrimoireTheme.accentIndigo),
                  label: Text(
                    ref.tr('browse_game_assets'),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _showAssetsGalleryDialog(context, ref, gameName),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF16182E),
                  side: const BorderSide(color: GrimoireTheme.borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                tooltip: ref.tr('open_assets_folder'),
                icon: const Icon(Icons.folder_open, size: 16, color: GrimoireTheme.accentEmerald),
                onPressed: () async {
                  final opened = await GameFolderService.openGameAssetsFolderInExplorer(gameName);
                  if (context.mounted && opened) {
                    final p = GameFolderService.getGameAssetsDir(gameName).absolute.path.replaceAll('/', '\\');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Carpeta abierta: $p'),
                        duration: const Duration(seconds: 3),
                        backgroundColor: const Color(0xFF16182E),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAssetsGalleryDialog(BuildContext context, WidgetRef ref, String gameName) {
    final assetImages = GameFolderService.listGameAssetImages(gameName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfacePanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.photo_library_outlined, color: GrimoireTheme.accentPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assets de "$gameName"',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'games/$gameName/assets/ (${assetImages.length} imágenes)',
                    style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 380,
          child: assetImages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 40, color: GrimoireTheme.textMuted),
                      SizedBox(height: 12),
                      Text(
                        'No hay imágenes guardadas en la carpeta assets/.',
                        style: TextStyle(color: GrimoireTheme.textSecondary, fontSize: 13),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Usa el botón "Subir Imagen desde PC" para importar imágenes.',
                        style: TextStyle(color: GrimoireTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: assetImages.length,
                  itemBuilder: (context, idx) {
                    final imgFile = assetImages[idx];
                    final fileName = imgFile.uri.pathSegments.last;
                    final relativePath = 'assets/$fileName';

                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        ref.read(editorProvider.notifier).assignAssetToActiveCard(relativePath);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: GrimoireTheme.accentEmerald,
                            content: Text('Imagen "$fileName" vinculada a la carta.'),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F111D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: GrimoireTheme.borderSubtle),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Image.file(
                                    imgFile,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Icon(Icons.broken_image, color: GrimoireTheme.textMuted),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  color: const Color(0xFF141726),
                                  child: Text(
                                    fileName,
                                    style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    BackgroundRemovalDialog.show(
                                      context,
                                      sourceImageFile: imgFile,
                                      gameName: gameName,
                                    );
                                  },
                                  child: const Tooltip(
                                    message: 'Quitar fondo a esta imagen',
                                    child: Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.auto_fix_high, size: 14, color: GrimoireTheme.accentIndigo),
                                    ),
                                  ),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GrimoireTheme.accentPurple,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.folder_open, size: 16),
            label: Text(ref.tr('open_assets_folder')),
            onPressed: () async {
              final opened = await GameFolderService.openGameAssetsFolderInExplorer(gameName);
              if (ctx.mounted && opened) {
                final p = GameFolderService.getGameAssetsDir(gameName).absolute.path.replaceAll('/', '\\');
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Carpeta abierta: $p'),
                    duration: const Duration(seconds: 3),
                    backgroundColor: const Color(0xFF16182E),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: GrimoireTheme.accentPurple,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildNumberInput(String label, double value, ValueChanged<double> onChanged, {String? keyPrefix}) {
    return TextFormField(
      key: ValueKey('${keyPrefix ?? ''}_$label'),
      initialValue: value.toStringAsFixed(1),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      onChanged: (str) {
        final parsed = double.tryParse(str);
        if (parsed != null) onChanged(parsed);
      },
    );
  }

  // --- Corner Radius Selector with Slider & TCG Presets ---
  Widget _buildCornerRadiusSelector(
    BuildContext context,
    WidgetRef ref, {
    required double currentRadius,
    required ValueChanged<double> onChanged,
  }) {
    final presets = [0.0, 8.0, 12.0, 16.0, 24.0, 32.0];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rounded_corner, size: 14, color: GrimoireTheme.accentPurple),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ref.tr('border_radius'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${currentRadius.toStringAsFixed(1)} px',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE9D5FF), fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: GrimoireTheme.accentPurple,
              inactiveTrackColor: const Color(0xFF222638),
              thumbColor: GrimoireTheme.accentPurple,
              overlayColor: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: currentRadius.clamp(0.0, 48.0),
              min: 0.0,
              max: 48.0,
              onChanged: (val) => onChanged(double.parse(val.toStringAsFixed(1))),
            ),
          ),

          // Quick Presets
          Text(
            ref.tr('corner_radius_presets'),
            style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: presets.map((p) {
              final isSelected = (currentRadius - p).abs() < 0.5;
              String label = '${p.toInt()} px';
              if (p == 0) label = '0 (Recto)';
              if (p == 12) label = '12 (TCG)';
              if (p == 16) label = '16 (Póker)';
              return InkWell(
                onTap: () => onChanged(p),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? GrimoireTheme.accentPurple.withValues(alpha: 0.35)
                        : const Color(0xFF161928),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- Color Picker with Palette Swatches, Hex Input & Opacity Slider ---
  Widget _buildColorPickerSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Color currentColor,
    required ValueChanged<Color> onChanged,
    bool allowTransparent = true,
  }) {
    final hexString = '#${currentColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final isTransparent = currentColor.a == 0;

    final palette = [
      const Color(0xFF0C0E17), // Obsidian
      const Color(0xFF131622), // Grimoire Dark Slate
      const Color(0xFF1E2337), // Midnight Navy
      const Color(0xFF2E1065), // Arcane Violet
      const Color(0xFF1E1B4B), // Mystic Indigo
      const Color(0xFF064E3B), // Abyssal Emerald
      const Color(0xFF450A0A), // Dragon Crimson
      const Color(0xFF451A03), // Ancient Amber
      const Color(0xFF18181B), // Charcoal Dark
      const Color(0xFF000000), // Pure Black
      const Color(0xFFF8FAFC), // Celestial White
      if (allowTransparent) Colors.transparent,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openColorPickerDialog(context, title, currentColor, onChanged, allowTransparent),
                borderRadius: BorderRadius.circular(6),
                child: Tooltip(
                  message: 'Abrir Selector de Color Libre (Cualquier Color)',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141728),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: GrimoireTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: currentColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: isTransparent
                              ? const Icon(Icons.block, size: 12, color: Colors.redAccent)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hexString,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC7D2FE),
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.colorize, size: 12, color: GrimoireTheme.accentPurple),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Palette Swatches
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...palette.map((col) {
                final isSelected = col.toARGB32() == currentColor.toARGB32();
                final isTrans = col.a == 0;

                return InkWell(
                  onTap: () => onChanged(col),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? GrimoireTheme.accentPurple
                            : Colors.white.withValues(alpha: 0.2),
                        width: isSelected ? 2.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: GrimoireTheme.accentPurple.withValues(alpha: 0.5),
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                    child: isTrans
                        ? const Icon(Icons.block, size: 14, color: Colors.redAccent)
                        : isSelected
                            ? Icon(
                                Icons.check,
                                size: 14,
                                color: ThemeData.estimateBrightnessForColor(col) == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              )
                            : null,
                  ),
                );
              }),
              // Free Color Picker Rainbow Button
              Tooltip(
                message: 'Abrir Selector de Color Libre (Cualquier Color)',
                child: InkWell(
                  onTap: () => _openColorPickerDialog(context, title, currentColor, onChanged, allowTransparent),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: GrimoireTheme.accentPurple,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.palette_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hex input row + Color Picker trigger + opacity slider
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  key: ValueKey('hex_${currentColor.toARGB32()}'),
                  initialValue: hexString,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: ref.tr('custom_hex'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    suffixIcon: IconButton(
                      tooltip: 'Abrir Selector de Color Libre',
                      icon: const Icon(Icons.palette_outlined, size: 16, color: GrimoireTheme.accentPurple),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () => _openColorPickerDialog(context, title, currentColor, onChanged, allowTransparent),
                    ),
                  ),
                  onFieldSubmitted: (val) {
                    final parsed = _tryParseHexColor(val);
                    if (parsed != null) onChanged(parsed);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ref.tr('opacity'), style: const TextStyle(fontSize: 9, color: GrimoireTheme.textMuted)),
                        Text('${(currentColor.a * 100).toInt()}%', style: const TextStyle(fontSize: 9, color: Colors.white, fontFamily: 'monospace')),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: GrimoireTheme.accentPurple,
                        inactiveTrackColor: const Color(0xFF222638),
                        thumbColor: GrimoireTheme.accentPurple,
                        overlayColor: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      ),
                      child: Slider(
                        value: currentColor.a,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          onChanged(currentColor.withValues(alpha: val));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openColorPickerDialog(
    BuildContext context,
    String title,
    Color currentColor,
    ValueChanged<Color> onChanged,
    bool allowTransparent,
  ) async {
    final picked = await GrimoireColorPickerDialog.show(
      context,
      initialColor: currentColor,
      title: title,
      allowTransparent: allowTransparent,
      onLiveChanged: (c) => onChanged(c),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  // --- Border Width Selector with Presets ---
  Widget _buildBorderWidthSelector(
    BuildContext context,
    WidgetRef ref, {
    required double currentWidth,
    required ValueChanged<double> onChanged,
  }) {
    final presets = [0.0, 1.0, 1.5, 2.0, 3.0, 4.0];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.line_weight, size: 14, color: GrimoireTheme.accentPurple),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ref.tr('border_width'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${currentWidth.toStringAsFixed(1)} px',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE9D5FF), fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: GrimoireTheme.accentPurple,
              inactiveTrackColor: const Color(0xFF222638),
              thumbColor: GrimoireTheme.accentPurple,
              overlayColor: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: currentWidth.clamp(0.0, 12.0),
              min: 0.0,
              max: 12.0,
              onChanged: (val) => onChanged(double.parse(val.toStringAsFixed(1))),
            ),
          ),

          // Presets
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: presets.map((p) {
              final isSelected = (currentWidth - p).abs() < 0.2;
              String label = '${p.toStringAsFixed(p.truncateToDouble() == p ? 0 : 1)} px';
              if (p == 0) label = '0 (Sin borde)';
              return InkWell(
                onTap: () => onChanged(p),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? GrimoireTheme.accentPurple.withValues(alpha: 0.35)
                        : const Color(0xFF161928),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color? _tryParseHexColor(String input) {
    var hex = input.trim().replaceAll('#', '').replaceAll('0x', '').replaceAll('0X', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length == 8) {
      final val = int.tryParse(hex, radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLayerIcon(LayerType type) {
    switch (type) {
      case LayerType.text:
        return Icons.title;
      case LayerType.image:
        return Icons.image_outlined;
      case LayerType.shape:
        return Icons.interests_outlined;
      case LayerType.background:
        return Icons.wallpaper_outlined;
    }
  }

  Widget _buildAlignmentToolbar(BuildContext context, WidgetRef ref, EditorState editorState) {
    final targets = editorState.selectedLayers
        .where((l) => !l.isLocked && l.type != LayerType.background)
        .toList();
    if (targets.isEmpty) return const SizedBox.shrink();

    Widget buildAlignBtn(Key key, IconData icon, String tooltip, VoidCallback? onPressed) {
      return Expanded(
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(5),
            onTap: onPressed,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: GrimoireTheme.surfaceCard,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: GrimoireTheme.borderSubtle),
              ),
              child: Icon(
                icon,
                size: 14,
                color: onPressed != null ? GrimoireTheme.textSecondary : GrimoireTheme.textMuted.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: GrimoireTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.align_horizontal_center, size: 13, color: GrimoireTheme.accentPurple),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Alineación y Distribución',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              buildAlignBtn(
                const Key('inspector_align_left'),
                Icons.align_horizontal_left,
                ref.tr('align_left'),
                () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.left),
              ),
              const SizedBox(width: 4),
              buildAlignBtn(
                const Key('inspector_align_center_h'),
                Icons.align_horizontal_center,
                ref.tr('align_center_h'),
                () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.centerHorizontal),
              ),
              const SizedBox(width: 4),
              buildAlignBtn(
                const Key('inspector_align_right'),
                Icons.align_horizontal_right,
                ref.tr('align_right'),
                () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              buildAlignBtn(
                const Key('inspector_align_top'),
                Icons.align_vertical_top,
                ref.tr('align_top'),
                () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.top),
              ),
              const SizedBox(width: 4),
              buildAlignBtn(
                const Key('inspector_align_center_v'),
                Icons.align_vertical_center,
                ref.tr('align_center_v'),
                () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.centerVertical),
              ),
              const SizedBox(width: 4),
              buildAlignBtn(
                const Key('inspector_align_bottom'),
                Icons.align_vertical_bottom,
                ref.tr('align_bottom'),
                () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.bottom),
              ),
            ],
          ),
          if (targets.length >= 3) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                buildAlignBtn(
                  const Key('inspector_distribute_h'),
                  Icons.horizontal_distribute,
                  ref.tr('distribute_h'),
                  () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.distributeHorizontal),
                ),
                const SizedBox(width: 6),
                buildAlignBtn(
                  const Key('inspector_distribute_v'),
                  Icons.vertical_distribute,
                  ref.tr('distribute_v'),
                  () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.distributeVertical),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiLayerInspector(BuildContext context, WidgetRef ref, EditorState editorState) {
    final targets = editorState.selectedLayers;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.layers, size: 16, color: GrimoireTheme.accentPurple),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${targets.length} ${ref.tr('selected_layers_count')}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Selección múltiple de capas',
                    style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: GrimoireTheme.accentPink),
              tooltip: ref.tr('delete'),
              onPressed: () => LayerDeleteDialog.show(context: context, ref: ref),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAlignmentToolbar(context, ref, editorState),
        const SizedBox(height: 12),
        _buildSectionHeader('Acciones en Lote'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('multi_layer_copy_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GrimoireTheme.accentIndigo,
                  side: BorderSide(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.copy, size: 14),
                label: Text(ref.tr('copy_layer'), style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  final count = ref.read(editorProvider.notifier).copySelectedLayers();
                  if (count > 0 && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$count ${ref.tr('selected_layers_count')} copiadas'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('multi_layer_duplicate_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GrimoireTheme.accentPurple,
                  side: BorderSide(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.copy_all_outlined, size: 14),
                label: Text(ref.tr('duplicate_layer'), style: const TextStyle(fontSize: 11)),
                onPressed: () => ref.read(editorProvider.notifier).duplicateSelectedLayers(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('Capas Incluidas'),
        const SizedBox(height: 8),
        for (final l in targets)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: GrimoireTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(_getLayerIcon(l.type), size: 14, color: GrimoireTheme.accentPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.name,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (l.isLocked)
                  const Icon(Icons.lock_outline, size: 13, color: GrimoireTheme.accentAmber),
              ],
            ),
          ),
      ],
    );
  }
}

class _MiniShapePreviewPainter extends CustomPainter {
  final ShapePreset preset;
  final Color color;

  const _MiniShapePreviewPainter({
    required this.preset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = ShapePathBuilder.buildPath(
      preset: preset,
      size: size,
      borderRadius: preset == ShapePreset.rectangle ? 2.5 : 0.0,
      customPoints: preset == ShapePreset.custom
          ? const [
              Offset(0.5, 0.05),
              Offset(0.95, 0.35),
              Offset(0.80, 0.95),
              Offset(0.20, 0.95),
              Offset(0.05, 0.35),
            ]
          : const [],
    );

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniShapePreviewPainter oldDelegate) {
    return oldDelegate.preset != preset || oldDelegate.color != color;
  }
}

class AssetInspectorWidget extends ConsumerStatefulWidget {
  final String assetPath;
  final String gameName;

  const AssetInspectorWidget({
    super.key,
    required this.assetPath,
    required this.gameName,
  });

  @override
  ConsumerState<AssetInspectorWidget> createState() => _AssetInspectorWidgetState();
}

class _AssetInspectorWidgetState extends ConsumerState<AssetInspectorWidget> {
  late TextEditingController _nameController;
  String? _imageDimensions;

  @override
  void initState() {
    super.initState();
    _initController();
    _loadImageDimensions();
  }

  void _initController() {
    final fileName = widget.assetPath.split(RegExp(r'[\\/]')).last;
    final baseName = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
    _nameController = TextEditingController(text: baseName);
  }

  @override
  void didUpdateWidget(covariant AssetInspectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath || oldWidget.gameName != widget.gameName) {
      _initController();
      _loadImageDimensions();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadImageDimensions() async {
    final file = GameFolderService.resolveCardImageFile(widget.gameName, widget.assetPath);
    if (file == null || !file.existsSync()) return;
    try {
      final bytes = await file.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      if (mounted) {
        setState(() {
          _imageDimensions = '${decoded.width} × ${decoded.height} px';
        });
      }
    } catch (_) {}
  }

  void _handleRename(File currentFile, String oldFileName, String ext) {
    final newBase = _nameController.text.trim();
    if (newBase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del asset no puede estar vacío.')),
      );
      return;
    }

    final newFileName = ext.isNotEmpty ? '$newBase.$ext' : newBase;
    if (newFileName == oldFileName) return;

    final success = ref.read(editorProvider.notifier).renameAsset(
          gameName: widget.gameName,
          oldFileName: oldFileName,
          newFileName: newFileName,
        );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GrimoireTheme.accentEmerald,
          content: Text('Asset renombrado a "$newFileName".'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error: ya existe un archivo con ese nombre o el nombre contiene caracteres inválidos.'),
        ),
      );
    }
  }

  void _confirmDelete(String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrimoireTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: GrimoireTheme.borderSubtle),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text(ref.tr('delete_asset_confirm'), style: const TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
        content: Text(
          ref.tr('delete_asset_desc'),
          style: const TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final deleted = GameFolderService.deleteGameAsset(widget.gameName, fileName);
              if (deleted) {
                ref.read(editorProvider.notifier).selectAsset(null);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: GrimoireTheme.accentEmerald,
                    content: Text('Asset "$fileName" eliminado.'),
                  ),
                );
              }
            },
            child: Text(ref.tr('delete')),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131728),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: GrimoireTheme.accentPurple),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 8.5, color: GrimoireTheme.textMuted, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assetFile = GameFolderService.resolveCardImageFile(widget.gameName, widget.assetPath);
    if (assetFile == null || !assetFile.existsSync()) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_outlined, size: 40, color: GrimoireTheme.textMuted),
            const SizedBox(height: 12),
            const Text('Asset no encontrado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(widget.assetPath, style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.read(editorProvider.notifier).selectAsset(null),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }

    final fileName = assetFile.uri.pathSegments.last;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final bytesLength = assetFile.lengthSync();
    final sizeStr = bytesLength < 1024 * 1024
        ? '${(bytesLength / 1024).toStringAsFixed(1)} KB'
        : '${(bytesLength / (1024 * 1024)).toStringAsFixed(2)} MB';
    final currentSubfolder = GameFolderService.getAssetSubfolder(widget.gameName, assetFile);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF141727),
            border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.tune, color: GrimoireTheme.accentPurple, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Especificaciones del Asset',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: GrimoireTheme.textMuted),
                tooltip: 'Cerrar especificaciones',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => ref.read(editorProvider.notifier).selectAsset(null),
              ),
            ],
          ),
        ),

        // Preview Box
        Container(
          height: 180,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF111422),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: TransparencyCheckerboardPainter(squareSize: 8)),
              Center(
                child: Image.file(
                  assetFile,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 36, color: GrimoireTheme.textMuted),
                ),
              ),
            ],
          ),
        ),

        // Specs Pills
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildSpecChip(
                  icon: Icons.aspect_ratio,
                  label: 'Resolución',
                  value: _imageDimensions ?? '...',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSpecChip(
                  icon: Icons.data_usage,
                  label: 'Tamaño',
                  value: sizeStr,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSpecChip(
                  icon: Icons.image_outlined,
                  label: 'Formato',
                  value: ext.toUpperCase(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Carpeta & Mover
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF151829),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(
                currentSubfolder != null ? Icons.folder : Icons.folder_special_outlined,
                size: 16,
                color: currentSubfolder != null ? GrimoireTheme.accentPurple : GrimoireTheme.accentEmerald,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Carpeta de Destino',
                      style: TextStyle(fontSize: 9, color: GrimoireTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      currentSubfolder ?? 'Raíz (assets/)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: GrimoireTheme.accentPurple,
                  side: const BorderSide(color: GrimoireTheme.accentPurple),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.drive_file_move_outlined, size: 12),
                label: const Text('Mover...', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await AssetFolderDialogs.showMoveAssetDialog(
                    context: context,
                    ref: ref,
                    gameName: widget.gameName,
                    assetFile: assetFile,
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 1. Cambiar Nombre
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF151829),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.drive_file_rename_outline, size: 13, color: Color(0xFF93C5FD)),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Cambiar Nombre',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          suffixText: ext.isNotEmpty ? '.$ext' : null,
                          suffixStyle: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                        ),
                        onSubmitted: (_) => _handleRename(assetFile, fileName, ext),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GrimoireTheme.accentPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _handleRename(assetFile, fileName, ext),
                      child: const Text('Guardar', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 2. Herramientas de Edición: Quitar Fondo & Dividir
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF151829),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_fix_high, size: 13, color: GrimoireTheme.accentEmerald),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Herramientas de Edición',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Quitar Fondo
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: GrimoireTheme.accentEmerald,
                  side: const BorderSide(color: GrimoireTheme.accentEmerald),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  minimumSize: const Size.fromHeight(34),
                ),
                onPressed: () async {
                  final transparentFile = await BackgroundRemovalDialog.show(
                    context,
                    sourceImageFile: assetFile,
                    gameName: widget.gameName,
                  );
                  if (transparentFile != null) {
                    ref.read(editorProvider.notifier).selectAsset('assets/${transparentFile.uri.pathSegments.last}');
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_fix_high, size: 14),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Quitar Fondo (Transparencia Alfa)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Dividir en Sprites
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC084FC),
                  side: const BorderSide(color: Color(0xFFC084FC)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  minimumSize: const Size.fromHeight(34),
                ),
                onPressed: () async {
                  await SpriteSheetSplitterDialog.show(
                    context,
                    gameName: widget.gameName,
                    initialFile: assetFile,
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_goldenratio, size: 14),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Dividir en Sprites...',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 3. Guía de Arrastre
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: GrimoireTheme.accentIndigo.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: GrimoireTheme.accentIndigo.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.touch_app, size: 15, color: Color(0xFF818CF8)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Para usar este asset en tu carta, arrástralo hacia el lienzo o hacia cualquier capa en el panel izquierdo.',
                  style: TextStyle(fontSize: 10, color: Color(0xFFC7D2FE), height: 1.3),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 4. Eliminar Asset
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              minimumSize: const Size.fromHeight(32),
            ),
            onPressed: () => _confirmDelete(fileName),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, size: 13),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Eliminar de Assets',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

