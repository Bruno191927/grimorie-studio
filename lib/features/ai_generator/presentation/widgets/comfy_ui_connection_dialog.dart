import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../services/comfy_ui_service.dart';
import '../../services/nvidia_service.dart';
import '../providers/comfy_ui_provider.dart';
import '../providers/nvidia_provider.dart';

class ComfyUiConnectionDialog extends ConsumerStatefulWidget {
  final int initialTab;
  const ComfyUiConnectionDialog({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showDialog(
      context: context,
      builder: (ctx) => ComfyUiConnectionDialog(initialTab: initialTab),
    );
  }

  @override
  ConsumerState<ComfyUiConnectionDialog> createState() => _ComfyUiConnectionDialogState();
}

class _ComfyUiConnectionDialogState extends ConsumerState<ComfyUiConnectionDialog> {
  late TextEditingController _urlController;
  late TextEditingController _nvidiaKeyController;
  bool _obscureNvidiaKey = true;

  @override
  void initState() {
    super.initState();
    final comfyState = ref.read(comfyUiProvider);
    _urlController = TextEditingController(text: comfyState.serverUrl);
    final nvidiaState = ref.read(nvidiaProvider);
    _nvidiaKeyController = TextEditingController(text: nvidiaState.apiKey);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nvidiaKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleBrowseWorkflow() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Selecciona tu archivo de workflow ComfyUI (.json)',
      );

