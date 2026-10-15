import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/grimoire_theme.dart';
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
    final state = ref.read(comfyUiProvider);
    _urlController = TextEditingController(text: state.serverUrl);
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
        width: 640,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.bolt, color: GrimoireTheme.accentPurple, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Conexión con ComfyUI & Motor de IA',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: serverInfo.isOnline
                          ? const Color(0xFF064E3B)
                          : const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: serverInfo.isOnline
                            ? GrimoireTheme.accentEmerald
                            : Colors.redAccent,
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
              const SizedBox(height: 20),

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
                    if (serverInfo.isOnline) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14182B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.memory, size: 16, color: GrimoireTheme.accentEmerald),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${serverInfo.gpuName ?? "GPU"} • VRAM: ${serverInfo.vramSummary ?? "N/A"} • v${serverInfo.comfyVersion ?? ""}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFD1FAE5), fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Active Workflow Section (Target: Image)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GrimoireTheme.accentPurple.withValues(alpha: 0.12),
                      const Color(0xFF10121F),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, color: GrimoireTheme.accentPurple, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'WORKFLOW ACTIVO DE COMFYUI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE9D5FF),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: GrimoireTheme.accentPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '🎯 ${activeWorkflow.name}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Grimoire Studio apunta directamente a este workflow para transformar las descripciones y prompts de tus cartas en ilustraciones de alta resolución.',
                      style: TextStyle(fontSize: 11.5, color: GrimoireTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    // Workflow Dropdown & File Picker
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF151829),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GrimoireTheme.borderSubtle),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: activeWorkflow.name,
                                dropdownColor: const Color(0xFF151829),
                                icon: const Icon(Icons.arrow_drop_down, color: GrimoireTheme.accentPurple),
                                isExpanded: true,
                                items: comfyState.availableWorkflows.map((item) {
                                  return DropdownMenuItem<String>(
                                    value: item.name,
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.name.toLowerCase() == 'image'
                                              ? Icons.auto_awesome
                                              : Icons.account_tree_outlined,
                                          size: 16,
                                          color: GrimoireTheme.accentPurple,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: item.name.toLowerCase() == 'image'
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (item.name.toLowerCase() == 'image')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Predeterminado', style: TextStyle(fontSize: 9.5, color: Color(0xFFE9D5FF))),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final found = comfyState.availableWorkflows.firstWhere((w) => w.name == val);
                                    ref.read(comfyUiProvider.notifier).selectWorkflow(found);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: GrimoireTheme.borderSubtle),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.folder_open, size: 15, color: GrimoireTheme.accentEmerald),
                          label: const Text('Examinar JSON', style: TextStyle(fontSize: 11.5)),
                          onPressed: _handleBrowseWorkflow,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Physical Path Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0D18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GrimoireTheme.borderSubtle.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, size: 14, color: GrimoireTheme.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeWorkflow.filePath,
                              style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: GrimoireTheme.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            icon: const Icon(Icons.copy, size: 13, color: GrimoireTheme.textMuted),
                            tooltip: 'Copiar ruta',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: activeWorkflow.filePath));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  duration: Duration(seconds: 2),
                                  content: Text('Ruta copiada al portapapeles'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Architecture Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141728),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GrimoireTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.hub_outlined, size: 14, color: GrimoireTheme.accentPurple),
                              SizedBox(width: 6),
                              Text(
                                'Mapeo de Nodos del Pipeline (Workflow: Image)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          const Divider(height: 16, color: GrimoireTheme.borderSubtle),
                          _buildNodeMappingRow('Subgrafo Principal', 'Anima Base v1.0 (circlestone-labs/Anima)'),
                          _buildNodeMappingRow('Prompt Positivo (Carta)', 'Nodo 90:77 • CLIPTextEncode'),
                          _buildNodeMappingRow('Prompt Negativo', 'Nodo 90:75 • CLIPTextEncode'),
                          _buildNodeMappingRow('Muestreo & Semilla', 'Nodo 90:76 • KSampler (Euler/Simple)'),
                          _buildNodeMappingRow('Salida de Imagen', 'Nodo 46 • SaveImage (Prefix: Grimoire)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
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
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Listo', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeMappingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: GrimoireTheme.textSecondary)),
          Text(
            value,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFC7D2FE), fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
