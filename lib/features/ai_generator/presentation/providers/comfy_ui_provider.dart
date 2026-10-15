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
    refreshWorkflows();
    await checkConnection();
  }

  void refreshWorkflows() {
    final workflows = _service.scanWorkflows();
    final currentTarget = workflows.firstWhere(
      (w) => w.name.toLowerCase() == 'image',
      orElse: () => workflows.isNotEmpty ? workflows.first : state.activeWorkflow,
    );

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
    state = state.copyWith(
      isChecking: false,
      serverInfo: info,
      statusNote: info.isOnline
          ? 'Conectado a ${info.gpuName ?? "ComfyUI"}'
          : (info.errorMessage ?? 'Servidor ComfyUI desconectado'),
    );
  }
}

final comfyUiProvider = StateNotifierProvider<ComfyUiNotifier, ComfyUiState>((ref) {
  return ComfyUiNotifier();
});
