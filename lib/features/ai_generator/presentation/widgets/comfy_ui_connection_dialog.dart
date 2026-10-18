import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../services/comfy_ui_service.dart';
import '../providers/comfy_ui_provider.dart';

class ComfyUiConnectionDialog extends ConsumerStatefulWidget {
  const ComfyUiConnectionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ComfyUiConnectionDialog(),
    );
  }

  @override
  ConsumerState<ComfyUiConnectionDialog> createState() => _ComfyUiConnectionDialogState();
}

class _ComfyUiConnectionDialogState extends ConsumerState<ComfyUiConnectionDialog> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    final comfyState = ref.read(comfyUiProvider);
    _urlController = TextEditingController(text: comfyState.serverUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
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

    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(22),
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
                              'Motor de Inteligencia Artificial (ComfyUI)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Conexión y selección de workflows para ComfyUI Local en tu PC',
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
            const SizedBox(height: 16),

            // Content
            Flexible(
              child: SingleChildScrollView(
                child: _buildComfyUiTabContent(context, comfyState, serverInfo, activeWorkflow),
              ),
            ),
          ],
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
}
