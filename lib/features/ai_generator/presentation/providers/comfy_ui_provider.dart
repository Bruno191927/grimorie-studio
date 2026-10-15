import 'package:flutter_riverpod/legacy.dart';
import '../../services/comfy_ui_service.dart';

class ComfyUiState {
  final String serverUrl;
  final ComfyUiServerInfo serverInfo;
  final ComfyWorkflowItem activeWorkflow;
  final List<ComfyWorkflowItem> availableWorkflows;
  final bool isChecking;
  final String? statusNote;

  const ComfyUiState({
    required this.serverUrl,
    required this.serverInfo,
    required this.activeWorkflow,
    required this.availableWorkflows,
    this.isChecking = false,
    this.statusNote,
  });

  ComfyUiState copyWith({
    String? serverUrl,
    ComfyUiServerInfo? serverInfo,
    ComfyWorkflowItem? activeWorkflow,
    List<ComfyWorkflowItem>? availableWorkflows,
    bool? isChecking,
    String? statusNote,
  }) {
    return ComfyUiState(
      serverUrl: serverUrl ?? this.serverUrl,
      serverInfo: serverInfo ?? this.serverInfo,
      activeWorkflow: activeWorkflow ?? this.activeWorkflow,
      availableWorkflows: availableWorkflows ?? this.availableWorkflows,
      isChecking: isChecking ?? this.isChecking,
      statusNote: statusNote ?? this.statusNote,
    );
  }
}

class ComfyUiNotifier extends StateNotifier<ComfyUiState> {
  final ComfyUiService _service = ComfyUiService();

  ComfyUiNotifier()
      : super(
          ComfyUiState(
            serverUrl: ComfyUiService().serverUrl,
            serverInfo: ComfyUiServerInfo.offline(),
            activeWorkflow: const ComfyWorkflowItem(
              name: 'Image',
              filePath: 'C:\\Users\\bruno\\AppData\\Local\\Comfy-Desktop\\ComfyUI-Installs\\ComfyUI\\ComfyUI\\user\\default\\workflows\\Image.json',
              description: 'Anima Base v1.0 (Text to Image Subgraph)',
              isDefaultTarget: true,
            ),
            availableWorkflows: const [],
          ),
        ) {
    init();
  }

  Future<void> init() async {
    await refreshWorkflows();
    await checkConnection();
  }

  Future<void> refreshWorkflows() async {
    final workflows = await _service.fetchAllWorkflows(state.serverUrl);
    
    // Preserve current selection if exists, otherwise prefer Image, otherwise first available
    ComfyWorkflowItem currentTarget = state.activeWorkflow;
    final foundCurrent = workflows.where(
      (w) =>
          w.filePath.toLowerCase() == state.activeWorkflow.filePath.toLowerCase() ||
          w.name.toLowerCase() == state.activeWorkflow.name.toLowerCase(),
    );

    if (foundCurrent.isNotEmpty) {
      currentTarget = foundCurrent.first;
    } else {
      final imageWf = workflows.where((w) => w.name.toLowerCase() == 'image');
      if (imageWf.isNotEmpty) {
        currentTarget = imageWf.first;
      } else if (workflows.isNotEmpty) {
        currentTarget = workflows.first;
      }
    }

    _service.targetWorkflowName = currentTarget.name;
    _service.targetWorkflowPath = currentTarget.filePath;

    state = state.copyWith(
      availableWorkflows: workflows,
      activeWorkflow: currentTarget,
    );
  }

  void setServerUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    _service.serverUrl = trimmed;
    state = state.copyWith(serverUrl: trimmed);
    checkConnection();
  }

  void selectWorkflow(ComfyWorkflowItem item) {
    _service.targetWorkflowName = item.name;
    _service.targetWorkflowPath = item.filePath;
    state = state.copyWith(activeWorkflow: item);
  }

  void selectWorkflowByName(String name) {
    final found = state.availableWorkflows.firstWhere(
      (w) => w.name.toLowerCase() == name.toLowerCase(),
      orElse: () => state.activeWorkflow,
    );
    selectWorkflow(found);
  }

  void setCustomWorkflowPath(String path) {
    final fileName = path.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
    final customItem = ComfyWorkflowItem(
      name: fileName,
      filePath: path,
      description: 'Workflow personalizado cargado desde disco',
    );

    final updated = List<ComfyWorkflowItem>.from(state.availableWorkflows);
    if (!updated.any((w) => w.filePath.toLowerCase() == path.toLowerCase())) {
      updated.insert(0, customItem);
    }

    _service.targetWorkflowName = customItem.name;
    _service.targetWorkflowPath = customItem.filePath;

    state = state.copyWith(
      availableWorkflows: updated,
      activeWorkflow: customItem,
    );
  }

  Future<void> checkConnection() async {
    state = state.copyWith(isChecking: true, statusNote: 'Verificando conexión...');
    final info = await _service.checkConnection(state.serverUrl);
    
    // Refresh workflows from server / disk
    final workflows = await _service.fetchAllWorkflows(state.serverUrl);
    
    ComfyWorkflowItem currentTarget = state.activeWorkflow;
    final foundCurrent = workflows.where(
      (w) =>
          w.filePath.toLowerCase() == state.activeWorkflow.filePath.toLowerCase() ||
          w.name.toLowerCase() == state.activeWorkflow.name.toLowerCase(),
    );
    if (foundCurrent.isNotEmpty) {
      currentTarget = foundCurrent.first;
    } else {
      final img = workflows.where((w) => w.name.toLowerCase() == 'image');
      if (img.isNotEmpty) {
        currentTarget = img.first;
      } else if (workflows.isNotEmpty) {
        currentTarget = workflows.first;
      }
    }

    _service.targetWorkflowName = currentTarget.name;
    _service.targetWorkflowPath = currentTarget.filePath;

    state = state.copyWith(
      isChecking: false,
      serverInfo: info,
      availableWorkflows: workflows,
      activeWorkflow: currentTarget,
      statusNote: info.isOnline
          ? 'Conectado a ${info.gpuName ?? "ComfyUI"}'
          : (info.errorMessage ?? 'Servidor ComfyUI desconectado'),
    );
  }
}

final comfyUiProvider = StateNotifierProvider<ComfyUiNotifier, ComfyUiState>((ref) {
  return ComfyUiNotifier();
});
