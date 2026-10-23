import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../editor/presentation/providers/editor_provider.dart';
import '../../../editor/services/background_removal_service.dart';
import '../../services/ai_service.dart';

class BatchAiDialog extends ConsumerStatefulWidget {
  final String? filterGame;

  const BatchAiDialog({super.key, this.filterGame});

  static Future<void> show(BuildContext context, {String? filterGame}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchAiDialog(filterGame: filterGame),
    );
  }

  @override
  ConsumerState<BatchAiDialog> createState() => _BatchAiDialogState();
}

class _BatchAiDialogState extends ConsumerState<BatchAiDialog> {
  bool _isProcessing = false;
  double _progress = 0.0;
  String _status = '';
  int _completed = 0;
  int _total = 0;
  bool _onlyMissingArt = true;
  bool _autoRemoveBg = false;
  AiProviderType _selectedProvider = AiProviderType.openAi;
  late TextEditingController _nvidiaKeyController;
  late TextEditingController _geminiKeyController;
  late TextEditingController _geminiModelController;
  late TextEditingController _openAiKeyController;
  late TextEditingController _openAiModelController;
  final List<String> _geminiPresetModels = [
    'imagen-3.0-generate-002',
    'imagen-3.0-generate-001',
    'imagen-3.0-fast-generate-001',
  ];
  final List<String> _openAiPresetModels = [
    'gpt-image-1',
    'dall-e-3',
    'dall-e-2',
  ];
  List<String> _geminiFetchedModels = [];
  List<String> _openAiFetchedModels = [];
  bool _isFetchingGeminiModels = false;
  bool _isFetchingOpenAiModels = false;
  bool _isCustomGeminiModel = false;
  bool _isCustomOpenAiModel = false;
  bool _obscureNvidiaKey = true;
  bool _obscureGeminiKey = true;
  bool _obscureOpenAiKey = true;

  @override
  void initState() {
    super.initState();
    _nvidiaKeyController = TextEditingController(text: AiService.getNvidiaApiKey());
    _geminiKeyController = TextEditingController(text: AiService.getGeminiApiKey());
    final currentModel = AiService.getGeminiModel();
    _geminiModelController = TextEditingController(text: currentModel);
    _isCustomGeminiModel = !_geminiPresetModels.contains(currentModel);

    _openAiKeyController = TextEditingController(text: AiService.getOpenAiApiKey());
    final currentOpenAiModel = AiService.getOpenAiModel();
    _openAiModelController = TextEditingController(text: currentOpenAiModel);
    _isCustomOpenAiModel = !_openAiPresetModels.contains(currentOpenAiModel);
    if (AiService.getOpenAiApiKey().isEmpty && AiService.getGeminiApiKey().isNotEmpty) {
      _selectedProvider = AiProviderType.googleGemini;
    }
  }

  @override
  void dispose() {
    _nvidiaKeyController.dispose();
    _geminiKeyController.dispose();
    _geminiModelController.dispose();
    _openAiKeyController.dispose();
    _openAiModelController.dispose();
    super.dispose();
  }