      if (res.isNotEmpty && res.first.path != null) {
        ref.read(comfyUiProvider.notifier).setCustomWorkflowPath(res.first.path!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GrimoireTheme.accentEmerald,
              content: Text('Workflow vinculado: ${res.first.name}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error al seleccionar archivo: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final comfyState = ref.watch(comfyUiProvider);
    final serverInfo = comfyState.serverInfo;
    final activeWorkflow = comfyState.activeWorkflow;
    final nvidiaState = ref.watch(nvidiaProvider);

    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Container(
        width: 660,
        constraints: const BoxConstraints(maxHeight: 760),
        padding: const EdgeInsets.all(22),
        child: DefaultTabController(
          length: 2,
          initialIndex: widget.initialTab.clamp(0, 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                          ),
                          child: const Icon(Icons.hub_outlined, color: GrimoireTheme.accentPurple, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Motores de Inteligencia Artificial',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'ComfyUI Local en tu PC o Modelos NVIDIA NIM en la nube',
                                style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // TabBar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10121F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GrimoireTheme.borderSubtle),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: GrimoireTheme.surfacePanel,
                    border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.6)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: GrimoireTheme.textMuted,
                  tabs: [
                    Tab(
                      height: 38,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bolt,
                            size: 15,
                            color: serverInfo.isOnline ? GrimoireTheme.accentEmerald : GrimoireTheme.accentPurple,
                          ),
                          const SizedBox(width: 8),
                          const Text('ComfyUI Local', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: serverInfo.isOnline ? GrimoireTheme.accentEmerald : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      height: 38,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.memory, size: 15, color: Color(0xFF76B900)),
                          const SizedBox(width: 8),
                          const Text('NVIDIA NIM Cloud', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: nvidiaState.isConfigured ? const Color(0xFF76B900) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // TabBarView
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: ComfyUI Local Content
                    SingleChildScrollView(
                      child: _buildComfyUiTabContent(context, comfyState, serverInfo, activeWorkflow),
                    ),

                    // Tab 2: NVIDIA NIM Cloud Content
                    SingleChildScrollView(
                      child: _buildNvidiaTabContent(context, nvidiaState),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComfyUiTabContent(
    BuildContext context,
    ComfyUiState comfyState,
    ComfyUiServerInfo serverInfo,
    ComfyWorkflowItem activeWorkflow,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ComfyUI Status Banner
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Servidor Local ComfyUI',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  serverInfo.isOnline ? 'Servidor local operativo' : 'Servidor local no detectado',
                  style: TextStyle(
                    fontSize: 11,
                    color: serverInfo.isOnline ? GrimoireTheme.accentEmerald : GrimoireTheme.textMuted,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: serverInfo.isOnline ? const Color(0xFF064E3B) : const Color(0xFF450A0A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: serverInfo.isOnline ? GrimoireTheme.accentEmerald : Colors.redAccent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: serverInfo.isOnline ? GrimoireTheme.accentEmerald : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    serverInfo.isOnline ? 'EN LÍNEA' : 'DESCONECTADO',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: serverInfo.isOnline ? GrimoireTheme.accentEmerald : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Server URL Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10121F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DIRECCIÓN DEL SERVIDOR LOCAL (ENDPOINT)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 12.5, color: Colors.white, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.link, size: 16, color: GrimoireTheme.accentPurple),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          filled: true,
                          fillColor: const Color(0xFF151829),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: GrimoireTheme.borderSubtle),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GrimoireTheme.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: comfyState.isChecking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh, size: 15),
                    label: const Text('Comprobar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      ref.read(comfyUiProvider.notifier).setServerUrl(_urlController.text);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Workflows Explorer Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10121F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECCIÓN DE WORKFLOW DE COMFYUI',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary, letterSpacing: 0.8),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Selecciona qué flujo ejecutará Grimoire Studio al generar arte con IA',
                        style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: GrimoireTheme.accentEmerald),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.folder_open, size: 14, color: GrimoireTheme.accentEmerald),
                    label: const Text('Examinar .json', style: TextStyle(fontSize: 11, color: GrimoireTheme.accentEmerald)),
                    onPressed: _handleBrowseWorkflow,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (comfyState.availableWorkflows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161828),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GrimoireTheme.borderSubtle),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: GrimoireTheme.textMuted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No se encontraron workflows en la ruta predeterminada de ComfyUI. Puedes pulsar "Examinar .json" para cargar tu workflow manualmente.',
                          style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comfyState.availableWorkflows.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final wf = comfyState.availableWorkflows[i];
                    final isSelected = wf.name.toLowerCase() == activeWorkflow.name.toLowerCase() ||
                        wf.filePath.toLowerCase() == activeWorkflow.filePath.toLowerCase();
                    final isImageWf = wf.name.toLowerCase() == 'image';

                    return InkWell(
                      onTap: () {
                        ref.read(comfyUiProvider.notifier).selectWorkflowByName(wf.name);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? GrimoireTheme.accentPurple.withValues(alpha: 0.15)
                              : const Color(0xFF141727),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.borderSubtle,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 16,
                              color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        wf.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      if (isImageWf) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                                          ),
                                          child: const Text(
                                            'Recomendado',
                                            style: TextStyle(fontSize: 9, color: Color(0xFFE9D5FF), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (wf.description != null && wf.description!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      wf.description!,
                                      style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check, size: 16, color: GrimoireTheme.accentEmerald),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Action Button
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: GrimoireTheme.textMuted)),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GrimoireTheme.accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(
                'Usar Workflow "${activeWorkflow.name}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                ref.read(comfyUiProvider.notifier).setServerUrl(_urlController.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: GrimoireTheme.accentEmerald,
                    content: Text('Workflow "${activeWorkflow.name}" seleccionado como motor activo de ComfyUI.'),
                  ),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNvidiaTabContent(BuildContext context, NvidiaState nvidiaState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // NVIDIA Status Banner
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF76B900),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NVIDIA',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NVIDIA NIM Cloud & AI Foundation',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Modelos en la nube: Stable Diffusion 3 Medium, FLUX.1 y Meta Llama 3.1',
                          style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: nvidiaState.isConfigured ? const Color(0xFF064E3B) : const Color(0xFF451A03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: nvidiaState.isConfigured ? GrimoireTheme.accentEmerald : const Color(0xFFF59E0B),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: nvidiaState.isConfigured ? const Color(0xFF76B900) : const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    nvidiaState.isConfigured ? 'API KEY GUARDADA' : 'CLAVE PENDIENTE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: nvidiaState.isConfigured ? const Color(0xFF76B900) : const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // API Key Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF101713),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF76B900).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.key, size: 14, color: Color(0xFF76B900)),
                  SizedBox(width: 6),
                  Text(
                    'CLAVE DE ACCESO NVIDIA API (NVAPI-...)',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF76B900), letterSpacing: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tu API Key se almacena localmente de forma privada en .grimoire_ai_config.json para reutilizarla siempre.',
                style: TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _nvidiaKeyController,
                        obscureText: _obscureNvidiaKey,
                        style: const TextStyle(fontSize: 12.5, color: Colors.white, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'nvapi-...',
                          prefixIcon: const Icon(Icons.vpn_key, size: 16, color: Color(0xFF76B900)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNvidiaKey ? Icons.visibility_off : Icons.visibility,
                              size: 16,
                              color: GrimoireTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureNvidiaKey = !_obscureNvidiaKey),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF151C17),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF76B900)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF76B900),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.save, size: 15),
                    label: const Text('Guardar Clave', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final key = _nvidiaKeyController.text.trim();
                      await ref.read(nvidiaProvider.notifier).saveApiKey(key);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: GrimoireTheme.accentEmerald,
                            content: Text(ref.tr('nvidia_api_key_saved')),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF76B900)),
                      foregroundColor: const Color(0xFF76B900),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: nvidiaState.isTesting
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF76B900)),
                          )
                        : const Icon(Icons.network_check, size: 15),
                    label: const Text('Probar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: nvidiaState.isTesting
                        ? null
                        : () async {
                            final candidate = _nvidiaKeyController.text.trim();
                            await ref.read(nvidiaProvider.notifier).testConnection(candidate);
                          },
                  ),
                ],
              ),
              if (nvidiaState.statusMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: nvidiaState.testSuccess == true
                        ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                        : const Color(0xFF450A0A).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: nvidiaState.testSuccess == true ? GrimoireTheme.accentEmerald : Colors.redAccent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        nvidiaState.testSuccess == true ? Icons.check_circle : Icons.error_outline,
                        size: 14,
                        color: nvidiaState.testSuccess == true ? GrimoireTheme.accentEmerald : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nvidiaState.statusMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            color: nvidiaState.testSuccess == true ? const Color(0xFFD1FAE5) : const Color(0xFFFECACA),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Model Selector Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10121F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MODELO DE GENERACIÓN DE ARTE PRINCIPAL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary, letterSpacing: 0.8),
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: NvidiaService.availableImageModels.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final model = NvidiaService.availableImageModels[i];
                  final isSelected = model.id == nvidiaState.selectedModel;

                  return InkWell(
                    onTap: () {
                      ref.read(nvidiaProvider.notifier).setModel(model.id);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF76B900).withValues(alpha: 0.12)
                            : const Color(0xFF141727),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF76B900) : GrimoireTheme.borderSubtle,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 15,
                            color: isSelected ? const Color(0xFF76B900) : GrimoireTheme.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      model.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    if (model.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF76B900).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFF76B900).withValues(alpha: 0.4)),
                                        ),
                                        child: const Text(
                                          'Recomendado TCG',
                                          style: TextStyle(fontSize: 9, color: Color(0xFF76B900), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  model.description,
                                  style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Aspect Ratio row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'PROPORCIÓN DE SALIDA:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: NvidiaService.availableAspectRatios.map((ratio) {
                        final isSel = ratio == nvidiaState.aspectRatio;
                        final label = ratio == '1:1' ? '1:1 (Cuadrado)' : (ratio == '2:3' ? '2:3 (Carta)' : ratio);
                        return ChoiceChip(
                          label: Text(label, style: TextStyle(fontSize: 10.5, color: isSel ? Colors.black : Colors.white)),
                          selected: isSel,
                          selectedColor: const Color(0xFF76B900),
                          backgroundColor: const Color(0xFF161A26),
                          onSelected: (val) {
                            if (val) ref.read(nvidiaProvider.notifier).setAspectRatio(ratio);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick Tutorial Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141724),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: GrimoireTheme.borderSubtle),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '💡 ¿Cómo obtener tu API Key gratuita de NVIDIA?\n'
                  '1. Inicia sesión en build.nvidia.com\n'
                  '2. Selecciona un modelo como Stable Diffusion 3 Medium o Llama 3.1.\n'
                  '3. Haz clic en "Get API Key" y copia tu clave (empieza con nvapi-).\n'
                  '4. Pégala en este campo y pulsa "Guardar Clave".',
                  style: TextStyle(fontSize: 10.5, color: GrimoireTheme.textMuted, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Footer Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: GrimoireTheme.textMuted)),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF76B900),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text(
                'Usar Motor NVIDIA NIM',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                final key = _nvidiaKeyController.text.trim();
                ref.read(nvidiaProvider.notifier).saveApiKey(key);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: GrimoireTheme.accentEmerald,
                    content: Text('NVIDIA NIM configurado con modelo "${nvidiaState.selectedModel}".'),
                  ),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ],
    );
  }
}
