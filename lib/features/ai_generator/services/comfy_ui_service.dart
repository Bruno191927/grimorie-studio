import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';
import 'ai_service.dart';

/// Information regarding a connected ComfyUI server instance
class ComfyUiServerInfo {
  final bool isOnline;
  final String? gpuName;
  final String? vramSummary;
  final String? comfyVersion;
  final String? pythonVersion;
  final String? pytorchVersion;
  final String? errorMessage;

  const ComfyUiServerInfo({
    required this.isOnline,
    this.gpuName,
    this.vramSummary,
    this.comfyVersion,
    this.pythonVersion,
    this.pytorchVersion,
    this.errorMessage,
  });

  factory ComfyUiServerInfo.offline([String? error]) => ComfyUiServerInfo(
        isOnline: false,
        errorMessage: error ?? 'No se pudo conectar a ComfyUI.',
      );
}

/// Represents a detected or configured ComfyUI workflow JSON
class ComfyWorkflowItem {
  final String name;
  final String filePath;
  final String? description;
  final bool isDefaultTarget;

  const ComfyWorkflowItem({
    required this.name,
    required this.filePath,
    this.description,
    this.isDefaultTarget = false,
  });
}

class ComfyUiService {
  static final ComfyUiService _instance = ComfyUiService._internal();
  factory ComfyUiService() => _instance;
  ComfyUiService._internal();

  String serverUrl = AppConstants.defaultComfyUiUrl;
  String targetWorkflowName = 'Image';
  String? targetWorkflowPath;

  /// Known standard directory where Comfy Desktop stores user workflows
  static Directory getStandardComfyWorkflowsDir() {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final userProfile = Platform.environment['USERPROFILE'] ?? '';

    final candidates = [
      Directory('$localAppData\\Comfy-Desktop\\ComfyUI-Installs\\ComfyUI\\ComfyUI\\user\\default\\workflows'),
      Directory('$userProfile\\AppData\\Local\\Comfy-Desktop\\ComfyUI-Installs\\ComfyUI\\ComfyUI\\user\\default\\workflows'),
      Directory('workflows'),
    ];

    for (final dir in candidates) {
      if (dir.existsSync()) {
        return dir;
      }
    }

    return candidates.first;
  }

  /// Scans the system for available ComfyUI workflow files, prioritizing 'Image.json'
  List<ComfyWorkflowItem> scanWorkflows() {
    final workflows = <ComfyWorkflowItem>[];
    final dir = getStandardComfyWorkflowsDir();

    if (dir.existsSync()) {
      try {
        final files = dir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.json')).toList();

        for (final file in files) {
          final fileName = file.uri.pathSegments.last;
          final baseName = fileName.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
          final isImage = baseName.toLowerCase() == 'image';

          workflows.add(
            ComfyWorkflowItem(
              name: baseName,
              filePath: file.path,
              description: isImage ? 'Anima Base v1.0 (Text to Image Subgraph)' : 'Workflow de ComfyUI',
              isDefaultTarget: isImage,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error scanning ComfyUI workflows: $e');
      }
    }

    // Ensure 'Image' is always present as an option even if directory path changed
    if (!workflows.any((w) => w.name.toLowerCase() == 'image')) {
      final defaultImagePath = '${dir.path}\\Image.json';
      workflows.insert(
        0,
        ComfyWorkflowItem(
          name: 'Image',
          filePath: defaultImagePath,
          description: 'Anima Base v1.0 (Text to Image Subgraph)',
          isDefaultTarget: true,
        ),
      );
    }

    return workflows;
  }

  /// Fetches workflows from both disk and ComfyUI server API /userdata?dir=workflows
  Future<List<ComfyWorkflowItem>> fetchAllWorkflows([String? urlOverride]) async {
    final workflows = <ComfyWorkflowItem>[];
    final seenNames = <String>{};

    // 1. Scan standard local filesystem
    final localList = scanWorkflows();
    for (final item in localList) {
      if (seenNames.add(item.name.toLowerCase())) {
        workflows.add(item);
      }
    }

    // 2. Query running ComfyUI server API (/userdata?dir=workflows)
    final url = urlOverride ?? serverUrl;
    try {
      final res = await http
          .get(Uri.parse('$url/userdata?dir=workflows'))
          .timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          final standardDir = getStandardComfyWorkflowsDir();
          for (final item in decoded) {
            final fileName = item.toString();
            final baseName = fileName.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
            if (seenNames.add(baseName.toLowerCase())) {
              final localFile = File('${standardDir.path}\\$fileName');
              final isImage = baseName.toLowerCase() == 'image';
              workflows.add(
                ComfyWorkflowItem(
                  name: baseName,
                  filePath: localFile.existsSync()
                      ? localFile.path
                      : '$url/userdata/workflows%2F$fileName',
                  description: isImage
                      ? 'Anima Base v1.0 (Text to Image Subgraph)'
                      : 'Workflow en servidor ComfyUI',
                  isDefaultTarget: isImage,
                ),
              );
            }
          }
        }
      }
    } catch (_) {
      // Server not accessible or offline, local workflows remain
    }

    // Always guarantee 'Image' is in the list
    if (!workflows.any((w) => w.name.toLowerCase() == 'image')) {
      final defaultImagePath = '${getStandardComfyWorkflowsDir().path}\\Image.json';
      workflows.insert(
        0,
        ComfyWorkflowItem(
          name: 'Image',
          filePath: defaultImagePath,
          description: 'Anima Base v1.0 (Text to Image Subgraph)',
          isDefaultTarget: true,
        ),
      );
    }

    return workflows;
  }

  /// Pings ComfyUI /system_stats to retrieve live server, GPU and VRAM metrics
  Future<ComfyUiServerInfo> checkConnection([String? urlOverride]) async {
    final url = urlOverride ?? serverUrl;
    try {
      final uri = Uri.parse('$url/system_stats');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final sys = (data['system'] as Map<String, dynamic>?) ?? {};
        final devices = (data['devices'] as List<dynamic>?) ?? [];

        String? gpuName;
        String? vramSummary;

        if (devices.isNotEmpty) {
          final firstDev = devices.first as Map<String, dynamic>;
          gpuName = firstDev['name']?.toString();
          final vramTotal = firstDev['vram_total'] as num?;
          final vramFree = firstDev['vram_free'] as num?;
          if (vramTotal != null && vramFree != null) {
            final freeGb = (vramFree / (1024 * 1024 * 1024)).toStringAsFixed(2);
            final totalGb = (vramTotal / (1024 * 1024 * 1024)).toStringAsFixed(2);
            vramSummary = '$freeGb GB libre / $totalGb GB total';
          }
        }

        return ComfyUiServerInfo(
          isOnline: true,
          gpuName: gpuName,
          vramSummary: vramSummary,
          comfyVersion: sys['comfyui_version']?.toString(),
          pythonVersion: sys['python_version']?.toString().split(' ').first,
          pytorchVersion: sys['pytorch_version']?.toString(),
        );
      } else {
        return ComfyUiServerInfo.offline('ComfyUI respondió con código HTTP ${res.statusCode}');
      }
    } catch (e) {
      return ComfyUiServerInfo.offline('No se pudo conectar a $url ($e)');
    }
  }

