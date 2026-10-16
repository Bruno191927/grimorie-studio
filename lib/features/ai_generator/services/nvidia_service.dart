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
        _textModel = (json['nvidia_text_model'] ?? AppConstants.defaultNvidiaTextModel).toString();
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
      // Test with chat completions with 1 token to verify key validity
      final url = Uri.parse('${AppConstants.defaultNvidiaBaseUrl}/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': 'meta/llama-3.1-8b-instruct',
          'messages': [
            {'role': 'user', 'content': 'hi'}
          ],
          'max_tokens': 1,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Conexión verificada con éxito con NVIDIA NIM.',
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

  /// Enhances a user concept prompt using NVIDIA's Meta Llama 3.1 70B model
  Future<String?> enhancePromptWithLlama({
    required String basicPrompt,
    String? customKey,
  }) async {
    final key = customKey ?? _apiKey;
    if (key.trim().isEmpty) return null;

    try {
      final url = Uri.parse('${AppConstants.defaultNvidiaBaseUrl}/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': _textModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a master concept artist and prompt engineer for tabletop collectible card games (TCG/CCG). '
                  'Transform the user card concept into a single vivid, highly visual art prompt suitable for AI diffusion generation. '
                  'Include art style, dramatic lighting, color palette, creature details, and composition. '
                  'Reply ONLY with the prompt itself, without quotes or introductory text.',
            },
            {
              'role': 'user',
              'content': basicPrompt,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 140,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final enhanced = data['choices']?[0]?['message']?['content']?.toString().trim();
        if (enhanced != null && enhanced.isNotEmpty) {
          return enhanced;
        }
      }
    } catch (_) {}

    return null;
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
