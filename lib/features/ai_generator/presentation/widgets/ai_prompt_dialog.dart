import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../editor/presentation/providers/editor_provider.dart';
import '../../services/ai_service.dart';
import '../../services/comfy_ui_service.dart';
import '../providers/comfy_ui_provider.dart';
import 'comfy_ui_connection_dialog.dart';
import '../../../editor/services/background_removal_service.dart';

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
  late TextEditingController _geminiKeyController;
  late TextEditingController _geminiModelController;
  final List<String> _geminiPresetModels = [
    'imagen-3.0-generate-002',
    'imagen-3.0-generate-001',
    'imagen-3.0-fast-generate-001',
  ];
  List<String> _geminiFetchedModels = [];
  bool _isFetchingGeminiModels = false;
  bool _isCustomGeminiModel = false;
  AiProviderType _selectedProvider = AiProviderType.googleGemini;
  String _selectedGeminiAspectRatio = '3:4';
  bool _isLoading = false;
  String? _statusMessage;
  bool _showNegativePrompt = false;
  bool _obscureNvidiaKey = true;
  bool _obscureGeminiKey = true;
  bool _autoRemoveBg = false;
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
    _nvidiaKeyController = TextEditingController(text: AiService.getNvidiaApiKey());
    _geminiKeyController = TextEditingController(text: AiService.getGeminiApiKey());
    final currentModel = AiService.getGeminiModel();
    _geminiModelController = TextEditingController(text: currentModel);
    _isCustomGeminiModel = !_geminiPresetModels.contains(currentModel);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    _nvidiaKeyController.dispose();
    _geminiKeyController.dispose();
    _geminiModelController.dispose();
    super.dispose();
  }

  Future<void> _fetchGeminiModels() async {
    final key = _geminiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa primero tu API Key de Google Gemini para consultar los modelos.')),
      );
      return;
    }
    setState(() => _isFetchingGeminiModels = true);
    final models = await AiService.fetchAvailableGeminiModels(apiKey: key);
    if (mounted) {
      setState(() {
        _isFetchingGeminiModels = false;
        if (models.isNotEmpty) {
          _geminiFetchedModels = models;
          if (!_geminiPresetModels.contains(_geminiModelController.text.trim()) &&
              !models.contains(_geminiModelController.text.trim())) {
            _geminiModelController.text = models.first;
            AiService.setGeminiModel(models.first);
            _isCustomGeminiModel = false;
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(models.isNotEmpty
              ? 'Se encontraron ${models.length} modelos en tu cuenta de Google AI Studio.'
              : 'No se encontraron modelos de imagen o la clave no tiene permisos.'),
        ),
      );
    }
  }

  Future<void> _handleGenerate() async {
    if (_selectedProvider == AiProviderType.googleGemini) {
      AiService.setGeminiApiKey(_geminiKeyController.text.trim());
      AiService.setGeminiModel(_geminiModelController.text.trim());
    } else if (_selectedProvider == AiProviderType.nvidiaFluxKlein) {
      AiService.setNvidiaApiKey(_nvidiaKeyController.text.trim());
    }

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
        aspectRatio: _selectedGeminiAspectRatio,
        geminiModel: _geminiModelController.text.trim(),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result.success && result.localFilePath != null) {
        String finalPath = result.localFilePath!;

        if (_autoRemoveBg) {
          if (mounted) {
            setState(() {
              _statusMessage = 'Quitando fondo con transparencia alfa...';
            });
          }
          try {
            final processedFile = await BackgroundRemovalService.removeBackgroundFromFile(
              File(finalPath),
            );
            finalPath = processedFile.path;
          } catch (e) {
            debugPrint('Error quitando fondo automáticamente: $e');
          }
        }

        final fileName = File(finalPath).uri.pathSegments.last;
        final relativeUrl = 'assets/$fileName';
        // The generated image is saved in the game's assets bank and is NOT forced onto any element.
        // The user can drag and drop it onto Background/Image layers or choose it from the inspector.

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GrimoireTheme.accentEmerald,
              content: Text(_autoRemoveBg
                  ? 'Arte generado y guardado en $relativeUrl con fondo transparente.'
                  : 'Arte guardado en $relativeUrl. Listo para arrastrar a Fondo o Imagen.'),
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
      case AiProviderType.googleGemini:
        return 'Google Gemini (Imagen 3 • Google AI Studio)';
      case AiProviderType.nvidiaFluxKlein:
        return 'NVIDIA NIM (BFL FLUX.1 [klein] 1024×1024)';
      case AiProviderType.comfyUiLocal:
        return 'Local ComfyUI (127.0.0.1:8188)';
      case AiProviderType.pollinationsCloud:
        return 'Nube Gratuita (Pollinations.ai - Sin API Key)';
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
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: GrimoireTheme.accentPurple.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: GrimoireTheme.accentPurple,
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
              if (_selectedProvider == AiProviderType.googleGemini) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2640),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4285F4).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF60A5FA)),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Google Gemini • Imagen 3 (imagen-3.0-generate-002)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tu Google Gemini API Key (se guarda localmente):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF93C5FD)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _geminiKeyController,
                        obscureText: _obscureGeminiKey,
                        style: const TextStyle(fontSize: 11.5, color: Colors.white, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'AIzaSy...',
                          hintStyle: const TextStyle(color: GrimoireTheme.textMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureGeminiKey ? Icons.visibility_off : Icons.visibility,
                              size: 16,
                              color: GrimoireTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureGeminiKey = !_obscureGeminiKey),
                          ),
                        ),
                        onChanged: (val) {
                          AiService.setGeminiApiKey(val.trim());
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 13, color: Color(0xFF93C5FD)),
                          const SizedBox(width: 5),
                          const Text(
                            'Modelo de Imagen (Gemini / Imagen 3):',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF93C5FD)),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: _isFetchingGeminiModels ? null : _fetchGeminiModels,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isFetchingGeminiModels)
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF93C5FD)),
                                    )
                                  else
                                    const Icon(Icons.sync, size: 12, color: Color(0xFF93C5FD)),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Consultar Modelos',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF93C5FD),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131728),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GrimoireTheme.borderSubtle),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _isCustomGeminiModel
                                ? '__custom__'
                                : ({..._geminiPresetModels, ..._geminiFetchedModels}.contains(_geminiModelController.text.trim())
                                    ? _geminiModelController.text.trim()
                                    : '__custom__'),
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E2640),
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                            items: [
                              ...{..._geminiPresetModels, ..._geminiFetchedModels}.map((m) {
                                String label = m;
                                if (m == 'imagen-3.0-generate-002') {
                                  label = '$m (Recomendado • Alta Calidad)';
                                } else if (m == 'imagen-3.0-generate-001') {
                                  label = '$m (Imagen 3 v1)';
                                } else if (m == 'imagen-3.0-fast-generate-001') {
                                  label = '$m (Fast Generate)';
                                }
                                return DropdownMenuItem(value: m, child: Text(label));
                              }),
                              const DropdownMenuItem(
                                value: '__custom__',
                                child: Text('Personalizado (Escribir ID manualmente)...'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              if (v == '__custom__') {
                                setState(() => _isCustomGeminiModel = true);
                              } else {
                                setState(() {
                                  _isCustomGeminiModel = false;
                                  _geminiModelController.text = v;
                                });
                                AiService.setGeminiModel(v);
                              }
                            },
                          ),
                        ),
                      ),
                      if (_isCustomGeminiModel) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: _geminiModelController,
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: 'Ej: imagen-3.0-generate-002',
                            hintStyle: TextStyle(color: GrimoireTheme.textMuted),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            prefixIcon: Icon(Icons.edit, size: 14, color: Color(0xFF93C5FD)),
                          ),
                          onChanged: (val) => AiService.setGeminiModel(val.trim()),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            'Proporción (Aspect Ratio):',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: GrimoireTheme.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131728),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: GrimoireTheme.borderSubtle),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedGeminiAspectRatio,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1E2640),
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                  items: const [
                                    DropdownMenuItem(value: '3:4', child: Text('3:4 • Carta Vertical (Estándar TCG)')),
                                    DropdownMenuItem(value: '1:1', child: Text('1:1 • Cuadrado (Iconos / Retratos)')),
                                    DropdownMenuItem(value: '4:3', child: Text('4:3 • Horizontal Clásico')),
                                    DropdownMenuItem(value: '9:16', child: Text('9:16 • Vertical Panorámico')),
                                    DropdownMenuItem(value: '16:9', child: Text('16:9 • Panorámico')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedGeminiAspectRatio = v);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '💡 Clave obtenible gratis en Google AI Studio (aistudio.google.com). El arte se guarda automáticamente en la carpeta assets.',
                        style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_selectedProvider == AiProviderType.nvidiaFluxKlein) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF76B900).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF76B900).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bolt, size: 22, color: Color(0xFF76B900)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'NVIDIA NIM Cloud • Modelo: Black Forest Labs FLUX.1 [klein] • Resolución: 1024×1024 (50 pasos)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tu NVIDIA API Key (se guarda localmente):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD9F99D)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nvidiaKeyController,
                        obscureText: _obscureNvidiaKey,
                        style: const TextStyle(fontSize: 11.5, color: Colors.white, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'nvapi-...',
                          hintStyle: const TextStyle(color: GrimoireTheme.textMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNvidiaKey ? Icons.visibility_off : Icons.visibility,
                              size: 16,
                              color: GrimoireTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureNvidiaKey = !_obscureNvidiaKey),
                          ),
                        ),
                        onChanged: (val) {
                          AiService.setNvidiaApiKey(val.trim());
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_selectedProvider == AiProviderType.pollinationsCloud) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentEmerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_done, size: 20, color: GrimoireTheme.accentEmerald),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Generación en la nube inmediata, 100% gratuita y sin necesidad de servidor local o API Key (vía Pollinations.ai).',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
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

              // Actions Row: Negative Prompt Toggle
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

              const SizedBox(height: 10),

              // Auto Background Removal Option
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _autoRemoveBg
                      ? GrimoireTheme.accentIndigo.withValues(alpha: 0.15)
                      : GrimoireTheme.surfacePanel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _autoRemoveBg
                        ? GrimoireTheme.accentIndigo.withValues(alpha: 0.5)
                        : GrimoireTheme.borderSubtle,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _autoRemoveBg,
                      activeColor: GrimoireTheme.accentIndigo,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) => setState(() => _autoRemoveBg = val ?? false),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_fix_high, size: 13, color: GrimoireTheme.accentIndigo),
                              SizedBox(width: 4),
                              Text(
                                'Quitar fondo automáticamente',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Genera transparencia alfa perfecta para el sujeto o icono al terminar.',
                            style: TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

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
