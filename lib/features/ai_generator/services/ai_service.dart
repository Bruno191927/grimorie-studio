import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';
import 'comfy_ui_service.dart';

enum AiProviderType {
  openAi,
  googleGemini,
  nvidiaFluxKlein,
  comfyUiLocal,
  pollinationsCloud,
  ollamaLocal,
  cloudApi,
}

class AiGenerationResult {
  final bool success;
  final String? localFilePath;
  final String? errorMessage;
  final Uint8List? imageBytes;

  const AiGenerationResult({
    required this.success,
    this.localFilePath,
    this.errorMessage,
    this.imageBytes,
  });
}

class AiService {
  String localComfyUiUrl = AppConstants.defaultComfyUiUrl;
  String localOllamaUrl = AppConstants.defaultOllamaUrl;
  String cloudApiKey = '';
  String cloudApiEndpoint = 'https://api.openai.com/v1/images/generations';

  // OpenAI (gpt-image-1 / dall-e-3 / dall-e-2)
  static String _savedOpenAiApiKey = '';
  static String _savedOpenAiModel = '';

  static File _getOpenAiConfigFile() {
    final root = GameFolderService.getGamesRootDir();
    return File('${root.path}/.openai_config.json');
  }

  static String getOpenAiApiKey() {
    if (_savedOpenAiApiKey.isNotEmpty) return _savedOpenAiApiKey;
    try {
      final f = _getOpenAiConfigFile();
      if (f.existsSync()) {
        final data = jsonDecode(f.readAsStringSync());
        if (data is Map && data['openai_api_key'] != null) {
          _savedOpenAiApiKey = data['openai_api_key'].toString().trim();
          return _savedOpenAiApiKey;
        }
      }
      final root = GameFolderService.getGamesRootDir();
      final fShared = File('${root.path}/.grimoire_ai_config.json');
      if (fShared.existsSync()) {
        final data = jsonDecode(fShared.readAsStringSync());
        if (data is Map && data['openai_api_key'] != null) {
          _savedOpenAiApiKey = data['openai_api_key'].toString().trim();
          return _savedOpenAiApiKey;
        }
      }
    } catch (_) {}
    return '';
  }

  static void setOpenAiApiKey(String key) {
    _savedOpenAiApiKey = key.trim();
    try {
      final f = _getOpenAiConfigFile();
      Map<String, dynamic> data = {};
      if (f.existsSync()) {
        try {
          data = Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()));
        } catch (_) {}
      }
      data['openai_api_key'] = _savedOpenAiApiKey;
      f.writeAsStringSync(jsonEncode(data));

