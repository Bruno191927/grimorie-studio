import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../editor/presentation/providers/editor_provider.dart';
import '../../services/ai_service.dart';
import '../../services/comfy_ui_service.dart';
import '../../services/nvidia_service.dart';
import '../providers/comfy_ui_provider.dart';
import '../providers/nvidia_provider.dart';
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
  late TextEditingController _nvidiaKeyController;
  bool _obscureNvidiaKey = true;
  bool _showApiKeyInput = false;
  bool _isEnhancingPrompt = false;
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
    _nvidiaKeyController = TextEditingController(text: NvidiaService().apiKey);

    // If ComfyUI is offline but NVIDIA key is configured, select NVIDIA automatically
    final isComfyOnline = ref.read(comfyUiProvider).serverInfo.isOnline;
    if (!isComfyOnline && NvidiaService().isConfigured) {
      _selectedProvider = AiProviderType.nvidiaCloud;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    _nvidiaKeyController.dispose();
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
    } else if (_selectedProvider == AiProviderType.nvidiaCloud) {
      final nvidiaService = NvidiaService();
      result = await nvidiaService.generateArtwork(
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
      case AiProviderType.nvidiaCloud:
        return 'NVIDIA NIM Cloud (Nemotron 3.5 / SD3)';
      case AiProviderType.ollamaLocal:
        return 'Local Ollama / LM Studio (127.0.0.1:11434)';
      case AiProviderType.cloudApi:
        return 'Cloud API (SDXL / Flux)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final comfyState = ref.watch(comfyUiProvider);
    final nvidiaState = ref.watch(nvidiaProvider);
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _selectedProvider == AiProviderType.nvidiaCloud
                              ? const Color(0xFF76B900).withValues(alpha: 0.2)
                              : GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedProvider == AiProviderType.nvidiaCloud
                                ? const Color(0xFF76B900).withValues(alpha: 0.6)
                                : GrimoireTheme.accentPurple.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(
                          _selectedProvider == AiProviderType.nvidiaCloud ? Icons.memory : Icons.auto_awesome,
                          color: _selectedProvider == AiProviderType.nvidiaCloud
                              ? const Color(0xFF76B900)
                              : GrimoireTheme.accentPurple,
                          size: 20,
                        ),
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
                    )
                  else if (_selectedProvider == AiProviderType.nvidiaCloud)
                    InkWell(
                      onTap: () => ComfyUiConnectionDialog.show(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: nvidiaState.isConfigured
                              ? const Color(0xFF064E3B)
                              : const Color(0xFF451A03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: nvidiaState.isConfigured ? GrimoireTheme.accentEmerald : const Color(0xFFF59E0B),
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
                                color: nvidiaState.isConfigured ? const Color(0xFF76B900) : const Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              nvidiaState.isConfigured ? 'NVIDIA Listo' : 'API Key Pendiente',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: nvidiaState.isConfigured ? const Color(0xFF76B900) : const Color(0xFFF59E0B),
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
                isExpanded: true,
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

              // Interactive Workflow Selector for ComfyUI
              if (_selectedProvider == AiProviderType.comfyUiLocal) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121424),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune, size: 14, color: GrimoireTheme.accentPurple),
                              SizedBox(width: 6),
                              Text(
                                'Workflow ComfyUI:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE9D5FF),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => ComfyUiConnectionDialog.show(context),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.settings, size: 12, color: GrimoireTheme.accentEmerald),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ajustes de Servidor',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: GrimoireTheme.accentEmerald,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1D33),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GrimoireTheme.borderSubtle),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: comfyState.availableWorkflows
                                          .any((w) => w.name == activeWorkflow.name)
                                      ? activeWorkflow.name
                                      : (comfyState.availableWorkflows.isNotEmpty
                                          ? comfyState.availableWorkflows.first.name
                                          : null),
                                  dropdownColor: const Color(0xFF1A1D33),
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: GrimoireTheme.accentPurple),
                                  items: comfyState.availableWorkflows.map((item) {
                                    final isImg = item.name.toLowerCase() == 'image';
                                    return DropdownMenuItem<String>(
                                      value: item.name,
                                      child: Row(
                                        children: [
                                          Icon(
                                            isImg ? Icons.auto_awesome : Icons.account_tree_outlined,
                                            size: 14,
                                            color: GrimoireTheme.accentPurple,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isImg)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('Recomendado',
                                                  style: TextStyle(fontSize: 9, color: Color(0xFFE9D5FF))),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      ref.read(comfyUiProvider.notifier).selectWorkflowByName(val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Examinar archivo de workflow (.json) desde tu PC',
                            child: IconButton(
                              icon: const Icon(Icons.folder_open, size: 18, color: GrimoireTheme.accentEmerald),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1A1D33),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: GrimoireTheme.borderSubtle),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  final res = await FilePicker.pickFiles(
                                    dialogTitle: 'Selecciona tu archivo de workflow ComfyUI (.json)',
                                    type: FileType.custom,
                                    allowedExtensions: ['json'],
                                  );
                                  if (res.isNotEmpty && res.first.path != null) {
                                    ref.read(comfyUiProvider.notifier).setCustomWorkflowPath(res.first.path!);
                                  }
                                } catch (_) {}
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        activeWorkflow.description ?? 'Workflow de generación de imagen para ComfyUI',
                        style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Interactive NVIDIA NIM Configuration Panel
              if (_selectedProvider == AiProviderType.nvidiaCloud) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101713),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF76B900).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NVIDIA Header & Status
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF76B900),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NVIDIA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Text(
                            'NVIDIA NIM & AI Foundation',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: nvidiaState.isConfigured
                                  ? const Color(0xFF064E3B)
                                  : const Color(0xFF451A03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: nvidiaState.isConfigured
                                    ? GrimoireTheme.accentEmerald
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  nvidiaState.isConfigured ? Icons.check_circle : Icons.warning_amber,
                                  size: 11,
                                  color: nvidiaState.isConfigured
                                      ? GrimoireTheme.accentEmerald
                                      : const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  nvidiaState.isConfigured
                                      ? ref.tr('nvidia_key_configured')
                                      : ref.tr('nvidia_key_missing'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: nvidiaState.isConfigured
                                        ? GrimoireTheme.accentEmerald
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // API Key Section (masked or inline editor)
                      if (!nvidiaState.isConfigured || _showApiKeyInput) ...[
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _nvidiaKeyController,
                                  obscureText: _obscureNvidiaKey,
                                  style: const TextStyle(fontSize: 11.5, color: Colors.white, fontFamily: 'monospace'),
                                  decoration: InputDecoration(
                                    hintText: 'nvapi-...',
                                    isDense: true,
                                    prefixIcon: const Icon(Icons.key, size: 14, color: Color(0xFF76B900)),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureNvidiaKey ? Icons.visibility_off : Icons.visibility,
                                        size: 14,
                                        color: GrimoireTheme.textMuted,
                                      ),
                                      onPressed: () => setState(() => _obscureNvidiaKey = !_obscureNvidiaKey),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF76B900),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.save, size: 14),
                              label: Text(
                                ref.tr('nvidia_save_key'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final key = _nvidiaKeyController.text.trim();
                                await ref.read(nvidiaProvider.notifier).saveApiKey(key);
                                if (!mounted) return;
                                setState(() => _showApiKeyInput = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: GrimoireTheme.accentEmerald,
                                    content: Text(ref.tr('nvidia_api_key_saved')),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Obtén tu clave gratuita en build.nvidia.com para Stable Diffusion 3 Medium y Llama 3.1',
                          style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.vpn_key, size: 13, color: Color(0xFF76B900)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'API Key: ${nvidiaState.maskedApiKey}',
                                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'monospace'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            TextButton.icon(
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
                              icon: const Icon(Icons.edit, size: 12, color: GrimoireTheme.accentEmerald),
                              label: const Text('Cambiar', style: TextStyle(fontSize: 10.5, color: GrimoireTheme.accentEmerald)),
                              onPressed: () {
                                _nvidiaKeyController.text = nvidiaState.apiKey;
                                setState(() => _showApiKeyInput = true);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Model and Aspect Ratio in a Row
                      Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MODELO NVIDIA:',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF151922),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: GrimoireTheme.borderSubtle),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: NvidiaService.availableImageModels.any((m) => m.id == nvidiaState.selectedModel)
                                          ? nvidiaState.selectedModel
                                          : NvidiaService.availableImageModels.first.id,
                                      dropdownColor: const Color(0xFF151922),
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF76B900)),
                                      items: NvidiaService.availableImageModels.map((m) {
                                        return DropdownMenuItem<String>(
                                          value: m.id,
                                          child: Text(
                                            m.name,
                                            style: const TextStyle(fontSize: 11.5, color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          ref.read(nvidiaProvider.notifier).setModel(val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PROPORCIÓN:',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF151922),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: GrimoireTheme.borderSubtle),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: nvidiaState.aspectRatio,
                                      dropdownColor: const Color(0xFF151922),
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF76B900)),
                                      items: NvidiaService.availableAspectRatios.map((r) {
                                        return DropdownMenuItem<String>(
                                          value: r,
                                          child: Text(
                                            r == '1:1' ? '1:1 Cuadrado' : (r == '2:3' ? '2:3 Carta' : r),
                                            style: const TextStyle(fontSize: 11.5, color: Colors.white),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          ref.read(nvidiaProvider.notifier).setAspectRatio(val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

              // Actions Row: Negative Prompt Toggle + Llama 3.1 Prompt Enhancer
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
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
                            _showNegativePrompt ? 'Ocultar Prompt Negativo' : 'Añadir Prompt Negativo',
                            style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Llama 3.1 Prompt Enhancer Button
                  InkWell(
                    onTap: _isEnhancingPrompt
                        ? null
                        : () async {
                            final current = _promptController.text.trim();
                            if (current.isEmpty) return;
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _isEnhancingPrompt = true);
                            final enhanced = await NvidiaService().enhancePromptWithLlama(basicPrompt: current);
                            if (!mounted) return;
                            setState(() => _isEnhancingPrompt = false);
                            if (enhanced != null && enhanced.isNotEmpty) {
                              _promptController.text = enhanced;
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: GrimoireTheme.accentEmerald,
                                  content: Text(ref.tr('nvidia_prompt_enhanced')),
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Configura tu API Key de NVIDIA para usar el optimizador Nemotron 3.5.'),
                                ),
                              );
                            }
                          },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF76B900).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF76B900).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isEnhancingPrompt)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF76B900)),
                            )
                          else
                            const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF76B900)),
                          const SizedBox(width: 5),
                          Text(
                            _isEnhancingPrompt ? ref.tr('nvidia_enhancing') : ref.tr('nvidia_enhance_prompt'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF76B900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(ref.tr('cancel'), style: const TextStyle(color: GrimoireTheme.textMuted)),
                  ),
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
