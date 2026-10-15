import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/grimoire_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/editor/presentation/screens/editor_screen.dart';
import 'features/gallery/presentation/screens/card_gallery_screen.dart';
import 'features/database/presentation/widgets/data_table_view.dart';
import 'features/playtest/presentation/screens/playtest_screen.dart';
import 'features/editor/presentation/providers/editor_provider.dart';
import 'core/localization/locale_provider.dart';
import 'core/localization/language_selector.dart';
import 'features/export/presentation/dialogs/export_options_dialog.dart';
import 'features/ai_generator/presentation/widgets/comfy_ui_connection_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: GrimoireApp(),
    ),
  );
}

class GrimoireApp extends StatelessWidget {
  const GrimoireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: GrimoireTheme.darkTheme,
      home: const GrimoireMainShell(),
    );
  }
}

class GrimoireMainShell extends ConsumerStatefulWidget {
  const GrimoireMainShell({super.key});

  @override
  ConsumerState<GrimoireMainShell> createState() => _GrimoireMainShellState();
}

class _GrimoireMainShellState extends ConsumerState<GrimoireMainShell> {
  int _currentTab = 0; // 0: Gallery, 1: Editor, 2: Database, 3: Playtest
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  void _showAiEngineStatusDialog() {
    ComfyUiConnectionDialog.show(context);
  }

  Future<void> _handleBatchExport() async {
    final project = ref.read(editorProvider).project;
    if (project.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available to export.')),
      );
      return;
    }

    await ExportOptionsDialog.show(
      context,
      repaintBoundaryKey: _repaintBoundaryKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrimoireTheme.bgCanvas,
      body: Column(
        children: [
          // Global App Header Bar (Inspired by the Reference Image)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: GrimoireTheme.surfacePanel,
              border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Section: Logo & Nav Tabs
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo & Brand Name
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [GrimoireTheme.accentPurple, GrimoireTheme.accentIndigo, GrimoireTheme.accentPink],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: GrimoireTheme.accentPurple.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.local_fire_department, color: Colors.white, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Grimoire ',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const Text(
                                  'Studio',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: GrimoireTheme.accentPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 28),

                            // Navigation Tabs
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildNavTab(0, ref.tr('nav_gallery'), Icons.collections_bookmark_outlined),
                                const SizedBox(width: 8),
                                _buildNavTab(1, ref.tr('nav_editor'), Icons.palette_outlined),
                                const SizedBox(width: 8),
                                _buildNavTab(2, ref.tr('nav_database'), Icons.table_chart_outlined),
                                const SizedBox(width: 8),
                                _buildNavTab(3, ref.tr('nav_playtest'), Icons.casino_outlined),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(width: 24),

                        // Right Section: Language Selector & Action Buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Language Selector (ES / EN)
                            const LanguageSelector(),
                            const SizedBox(width: 12),

                            // Action: Connect AI Engine Button (Styled like "Wallet Connect" in the reference image)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: GrimoireTheme.accentPurple.withValues(alpha: 0.6)),
                                backgroundColor: const Color(0xFF16172B),
                                foregroundColor: const Color(0xFFE9D5FF),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.bolt, size: 16, color: GrimoireTheme.accentPurple),
                              label: Text(ref.tr('btn_connect_ai'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              onPressed: _showAiEngineStatusDialog,
                            ),
                            const SizedBox(width: 12),

                            // Batch 300 DPI Export Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GrimoireTheme.accentPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.archive_outlined, size: 16),
                              label: Text(ref.tr('btn_batch_export')),
                              onPressed: _handleBatchExport,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main Screen Body
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                // 0: Card Gallery (Visual style matching the reference image)
                CardGalleryScreen(
                  onOpenEditor: () {
                    setState(() => _currentTab = 1);
                  },
                ),

                // 1: Canvas Editor (Three-panel interactive layout)
                EditorScreen(repaintBoundaryKey: _repaintBoundaryKey),

                // 2: Database Table & CSV Importer
                const DataTableView(),

                // 3: Tabletop Playtesting Mat
                const PlaytestScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab(int index, String label, IconData icon) {
    final isSelected = _currentTab == index;

    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? GrimoireTheme.accentPurple.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? GrimoireTheme.accentPurple : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

