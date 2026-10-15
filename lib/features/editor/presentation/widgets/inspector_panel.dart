import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/layer_item.dart';
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref.tr('project_card_settings'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            project.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GrimoireTheme.accentPurple),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(ref.tr('card_size'), '${project.widthMm.toStringAsFixed(1)} x ${project.heightMm.toStringAsFixed(1)} mm (Poker)'),
          _buildInfoRow(ref.tr('dpi_target'), '300 DPI Print-Ready'),
          _buildInfoRow(ref.tr('database_rows'), '${project.rows.length} cards'),
          _buildInfoRow(ref.tr('active_template'), project.activeTemplate.name),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            ref.tr('select_layer_hint'),
            style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted, height: 1.5),
          ),
        ],
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNumberInput(ref.tr('border_radius'), layer.borderRadius, (val) {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderRadius: val));
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput(ref.tr('border_width'), layer.borderWidth, (val) {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderWidth: val));
                }),
              ),
            ],
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

  Widget _buildNumberInput(String label, double value, ValueChanged<double> onChanged) {
    return TextFormField(
      key: ValueKey('${label}_$value'),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
          Text(value, style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
