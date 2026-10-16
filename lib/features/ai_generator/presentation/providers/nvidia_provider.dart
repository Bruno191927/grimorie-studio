import 'package:flutter_riverpod/legacy.dart';
import '../../services/nvidia_service.dart';

class NvidiaState {
  final String apiKey;
  final String selectedModel;
  final String aspectRatio;
  final String textModel;
  final bool isTesting;
  final bool? testSuccess;
  final String? statusMessage;
  final List<String> remoteModels;
  final bool isLoadingModels;

  const NvidiaState({
    required this.apiKey,
    required this.selectedModel,
    required this.aspectRatio,
    required this.textModel,
    this.isTesting = false,
    this.testSuccess,
    this.statusMessage,
    this.remoteModels = const [],
    this.isLoadingModels = false,
  });

  bool get isConfigured => apiKey.trim().isNotEmpty;
  String get maskedApiKey => NvidiaService.maskApiKey(apiKey);

  NvidiaState copyWith({
    String? apiKey,
    String? selectedModel,
    String? aspectRatio,
    String? textModel,
    bool? isTesting,
    bool? testSuccess,
    String? statusMessage,
    List<String>? remoteModels,
    bool? isLoadingModels,
  }) {
    return NvidiaState(
      apiKey: apiKey ?? this.apiKey,
      selectedModel: selectedModel ?? this.selectedModel,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      textModel: textModel ?? this.textModel,
      isTesting: isTesting ?? this.isTesting,
      testSuccess: testSuccess ?? this.testSuccess,
      statusMessage: statusMessage ?? this.statusMessage,
      remoteModels: remoteModels ?? this.remoteModels,
      isLoadingModels: isLoadingModels ?? this.isLoadingModels,
    );
  }
}

class NvidiaNotifier extends StateNotifier<NvidiaState> {
  final NvidiaService _service = NvidiaService();

  NvidiaNotifier()
      : super(
          NvidiaState(
            apiKey: NvidiaService().apiKey,
            selectedModel: NvidiaService().selectedModel,
            aspectRatio: NvidiaService().aspectRatio,
            textModel: NvidiaService().textModel,
          ),
        );

  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    await _service.saveSettings(apiKey: trimmed);
    state = state.copyWith(
      apiKey: trimmed,
      testSuccess: null,
      statusMessage: null,
    );
  }

  Future<void> setModel(String model) async {
    await _service.saveSettings(model: model);
    state = state.copyWith(selectedModel: model);
  }

  Future<void> setAspectRatio(String ratio) async {
    await _service.saveSettings(aspectRatio: ratio);
    state = state.copyWith(aspectRatio: ratio);
  }

  Future<void> setTextModel(String textModel) async {
    await _service.saveSettings(textModel: textModel);
    state = state.copyWith(textModel: textModel);
  }

  Future<bool> testConnection([String? candidateKey]) async {
    state = state.copyWith(isTesting: true, statusMessage: 'Verificando con NVIDIA NIM...');
    final result = await _service.testConnection(candidateKey);
    final success = result['success'] == true;
    final msg = result['message']?.toString();

    state = state.copyWith(
      isTesting: false,
      testSuccess: success,
      statusMessage: msg,
    );

    return success;
  }

  Future<void> fetchRemoteModels([String? key]) async {
    state = state.copyWith(isLoadingModels: true);
    final models = await _service.fetchRemoteModels(key ?? state.apiKey);
    state = state.copyWith(
      isLoadingModels: false,
      remoteModels: models,
    );
  }
}

final nvidiaProvider = StateNotifierProvider<NvidiaNotifier, NvidiaState>((ref) {
  return NvidiaNotifier();
});
