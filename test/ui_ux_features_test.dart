import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire_studio/core/widgets/keyboard_shortcuts_dialog.dart';
import 'package:grimoire_studio/core/widgets/quick_card_search_dialog.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/screens/editor_screen.dart';
import 'package:grimoire_studio/features/gallery/presentation/screens/card_gallery_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI & UX Enhancements Test Suite', () {
    testWidgets('KeyboardShortcutsDialog renders all shortcut sections and closes', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => KeyboardShortcutsDialog.show(context),
              child: const Text('Open Shortcuts'),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Shortcuts'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Atajos de Teclado'), findsOneWidget);
      expect(find.text('NAVEGACIÓN GLOBAL'), findsOneWidget);
      expect(find.text('EDICIÓN & PROYECTO'), findsOneWidget);
      expect(find.text('LIENZO & CAPAS'), findsOneWidget);
      expect(find.text('MESA DE PLAYTEST'), findsOneWidget);
      expect(find.text('Búsqueda rápida de cartas (Spotlight)'), findsOneWidget);
      expect(find.text('Alternar guías de corte y sangrado (3mm)'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Atajos de Teclado'), findsNothing);
    });

    testWidgets('QuickCardSearchDialog searches cards and filters results', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late final ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => QuickCardSearchDialog.show(context, onCardSelected: () {}),
                    child: const Text('Search Cards'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Populate sample games so there are cards to search
      container.read(editorProvider.notifier).restoreSampleGames();
      await tester.pumpAndSettle();

      // Open quick search dialog
      await tester.tap(find.text('Search Cards'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Dragón');
      await tester.pumpAndSettle();

      // Close modal
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });

    testWidgets('CardGallery density toggle switches between comfortable and compact', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late final ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: Scaffold(
                  body: CardGalleryScreen(onOpenEditor: () {}),
                ),
              );
            },
          ),
        ),
      );

      // Restore sample games so gallery displays the controls bar
      container.read(editorProvider.notifier).restoreSampleGames();
      await tester.pumpAndSettle();

      // Density switcher buttons exist
      expect(find.byKey(const Key('gallery_density_comfortable')), findsOneWidget);
      expect(find.byKey(const Key('gallery_density_compact')), findsOneWidget);

      // Tap compact mode
      await tester.tap(find.byKey(const Key('gallery_density_compact')));
      await tester.pumpAndSettle();

      // Tap back to comfortable mode
      await tester.tap(find.byKey(const Key('gallery_density_comfortable')));
      await tester.pumpAndSettle();
    });

    testWidgets('EditorScreen toolbar has card cycling buttons and bleed guides toggle', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late final ProviderContainer container;
      final key = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: Scaffold(
                  body: EditorScreen(repaintBoundaryKey: key),
                ),
              );
            },
          ),
        ),
      );

      // Populate sample games so cards exist for cycling
      container.read(editorProvider.notifier).restoreSampleGames();
      await tester.pumpAndSettle();

      // Verify card prev/next buttons
      expect(find.byKey(const Key('editor_prev_card_button')), findsOneWidget);
      expect(find.byKey(const Key('editor_next_card_button')), findsOneWidget);

      // Verify bleed guides toggle button
      expect(find.byKey(const Key('toolbar_toggle_bleed_guides')), findsOneWidget);

      // Tap next card
      await tester.tap(find.byKey(const Key('editor_next_card_button')));
      await tester.pumpAndSettle();

      // Tap previous card
      await tester.tap(find.byKey(const Key('editor_prev_card_button')));
      await tester.pumpAndSettle();

      // Toggle bleed guides
      await tester.tap(find.byKey(const Key('toolbar_toggle_bleed_guides')));
      await tester.pumpAndSettle();
    });
  });
}
