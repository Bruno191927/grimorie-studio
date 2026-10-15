import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../editor/presentation/providers/editor_provider.dart';
import '../../services/ai_service.dart';

class AiPromptDialog extends ConsumerStatefulWidget {
  final String layerId;

  const AiPromptDialog({super.key, required this.layerId});

  @override
  ConsumerState<AiPromptDialog> createState() => _AiPromptDialogState();
}

class _AiPromptDialogState extends ConsumerState<AiPromptDialog> {
  late TextEditingController _promptController;
  AiProviderType _selectedProvider = AiProviderType.comfyUiLocal;
  bool _isLoading = false;
  String? _statusMessage;
  final AiService _aiService = AiService();

  @override
  void initState() {
    super.initState();
    final editorState = ref.read(editorProvider);
    final activeRow = editorState.project.activeRow;
    final defaultPrompt = activeRow['prompt']?.toString() ??
        'Chibi 3D stylized tabletop creature, vibrant octane render, card illustration';
    _promptController = TextEditingController(text: defaultPrompt);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to ${_getProviderName(_selectedProvider)}...';
    });

    final result = await _aiService.generateArtwork(
      prompt: _promptController.text.trim(),
      provider: _selectedProvider,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        // Update layer with image path
        final editorState = ref.read(editorProvider);
        final layer = editorState.selectedLayer;
        if (layer != null) {
          ref.read(editorProvider.notifier).updateLayer(
                layer.copyWith(imagePath: result.localFilePath),
              );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GrimoireTheme.accentEmerald,
            content: Text('Artwork generated and saved to ${result.localFilePath ?? "assets/generated/"}'),
          ),
        );
        Navigator.of(context).pop();
      } else {
        setState(() {
          _statusMessage = result.errorMessage ?? 'Generation failed.';
        });
      }
    }
  }

  String _getProviderName(AiProviderType type) {
    switch (type) {
      case AiProviderType.comfyUiLocal:
        return 'Local ComfyUI (127.0.0.1:8188)';
      case AiProviderType.ollamaLocal:
        return 'Local Ollama / LM Studio (127.0.0.1:11434)';
      case AiProviderType.cloudApi:
        return 'Cloud API (SDXL / Flux)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  child: const Icon(Icons.auto_awesome, color: GrimoireTheme.accentPurple, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AI Artwork Generator',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Provider Selector
            const Text(
              'Select AI Generation Engine:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GrimoireTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<AiProviderType>(
              initialValue: _selectedProvider,
              dropdownColor: GrimoireTheme.surfacePanel,
              style: const TextStyle(fontSize: 12, color: Colors.white),
              decoration: const InputDecoration(isDense: true),
              items: AiProviderType.values.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(_getProviderName(p)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedProvider = val);
              },
            ),
            const SizedBox(height: 14),

            // Prompt text field
            const Text(
              'Art Prompt Description:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GrimoireTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _promptController,
              maxLines: 3,
              style: const TextStyle(fontSize: 12, color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter detailed prompt or {{variables}}...',
              ),
            ),
            const SizedBox(height: 12),

            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(fontSize: 11, color: GrimoireTheme.accentAmber),
                ),
              ),

            // Dialog actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: GrimoireTheme.textMuted)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GrimoireTheme.accentPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.bolt, size: 16),
                  label: Text(_isLoading ? 'Generating...' : 'Generate & Bind'),
                  onPressed: _isLoading ? null : _handleGenerate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
