import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:grimoire_studio/core/constants/app_constants.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';
import 'ai_service.dart';

class NvidiaModelOption {
  final String id;
  final String name;
  final String description;
  final bool isDefault;

  const NvidiaModelOption({
    required this.id,
    required this.name,
    required this.description,
    this.isDefault = false,
  });
}

class NvidiaService {
  static final NvidiaService _instance = NvidiaService._internal();
  factory NvidiaService() => _instance;

  NvidiaService._internal() {
    loadSettingsSync();
  }

  String _apiKey = '';
  String _selectedModel = AppConstants.defaultNvidiaImageModel;
  String _aspectRatio = '1:1';
  String _textModel = AppConstants.defaultNvidiaTextModel;

  String get apiKey => _apiKey;
  String get selectedModel => _selectedModel;
  String get aspectRatio => _aspectRatio;
  String get textModel => _textModel;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  static const List<NvidiaModelOption> availableImageModels = [
    NvidiaModelOption(
      id: 'stabilityai/stable-diffusion-3-medium',
      name: 'SD3 Medium (Stability AI)',
      description: 'Modelo insignia para ilustraciones de fantasía, criaturas y TCG.',
      isDefault: true,
    ),
    NvidiaModelOption(
      id: 'black-forest-labs/flux-1-schnell',
      name: 'FLUX.1 Schnell (Black Forest)',
      description: 'Generación ultra rápida con gran nitidez y detalles visuales.',
    ),
    NvidiaModelOption(
      id: 'black-forest-labs/flux-1-dev',
      name: 'FLUX.1 Dev (Black Forest)',
      description: 'Máxima fidelidad anatómica, iluminación mágica y texturas.',
    ),
    NvidiaModelOption(
      id: 'stabilityai/sdxl-turbo',
      name: 'SDXL Turbo (Stability AI)',
      description: 'Generación ultraligera en tiempo real optimizada por NVIDIA.',
    ),
  ];

  static const List<NvidiaModelOption> availableTextModels = [
    NvidiaModelOption(
      id: 'nvidia/nemotron-3.5-super-vl-120b-a12b',
      name: 'Nemotron 3.5 Super VL 120B (NVIDIA)',
      description: 'Modelo de razonamiento profundo (Thinking) y visión multimodal para análisis y generación.',
      isDefault: true,
    ),
    NvidiaModelOption(
      id: 'nvidia/llama-3.1-nemotron-70b-instruct',
      name: 'Nemotron 70B Instruct (NVIDIA)',
      description: 'Alta precisión y seguimiento de instrucciones para mecánicas y reglas de juego.',
    ),
    NvidiaModelOption(
      id: 'meta/llama-3.2-90b-vision-instruct',
      name: 'Llama 3.2 90B Vision (Meta)',
      description: 'Análisis detallado de imágenes e ilustraciones de cartas.',
    ),
    NvidiaModelOption(
      id: 'meta/llama-3.2-11b-vision-instruct',
      name: 'Llama 3.2 11B Vision (Meta)',
      description: 'Modelo ligero y rápido para lore y visión multimodal.',
    ),
  ];

  static const List<String> availableAspectRatios = [
    '1:1',
    '2:3',
    '16:9',
    '9:16',
  ];

