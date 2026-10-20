import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../services/onboarding_service.dart';

class OnboardingStepItem {
  final IconData icon;
  final Color accentColor;
  final String titleKey;
  final String descKey;
  final int? tabIndex;
  final String? shortcut;
  final List<OnboardingHighlight> highlights;

  const OnboardingStepItem({
    required this.icon,
    required this.accentColor,
    required this.titleKey,
    required this.descKey,
    this.tabIndex,
    this.shortcut,
    required this.highlights,
  });
}

class OnboardingHighlight {
  final String emoji;
  final String title;
  final String description;

  const OnboardingHighlight({
    required this.emoji,
    required this.title,
    required this.description,
  });
}

class GrimoireOnboardingDialog extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const GrimoireOnboardingDialog({
    super.key,
    this.onNavigateToTab,
  });

  static Future<void> show(
    BuildContext context, {
    ValueChanged<int>? onNavigateToTab,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => GrimoireOnboardingDialog(
        onNavigateToTab: onNavigateToTab,
      ),
    );
  }

  @override
  ConsumerState<GrimoireOnboardingDialog> createState() => _GrimoireOnboardingDialogState();
}

class _GrimoireOnboardingDialogState extends ConsumerState<GrimoireOnboardingDialog> {
  int _currentStep = 0;
  bool _dontShowAgain = true;

  final List<OnboardingStepItem> _steps = const [
    OnboardingStepItem(
      icon: Icons.auto_awesome,
      accentColor: GrimoireTheme.accentPurple,
      titleKey: 'onboarding_welcome_title',
      descKey: 'onboarding_welcome_desc',
      highlights: [
        OnboardingHighlight(
          emoji: '🎴',
          title: 'All-in-One Studio',
          description: 'Designed specifically for trading card games, board games, and custom card projects.',
        ),
        OnboardingHighlight(
          emoji: '⚡',
          title: 'Speed & Data Automation',
          description: 'Iterate effortlessly from single prototypes to full 100+ card expansions with CSV data.',
        ),
        OnboardingHighlight(
          emoji: '🖨️',
          title: 'Prepress & Virtual Play',
          description: 'Export 300 DPI CMYK-ready PDFs with bleed, or playtest instantly on the virtual mat.',
        ),
      ],
    ),
    OnboardingStepItem(
      icon: Icons.collections_bookmark_outlined,
      accentColor: GrimoireTheme.accentPurple,
      titleKey: 'onboarding_gallery_title',
      descKey: 'onboarding_gallery_desc',
      tabIndex: 0,
      shortcut: 'Ctrl+1',
      highlights: [
        OnboardingHighlight(
          emoji: '🏷️',
          title: 'Archetypes & Categories',
          description: 'Group cards by archetype (Creatures, Spells, Items) with clean emoji icons.',
        ),
        OnboardingHighlight(
          emoji: '🔍',
          title: 'Visual Filters & Search',
          description: 'Filter by cost, stats, or tags with Spotlight search (Ctrl+K) for instant navigation.',
        ),
        OnboardingHighlight(
          emoji: '✨',
          title: 'Card Management',
          description: 'Duplicate cards, customize presets, and track deck metrics in real time.',
        ),
      ],
    ),
    OnboardingStepItem(
      icon: Icons.palette_outlined,
      accentColor: GrimoireTheme.accentIndigo,
      titleKey: 'onboarding_editor_title',
      descKey: 'onboarding_editor_desc',
      tabIndex: 1,
      shortcut: 'Ctrl+2',
      highlights: [
        OnboardingHighlight(
          emoji: '🔄',
          title: 'Dual-Sided Canvas',
          description: 'Switch between Front and Back face to design card backs and flip mechanics.',
        ),
        OnboardingHighlight(
          emoji: '✏️',
          title: 'WYSIWYG Inline Editing',
          description: 'Double-click any canvas text to edit directly, and resize layers with 8 handles.',
        ),
        OnboardingHighlight(
          emoji: '📐',
          title: 'Shapes & Google Fonts',
          description: 'Curated TCG typography, gradient presets, corner radius, and custom polygon node editor.',
        ),
      ],
    ),
    OnboardingStepItem(
      icon: Icons.table_chart_outlined,
      accentColor: GrimoireTheme.accentEmerald,
      titleKey: 'onboarding_database_title',
      descKey: 'onboarding_database_desc',
      tabIndex: 2,
      shortcut: 'Ctrl+3',
      highlights: [
        OnboardingHighlight(
          emoji: '📊',
          title: 'Built-in Spreadsheet',
          description: 'View and edit your card database with instant auto-save to data.csv.',
        ),
        OnboardingHighlight(
          emoji: '🔗',
          title: 'Dynamic Variables',
          description: 'Use {{card_name}}, {{cost}}, or {{rules_text}} on layers to automatically pull row values.',
        ),
        OnboardingHighlight(
          emoji: '🚀',
          title: 'Batch Generation',
          description: 'Create dozens or hundreds of balanced cards in seconds without manual editing.',
        ),
      ],
    ),
    OnboardingStepItem(
      icon: Icons.casino_outlined,
      accentColor: GrimoireTheme.accentCyan,
      titleKey: 'onboarding_playtest_title',
      descKey: 'onboarding_playtest_desc',
      tabIndex: 3,
      shortcut: 'Ctrl+4 & Ctrl+E',
      highlights: [
        OnboardingHighlight(
          emoji: '🎲',
          title: 'Interactive Playmat',
          description: 'Simulate tabletop gameplay in Solo or Duel mode (1-8 players) with dice, counters & tokens.',
        ),
        OnboardingHighlight(
          emoji: '🖨️',
          title: '300 DPI Pre-flight Prepress',
          description: 'Generate commercial print PDFs with 3mm bleed margin and guillotine vector crop marks.',
        ),
        OnboardingHighlight(
          emoji: '🌐',
          title: 'Tabletop Simulator & Web 3D',
          description: 'Export TTS sprite sheets with TXT configs, or self-contained interactive 3D Web showcases.',
        ),
      ],
    ),
  ];