  Future<void> _fetchOpenAiModels() async {
    final key = _openAiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa primero tu API Key de OpenAI para consultar los modelos.')),
      );
      return;
    }
    setState(() => _isFetchingOpenAiModels = true);
    final models = await AiService.fetchAvailableOpenAiModels(apiKey: key);
    if (mounted) {
      setState(() {
        _isFetchingOpenAiModels = false;
        if (models.isNotEmpty) {
          _openAiFetchedModels = models;
          if (!_openAiPresetModels.contains(_openAiModelController.text.trim()) &&
              !models.contains(_openAiModelController.text.trim())) {
            _openAiModelController.text = models.first;
            AiService.setOpenAiModel(models.first);
            _isCustomOpenAiModel = false;
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(models.isNotEmpty
              ? 'Se encontraron ${models.length} modelos de imagen en tu cuenta de OpenAI.'
              : 'No se encontraron modelos adicionales o la clave no tiene permisos.'),
        ),
      );
    }
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

  Future<void> _startBatch() async {
    if (_selectedProvider == AiProviderType.openAi) {
      AiService.setOpenAiApiKey(_openAiKeyController.text.trim());
      AiService.setOpenAiModel(_openAiModelController.text.trim());
    } else if (_selectedProvider == AiProviderType.googleGemini) {
      AiService.setGeminiApiKey(_geminiKeyController.text.trim());
      AiService.setGeminiModel(_geminiModelController.text.trim());
    } else if (_selectedProvider == AiProviderType.nvidiaFluxKlein) {
      AiService.setNvidiaApiKey(_nvidiaKeyController.text.trim());
    }

    final allRows = ref.read(editorProvider).project.rows;
    final candidates = allRows.where((r) {
      if (widget.filterGame != null && widget.filterGame != 'All') {
        if ((r['game'] ?? '').toString().toLowerCase() != widget.filterGame!.toLowerCase()) {
          return false;
        }
      }
      if (_onlyMissingArt) {
        final art = (r['art_url'] ?? '').toString().trim();
        return art.isEmpty || art.contains('black_lotus') || art.contains('lightning_bolt');
      }
      return true;
    }).toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cartas pendientes para generar arte.')),
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isProcessing = true;
      _total = candidates.length;
      _completed = 0;
      _progress = 0.0;
      _status = 'Iniciando generación en lote...';
    });

    final aiService = AiService();
    final notifier = ref.read(editorProvider.notifier);

    for (int i = 0; i < candidates.length; i++) {
      final card = candidates[i];
      final cardName = (card['card_name'] ?? 'Card').toString();
      final gameName = (card['game'] ?? 'Magic').toString();
      final prompt = (card['prompt'] ?? '').toString().isNotEmpty
          ? card['prompt'].toString()
          : 'High fantasy masterpiece trading card art of $cardName, intricate details, vivid lighting, 8k resolution';

      setState(() {
        _status = 'Generando [${i + 1}/$_total]: $cardName...';
        _progress = (i) / _total;
      });

      final isNativeOpenAiTransparent = _selectedProvider == AiProviderType.openAi &&
          _autoRemoveBg &&
          _openAiModelController.text.trim().toLowerCase().contains('gpt-image');

      final result = await aiService.generateArtwork(
        prompt: prompt,
        gameName: gameName,
        provider: _selectedProvider,
        geminiModel: _geminiModelController.text.trim(),
        openAiModel: _openAiModelController.text.trim(),
        openAiTransparentBackground: isNativeOpenAiTransparent,
      );

      if (result.success && result.localFilePath != null) {
        String finalPath = result.localFilePath!;
        if (_autoRemoveBg && !isNativeOpenAiTransparent) {
          try {
            final processed = await BackgroundRemovalService.removeBackgroundFromFile(
              File(finalPath),
            );
            finalPath = processed.path;
          } catch (_) {}
        }
        final relativePath = 'assets/${finalPath.split(RegExp(r'[\\/]')).last}';
        final rowIndex = allRows.indexOf(card);
        if (rowIndex != -1) {
          final updatedRow = Map<String, dynamic>.from(allRows[rowIndex]);
          updatedRow['art_url'] = relativePath;
          notifier.updateRow(rowIndex, updatedRow);
        }
      }

      setState(() {
        _completed = i + 1;
        _progress = _completed / _total;
      });
    }

    setState(() {
      _isProcessing = false;
      _status = '¡Generación en lote completada con éxito!';
    });

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context);
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.auto_awesome, color: GrimoireTheme.accentPurple, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Generación de Arte IA en Lote',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          widget.filterGame != null && widget.filterGame != 'All'
                              ? 'Mazo: ${widget.filterGame}'
                              : 'Todas las cartas con prompt configurado',
                          style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (!_isProcessing)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
              // Engine selector
              const Text('Motor de Generación IA:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<AiProviderType>(
                initialValue: _selectedProvider,
                isExpanded: true,
                dropdownColor: GrimoireTheme.surfaceElevated,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(
                    value: AiProviderType.openAi,
                    child: Text('OpenAI (GPT Image 1 / DALL·E 3 • OpenAI API)'),
                  ),
                  DropdownMenuItem(
                    value: AiProviderType.googleGemini,
                    child: Text('Google Gemini (Imagen 3 • Google AI Studio)'),
                  ),
                  DropdownMenuItem(
                    value: AiProviderType.nvidiaFluxKlein,
                    child: Text('NVIDIA NIM (BFL FLUX.1 [klein] 1024×1024)'),
                  ),
                  DropdownMenuItem(
                    value: AiProviderType.pollinationsCloud,
                    child: Text('Nube Gratuita (Pollinations.ai)'),
                  ),
                  DropdownMenuItem(
                    value: AiProviderType.comfyUiLocal,
                    child: Text('Local ComfyUI (127.0.0.1:8188)'),
                  ),
                ],
                onChanged: _isProcessing ? null : (val) {
                  if (val != null) setState(() => _selectedProvider = val);
                },
              ),
              const SizedBox(height: 10),

              if (_selectedProvider == AiProviderType.openAi) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2420),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10A37F).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu OpenAI API Key (se guarda localmente):',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6EE7B7)),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _openAiKeyController,
                        obscureText: _obscureOpenAiKey,
                        enabled: !_isProcessing,
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'sk-proj-...',
                          hintStyle: const TextStyle(color: GrimoireTheme.textMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureOpenAiKey ? Icons.visibility_off : Icons.visibility,
                              size: 15,
                              color: GrimoireTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureOpenAiKey = !_obscureOpenAiKey),
                          ),
                        ),
                        onChanged: (val) => AiService.setOpenAiApiKey(val.trim()),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 12, color: Color(0xFF6EE7B7)),
                          const SizedBox(width: 4),
                          const Text(
                            'Modelo de Imagen (OpenAI):',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6EE7B7)),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: (_isProcessing || _isFetchingOpenAiModels) ? null : _fetchOpenAiModels,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isFetchingOpenAiModels)
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF6EE7B7)),
                                    )
                                  else
                                    const Icon(Icons.sync, size: 11, color: Color(0xFF6EE7B7)),
                                  const SizedBox(width: 3),
                                  const Text(
                                    'Consultar Modelos',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF6EE7B7),
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
                      const SizedBox(height: 4),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1714),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GrimoireTheme.borderSubtle),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _isCustomOpenAiModel
                                ? '__custom__'
                                : ({..._openAiPresetModels, ..._openAiFetchedModels}.contains(_openAiModelController.text.trim())
                                    ? _openAiModelController.text.trim()
                                    : '__custom__'),
                            isExpanded: true,
                            dropdownColor: const Color(0xFF0F2420),
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                            items: [
                              ...{..._openAiPresetModels, ..._openAiFetchedModels}.map((m) {
                                String label = m;
                                if (m == 'gpt-image-1') {
                                  label = '$m (Recomendado)';
                                } else if (m == 'dall-e-3') {
                                  label = '$m (DALL·E 3)';
                                } else if (m == 'dall-e-2') {
                                  label = '$m (DALL·E 2)';
                                }
                                return DropdownMenuItem(value: m, child: Text(label));
                              }),
                              const DropdownMenuItem(
                                value: '__custom__',
                                child: Text('Personalizado (Escribir ID)...'),
                              ),
                            ],
                            onChanged: _isProcessing
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    if (v == '__custom__') {
                                      setState(() => _isCustomOpenAiModel = true);
                                    } else {
                                      setState(() {
                                        _isCustomOpenAiModel = false;
                                        _openAiModelController.text = v;
                                      });
                                      AiService.setOpenAiModel(v);
                                    }
                                  },
                          ),
                        ),
                      ),
                      if (_isCustomOpenAiModel) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: _openAiModelController,
                          enabled: !_isProcessing,
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: 'Ej: gpt-image-1',
                            hintStyle: TextStyle(color: GrimoireTheme.textMuted),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            prefixIcon: Icon(Icons.edit, size: 13, color: Color(0xFF6EE7B7)),
                          ),
                          onChanged: (val) => AiService.setOpenAiModel(val.trim()),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (_selectedProvider == AiProviderType.googleGemini) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2640),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu Google Gemini API Key (se guarda localmente):',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF93C5FD)),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _geminiKeyController,
                        obscureText: _obscureGeminiKey,
                        enabled: !_isProcessing,
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'AIzaSy...',
                          hintStyle: const TextStyle(color: GrimoireTheme.textMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureGeminiKey ? Icons.visibility_off : Icons.visibility,
                              size: 15,
                              color: GrimoireTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureGeminiKey = !_obscureGeminiKey),
                          ),
                        ),
                        onChanged: (val) => AiService.setGeminiApiKey(val.trim()),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 12, color: Color(0xFF93C5FD)),
                          const SizedBox(width: 4),
                          const Text(
                            'Modelo de Imagen:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF93C5FD)),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: (_isProcessing || _isFetchingGeminiModels) ? null : _fetchGeminiModels,
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
                                    const Icon(Icons.sync, size: 11, color: Color(0xFF93C5FD)),
                                  const SizedBox(width: 3),
                                  const Text(
                                    'Consultar Modelos',
                                    style: TextStyle(
                                      fontSize: 9.5,
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
                      const SizedBox(height: 4),
                      Container(
                        height: 32,
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
                                  label = '$m (Recomendado)';
                                } else if (m == 'imagen-3.0-generate-001') {
                                  label = '$m (Imagen 3 v1)';
                                } else if (m == 'imagen-3.0-fast-generate-001') {
                                  label = '$m (Fast Generate)';
                                }
                                return DropdownMenuItem(value: m, child: Text(label));
                              }),
                              const DropdownMenuItem(
                                value: '__custom__',
                                child: Text('Personalizado (Escribir ID)...'),
                              ),
                            ],
                            onChanged: _isProcessing
                                ? null
                                : (v) {
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
                          enabled: !_isProcessing,
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: 'Ej: imagen-3.0-generate-002',
                            hintStyle: TextStyle(color: GrimoireTheme.textMuted),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            prefixIcon: Icon(Icons.edit, size: 13, color: Color(0xFF93C5FD)),
                          ),
                          onChanged: (val) => AiService.setGeminiModel(val.trim()),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (_selectedProvider == AiProviderType.nvidiaFluxKlein) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF76B900).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF76B900).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu NVIDIA API Key (se guarda localmente):',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD9F99D)),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _nvidiaKeyController,
                        obscureText: _obscureNvidiaKey,
                        enabled: !_isProcessing,
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'nvapi-...',
                          hintStyle: const TextStyle(color: GrimoireTheme.textMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNvidiaKey ? Icons.visibility_off : Icons.visibility,
                              size: 15,
                              color: GrimoireTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureNvidiaKey = !_obscureNvidiaKey),
                          ),
                        ),
                        onChanged: (val) => AiService.setNvidiaApiKey(val.trim()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Solo cartas sin imagen / con arte de muestra', style: TextStyle(fontSize: 13, color: Colors.white)),
                subtitle: const Text('Ignora las cartas que ya tengan una imagen física asignada', style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                value: _onlyMissingArt,
                activeThumbColor: GrimoireTheme.accentPurple,
                onChanged: _isProcessing ? null : (v) => setState(() => _onlyMissingArt = v),
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Row(
                  children: [
                    Icon(Icons.auto_fix_high, size: 14, color: GrimoireTheme.accentEmerald),
                    SizedBox(width: 6),
                    Text('Quitar fondo a cada imagen', style: TextStyle(fontSize: 13, color: Colors.white)),
                  ],
                ),
                subtitle: const Text('Genera transparencia alfa automática para personajes o iconos del lote', style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted)),
                value: _autoRemoveBg,
                activeThumbColor: GrimoireTheme.accentEmerald,
                onChanged: _isProcessing ? null : (v) => setState(() => _autoRemoveBg = v),
              ),

              const SizedBox(height: 14),

              if (_isProcessing) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: const Color(0xFF10121E),
                  valueColor: const AlwaysStoppedAnimation(GrimoireTheme.accentPurple),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  _status,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFE9D5FF)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: GrimoireTheme.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bolt, size: 16),
                    label: Text(_isProcessing ? 'Generando...' : 'Iniciar Lote'),
                    onPressed: _isProcessing ? null : _startBatch,
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