  /// Masks API key for safe UI display (e.g. nvapi-••••••••1234)
  static String maskApiKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 10) return '••••••••';
    final prefix = trimmed.startsWith('nvapi-') ? 'nvapi-' : trimmed.substring(0, 4);
    final suffix = trimmed.substring(trimmed.length - 4);
    return '$prefix••••••••$suffix';
  }

  File _getConfigFile() {
    try {
      final rootDir = GameFolderService.getGamesRootDir();
      final sep = Platform.isWindows ? '\\' : '/';
      return File('${rootDir.path}$sep.grimoire_ai_config.json');
    } catch (_) {
      return File('.grimoire_ai_config.json');
    }
  }

  /// Synchronous configuration loader
  void loadSettingsSync() {
    try {
      final file = _getConfigFile();
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _apiKey = (json['nvidia_api_key'] ?? '').toString();
        _selectedModel = (json['nvidia_model'] ?? AppConstants.defaultNvidiaImageModel).toString();
        _aspectRatio = (json['nvidia_aspect_ratio'] ?? '1:1').toString();
        final rawTextModel = (json['nvidia_text_model'] ?? '').toString();
        if (rawTextModel.isNotEmpty && !rawTextModel.contains('llama-3.1-70b') && !rawTextModel.contains('llama-3.1-8b')) {
          _textModel = rawTextModel;
        } else {
          _textModel = AppConstants.defaultNvidiaTextModel;
        }
      } else {
        // Pre-configure the active NVIDIA API key if no config exists yet
        _apiKey = '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';
        _textModel = AppConstants.defaultNvidiaTextModel;
      }
    } catch (_) {}
  }

  /// Asynchronous configuration loader
  Future<void> loadSettings() async {
    loadSettingsSync();
  }

  /// Saves current configuration to persistent storage file
  Future<void> saveSettings({
    String? apiKey,
    String? model,
    String? aspectRatio,
    String? textModel,
  }) async {
    if (apiKey != null) _apiKey = apiKey.trim();
    if (model != null && model.trim().isNotEmpty) _selectedModel = model.trim();
    if (aspectRatio != null && aspectRatio.trim().isNotEmpty) _aspectRatio = aspectRatio.trim();
    if (textModel != null && textModel.trim().isNotEmpty) _textModel = textModel.trim();

    try {
      final file = _getConfigFile();
      final data = {
        'nvidia_api_key': _apiKey,
        'nvidia_model': _selectedModel,
        'nvidia_aspect_ratio': _aspectRatio,
        'nvidia_text_model': _textModel,
        'updated_at': DateTime.now().toIso8601String(),
      };
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    } catch (_) {}
  }

  /// Tests connectivity and validity of an NVIDIA API Key
  Future<Map<String, dynamic>> testConnection([String? testKey]) async {
    final key = testKey ?? _apiKey;
    if (key.trim().isEmpty) {
      return {
        'success': false,
        'message': 'No se ha proporcionado ninguna API Key de NVIDIA.',
      };
    }

    try {
      // Test with chat completions using 1 token to verify key validity
      final url = Uri.parse('${AppConstants.defaultNvidiaBaseUrl}/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': 'nvidia/nemotron-3.5-super-vl-120b-a12b',
          'messages': [
            {'role': 'user', 'content': 'hi'}
          ],
          'max_tokens': 1,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Conexión verificada con éxito con NVIDIA NIM (Nemotron 3.5 Super VL 120B).',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Clave no autorizada (HTTP 401). Verifica tu API Key de NVIDIA.',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': true, // Key is valid, just rate-limited
          'message': 'API Key válida (Límite temporal de peticiones o créditos agotados).',
        };
      } else {
        return {
          'success': false,
          'message': 'NVIDIA NIM respondió con código ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de red al conectar con NVIDIA: $e',
      };
    }
  }

  /// Invokes NVIDIA NIM Chat Completions supporting Nemotron 3.5 Super VL 120B,
  /// streaming SSE, reasoning tokens, vision image_url, and thinking template kwargs.
  Future<String?> invokeChatCompletion({
    required List<Map<String, dynamic>> messages,
    String? model,
    double temperature = 1.0,
    double topP = 0.95,
    int maxTokens = 16384,
    int seed = 42,
    bool enableThinking = true,
    bool stream = true,
    String? customKey,
    void Function(String token)? onToken,
    void Function(String reasoningToken)? onReasoning,
  }) async {
    final key = customKey ?? _apiKey;
    if (key.trim().isEmpty) return null;

    final targetModel = model ?? _textModel;
    final uri = Uri.parse('${AppConstants.defaultNvidiaBaseUrl}/chat/completions');

    final payload = <String, dynamic>{
      'model': targetModel,
      'messages': messages,
      'temperature': temperature,
      'top_p': topP,
      'max_tokens': maxTokens,
      'parallel_tool_calls': true,
      'seed': seed,
      'chat_template_kwargs': {'enable_thinking': enableThinking},
      'stream': stream,
    };

    try {
      final client = HttpClient();
      final req = await client.postUrl(uri);
      req.headers.set('Authorization', 'Bearer $key');
      req.headers.set('Accept', 'application/json');
      req.headers.set('Content-Type', 'application/json');

      final jsonBytes = utf8.encode(jsonEncode(payload));
      req.add(jsonBytes);

      final res = await req.close();
      if (res.statusCode != 200) {
        client.close();
        return null;
      }

      final contentBuffer = StringBuffer();
      final reasoningBuffer = StringBuffer();

      if (stream) {
        await for (final line in res.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') break;
            try {
              final json = jsonDecode(dataStr);
              final delta = json['choices']?[0]?['delta'];
              if (delta != null) {
                final reasoning = delta['reasoning_content']?.toString();
                final content = delta['content']?.toString();
                if (reasoning != null && reasoning.isNotEmpty) {
                  reasoningBuffer.write(reasoning);
                  onReasoning?.call(reasoning);
                }
                if (content != null && content.isNotEmpty) {
                  contentBuffer.write(content);
                  onToken?.call(content);
                }
              }
            } catch (_) {}
          }
        }
      } else {
        final rawBody = await utf8.decodeStream(res);
        final json = jsonDecode(rawBody);
        final msg = json['choices']?[0]?['message'];
        if (msg != null) {
          final content = msg['content']?.toString();
          if (content != null) contentBuffer.write(content);
        }
      }

      client.close();

      final result = contentBuffer.toString().trim();
      if (result.isNotEmpty) return result;
      if (reasoningBuffer.isNotEmpty) return reasoningBuffer.toString().trim();
    } catch (_) {}

    return null;
  }

  /// Enhances a prompt using Nemotron 3.5 Super VL 120B reasoning model
  Future<String?> enhancePromptWithNemotron({
    required String basicPrompt,
    String? customKey,
    void Function(String token)? onToken,
  }) async {
    final messages = [
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text':
                'You are a master concept artist and prompt engineer for tabletop collectible card games (TCG/CCG). '
                'Transform this concept into a single vivid, highly visual art prompt for image generation: "$basicPrompt". '
                'Include visual style, dramatic lighting, rich color palette, anatomy/creature details, and composition. '
                'Reply ONLY with the prompt itself, without quotes or introductory commentary.',
          }
        ]
      }
    ];

    return invokeChatCompletion(
      messages: messages,
      model: _textModel,
      temperature: 1.0,
      topP: 0.95,
      maxTokens: 2048,
      seed: 42,
      enableThinking: true,
      stream: true,
      customKey: customKey,
      onToken: onToken,
    );
  }

  /// Enhances a prompt (backward-compatible alias)
  Future<String?> enhancePromptWithLlama({
    required String basicPrompt,
    String? customKey,
  }) async {
    return enhancePromptWithNemotron(basicPrompt: basicPrompt, customKey: customKey);
  }

  /// Multimodal vision query using Nemotron 3.5 Super VL 120B
  Future<String?> analyzeImageWithNemotron({
    required String prompt,
    String? imageUrl,
    String? localImagePath,
    String? customKey,
    void Function(String token)? onToken,
  }) async {
    final contentList = <Map<String, dynamic>>[];
    contentList.add({'type': 'text', 'text': prompt});

    if (imageUrl != null && imageUrl.isNotEmpty) {
      contentList.add({
        'type': 'image_url',
        'image_url': {'url': imageUrl},
      });
    } else if (localImagePath != null && localImagePath.isNotEmpty) {
      final file = File(localImagePath);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final b64 = base64Encode(bytes);
        final ext = localImagePath.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        contentList.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/$ext;base64,$b64'},
        });
      }
    }

    final messages = [
      {
        'role': 'user',
        'content': contentList,
      }
    ];

    return invokeChatCompletion(
      messages: messages,
      model: 'nvidia/nemotron-3.5-super-vl-120b-a12b',
      temperature: 1.0,
      topP: 0.95,
      maxTokens: 4096,
      seed: 42,
      enableThinking: true,
      stream: true,
      customKey: customKey,
      onToken: onToken,
    );
  }

  /// Generates artwork for a card layer via NVIDIA NIM
  Future<AiGenerationResult> generateArtwork({
    required String prompt,
    String? gameName,
    String? negativePrompt,
    String? customModel,
    String? customAspectRatio,
    Function(String status)? onProgress,
  }) async {
    final key = _apiKey.trim();
    if (key.isEmpty) {
      return const AiGenerationResult(
        success: false,
        errorMessage: 'Debes configurar tu API Key de NVIDIA (nvapi-...) para generar arte con este modelo.',
      );
    }

    final model = customModel ?? _selectedModel;
    final ratio = customAspectRatio ?? _aspectRatio;

    onProgress?.call('Conectando con NVIDIA NIM ($model)...');

    try {
      // Determine target destination file in game's assets folder
      Directory targetDir;
      if (gameName != null && gameName.trim().isNotEmpty) {
        await GameFolderService.ensureGameFolderExists(gameName);
        targetDir = GameFolderService.getGameAssetsDir(gameName);
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        targetDir = Directory('${docsDir.path}/GrimoireStudio/assets/generated');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'art_nvidia_$timestamp.jpg';
      final file = File('${targetDir.path}/$fileName');

      onProgress?.call('Generando arte con $model...');

      // 1. Primary endpoint: NVIDIA GenAI NIM route
      final genAiUrl = Uri.parse('${AppConstants.defaultNvidiaGenAiUrl}/$model');
      
      http.Response response;
      try {
        response = await http.post(
          genAiUrl,
          headers: {
            'Authorization': 'Bearer $key',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'prompt': prompt,
            if (negativePrompt != null && negativePrompt.trim().isNotEmpty)
              'negative_prompt': negativePrompt.trim(),
            'aspect_ratio': ratio,
            'cfg_scale': 5,
            'steps': 40,
            'output_format': 'jpeg',
          }),
        ).timeout(const Duration(seconds: 60));
      } catch (_) {
        // Fallback: OpenAI-compatible images route on integrate.api.nvidia.com
        final openAiUrl = Uri.parse('${AppConstants.defaultNvidiaBaseUrl}/images/generations');
        response = await http.post(
          openAiUrl,
          headers: {
            'Authorization': 'Bearer $key',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'prompt': prompt,
            'n': 1,
            'response_format': 'b64_json',
          }),
        ).timeout(const Duration(seconds: 60));
      }

      onProgress?.call('Procesando respuesta de NVIDIA...');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        Uint8List? imageBytes;

        // Extract base64 image data from different possible schemas
        if (body is Map<String, dynamic>) {
          if (body['image'] is String) {
            imageBytes = base64Decode(body['image'] as String);
          } else if (body['artifacts'] is List && (body['artifacts'] as List).isNotEmpty) {
            final first = (body['artifacts'] as List).first;
            if (first is Map && first['base64'] is String) {
              imageBytes = base64Decode(first['base64'] as String);
            }
          } else if (body['data'] is List && (body['data'] as List).isNotEmpty) {
            final first = (body['data'] as List).first;
            if (first is Map && first['b64_json'] is String) {
              imageBytes = base64Decode(first['b64_json'] as String);
            } else if (first is Map && first['url'] is String) {
              final imgRes = await http.get(Uri.parse(first['url'] as String));
              if (imgRes.statusCode == 200) imageBytes = imgRes.bodyBytes;
            }
          } else if (body['b64_json'] is String) {
            imageBytes = base64Decode(body['b64_json'] as String);
          }
        }

        if (imageBytes != null && imageBytes.isNotEmpty) {
          await file.writeAsBytes(imageBytes);
          return AiGenerationResult(
            success: true,
            localFilePath: file.path,
            imageBytes: imageBytes,
          );
        }
      } else if (response.statusCode == 401) {
        return const AiGenerationResult(
          success: false,
          errorMessage: 'API Key de NVIDIA no válida (HTTP 401). Verifica tu clave en la configuración.',
        );
      } else if (response.statusCode == 429) {
        return const AiGenerationResult(
          success: false,
          errorMessage: 'Límite de solicitudes de NVIDIA alcanzado. Espera un momento o revisa tus créditos en build.nvidia.com.',
        );
      } else {
        return AiGenerationResult(
          success: false,
          errorMessage: 'NVIDIA NIM devolvió código ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return AiGenerationResult(
        success: false,
        errorMessage: 'Error al generar con NVIDIA: $e',
      );
    }

    return const AiGenerationResult(
      success: false,
      errorMessage: 'No se pudo obtener la imagen del modelo de NVIDIA.',
    );
  }
}
