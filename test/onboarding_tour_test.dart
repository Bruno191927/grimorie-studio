import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';
import 'package:grimoire_studio/features/onboarding/services/onboarding_service.dart';
import 'package:grimoire_studio/features/onboarding/presentation/dialogs/grimoire_onboarding_dialog.dart';

void main() {
  setUp(() {
    OnboardingService.setForceTestMode(false);
    OnboardingService.setInMemoryOverride(null);
  });

  tearDown(() {
    OnboardingService.setForceTestMode(false);
    OnboardingService.setInMemoryOverride(null);
  });

  group('OnboardingService Unit Tests', () {
    test('Default in test environment treats onboarding as seen to prevent test disruption', () {
      expect(OnboardingService.hasSeenOnboarding(), isTrue);
    });

    test('When forceTestMode is active and memory override is false, returns false', () {
      OnboardingService.setForceTestMode(true);
      OnboardingService.setInMemoryOverride(false);
      expect(OnboardingService.hasSeenOnboarding(), isFalse);
    });

    test('setInMemoryOverride directly overrides status', () {
      OnboardingService.setInMemoryOverride(true);
      expect(OnboardingService.hasSeenOnboarding(), isTrue);

      OnboardingService.setInMemoryOverride(false);
      OnboardingService.setForceTestMode(true);
      expect(OnboardingService.hasSeenOnboarding(), isFalse);
    });

    test('setOnboardingCompleted updates in-memory cache and returns true', () async {
      OnboardingService.setForceTestMode(true);
      OnboardingService.setInMemoryOverride(false);
      expect(OnboardingService.hasSeenOnboarding(), isFalse);

      await OnboardingService.setOnboardingCompleted(completed: true);
      expect(OnboardingService.hasSeenOnboarding(), isTrue);
    });
  });

  group('Onboarding Localization Tests across 5 Languages', () {
    const onboardingKeys = [
      'app_tour',
      'app_tour_tooltip',
      'onboarding_step_counter',
      'onboarding_welcome_title',
      'onboarding_welcome_desc',
      'onboarding_welcome_badge',
      'onboarding_gallery_title',
      'onboarding_gallery_desc',
      'onboarding_editor_title',
      'onboarding_editor_desc',
      'onboarding_database_title',
      'onboarding_database_desc',
      'onboarding_playtest_title',
      'onboarding_playtest_desc',
      'onboarding_dont_show_again',
      'onboarding_next',
      'onboarding_previous',
      'onboarding_get_started',
      'onboarding_jump_to',
      'onboarding_skip',
      'search_cards_tags',
      'keyboard_shortcuts',
    ];

    for (final lang in AppLanguage.values) {
      test('Language ${lang.name} contains valid translations for all onboarding keys', () {
        for (final key in onboardingKeys) {
          final val = AppStrings.get(lang, key);
          expect(val, isNotEmpty, reason: 'Key $key in ${lang.name} should not be empty');
          expect(val, isNot(equals(key)), reason: 'Key $key in ${lang.name} should not match raw key');
        }
      });
    }
  });

  group('GrimoireOnboardingDialog Widget Flow Tests', () {
    Widget buildTestHarness({void Function(int)? onNavigateToTab}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    GrimoireOnboardingDialog.show(
                      context,
                      onNavigateToTab: onNavigateToTab,
                    );
                  },
                  child: const Text('Launch Tour'),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('Opens dialog, steps forward and backward through all 5 tour steps', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(buildTestHarness());

      // Open dialog
      await tester.tap(find.text('Launch Tour'));
      await tester.pumpAndSettle();

      // Step 1: Welcome
      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_welcome_title')), findsOneWidget);
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_skip')), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_next')), findsOneWidget);

      // Advance to Step 2: Gallery
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'onboarding_next')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_gallery_title')), findsOneWidget);
      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_previous')), findsOneWidget);

      // Advance to Step 3: Editor
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'onboarding_next')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_editor_title')), findsOneWidget);
      expect(find.text('Step 3 of 5'), findsOneWidget);

      // Advance to Step 4: Database
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'onboarding_next')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_database_title')), findsOneWidget);
      expect(find.text('Step 4 of 5'), findsOneWidget);

      // Advance to Step 5: Playtest & 300 DPI
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'onboarding_next')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_playtest_title')), findsOneWidget);
      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_get_started')), findsOneWidget);

      // Step backward to Step 4
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'onboarding_previous')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_database_title')), findsOneWidget);
      expect(find.text('Step 4 of 5'), findsOneWidget);

      // Step forward back to Step 5 and finish
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_get_started')), findsOneWidget);

      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'onboarding_get_started')), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(GrimoireOnboardingDialog), findsNothing);
    });

    testWidgets('Jump to tool button triggers navigation callback with tab index', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      int? navigatedTab;

      await tester.pumpWidget(buildTestHarness(
        onNavigateToTab: (index) {
          navigatedTab = index;
        },
      ));

      await tester.tap(find.text('Launch Tour'));
      await tester.pumpAndSettle();

      // Move to Step 2 (Gallery -> Tab 0)
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.get(AppLanguage.en, 'onboarding_gallery_title')), findsOneWidget);

      // Tap 'Open this tool'
      await tester.tap(find.text(AppStrings.get(AppLanguage.en, 'onboarding_jump_to')));
      await tester.pumpAndSettle();

      expect(navigatedTab, equals(0));
      // Dialog should close after jump
      expect(find.byType(GrimoireOnboardingDialog), findsNothing);
    });

    testWidgets('Skip Tour button dismisses dialog immediately', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(buildTestHarness());

      await tester.tap(find.text('Launch Tour'));
      await tester.pumpAndSettle();

      expect(find.byType(GrimoireOnboardingDialog), findsOneWidget);

      await tester.tap(find.text('Skip Tour'));
      await tester.pumpAndSettle();

      expect(find.byType(GrimoireOnboardingDialog), findsNothing);
    });
  });
}