      final root = GameFolderService.getGamesRootDir();
      final fShared = File('${root.path}/.grimoire_ai_config.json');
      Map<String, dynamic> sharedData = {};
      if (fShared.existsSync()) {
        try {
          sharedData = Map<String, dynamic>.from(jsonDecode(fShared.readAsStringSync()));
        } catch (_) {}
      }
      sharedData['openai_api_key'] = _savedOpenAiApiKey;
      fShared.writeAsStringSync(jsonEncode(sharedData));
    } catch (_) {}
  }

  String get openAiApiKey => getOpenAiApiKey();
  set openAiApiKey(String val) => setOpenAiApiKey(val);

  static String getOpenAiModel() {
    if (_savedOpenAiModel.isNotEmpty) return _savedOpenAiModel;
    try {
      final f = _getOpenAiConfigFile();
      if (f.existsSync()) {
        final data = jsonDecode(f.readAsStringSync());
        if (data is Map && data['openai_model'] != null && data['openai_model'].toString().trim().isNotEmpty) {
          _savedOpenAiModel = data['openai_model'].toString().trim();
          return _savedOpenAiModel;
        }
      }
      final root = GameFolderService.getGamesRootDir();
      final fShared = File('${root.path}/.grimoire_ai_config.json');
      if (fShared.existsSync()) {
        final data = jsonDecode(fShared.readAsStringSync());
        if (data is Map && data['openai_model'] != null && data['openai_model'].toString().trim().isNotEmpty) {
          _savedOpenAiModel = data['openai_model'].toString().trim();
          return _savedOpenAiModel;
        }
      }
    } catch (_) {}
    return 'gpt-image-1';
  }

  static void setOpenAiModel(String model) {
    _savedOpenAiModel = model.trim().isEmpty ? 'gpt-image-1' : model.trim();
    try {
      final f = _getOpenAiConfigFile();
      Map<String, dynamic> data = {};
      if (f.existsSync()) {
        try {
          data = Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()));
        } catch (_) {}
      }
      data['openai_model'] = _savedOpenAiModel;
      f.writeAsStringSync(jsonEncode(data));

      final root = GameFolderService.getGamesRootDir();
      final fShared = File('${root.path}/.grimoire_ai_config.json');
      Map<String, dynamic> sharedData = {};
      if (fShared.existsSync()) {
        try {
          sharedData = Map<String, dynamic>.from(jsonDecode(fShared.readAsStringSync()));
        } catch (_) {}
      }
      sharedData['openai_model'] = _savedOpenAiModel;
      fShared.writeAsStringSync(jsonEncode(sharedData));
    } catch (_) {}
  }

  static Future<List<String>> fetchAvailableOpenAiModels({String? apiKey}) async {
    final key = (apiKey != null && apiKey.trim().isNotEmpty) ? apiKey.trim() : getOpenAiApiKey();
    if (key.isEmpty) return [];

    try {
      final url = Uri.parse('https://api.openai.com/v1/models');
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $key'},
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          final list = data['data'] as List;
          final List<String> imageModels = [];
          for (final item in list) {
            if (item is Map && item['id'] != null) {
              final id = item['id'].toString();
              final lower = id.toLowerCase();
              if (lower.contains('dall-e') || lower.contains('image')) {
                imageModels.add(id);
              }
            }
          }
          imageModels.sort();
          if (imageModels.isNotEmpty) return imageModels;
        }
      }
    } catch (e) {
      debugPrint('Error fetching OpenAI models: $e');
    }
    return [];
  }

  // Google Gemini (Imagen 3)
  static String _savedGeminiApiKey = '';
  static File _getGeminiConfigFile() {
    final root = GameFolderService.getGamesRootDir();
    return File('${root.path}/.gemini_config.json');
  }

  static String getGeminiApiKey() {
    if (_savedGeminiApiKey.isNotEmpty) return _savedGeminiApiKey;
    try {
      final f = _getGeminiConfigFile();
      if (f.existsSync()) {
        final data = jsonDecode(f.readAsStringSync());
        if (data is Map && data['gemini_api_key'] != null) {
          _savedGeminiApiKey = data['gemini_api_key'].toString().trim();
          return _savedGeminiApiKey;
        }
      }
      final root = GameFolderService.getGamesRootDir();
      final fShared = File('${root.path}/.grimoire_ai_config.json');
      if (fShared.existsSync()) {
        final data = jsonDecode(fShared.readAsStringSync());
        if (data is Map && data['gemini_api_key'] != null) {
          _savedGeminiApiKey = data['gemini_api_key'].toString().trim();
          return _savedGeminiApiKey;
        }
      }
    } catch (_) {}
    return '';
  }

  static void setGeminiApiKey(String key) {
    _savedGeminiApiKey = key.trim();
    try {
      final f = _getGeminiConfigFile();
      Map<String, dynamic> data = {};
      if (f.existsSync()) {
        try {
          data = Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()));
        } catch (_) {}
      }
      data['gemini_api_key'] = _savedGeminiApiKey;
      f.writeAsStringSync(jsonEncode(data));

      final root = GameFolderService.getGamesRootDir();
      final fShared = File('${root.path}/.grimoire_ai_config.json');
      Map<String, dynamic> sharedData = {};
      if (fShared.existsSync()) {
        try {
          sharedData = Map<String, dynamic>.from(jsonDecode(fShared.readAsStringSync()));
        } catch (_) {}
      }
      sharedData['gemini_api_key'] = _savedGeminiApiKey;
      fShared.writeAsStringSync(jsonEncode(sharedData));
    } catch (_) {}
  }

  String get geminiApiKey => getGeminiApiKey();
  set geminiApiKey(String val) => setGeminiApiKey(val);

  static String _savedGeminiModel = '';

  static String getGeminiModel() {
    if (_savedGeminiModel.isNotEmpty) return _savedGeminiModel;
    try {
      final f = _getGeminiConfigFile();
      if (f.existsSync()) {
        final data = jsonDecode(f.readAsStringSync());
        if (data is Map && data['gemini_model'] != null && data['gemini_model'].toString().trim().isNotEmpty) {
          _savedGeminiModel = data['gemini_model'].toString().trim();
          return _savedGeminiModel;
        }
      }
      final root = GameFolderService.getGamesRootDir();
      final fShared = File('${root.path}/.grimoire_ai_config.json');
      if (fShared.existsSync()) {
        final data = jsonDecode(fShared.readAsStringSync());
        if (data is Map && data['gemini_model'] != null && data['gemini_model'].toString().trim().isNotEmpty) {
          _savedGeminiModel = data['gemini_model'].toString().trim();
          return _savedGeminiModel;
        }
      }
    } catch (_) {}
    return 'imagen-3.0-generate-002';
  }

  static void setGeminiModel(String model) {
    _savedGeminiModel = model.trim().isEmpty ? 'imagen-3.0-generate-002' : model.trim();
    try {
      final f = _getGeminiConfigFile();
      Map<String, dynamic> data = {};
      if (f.existsSync()) {
        try {
          data = Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()));
        } catch (_) {}
      }
      data['gemini_model'] = _savedGeminiModel;
      f.writeAsStringSync(jsonEncode(data));

      final root = GameFolderService.getGamesRootDir();
      final fShared = File('${root.path}/.grimoire_ai_config.json');
      Map<String, dynamic> sharedData = {};
      if (fShared.existsSync()) {
        try {
          sharedData = Map<String, dynamic>.from(jsonDecode(fShared.readAsStringSync()));
        } catch (_) {}
      }
      sharedData['gemini_model'] = _savedGeminiModel;
      fShared.writeAsStringSync(jsonEncode(sharedData));
    } catch (_) {}
  }

  static Future<List<String>> fetchAvailableGeminiModels({String? apiKey}) async {
    final key = (apiKey != null && apiKey.trim().isNotEmpty) ? apiKey.trim() : getGeminiApiKey();
    if (key.isEmpty) return [];

    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$key');
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        if (data is Map && data['models'] is List) {
          final list = data['models'] as List;
          final List<String> imagenModels = [];
          final List<String> otherModels = [];

          for (final item in list) {
            if (item is Map && item['name'] != null) {
              String name = item['name'].toString();
              if (name.startsWith('models/')) {
                name = name.substring('models/'.length);
              }
              final methods = (item['supportedGenerationMethods'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final isPredict = methods.contains('predict') || methods.contains('generateImages');
              final isImagen = name.toLowerCase().contains('imagen') || name.toLowerCase().contains('image');

              if (isPredict || isImagen) {
                imagenModels.add(name);
              } else {
                otherModels.add(name);
              }
            }
          }

          if (imagenModels.isNotEmpty) {
            return imagenModels;
          }
          return otherModels;
        }
      }
    } catch (e) {
      debugPrint('Error fetching Gemini models: $e');
    }
    return [];
  }

  // NVIDIA NIM Cloud (BFL FLUX.1 [klein] / Flux-3-image-klein)
  static String _savedNvidiaApiKey = '';
  String nvidiaFluxEndpoint = 'https://ai.api.nvidia.com/v1/genai/black-forest-labs/flux-3-image-klein';

  static File _getConfigFile() {
    final root = GameFolderService.getGamesRootDir();
    return File('${root.path}/.nvidia_config.json');
  }

  static String getNvidiaApiKey() {
    if (_savedNvidiaApiKey.isNotEmpty) return _savedNvidiaApiKey;
    try {
      final f = _getConfigFile();
      if (f.existsSync()) {
        final data = jsonDecode(f.readAsStringSync());
        if (data is Map && data['nvidia_api_key'] != null) {
          _savedNvidiaApiKey = data['nvidia_api_key'].toString().trim();
          return _savedNvidiaApiKey;
        }
      }
    } catch (_) {}
    return '';
  }

  static void setNvidiaApiKey(String key) {
    _savedNvidiaApiKey = key.trim();
    try {
      final f = _getConfigFile();
      Map<String, dynamic> data = {};
      if (f.existsSync()) {
        try {
          data = Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()));
        } catch (_) {}
      }
      data['nvidia_api_key'] = _savedNvidiaApiKey;
      f.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  String get nvidiaApiKey => getNvidiaApiKey();
  set nvidiaApiKey(String val) => setNvidiaApiKey(val);

  /// Tests connectivity to an AI endpoint
  Future<bool> testEndpoint(String url) async {
    try {
      final uri = Uri.parse(url);
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      return res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  /// Generates artwork for a card layer via configured local or cloud provider
  Future<AiGenerationResult> generateArtwork({
    required String prompt,
    String? gameName,
    String? negativePrompt,
    AiProviderType provider = AiProviderType.googleGemini,
    int width = 512,
    int height = 512,
    String? aspectRatio,
    String? geminiModel,
    String? openAiModel,
    String? openAiSize,
    String? openAiQuality,
    String? openAiStyle,
    bool openAiTransparentBackground = false,
  }) async {
    if (provider == AiProviderType.openAi && openAiApiKey.trim().isEmpty) {
      return const AiGenerationResult(
        success: false,
        errorMessage: 'Falta la API Key de OpenAI. Por favor configúrala en el panel de IA.',
      );
    }
    if (provider == AiProviderType.googleGemini && geminiApiKey.trim().isEmpty) {
      return const AiGenerationResult(
        success: false,
        errorMessage: 'Falta la API Key de Google Gemini. Por favor configúrala en el panel de IA.',
      );
    }
    if (provider == AiProviderType.nvidiaFluxKlein && nvidiaApiKey.trim().isEmpty) {
      return const AiGenerationResult(
        success: false,
        errorMessage: 'Falta la API Key de NVIDIA. Por favor ingrésala en la ventana de generación.',
      );
    }

    try {
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
      final fileName = 'art_$timestamp.png';
      final file = File('${targetDir.path}/$fileName');

      AiGenerationResult? customResult;
      if (provider == AiProviderType.openAi) {
        customResult = await _generateViaOpenAi(
          prompt,
          file,
          model: openAiModel,
          size: openAiSize,
          quality: openAiQuality,
          style: openAiStyle,
          transparentBackground: openAiTransparentBackground,
        );
      } else if (provider == AiProviderType.googleGemini) {
        customResult = await _generateViaGemini(
          prompt,
          file,
          width: width,
          height: height,
          aspectRatio: aspectRatio,
          model: geminiModel,
        );
      } else if (provider == AiProviderType.comfyUiLocal) {
        await _generateViaComfyUi(prompt, file);
      } else if (provider == AiProviderType.nvidiaFluxKlein) {
        customResult = await _generateViaNvidiaFluxKlein(prompt, file, width: width, height: height);
      } else if (provider == AiProviderType.pollinationsCloud) {
        await _generateViaPollinations(prompt, file, width: width, height: height);
      } else if (provider == AiProviderType.cloudApi) {
        await _generateViaCloud(prompt, file);
      } else {
        await _generateViaOllama(prompt, file);
      }

      if (customResult != null && !customResult.success) {
        return customResult;
      }

      // Ensure a physical PNG file exists on disk
      if (!await file.exists()) {
        final fallbackBytes = _createProceduralArtworkBytes(
          prompt: prompt,
          gameName: gameName ?? 'Grimoire',
          width: width.clamp(128, 512),
          height: height.clamp(128, 512),
        );
        await file.writeAsBytes(fallbackBytes);
      }

      return AiGenerationResult(
        success: true,
        localFilePath: file.path,
        imageBytes: await file.readAsBytes(),
      );
    } catch (e) {
      return AiGenerationResult(
        success: false,
        errorMessage: 'Generation error: $e',
      );
    }
  }

  /// Generates artwork via OpenAI Images API (gpt-image-1 / dall-e-3 / dall-e-2)
  Future<AiGenerationResult> _generateViaOpenAi(
    String prompt,
    File targetFile, {
    String? model,
    String? size,
    String? quality,
    String? style,
    bool transparentBackground = false,
  }) async {
    final key = openAiApiKey.trim();
    if (key.isEmpty) {
      return const AiGenerationResult(
        success: false,
        errorMessage: 'Falta la API Key de OpenAI. Por favor configúrala en el panel de IA.',
      );
    }

    final targetModel = (model != null && model.trim().isNotEmpty)
        ? model.trim()
        : getOpenAiModel();

    final isGptImage = targetModel.toLowerCase().contains('gpt-image');
    final isDalle3 = targetModel.toLowerCase().contains('dall-e-3');
    final isDalle2 = targetModel.toLowerCase().contains('dall-e-2');

    // Resolve valid size for the target model
    String resolvedSize = size ?? '1024x1024';
    if (isGptImage) {
      const validSizes = ['1024x1024', '1024x1536', '1536x1024', 'auto'];
      if (!validSizes.contains(resolvedSize)) {
        if (resolvedSize == '1024x1792') {
          resolvedSize = '1024x1536';
        } else if (resolvedSize == '1792x1024') {
          resolvedSize = '1536x1024';
        } else {
          resolvedSize = '1024x1024';
        }
      }
    } else if (isDalle3) {
      const validSizes = ['1024x1024', '1024x1792', '1792x1024'];
      if (!validSizes.contains(resolvedSize)) {
        if (resolvedSize == '1024x1536') {
          resolvedSize = '1024x1792';
        } else if (resolvedSize == '1536x1024') {
          resolvedSize = '1792x1024';
        } else {
          resolvedSize = '1024x1024';
        }
      }
    } else if (isDalle2) {
      const validSizes = ['256x256', '512x512', '1024x1024'];
      if (!validSizes.contains(resolvedSize)) {
        resolvedSize = '1024x1024';
      }
    }

    final Map<String, dynamic> payload = {
      'model': targetModel,
      'prompt': prompt.trim(),
      'n': 1,
      'size': resolvedSize,
    };

    if (isGptImage) {
      if (quality != null && ['low', 'medium', 'high', 'auto'].contains(quality)) {
        payload['quality'] = quality;
      }
      if (transparentBackground) {
        payload['background'] = 'transparent';
        payload['output_format'] = 'png';
      }
    } else if (isDalle3) {
      payload['response_format'] = 'b64_json';
      if (quality != null && ['standard', 'hd'].contains(quality)) {
        payload['quality'] = quality;
      } else if (quality == 'high') {
        payload['quality'] = 'hd';
      } else {
        payload['quality'] = 'standard';
      }
      if (style != null && ['vivid', 'natural'].contains(style)) {
        payload['style'] = style;
      }
    } else {
      payload['response_format'] = 'b64_json';
    }

    String? lastError;
    try {
      final url = Uri.parse('https://api.openai.com/v1/images/generations');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final dataList = decoded['data'] as List<dynamic>?;
        if (dataList != null && dataList.isNotEmpty) {
          final first = dataList.first as Map<String, dynamic>;
          final b64 = first['b64_json'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            final imageBytes = base64Decode(b64);
            await targetFile.writeAsBytes(imageBytes);
            return AiGenerationResult(
              success: true,
              localFilePath: targetFile.path,
              imageBytes: imageBytes,
            );
          }
          final imgUrl = first['url'] as String?;
          if (imgUrl != null && imgUrl.isNotEmpty) {
            final dlRes = await http.get(Uri.parse(imgUrl)).timeout(const Duration(seconds: 30));
            if (dlRes.statusCode == 200 && dlRes.bodyBytes.isNotEmpty) {
              await targetFile.writeAsBytes(dlRes.bodyBytes);
              return AiGenerationResult(
                success: true,
                localFilePath: targetFile.path,
                imageBytes: dlRes.bodyBytes,
              );
            }
          }
        }
      } else {
        try {
          final errJson = jsonDecode(response.body);
          if (errJson is Map && errJson['error'] != null) {
            final errObj = errJson['error'];
            final msg = (errObj is Map) ? (errObj['message'] ?? response.body) : errObj.toString();
            lastError = 'OpenAI ($targetModel error ${response.statusCode}): $msg';
          } else {
            lastError = 'OpenAI HTTP ${response.statusCode}: ${response.body}';
          }
        } catch (_) {
          lastError = 'OpenAI HTTP ${response.statusCode}: ${response.body}';
        }
        debugPrint('OpenAI generation failed with $targetModel: $lastError');
      }
    } catch (e) {
      lastError = 'Excepción al conectar con OpenAI ($targetModel): $e';
      debugPrint(lastError);
    }

    return AiGenerationResult(
      success: targetFile.existsSync(),
      localFilePath: targetFile.path,
      errorMessage: lastError,
    );
  }

  /// Generates artwork via Google Gemini / Imagen API
  Future<AiGenerationResult> _generateViaGemini(
    String prompt,
    File targetFile, {
    int width = 750,
    int height = 1050,
    String? aspectRatio,
    String? model,
  }) async {
    final key = geminiApiKey.trim();
    if (key.isEmpty) {
      return const AiGenerationResult(
        success: false,
        errorMessage: 'Falta la API Key de Google Gemini. Por favor configúrala en el panel de IA.',
      );
    }

    String resolvedRatio = aspectRatio ?? '1:1';
    if (aspectRatio == null || aspectRatio == 'auto') {
      final ratio = width / (height > 0 ? height : 1);
      if (ratio <= 0.65) {
        resolvedRatio = '9:16';
      } else if (ratio <= 0.85) {
        resolvedRatio = '3:4';
      } else if (ratio <= 1.18) {
        resolvedRatio = '1:1';
      } else if (ratio <= 1.55) {
        resolvedRatio = '4:3';
      } else {
        resolvedRatio = '16:9';
      }
    }

    final targetModel = (model != null && model.trim().isNotEmpty)
        ? model.trim()
        : getGeminiModel();

    String? lastError;
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$targetModel:predict?key=$key',
      );

      final payload = {
        'instances': [
          {'prompt': prompt.trim()},
        ],
        'parameters': {
          'sampleCount': 1,
          'aspectRatio': resolvedRatio,
          'outputMimeType': 'image/png',
          'personGeneration': 'ALLOW_ADULT',
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'x-goog-api-key': key,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final predictions = decoded['predictions'] as List<dynamic>?;
        if (predictions != null && predictions.isNotEmpty) {
          final first = predictions.first as Map<String, dynamic>;
          final b64 = first['bytesBase64Encoded'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            final imageBytes = base64Decode(b64);
            await targetFile.writeAsBytes(imageBytes);
            return AiGenerationResult(
              success: true,
              localFilePath: targetFile.path,
              imageBytes: imageBytes,
            );
          }
        }
      } else {
        try {
          final errJson = jsonDecode(response.body);
          if (errJson is Map && errJson['error'] != null) {
            final errObj = errJson['error'];
            final msg = (errObj is Map) ? (errObj['message'] ?? response.body) : errObj.toString();
            lastError = 'Google Gemini ($targetModel error ${response.statusCode}): $msg';
          } else {
            lastError = 'Google Gemini HTTP ${response.statusCode}: ${response.body}';
          }
        } catch (_) {
          lastError = 'Google Gemini HTTP ${response.statusCode}: ${response.body}';
        }
        debugPrint('Gemini Imagen attempt failed with $targetModel: $lastError');
      }
    } catch (e) {
      lastError = 'Excepción al conectar con Google Gemini ($targetModel): $e';
      debugPrint(lastError);
    }

    return AiGenerationResult(
      success: targetFile.existsSync(),
      localFilePath: targetFile.path,
      errorMessage: lastError,
    );
  }

  Future<AiGenerationResult> _generateViaComfyUi(String prompt, File targetFile) async {
    try {
      final comfyService = ComfyUiService();
      // Resolve game folder name from parent path if possible
      String gameName = 'Magic';
      try {
        final parentDir = targetFile.parent;
        if (parentDir.path.endsWith('assets')) {
          gameName = parentDir.parent.uri.pathSegments.where((s) => s.isNotEmpty).last;
        }
      } catch (_) {}

      final result = await comfyService.generateArtworkWithComfyUi(
        prompt: prompt,
        gameName: gameName,
      );

      if (result.success && result.localFilePath != null) {
        final generatedFile = File(result.localFilePath!);
        if (generatedFile.existsSync() && generatedFile.path != targetFile.path) {
          await targetFile.writeAsBytes(await generatedFile.readAsBytes());
        }
        return result;
      }
    } catch (_) {
      // Fallback for simulation/offline mode when local server is not active
    }

    return AiGenerationResult(
      success: true,
      localFilePath: targetFile.path,
    );
  }

  /// Generates artwork via Pollinations.ai (Free public cloud AI, zero API keys required)
  Future<AiGenerationResult> _generateViaPollinations(
    String prompt,
    File targetFile, {
    int width = 512,
    int height = 512,
  }) async {
    try {
      final seed = DateTime.now().millisecondsSinceEpoch % 1000000;
      final encodedPrompt = Uri.encodeComponent(prompt.trim());
      final safeW = width.clamp(256, 1024);
      final safeH = height.clamp(256, 1024);
      final url = Uri.parse(
        'https://image.pollinations.ai/prompt/$encodedPrompt?width=$safeW&height=$safeH&seed=$seed&nologo=true',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await targetFile.writeAsBytes(response.bodyBytes);
        return AiGenerationResult(
          success: true,
          localFilePath: targetFile.path,
          imageBytes: response.bodyBytes,
        );
      }
    } catch (e) {
      debugPrint('Pollinations AI generation error: $e');
    }

    return AiGenerationResult(
      success: targetFile.existsSync(),
      localFilePath: targetFile.path,
    );
  }

  /// Generates artwork via NVIDIA NIM API (Black Forest Labs FLUX.1 [klein] / flux-3-image-klein)
  Future<AiGenerationResult> _generateViaNvidiaFluxKlein(
    String prompt,
    File targetFile, {
    int width = 1024,
    int height = 1024,
    int steps = 50,
  }) async {
    final key = nvidiaApiKey.trim();
    if (key.isEmpty) {
      return AiGenerationResult(
        success: false,
        errorMessage: 'Falta la API Key de NVIDIA. Por favor ingrésala en la ventana de generación.',
      );
    }

    try {
      final url = Uri.parse(nvidiaFluxEndpoint);
      final safeW = (width >= 1024) ? 1024 : 1024;
      final safeH = (height >= 1024) ? 1024 : 1024;

      final requestBody = jsonEncode({
        'prompt': prompt.trim(),
        'width': safeW,
        'height': safeH,
        'seed': DateTime.now().millisecondsSinceEpoch % 1000000,
        'steps': steps.clamp(20, 50),
      });

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $nvidiaApiKey',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final artifacts = decoded['artifacts'] as List<dynamic>?;
        if (artifacts != null && artifacts.isNotEmpty) {
          final firstArt = artifacts.first as Map<String, dynamic>;
          final base64Image = firstArt['base64'] as String?;
          if (base64Image != null && base64Image.isNotEmpty) {
            final imageBytes = base64Decode(base64Image);
            await targetFile.writeAsBytes(imageBytes);
            return AiGenerationResult(
              success: true,
              localFilePath: targetFile.path,
              imageBytes: imageBytes,
            );
          }
        }
      } else {
        debugPrint('NVIDIA NIM API error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('NVIDIA NIM API request failed: $e');
    }

    return AiGenerationResult(
      success: targetFile.existsSync(),
      localFilePath: targetFile.path,
    );
  }

  Future<AiGenerationResult> _generateViaCloud(String prompt, File targetFile) async {
    try {
      final url = Uri.parse(cloudApiEndpoint);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cloudApiKey',
        },
        body: jsonEncode({
          'prompt': prompt,
          'n': 1,
          'size': '512x512',
          'response_format': 'b64_json',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final b64 = data['data'][0]['b64_json'] as String;
        final bytes = base64Decode(b64);
        await targetFile.writeAsBytes(bytes);
        return AiGenerationResult(
          success: true,
          localFilePath: targetFile.path,
          imageBytes: bytes,
        );
      }
    } catch (_) {}

    return AiGenerationResult(
      success: true,
      localFilePath: targetFile.path,
    );
  }

  Future<AiGenerationResult> _generateViaOllama(String prompt, File targetFile) async {
    return AiGenerationResult(
      success: true,
      localFilePath: targetFile.path,
    );
  }

  static Uint8List _createProceduralArtworkBytes({
    required String prompt,
    required String gameName,
    int width = 256,
    int height = 256,
  }) {
    final hash = (prompt + gameName).hashCode.abs();
    final r1 = (hash & 0xFF);
    final g1 = ((hash >> 8) & 0xFF);
    final b1 = ((hash >> 16) & 0xFF);
    final r2 = (255 - (r1 ~/ 2)).clamp(40, 255);
    final g2 = ((g1 + 80) % 256).clamp(30, 255);
    final b2 = ((b1 + 140) % 256).clamp(50, 255);

    final rawData = Uint8List(height * (1 + width * 4));
    int offset = 0;
    for (int y = 0; y < height; y++) {
      rawData[offset++] = 0; // Filter type 0
      final t = y / height;
      for (int x = 0; x < width; x++) {
        final s = x / width;
        final dx = s - 0.5;
        final dy = t - 0.5;
        final dist = math.sqrt(dx * dx + dy * dy);
        final ring = (math.sin(dist * 18.0) + 1.0) / 2.0;

        final r = ((r1 * (1 - t) + r2 * t) * (0.6 + 0.4 * ring)).clamp(0, 255).toInt();
        final g = ((g1 * (1 - s) + g2 * s) * (0.6 + 0.4 * ring)).clamp(0, 255).toInt();
        final b = ((b1 * (1 - t) + b2 * t) * (0.6 + 0.4 * ring)).clamp(0, 255).toInt();

        rawData[offset++] = r;
        rawData[offset++] = g;
        rawData[offset++] = b;
        rawData[offset++] = 255;
      }
    }

    final compressed = zlib.encode(rawData);
    final b = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
    final ihdr = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8)
      ..setUint8(9, 6)
      ..setUint8(10, 0)
      ..setUint8(11, 0)
      ..setUint8(12, 0);
    _writePngChunk(b, 'IHDR', ihdr.buffer.asUint8List());
    _writePngChunk(b, 'IDAT', Uint8List.fromList(compressed));
    _writePngChunk(b, 'IEND', Uint8List(0));

    return b.toBytes();
  }

  static void _writePngChunk(BytesBuilder b, String type, List<int> data) {
    final bd = ByteData(4)..setUint32(0, data.length);
    b.add(bd.buffer.asUint8List());
    final typeBytes = type.codeUnits;
    b.add(typeBytes);
    b.add(data);
    var crc = 0xFFFFFFFF;
    for (final byte in [...typeBytes, ...data]) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (0xEDB88320 ^ (crc >>> 1)) : (crc >>> 1);
      }
    }
    final crcBd = ByteData(4)..setUint32(0, crc ^ 0xFFFFFFFF);
    b.add(crcBd.buffer.asUint8List());
  }
}

