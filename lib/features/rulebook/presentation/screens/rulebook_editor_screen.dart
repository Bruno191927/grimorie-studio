import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../editor/presentation/providers/editor_provider.dart';
import '../../domain/models/rulebook_data.dart';
import '../../services/rulebook_service.dart';

class RulebookEditorScreen extends ConsumerStatefulWidget {
  const RulebookEditorScreen({super.key});

  @override
  ConsumerState<RulebookEditorScreen> createState() => _RulebookEditorScreenState();
}

class _RulebookEditorScreenState extends ConsumerState<RulebookEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RulebookData? _rulebook = const RulebookData(gameName: 'Magic');
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isExporting = false;
  String _lastGameName = '';

  // Controllers for general info
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _authorController = TextEditingController();
  final _playersController = TextEditingController();
  final _timeController = TextEditingController();
  final _ageController = TextEditingController();
  final _introController = TextEditingController();
  final _objectiveController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final editorState = ref.read(editorProvider);
        final activeRow = editorState.project.rows.isNotEmpty ? editorState.project.activeRow : <String, dynamic>{};
        final currentGame = (activeRow['game'] ?? 'Magic').toString();
        _loadRulebookForCurrentGame(currentGame);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _authorController.dispose();
    _playersController.dispose();
    _timeController.dispose();
    _ageController.dispose();
    _introController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }

  Future<void> _loadRulebookForCurrentGame(String gameName) async {
    if (_lastGameName == gameName && _rulebook != null && _rulebook!.gameName == gameName) return;
    _lastGameName = gameName;

    final editorState = ref.read(editorProvider);
    final rows = editorState.project.rows
        .where((r) => (r['game'] ?? 'Magic').toString().trim().toLowerCase() == gameName.trim().toLowerCase())
        .toList();

    final data = await RulebookService.loadRulebook(gameName, rows);
    _rulebook = data;

    _titleController.text = data.gameName;
    _subtitleController.text = data.subtitle;
    _authorController.text = data.author;
    _playersController.text = data.targetPlayers;
    _timeController.text = data.playTime;
    _ageController.text = data.ageRating;
    _introController.text = data.introduction;
    _objectiveController.text = data.objective;

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRulebook() async {
    if (_rulebook == null) return;
    setState(() => _isSaving = true);

    final updated = _rulebook!.copyWith(
      gameName: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      author: _authorController.text.trim(),
      targetPlayers: _playersController.text.trim(),
      playTime: _timeController.text.trim(),
      ageRating: _ageController.text.trim(),
      introduction: _introController.text.trim(),
      objective: _objectiveController.text.trim(),
    );
    _rulebook = updated;

    await RulebookService.saveRulebook(updated.gameName, updated);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GrimoireTheme.accentEmerald,
          duration: Duration(seconds: 2),
          content: Text('📖 Manual de reglas guardado correctamente.'),
        ),
      );
    }
  }

  Future<void> _syncFromDatabase() async {
    if (_rulebook == null) return;
    final editorState = ref.read(editorProvider);
    final gameName = _rulebook!.gameName;
    final rows = editorState.project.rows
        .where((r) => (r['game'] ?? 'Magic').toString().trim().toLowerCase() == gameName.trim().toLowerCase())
        .toList();

    final synced = RulebookService.autoSyncComponents(_rulebook!, rows);
    setState(() {
      _rulebook = synced;
    });
    await _saveRulebook();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GrimoireTheme.accentPurple,
          content: Text('✨ Componentes sincronizados (${synced.components.length} categorías detectadas).'),
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    if (_rulebook == null) return;
    await _saveRulebook();
    setState(() => _isExporting = true);

    try {
      final file = await RulebookService.exportRulebookPdf(_rulebook!);
      if (mounted) {
        setState(() => _isExporting = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: GrimoireTheme.surfaceCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: GrimoireTheme.accentEmerald),
                SizedBox(width: 8),
                Text('Manual Exportado con Éxito', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'El manual de reglas ha sido generado en formato folleto A5 listo para imprimir o distribuir digitalmente.',
                  style: TextStyle(color: GrimoireTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GrimoireTheme.borderSubtle),
                  ),
                  child: SelectableText(
                    file.path,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: GrimoireTheme.accentGold),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Abrir Carpeta'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Process.run('explorer.exe', ['/select,', file.path]);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Error al exportar PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final activeRow = editorState.project.rows.isNotEmpty ? editorState.project.activeRow : <String, dynamic>{};
    final currentGame = (activeRow['game'] ?? 'Magic').toString();

    if (_lastGameName.isNotEmpty && _lastGameName != currentGame) {
      _lastGameName = currentGame;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadRulebookForCurrentGame(currentGame);
      });
    }

    if (_rulebook == null) {
      return const Scaffold(
        backgroundColor: GrimoireTheme.bgDark,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: GrimoireTheme.bgDark,
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: GrimoireTheme.surfaceCard,
              border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: GrimoireTheme.accentPurple, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Creador del Manual de Reglas (Rulebook Builder)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: GrimoireTheme.accentGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: GrimoireTheme.accentGold.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              _rulebook!.gameName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrimoireTheme.accentGold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Diseña, redacta y exporta el reglamento oficial en formato folleto PDF para tu juego.',
                        style: TextStyle(fontSize: 11.5, color: GrimoireTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF67E8F9),
                    side: BorderSide(color: const Color(0xFF67E8F9).withValues(alpha: 0.5)),
                  ),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sincronizar Componentes'),
                  onPressed: _syncFromDatabase,
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GrimoireTheme.accentEmerald,
                    side: BorderSide(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.5)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Guardar'),
                  onPressed: _isSaving ? null : _saveRulebook,
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: GrimoireTheme.accentGold,
                    foregroundColor: Colors.black,
                  ),
                  icon: _isExporting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Exportar Manual PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isExporting ? null : _exportPdf,
                ),
              ],
            ),
          ),

          // Tabs Navigation
          Container(
            color: const Color(0xFF141726),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: GrimoireTheme.accentGold,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: GrimoireTheme.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              tabs: const [
                Tab(icon: Icon(Icons.article_outlined, size: 17), text: '1. Info & Lore'),
                Tab(icon: Icon(Icons.inventory_2_outlined, size: 17), text: '2. Componentes'),
                Tab(icon: Icon(Icons.flag_outlined, size: 17), text: '3. Objetivo & Setup'),
                Tab(icon: Icon(Icons.replay_circle_filled_outlined, size: 17), text: '4. Fases de Turno'),
                Tab(icon: Icon(Icons.style_outlined, size: 17), text: '5. Anatomía de Carta'),
                Tab(icon: Icon(Icons.help_outline, size: 17), text: '6. Glosario & FAQ'),
                Tab(icon: Icon(Icons.auto_stories, size: 17), text: '7. Vista Previa Folleto'),
              ],
            ),
          ),

          // Tab Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoAndLoreTab(),
                _buildComponentsTab(),
                _buildObjectiveAndSetupTab(),
                _buildTurnPhasesTab(),
                _buildCardAnatomyTab(),
                _buildGlossaryAndFaqTab(),
                _buildLiveBookletPreviewTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: INFO & LORE ---
  Widget _buildInfoAndLoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Información General del Juego', 'Detalles editoriales, título y público objetivo'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField('Nombre del Juego', _titleController),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: _buildTextField('Subtítulo o Versión', _subtitleController),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTextField('Autor / Estudio', _authorController),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildTextField('Jugadores (ej. 2 - 4)', _playersController)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildTextField('Duración (ej. 30 - 45 min)', _timeController)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildTextField('Edad Recomendada', _ageController)),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Introducción & Ambientación (Lore)', 'El trasfondo narrativo que sumerge a los jugadores en tu mundo'),
              const SizedBox(height: 12),
              _buildTextArea('Historia y Contexto', _introController, minLines: 4),
              const SizedBox(height: 20),
              _buildSectionTitle('Objetivo del Juego', '¿Cómo gana un jugador la partida?'),
              const SizedBox(height: 12),
              _buildTextArea('Condición de Victoria', _objectiveController, minLines: 3),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 2: COMPONENTES ---
  Widget _buildComponentsTab() {
    final comps = _rulebook!.components;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Inventario & Componentes del Juego', 'Desglose exacto de cartas y accesorios incluidos en la caja'),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir Componente'),
                    onPressed: () {
                      setState(() {
                        _rulebook = _rulebook!.copyWith(
                          components: [
                            ..._rulebook!.components,
                            const RulebookComponentItem(name: 'Nuevo Componente', quantity: 1, category: 'Token', description: 'Descripción'),
                          ],
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (comps.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GrimoireTheme.borderSubtle),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 40, color: GrimoireTheme.textMuted),
                        const SizedBox(height: 10),
                        const Text('No hay componentes registrados.', style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 6),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.sync),
                          label: const Text('Auto-sincronizar desde Base de Datos'),
                          onPressed: _syncFromDatabase,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comps.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final item = comps[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: GrimoireTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GrimoireTheme.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: GrimoireTheme.accentGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GrimoireTheme.accentGold.withValues(alpha: 0.4)),
                            ),
                            child: Center(
                              child: Text(
                                '${item.quantity}x',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: GrimoireTheme.accentGold, fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: item.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              decoration: const InputDecoration(labelText: 'Nombre Componente', isDense: true),
                              onChanged: (val) {
                                final updated = List<RulebookComponentItem>.from(_rulebook!.components);
                                updated[idx] = item.copyWith(name: val);
                                _rulebook = _rulebook!.copyWith(components: updated);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              initialValue: item.description,
                              style: const TextStyle(color: GrimoireTheme.textSecondary, fontSize: 12),
                              decoration: const InputDecoration(labelText: 'Descripción / Rol en el juego', isDense: true),
                              onChanged: (val) {
                                final updated = List<RulebookComponentItem>.from(_rulebook!.components);
                                updated[idx] = item.copyWith(description: val);
                                _rulebook = _rulebook!.copyWith(components: updated);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              final updated = List<RulebookComponentItem>.from(_rulebook!.components)..removeAt(idx);
                              setState(() {
                                _rulebook = _rulebook!.copyWith(components: updated);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 3: OBJETIVO & PREPARACIÓN ---
  Widget _buildObjectiveAndSetupTab() {
    final steps = _rulebook!.setupSteps;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Pasos de Preparación (Setup)', 'Instrucciones paso a paso para colocar la mesa antes de jugar'),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir Paso'),
                    onPressed: () {
                      setState(() {
                        _rulebook = _rulebook!.copyWith(
                          setupSteps: [..._rulebook!.setupSteps, 'Nuevo paso de preparación.'],
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: steps.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GrimoireTheme.borderSubtle),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: GrimoireTheme.accentPurple,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: steps[idx],
                            maxLines: 2,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                            onChanged: (val) {
                              final updated = List<String>.from(_rulebook!.setupSteps);
                              updated[idx] = val;
                              _rulebook = _rulebook!.copyWith(setupSteps: updated);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            final updated = List<String>.from(_rulebook!.setupSteps)..removeAt(idx);
                            setState(() {
                              _rulebook = _rulebook!.copyWith(setupSteps: updated);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 4: FASES DE TURNO ---
  Widget _buildTurnPhasesTab() {
    final phases = _rulebook!.turnPhases;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Estructura del Turno de Juego', 'Secuencia ordenada de fases que cada jugador ejecuta en su ronda'),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir Fase'),
                    onPressed: () {
                      setState(() {
                        final newNum = _rulebook!.turnPhases.length + 1;
                        _rulebook = _rulebook!.copyWith(
                          turnPhases: [
                            ..._rulebook!.turnPhases,
                            RulebookPhase(phaseNumber: newNum, name: 'Fase $newNum', shortSummary: 'Resumen', details: 'Detalles de la fase.'),
                          ],
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: phases.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final p = phases[idx];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GrimoireTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GrimoireTheme.accentGold.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: GrimoireTheme.accentGold,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'FASE ${p.phaseNumber}',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: p.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: const InputDecoration(labelText: 'Nombre de la Fase', isDense: true),
                                onChanged: (val) {
                                  final updated = List<RulebookPhase>.from(_rulebook!.turnPhases);
                                  updated[idx] = p.copyWith(name: val);
                                  _rulebook = _rulebook!.copyWith(turnPhases: updated);
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                final updated = List<RulebookPhase>.from(_rulebook!.turnPhases)..removeAt(idx);
                                setState(() {
                                  _rulebook = _rulebook!.copyWith(turnPhases: updated);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          initialValue: p.shortSummary,
                          style: const TextStyle(color: GrimoireTheme.accentGold, fontSize: 12),
                          decoration: const InputDecoration(labelText: 'Resumen Rápido / Subtítulo', isDense: true),
                          onChanged: (val) {
                            final updated = List<RulebookPhase>.from(_rulebook!.turnPhases);
                            updated[idx] = p.copyWith(shortSummary: val);
                            _rulebook = _rulebook!.copyWith(turnPhases: updated);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: p.details,
                          maxLines: 2,
                          style: const TextStyle(color: GrimoireTheme.textSecondary, fontSize: 12),
                          decoration: const InputDecoration(labelText: 'Reglas y acciones permitidas durante esta fase', isDense: true),
                          onChanged: (val) {
                            final updated = List<RulebookPhase>.from(_rulebook!.turnPhases);
                            updated[idx] = p.copyWith(details: val);
                            _rulebook = _rulebook!.copyWith(turnPhases: updated);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 5: ANATOMÍA DE CARTA ---
  Widget _buildCardAnatomyTab() {
    final anatomy = _rulebook!.cardAnatomy;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Anatomía de una Carta', 'Guía visual para que los jugadores reconozcan cada icono, número y elemento'),
              const SizedBox(height: 16),
              ...anatomy.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GrimoireTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.crop_original, size: 18, color: GrimoireTheme.accentPurple),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 180,
                        child: Text(
                          entry.key,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: entry.value,
                          style: const TextStyle(color: GrimoireTheme.textSecondary, fontSize: 12),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          onChanged: (val) {
                            final updated = Map<String, String>.from(_rulebook!.cardAnatomy);
                            updated[entry.key] = val;
                            _rulebook = _rulebook!.copyWith(cardAnatomy: updated);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 6: GLOSARIO & FAQ ---
  Widget _buildGlossaryAndFaqTab() {
    final glossary = _rulebook!.glossary;
    final faqs = _rulebook!.faqs;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Glosario de Palabras Clave & Símbolos', 'Definición de habilidades comunes como {T}, {fire}, {skull}, etc.'),
              const SizedBox(height: 14),
              ...glossary.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GrimoireTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: Text(
                          entry.key,
                          style: const TextStyle(color: GrimoireTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: entry.value,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          onChanged: (val) {
                            final updated = Map<String, String>.from(_rulebook!.glossary);
                            updated[entry.key] = val;
                            _rulebook = _rulebook!.copyWith(glossary: updated);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Preguntas Frecuentes (FAQ)', 'Respuestas a dudas y situaciones límite habituales'),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: GrimoireTheme.accentPurple),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir FAQ'),
                    onPressed: () {
                      setState(() {
                        _rulebook = _rulebook!.copyWith(
                          faqs: [
                            ..._rulebook!.faqs,
                            const RulebookFaqItem(question: '¿Nueva Pregunta?', answer: 'Respuesta detallada.'),
                          ],
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...faqs.asMap().entries.map((entry) {
                final idx = entry.key;
                final faq = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: GrimoireTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GrimoireTheme.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: faq.question,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              decoration: const InputDecoration(labelText: 'Pregunta (P)', isDense: true),
                              onChanged: (val) {
                                final updated = List<RulebookFaqItem>.from(_rulebook!.faqs);
                                updated[idx] = faq.copyWith(question: val);
                                _rulebook = _rulebook!.copyWith(faqs: updated);
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              final updated = List<RulebookFaqItem>.from(_rulebook!.faqs)..removeAt(idx);
                              setState(() {
                                _rulebook = _rulebook!.copyWith(faqs: updated);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: faq.answer,
                        maxLines: 2,
                        style: const TextStyle(color: GrimoireTheme.textSecondary, fontSize: 12),
                        decoration: const InputDecoration(labelText: 'Respuesta (R)', isDense: true),
                        onChanged: (val) {
                          final updated = List<RulebookFaqItem>.from(_rulebook!.faqs);
                          updated[idx] = faq.copyWith(answer: val);
                          _rulebook = _rulebook!.copyWith(faqs: updated);
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 7: VISTA PREVIA DEL FOLLETO ---
  Widget _buildLiveBookletPreviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GrimoireTheme.accentGold, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'MANUAL OFICIAL DE REGLAS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GrimoireTheme.accentGold, letterSpacing: 2.5),
              ),
              const SizedBox(height: 10),
              Text(
                _titleController.text.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (_subtitleController.text.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _subtitleController.text,
                  style: const TextStyle(fontSize: 13, color: GrimoireTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              Container(width: 80, height: 2, color: GrimoireTheme.accentGold),
              const SizedBox(height: 20),

              // Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPreviewBadge('👥 ${_playersController.text}'),
                  const SizedBox(width: 12),
                  _buildPreviewBadge('⏳ ${_timeController.text}'),
                  const SizedBox(width: 12),
                  _buildPreviewBadge('🎯 Edad: ${_ageController.text}'),
                ],
              ),
              const SizedBox(height: 24),

              // Lore narrative
              if (_introController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    _introController.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0), height: 1.5, fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 24),

              // Objective
              if (_objectiveController.text.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF451A03).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GrimoireTheme.accentGold.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🏆 OBJETIVO DE LA PARTIDA',
                        style: TextStyle(fontWeight: FontWeight.bold, color: GrimoireTheme.accentGold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _objectiveController.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Quick action button
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: GrimoireTheme.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                label: const Text('Descargar Folleto Completo en PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _exportPdf,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: GrimoireTheme.textMuted)),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: GrimoireTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: GrimoireTheme.surfaceCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrimoireTheme.borderSubtle)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrimoireTheme.accentPurple)),
      ),
    );
  }

  Widget _buildTextArea(String label, TextEditingController controller, {int minLines = 3}) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: null,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: GrimoireTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: GrimoireTheme.surfaceCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrimoireTheme.borderSubtle)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GrimoireTheme.accentPurple)),
      ),
    );
  }
}
