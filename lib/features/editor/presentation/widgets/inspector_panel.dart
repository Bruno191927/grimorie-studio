import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/layer_item.dart';
import '../../models/game_category.dart';
import '../../services/game_folder_service.dart';
import '../providers/editor_provider.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import 'package:grimoire_studio/features/ai_generator/presentation/widgets/ai_prompt_dialog.dart';

class InspectorPanel extends ConsumerWidget {
  const InspectorPanel({super.key});

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
      child: selectedLayer == null
          ? _buildProjectSettings(context, ref, editorState)
          : _buildLayerInspector(context, ref, selectedLayer),
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
        _buildInfoRow(ref.tr('card_size'), '${project.widthMm.toStringAsFixed(1)} x ${project.heightMm.toStringAsFixed(1)} mm (Poker)'),
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
                .where((l) => l.name.toLowerCase().contains('background'))
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
                .where((l) => l.name.toLowerCase().contains('background'))
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
        ],
      ),
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
              child: Text(
                layer.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: GrimoireTheme.accentPink),
              tooltip: ref.tr('delete_layer'),
              onPressed: () {
                ref.read(editorProvider.notifier).removeLayer(layer.id);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Geometry Section
        _buildSectionHeader(ref.tr('transform_geometry')),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildNumberInput('X', layer.x, (val) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(x: val));
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumberInput('Y', layer.y, (val) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(y: val));
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildNumberInput(ref.tr('width'), layer.width, (val) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(width: val));
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumberInput(ref.tr('height'), layer.height, (val) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(height: val));
              }),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _buildSectionHeader(ref.tr('databinding_token')),
        const SizedBox(height: 8),
        TextFormField(
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

        // Type-Specific Properties
        if (layer.type == LayerType.text) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(ref.tr('typography_style')),
          const SizedBox(height: 8),
          TextFormField(
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNumberInput(ref.tr('font_size'), layer.fontSize, (val) {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(fontSize: val));
                }),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.format_bold,
                  color: layer.isBold ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                ),
                onPressed: () {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(isBold: !layer.isBold));
                },
              ),
            ],
          ),
        ],

        if (layer.type == LayerType.shape) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(ref.tr('shape_border_appearance')),
          const SizedBox(height: 10),

          // 1. Color de Fondo (Background Fill Color)
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

          // 2. Radio de los Bordes (Corner Radius)
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

          // 3. Color de Borde (Border Color)
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

          // 4. Grosor de Borde (Border Width)
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

        // Local Image Upload & Asset Management
        const SizedBox(height: 16),
        _buildLocalImageAssetsSection(context, ref, ref.watch(editorProvider), layer),

        // AI Art Generation Trigger (as required by AGENT.MD Section 3.B)
        const SizedBox(height: 20),
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
                if (files.isNotEmpty && files.first.path != null) {
                  final sourcePath = files.first.path!;
                  final savedRelPath = await ref.read(editorProvider.notifier).uploadImageForActiveCard(sourcePath);
                  if (context.mounted && savedRelPath != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: GrimoireTheme.accentEmerald,
                        content: Text('Imagen guardada con éxito en games/$gameName/$savedRelPath'),
                      ),
                    );
                  }
                }
              },
            ),
          ),
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
                onPressed: () => GameFolderService.openGameFolderInExplorer(gameName),
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
                        child: Column(
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
            onPressed: () => GameFolderService.openGameFolderInExplorer(gameName),
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
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                ),
                child: isTransparent
                    ? const Icon(Icons.block, size: 12, color: Colors.redAccent)
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                hexString,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC7D2FE), fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Palette Swatches
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: palette.map((col) {
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
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Hex input row + opacity slider
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
}
