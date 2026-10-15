import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/main.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Unstable Unicorns game exists with cards, custom template, and playtest integration', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: GrimoireApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Unstable Unicorns Game Pill is present in Gallery sub-header
    final unicornGamePill = find.text('Unstable Unicorns');
    expect(unicornGamePill, findsWidgets);

    // Tap on the Unstable Unicorns filter pill
    await tester.tap(unicornGamePill.first);
    await tester.pumpAndSettle();

    // 2. Verify key Unstable Unicorns cards are displayed in the gallery
    expect(find.text('"Unicornio Bebé Arcoíris"'), findsOneWidget);
    expect(find.text('"Unicornio Seductor"'), findsOneWidget);
    expect(find.text('"¡Relincho! (Neigh!)"'), findsOneWidget);
    expect(find.text('"Bomba de Purpurina"'), findsOneWidget);
    expect(find.text('"Melena Arcoíris Protectora"'), findsOneWidget);

    // 3. Tap on "Unicornio Seductor" to open Canvas Editor
    await tester.tap(find.text('"Unicornio Seductor"'));
    await tester.pumpAndSettle();

    // Verify Canvas Editor is open and Unicorn Stable Frame template is auto-activated
    expect(find.text('Plantilla Activa'), findsWidgets);
    expect(find.text('Unicorn Stable Frame (Kawaii Chaos)'), findsWidgets);

    // Verify rules text is bound in canvas
    expect(find.textContaining('Al entrar a tu establo, roba 1 carta de Unicornio'), findsWidgets);

    // 4. Navigate to Playtest Screen
    final playtestNavTab = find.text('Mesa de Playtest');
    expect(playtestNavTab, findsOneWidget);
    await tester.tap(playtestNavTab);
    await tester.pumpAndSettle();

    // Verify Playtest screen loads Unstable Unicorns deck
    expect(find.text('Unstable Unicorns'), findsWidgets);
    expect(find.text('Tapete de Juego Tabletop'), findsOneWidget);

    // Verify player has cards in hand
    expect(find.byType(Draggable<Map<String, dynamic>>), findsWidgets);

    // Tap on "Robar Carta" to draw another unicorn card
    final drawDeckButton = find.text('Robar');
    expect(drawDeckButton, findsOneWidget);
    await tester.tap(drawDeckButton);
    await tester.pumpAndSettle();

    // Tap on Next Turn
    final nextTurnButton = find.textContaining('Siguiente Turno');
    expect(nextTurnButton, findsOneWidget);
    await tester.tap(nextTurnButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('(2)'), findsOneWidget);
  });
}
