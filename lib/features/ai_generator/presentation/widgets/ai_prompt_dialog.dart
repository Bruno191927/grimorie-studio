import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../editor/presentation/providers/editor_provider.dart';
import '../../services/ai_service.dart';
import '../../services/comfy_ui_service.dart';
import '../providers/comfy_ui_provider.dart';
import 'comfy_ui_connection_dialog.dart';

class AiPromptDialog extends ConsumerStatefulWidget {
  final String? layerId;
  final String? gameName;

  const AiPromptDialog({super.key, this.layerId, this.gameName});

  @override
  ConsumerState<AiPromptDialog> createState() => _AiPromptDialogState();
}

class _AiPromptDialogState extends ConsumerState<AiPromptDialog> {
  late TextEditingController _promptController;
  late TextEditingController _negativePromptController;
  AiProviderType _selectedProvider = AiProviderType.comfyUiLocal;
  bool _isLoading = false;
  String? _statusMessage;
  bool _showNegativePrompt = false;
  final AiService _aiService = AiService();

  @override
  void initState() {
    super.initState();
    final editorState = ref.read(editorProvider);
    final activeRow = editorState.project.activeRow;
    final defaultPrompt = activeRow['prompt']?.toString() ??
        'Chibi 3D stylized tabletop creature, vibrant octane render, card illustration';
    _promptController = TextEditingController(text: defaultPrompt);
    _negativePromptController = TextEditingController(
      text: 'worst quality, low quality, score_1, score_2, score_3, blurry, jpeg artifacts, sepia',
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Iniciando generación con ${_getProviderName(_selectedProvider)}...';
    });

    final editorState = ref.read(editorProvider);
    final activeRow = editorState.project.activeRow;
    final game = widget.gameName ?? (activeRow['game'] ?? 'Magic').toString();

    AiGenerationResult result;

    if (_selectedProvider == AiProviderType.comfyUiLocal) {
      final comfyService = ComfyUiService();
      result = await comfyService.generateArtworkWithComfyUi(
        prompt: _promptController.text.trim(),
        negativePrompt: _negativePromptController.text.trim().isNotEmpty
            ? _negativePromptController.text.trim()
            : null,
        gameName: game,
        onProgress: (status) {
          if (mounted) setState(() => _statusMessage = status);
        },
      );
    } else {
      result = await _aiService.generateArtwork(
        prompt: _promptController.text.trim(),
        gameName: game,
        provider: _selectedProvider,
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result.success && result.localFilePath != null) {
        final fileName = File(result.localFilePath!).uri.pathSegments.last;
        final relativeUrl = 'assets/$fileName';
        await ref.read(editorProvider.notifier).assignAssetToActiveCard(relativeUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GrimoireTheme.accentEmerald,
              content: Text('Arte generado y guardado en $relativeUrl'),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = result.errorMessage ?? 'Error durante la generación.';
          });
        }
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
    final comfyState = ref.watch(comfyUiProvider);
    final activeWorkflow = comfyState.activeWorkflow;
    final serverInfo = comfyState.serverInfo;

    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.auto_awesome, color: GrimoireTheme.accentPurple, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ref.tr('ai_artwork_generator'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  if (_selectedProvider == AiProviderType.comfyUiLocal)
                    InkWell(
                      onTap: () => ComfyUiConnectionDialog.show(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: serverInfo.isOnline
                              ? const Color(0xFF064E3B)
                              : const Color(0xFF450A0A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: serverInfo.isOnline ? GrimoireTheme.accentEmerald : Colors.redAccent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: serverInfo.isOnline ? GrimoireTheme.accentEmerald : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              serverInfo.isOnline ? 'ComfyUI Conectado' : 'ComfyUI Offline',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: serverInfo.isOnline ? GrimoireTheme.accentEmerald : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Provider Selector
              Text(
                ref.tr('select_ai_engine'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GrimoireTheme.textSecondary),
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
              const SizedBox(height: 12),

              // Targeted Workflow Card for ComfyUI
              if (_selectedProvider == AiProviderType.comfyUiLocal) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121424),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.tune, size: 16, color: GrimoireTheme.accentPurple),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Workflow Vinculado:',
                                  style: TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: GrimoireTheme.accentPurple,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    activeWorkflow.name,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeWorkflow.description ?? 'Anima Base v1.0',
                              style: const TextStyle(fontSize: 10, color: GrimoireTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          foregroundColor: GrimoireTheme.accentEmerald,
                        ),
                        icon: const Icon(Icons.settings, size: 14),
                        label: const Text('Configurar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => ComfyUiConnectionDialog.show(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Prompt Text Field
              Text(
                ref.tr('art_prompt_desc'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GrimoireTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _promptController,
                maxLines: 3,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  hintText: ref.tr('enter_prompt_hint'),
                ),
              ),
              const SizedBox(height: 8),

              // Negative Prompt Toggle
              InkWell(
                onTap: () => setState(() => _showNegativePrompt = !_showNegativePrompt),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showNegativePrompt ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16,
                        color: GrimoireTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showNegativePrompt ? 'Ocultar Prompt Negativo' : 'Añadir Prompt Negativo (Opcional)',
                        style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showNegativePrompt) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: _negativePromptController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'ej. low quality, blurry, deformed...',
                    isDense: true,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Status message or progress
              if (_statusMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isLoading
                        ? GrimoireTheme.accentPurple.withValues(alpha: 0.15)
                        : Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isLoading
                          ? GrimoireTheme.accentPurple.withValues(alpha: 0.4)
                          : Colors.redAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: GrimoireTheme.accentPurple),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.info_outline, size: 16, color: Colors.redAccent),
                        ),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            color: _isLoading ? const Color(0xFFE9D5FF) : Colors.redAccent,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Dialog actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: Text(_isLoading ? ref.tr('generating') : ref.tr('generate_and_bind')),
                    onPressed: _isLoading ? null : _handleGenerate,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