  /// Builds the execution prompt dictionary for the 'Image' workflow (Anima Base v1.0)
  Map<String, dynamic> buildAnimaWorkflowPrompt({
    required String positivePrompt,
    String? negativePrompt,
    int? seed,
  }) {
    final effectiveSeed = seed ?? (math.Random().nextInt(900000000) + 100000000);
    final effectiveNegative = negativePrompt ??
        'worst quality, low quality, score_1, score_2, score_3, blurry, jpeg artifacts, sepia';

    return {
      '46': {
        'inputs': {
          'filename_prefix': 'Grimoire',
          'images': ['90:73', 0],
        },
        'class_type': 'SaveImage',
      },
      '91': {
        'inputs': {
          'aspect_ratio': '1:1 (Square)',
          'megapixels': 1.0,
          'multiple': 16,
        },
        'class_type': 'ResolutionSelector',
      },
      '90:71': {
        'inputs': {
          'clip_name': 'qwen_3_06b_base.safetensors',
          'type': 'stable_diffusion',
          'device': 'default',
        },
        'class_type': 'CLIPLoader',
      },
      '90:72': {
        'inputs': {
          'vae_name': 'qwen_image_vae.safetensors',
        },
        'class_type': 'VAELoader',
      },
      '90:73': {
        'inputs': {
          'samples': ['90:76', 0],
          'vae': ['90:72', 0],
        },
        'class_type': 'VAEDecode',
      },
      '90:74': {
        'inputs': {
          'width': ['91', 0],
          'height': ['91', 1],
          'batch_size': 1,
        },
        'class_type': 'EmptyLatentImage',
      },
      '90:75': {
        'inputs': {
          'text': effectiveNegative,
          'clip': ['90:71', 0],
        },
        'class_type': 'CLIPTextEncode',
      },
      '90:76': {
        'inputs': {
          'seed': effectiveSeed,
          'steps': ['90:85', 0],
          'cfg': ['90:87', 0],
          'sampler_name': 'euler',
          'scheduler': 'simple',
          'denoise': 1.0,
          'model': ['90:84', 0],
          'positive': ['90:77', 0],
          'negative': ['90:75', 0],
          'latent_image': ['90:74', 0],
        },
        'class_type': 'KSampler',
      },
      '90:77': {
        'inputs': {
          'text': positivePrompt,
          'clip': ['90:71', 0],
        },
        'class_type': 'CLIPTextEncode',
      },
      '90:78': {
        'inputs': {
          'unet_name': 'anima-base-v1.0.safetensors',
          'weight_dtype': 'default',
        },
        'class_type': 'UNETLoader',
      },
      '90:79': {
        'inputs': {'value': 30},
        'class_type': 'PrimitiveInt',
      },
      '90:81': {
        'inputs': {'value': 8},
        'class_type': 'PrimitiveInt',
      },
      '90:83': {
        'inputs': {
          'lora_name': 'anima-turbo-lora-v0.2.safetensors',
          'strength_model': 1.0,
          'model': ['90:78', 0],
        },
        'class_type': 'LoraLoaderModelOnly',
      },
      '90:84': {
        'inputs': {
          'switch': ['90:89', 0],
          'on_false': ['90:78', 0],
          'on_true': ['90:83', 0],
        },
        'class_type': 'ComfySwitchNode',
      },
      '90:85': {
        'inputs': {
          'switch': ['90:89', 0],
          'on_false': ['90:79', 0],
          'on_true': ['90:81', 0],
        },
        'class_type': 'ComfySwitchNode',
      },
      '90:86': {
        'inputs': {'value': 4.0},
        'class_type': 'PrimitiveFloat',
      },
      '90:87': {
        'inputs': {
          'switch': ['90:89', 0],
          'on_false': ['90:86', 0],
          'on_true': ['90:88', 0],
        },
        'class_type': 'ComfySwitchNode',
      },
      '90:88': {
        'inputs': {'value': 1.0},
        'class_type': 'PrimitiveFloat',
      },
      '90:89': {
        'inputs': {'value': false},
        'class_type': 'PrimitiveBoolean',
      },
    };
  }

