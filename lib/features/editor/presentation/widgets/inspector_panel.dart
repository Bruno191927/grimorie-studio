import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/layer_item.dart';
import '../providers/editor_provider.dart';
import '../../../../core/theme/grimoire_theme.dart';
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
          const Text(
            'Project & Card Settings',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            project.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GrimoireTheme.accentPurple),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Card Size', '${project.widthMm.toStringAsFixed(1)} x ${project.heightMm.toStringAsFixed(1)} mm (Poker)'),
          _buildInfoRow('DPI Target', '300 DPI Print-Ready'),
          _buildInfoRow('Database Rows', '${project.rows.length} cards synchronized'),
          _buildInfoRow('Active Template', project.activeTemplate.name),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Select a layer on the canvas or from the layers tree to inspect its data bindings, typography, geometry and Smart Token rules.',
            style: TextStyle(fontSize: 12, color: GrimoireTheme.textMuted, height: 1.5),
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
              tooltip: 'Delete Layer',
              onPressed: () {
                ref.read(editorProvider.notifier).removeLayer(layer.id);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Geometry Section
        _buildSectionHeader('Transform & Geometry'),
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
              child: _buildNumberInput('Width', layer.width, (val) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(width: val));
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumberInput('Height', layer.height, (val) {
                ref.read(editorProvider.notifier).updateLayer(layer.copyWith(height: val));
              }),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _buildSectionHeader('Data-Binding Token'),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: layer.bindingKey,
          style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            labelText: 'Variable Binding Key',
            hintText: 'e.g. card_name, cost, attack',
            isDense: true,
          ),
          onChanged: (val) {
            ref.read(editorProvider.notifier).updateLayer(layer.copyWith(bindingKey: val.trim()));
          },
        ),

        // Type-Specific Properties
        if (layer.type == LayerType.text) ...[
          const SizedBox(height: 16),
          _buildSectionHeader('Typography & Style'),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: layer.text,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Static / Template Text',
              hintText: 'e.g. {{card_name}}',
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
                child: _buildNumberInput('Font Size', layer.fontSize, (val) {
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
          _buildSectionHeader('Shape & Border Appearance'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNumberInput('Border Radius', layer.borderRadius, (val) {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderRadius: val));
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput('Border Width', layer.borderWidth, (val) {
                  ref.read(editorProvider.notifier).updateLayer(layer.copyWith(borderWidth: val));
                }),
              ),
            ],
          ),
        ],

        // Smart Tokens / Conditional Rules Section
        const SizedBox(height: 16),
        _buildSectionHeader('Smart Tokens (Conditional Rules)'),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: layer.conditionalRules['condition']?.toString() ?? '',
          style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            labelText: 'Rule Expression',
            hintText: 'e.g. cost > 5, rarity == "Mythic"',
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
        _buildSectionHeader('Generative AI Art Integration'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: GrimoireTheme.accentPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('Generate AI Art for Layer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
