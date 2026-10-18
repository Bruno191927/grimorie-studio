import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/presentation/widgets/card_renderer_widget.dart';
import 'package:grimoire_studio/features/gallery/presentation/screens/card_gallery_screen.dart';

void main() {
  testWidgets('CardGalleryScreen renders cards using CardRendererWidget', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final container = ProviderContainer();
    container.read(editorProvider.notifier).addRow({
      'card_name': 'Dragón Dorado',
      'game': 'General',
      'type': 'Creature',
      'cost': '5',
      'attack': '6',
      'defense': '6',
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: CardGalleryScreen(
              onOpenEditor: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that CardRendererWidget is rendered for cards in the gallery
    expect(find.byType(CardRendererWidget), findsWidgets);
  });
}