  /// Builds execution prompt dictionary dynamically based on the active target workflow
  Future<Map<String, dynamic>> buildWorkflowPromptForTarget({
    required String positivePrompt,
    String? negativePrompt,
    int? seed,
  }) async {
    // If target is Image (Anima Base v1.0), use the verified optimized prompt
    if (targetWorkflowName.toLowerCase() == 'image' || targetWorkflowPath == null) {
      return buildAnimaWorkflowPrompt(
        positivePrompt: positivePrompt,
        negativePrompt: negativePrompt,
        seed: seed,
      );
    }

    // Try reading custom workflow from disk if path exists
    try {
      final file = File(targetWorkflowPath!);
      if (file.existsSync()) {
        final content = await file.readAsString();
        final dynamic decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          // If in ComfyUI API format (map of node IDs with class_type & inputs)
          final isApiFormat = decoded.values.any((v) => v is Map && v.containsKey('class_type'));
          if (isApiFormat) {
            final Map<String, dynamic> promptMap = Map<String, dynamic>.from(decoded);
            final effectiveSeed = seed ?? (math.Random().nextInt(900000000) + 100000000);

            final textNodes = promptMap.entries.where((e) {
              final val = e.value;
              return val is Map && val['class_type'] == 'CLIPTextEncode';
            }).toList();

            if (textNodes.length == 1) {
              textNodes[0].value['inputs']['text'] = positivePrompt;
            } else if (textNodes.length >= 2) {
              textNodes[0].value['inputs']['text'] = positivePrompt;
              textNodes[1].value['inputs']['text'] =
                  negativePrompt ?? 'worst quality, low quality, blurry, bad anatomy';
            }

            for (final entry in promptMap.entries) {
              final val = entry.value;
              if (val is Map &&
                  (val['class_type'] == 'KSampler' || val['class_type'] == 'KSamplerAdvanced')) {
                if (val['inputs'] is Map && val['inputs'].containsKey('seed')) {
                  val['inputs']['seed'] = effectiveSeed;
                }
              }
              if (val is Map && val['class_type'] == 'SaveImage') {
                if (val['inputs'] is Map) {
                  val['inputs']['filename_prefix'] = 'Grimoire';
                }
              }
            }

            return promptMap;
          }
        }
      }
    } catch (e) {
      debugPrint('Fallback to Anima prompt due to error adapting custom workflow: $e');
    }