  void _finishTour({int? jumpToTab}) {
    if (_dontShowAgain) {
      OnboardingService.setOnboardingCompleted(completed: true);
    }
    Navigator.of(context).pop();
    if (jumpToTab != null) {
      widget.onNavigateToTab?.call(jumpToTab);
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _finishTour(jumpToTab: 0);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Dialog(
      backgroundColor: GrimoireTheme.surfacePanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: step.accentColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 660),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Badge, Step Indicator & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [step.accentColor, GrimoireTheme.accentIndigo],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(step.icon, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.tr('app_tour'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          ref.tr('onboarding_step_counter')
                              .replaceAll('{current}', '${_currentStep + 1}')
                              .replaceAll('{total}', '${_steps.length}'),
                          style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                  onPressed: () => _finishTour(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Step Content Area
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Title & Description
                    Text(
                      ref.tr(step.titleKey),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ref.tr(step.descKey),
                      style: const TextStyle(fontSize: 12.5, color: GrimoireTheme.textSecondary, height: 1.45),
                    ),
                    const SizedBox(height: 16),

                    // Feature Highlights Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101322),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GrimoireTheme.borderSubtle),
                      ),
                      child: Column(
                        children: step.highlights.map((h) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.emoji, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        h.title,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        h.description,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: GrimoireTheme.textMuted,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    if (step.shortcut != null || step.tabIndex != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (step.shortcut != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.keyboard_outlined, size: 14, color: GrimoireTheme.textMuted),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF181C2E),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: GrimoireTheme.borderSubtle),
                                  ),
                                  child: Text(
                                    step.shortcut!,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFFE9D5FF), fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                          if (step.tabIndex != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: step.accentColor,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.arrow_outward, size: 14),
                              label: Text(
                                ref.tr('onboarding_jump_to'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              onPressed: () => _finishTour(jumpToTab: step.tabIndex),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Footer Navigation Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Checkbox: Don't show again on startup
                  InkWell(
                    onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: Checkbox(
                              value: _dontShowAgain,
                              activeColor: GrimoireTheme.accentPurple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) => setState(() => _dontShowAgain = val ?? true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ref.tr('onboarding_dont_show_again'),
                            style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Step Dots Indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_steps.length, (idx) {
                      final isSel = idx == _currentStep;
                      return InkWell(
                        onTap: () => setState(() => _currentStep = idx),
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isSel ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSel ? _steps[idx].accentColor : const Color(0xFF232840),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(width: 16),

                  // Action Buttons: Previous & Next / Finish
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentStep > 0) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: GrimoireTheme.borderSubtle),
                            foregroundColor: GrimoireTheme.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _previousStep,
                          child: Text(ref.tr('onboarding_previous'), style: const TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: GrimoireTheme.textMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () => _finishTour(),
                          child: Text(ref.tr('onboarding_skip'), style: const TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLast ? GrimoireTheme.accentEmerald : GrimoireTheme.accentPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(isLast ? Icons.check : Icons.arrow_forward, size: 14),
                        label: Text(
                          isLast ? ref.tr('onboarding_get_started') : ref.tr('onboarding_next'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _nextStep,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
