import 'package:flutter_riverpod/legacy.dart';
import '../../services/nvidia_service.dart';

class NvidiaState {
  final String apiKey;
  final String selectedModel;
  final String aspectRatio;
  final bool isTesting;
  final bool? testSuccess;
  final String? statusMessage;

  const NvidiaState({
    required this.apiKey,
    required this.selectedModel,
    required this.aspectRatio,
    this.isTesting = false,
    this.testSuccess,
    this.statusMessage,
  });

  bool get isConfigured => apiKey.trim().isNotEmpty;
  String get maskedApiKey => NvidiaService.maskApiKey(apiKey);

  NvidiaState copyWith({
    String? apiKey,
    String? selectedModel,
    String? aspectRatio,
    bool? isTesting,
    bool? testSuccess,
    String? statusMessage,
  }) {
    return NvidiaState(
      apiKey: apiKey ?? this.apiKey,
      selectedModel: selectedModel ?? this.selectedModel,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      isTesting: isTesting ?? this.isTesting,
      testSuccess: testSuccess ?? this.testSuccess,
      statusMessage: statusMessage ?? this.statusMessage,
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
}

final nvidiaProvider = StateNotifierProvider<NvidiaNotifier, NvidiaState>((ref) {
  return NvidiaNotifier();
});