    return buildAnimaWorkflowPrompt(
      positivePrompt: positivePrompt,
      negativePrompt: negativePrompt,
      seed: seed,
    );
  }

  /// Sends a generation prompt to ComfyUI, waits for the output, and saves the image to game assets
  Future<AiGenerationResult> generateArtworkWithComfyUi({
    required String prompt,
    required String gameName,
    String? negativePrompt,
    Function(String status)? onProgress,
  }) async {
    try {
      onProgress?.call('Conectando con ComfyUI en $serverUrl...');
      final connInfo = await checkConnection();
      if (!connInfo.isOnline) {
        return AiGenerationResult(
          success: false,
          errorMessage: 'El servidor local de ComfyUI ($serverUrl) no está respondiendo. Inicia ComfyUI Desktop.',
        );
      }

      onProgress?.call('Preparando workflow "$targetWorkflowName"...');
      final promptDict = await buildWorkflowPromptForTarget(
        positivePrompt: prompt,
        negativePrompt: negativePrompt,
      );

      final payload = {
        'prompt': promptDict,
        'client_id': 'grimoire_studio',
      };

      onProgress?.call('Enviando prompt a ComfyUI...');
      final postUri = Uri.parse('$serverUrl/prompt');
      final postResponse = await http
          .post(
            postUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (postResponse.statusCode != 200) {
        String errorDetail = postResponse.body;
        try {
          final errJson = jsonDecode(postResponse.body) as Map<String, dynamic>;
          final nodeErrors = errJson['node_errors'] as Map<String, dynamic>?;
          if (nodeErrors != null && nodeErrors.isNotEmpty) {
            final firstKey = nodeErrors.keys.first;
            final errList = (nodeErrors[firstKey]['errors'] as List<dynamic>?) ?? [];
            if (errList.isNotEmpty) {
              errorDetail = errList.first['details']?.toString() ?? errList.first['message']?.toString() ?? errorDetail;
            }
          }
        } catch (_) {}

        return AiGenerationResult(
          success: false,
          errorMessage: 'ComfyUI rechazó la petición: $errorDetail',
        );
      }

      final postData = jsonDecode(postResponse.body) as Map<String, dynamic>;
      final promptId = postData['prompt_id']?.toString();

      if (promptId == null || promptId.isEmpty) {
        return const AiGenerationResult(
          success: false,
          errorMessage: 'ComfyUI no devolvió un prompt_id válido.',
        );
      }

      onProgress?.call('Muestreando en GPU con KSampler (ID: ${promptId.substring(0, 8)})...');

      // Poll /history/$prompt_id until image is ready (timeout after 120s)
      String? outputFileName;
      String? outputSubfolder;
      String? outputType;

      const pollInterval = Duration(milliseconds: 1200);
      const maxAttempts = 100;

      for (int i = 0; i < maxAttempts; i++) {
        await Future.delayed(pollInterval);
        try {
          final historyUri = Uri.parse('$serverUrl/history/$promptId');
          final histRes = await http.get(historyUri);

          if (histRes.statusCode == 200) {
            final histData = jsonDecode(histRes.body) as Map<String, dynamic>;
            if (histData.containsKey(promptId)) {
              final runData = histData[promptId] as Map<String, dynamic>;
              final outputs = (runData['outputs'] as Map<String, dynamic>?) ?? {};

              // Find SaveImage output
              for (final nodeOutput in outputs.values) {
                final images = (nodeOutput['images'] as List<dynamic>?) ?? [];
                if (images.isNotEmpty) {
                  final firstImg = images.first as Map<String, dynamic>;
                  outputFileName = firstImg['filename']?.toString();
                  outputSubfolder = firstImg['subfolder']?.toString() ?? '';
                  outputType = firstImg['type']?.toString() ?? 'output';
                  break;
                }
              }

              if (outputFileName != null) {
                break;
              }
            }
          }
        } catch (_) {}
      }

      if (outputFileName == null) {
        return const AiGenerationResult(
          success: false,
          errorMessage: 'Tiempo de espera agotado mientras ComfyUI procesaba la imagen.',
        );
      }

      onProgress?.call('Descargando imagen generada ($outputFileName)...');
      final viewUri = Uri.parse(
        '$serverUrl/view?filename=$outputFileName&subfolder=${outputSubfolder ?? ''}&type=${outputType ?? 'output'}',
      );

      final imgResponse = await http.get(viewUri).timeout(const Duration(seconds: 15));
      if (imgResponse.statusCode != 200 || imgResponse.bodyBytes.isEmpty) {
        return AiGenerationResult(
          success: false,
          errorMessage: 'Error al descargar la imagen desde $viewUri',
        );
      }

      // Save into active game's assets folder
      await GameFolderService.ensureGameFolderExists(gameName);
      final assetsDir = GameFolderService.getGameAssetsDir(gameName);
      final targetFile = File('${assetsDir.path}/$outputFileName');
      await targetFile.writeAsBytes(imgResponse.bodyBytes);

      return AiGenerationResult(
        success: true,
        localFilePath: targetFile.path,
        imageBytes: Uint8List.fromList(imgResponse.bodyBytes),
      );
    } catch (e) {
      return AiGenerationResult(
        success: false,
        errorMessage: 'Error en la conexión a ComfyUI: $e',
      );
    }
  }
}
