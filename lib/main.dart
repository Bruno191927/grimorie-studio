import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
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
import 'core/widgets/keyboard_shortcuts_dialog.dart';
import 'core/widgets/quick_card_search_dialog.dart';
import 'core/widgets/grimoire_toast.dart';
import 'features/onboarding/services/onboarding_service.dart';
import 'features/onboarding/presentation/dialogs/grimoire_onboarding_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!OnboardingService.hasSeenOnboarding()) {
        GrimoireOnboardingDialog.show(
          context,
          onNavigateToTab: (tabIndex) {
            if (mounted) {
              setState(() => _currentTab = tabIndex);
            }
          },
        );
      }
    });
  }

  Future<void> _handleBatchExport() async {
    final project = ref.read(editorProvider).project;
    if (project.rows.isEmpty) {
      GrimoireToast.warning(context, 'No cards available to export.');
      return;
    }

    await ExportOptionsDialog.show(
      context,
      repaintBoundaryKey: _repaintBoundaryKey,
    );
  }

  Future<void> _handleImportGrimoire() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['grimoire', 'zip'],
        dialogTitle: 'Seleccionar paquete de juego Grimoire Studio (.grimoire / .zip)',
      );

      if (files.isEmpty || files.first.path == null) {
        return;
      }

      final file = File(files.first.path!);
      final result = await ref.read(editorProvider.notifier).importGrimoirePackage(file);
      if (!mounted) return;

      if (result.success) {
        GrimoireToast.success(context, result.message);
      } else {
        GrimoireToast.error(context, result.message);
      }
    } catch (e) {
      if (mounted) {
        GrimoireToast.error(context, 'Error al importar paquete: $e');
      }
    }
  }

  Future<void> _handleSaveProject() async {
    await ref.read(editorProvider.notifier).saveActiveProjectAndCsv();
    if (mounted) {
      GrimoireToast.success(
        context,
        'Proyecto y CSV guardados con éxito (Ctrl+S)',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _handleSaveProject,
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): _handleBatchExport,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _handleImportGrimoire,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => QuickCardSearchDialog.show(
              context,
              onCardSelected: () => setState(() => _currentTab = 1),
            ),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true, shift: true): () =>
            ref.read(editorProvider.notifier).toggleBleedGuides(),
        const SingleActivator(LogicalKeyboardKey.slash, control: true): () => KeyboardShortcutsDialog.show(context),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => setState(() => _currentTab = 0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => setState(() => _currentTab = 1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => setState(() => _currentTab = 2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => setState(() => _currentTab = 3),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: GrimoireTheme.bgCanvas,
          body: Column(
            children: [
              // Global App Header Bar
              Container(
                height: 60,
                padding: const EdgeInsets.only(left: 18, right: 36),
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
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.asset(
                                          'assets/app_icon.png',
                                          fit: BoxFit.contain,
                                        ),
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
                                const SizedBox(width: 20),

                                // Navigation Tabs with Hotkeys
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildNavTab(0, ref.tr('nav_gallery'), Icons.collections_bookmark_outlined),
                                    const SizedBox(width: 6),
                                    _buildNavTab(1, ref.tr('nav_editor'), Icons.palette_outlined),
                                    const SizedBox(width: 6),
                                    _buildNavTab(2, ref.tr('nav_database'), Icons.table_chart_outlined),
                                    const SizedBox(width: 6),
                                    _buildNavTab(3, ref.tr('nav_playtest'), Icons.casino_outlined),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(width: 16),

                            // Center: Quick Spotlight Card Search Bar
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => QuickCardSearchDialog.show(
                                context,
                                onCardSelected: () => setState(() => _currentTab = 1),
                              ),
                              child: Container(
                                width: 200,
                                height: 34,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131625),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: GrimoireTheme.borderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search, size: 16, color: GrimoireTheme.textMuted),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ref.tr('search_cards_tags'),
                                        style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E2235),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF2E3550)),
                                      ),
                                      child: const Text('Ctrl+K', style: TextStyle(fontSize: 9.5, color: GrimoireTheme.textSecondary, fontFamily: 'monospace')),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Right Section: Onboarding Guide, Shortcuts Helper & Language Selector
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Interactive Onboarding Tour Button
                                IconButton(
                                  tooltip: ref.tr('app_tour_tooltip'),
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF141726),
                                    side: const BorderSide(color: GrimoireTheme.borderSubtle),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  icon: const Icon(Icons.school_outlined, size: 16, color: GrimoireTheme.accentPurple),
                                  onPressed: () => GrimoireOnboardingDialog.show(
                                    context,
                                    onNavigateToTab: (tabIndex) {
                                      if (mounted) {
                                        setState(() => _currentTab = tabIndex);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Keyboard Shortcuts Helper Button
                                IconButton(
                                  tooltip: ref.tr('keyboard_shortcuts'),
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF141726),
                                    side: const BorderSide(color: GrimoireTheme.borderSubtle),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  icon: const Icon(Icons.keyboard_outlined, size: 16, color: GrimoireTheme.textSecondary),
                                  onPressed: () => KeyboardShortcutsDialog.show(context),
                                ),
                                const SizedBox(width: 8),

                                // Language Selector (ES / EN)
                                const LanguageSelector(),
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
                        ref.read(editorProvider.notifier).syncActiveTemplateWithActiveRow();
                        setState(() => _currentTab = 1);
                      },
                      onBatchExport: _handleBatchExport,
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
        ),
      ),
    );
  }

  Widget _buildNavTab(int index, String label, IconData icon) {
    final isSelected = _currentTab == index;
    final shortcutNumber = index + 1;

    return InkWell(
      onTap: () {
        if (index == 1) {
          ref.read(editorProvider.notifier).syncActiveTemplateWithActiveRow();
        }
        setState(() => _currentTab = index);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? GrimoireTheme.accentPurple.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? GrimoireTheme.accentPurple.withValues(alpha: 0.8) : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? GrimoireTheme.accentPurple : GrimoireTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : GrimoireTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? GrimoireTheme.accentPurple.withValues(alpha: 0.3)
                    : const Color(0xFF191D2F),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$shortcutNumber',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFFE9D5FF) : GrimoireTheme.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
