import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/main.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';

void main() {
  testWidgets('Grimoire Studio smoke test and language selector test', (WidgetTester tester) async {
    // Set desktop screen resolution
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const GrimoireApp();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Grimoire Studio header is present
    expect(find.text('Grimoire '), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);

    // Initial language is Spanish
    expect(find.text('Galería de Cartas'), findsOneWidget);

    // Switch to English via provider
    container.read(localeProvider.notifier).setLanguage(AppLanguage.en);
    await tester.pumpAndSettle();

    // Verify UI switched to English
    expect(find.text('Card Gallery'), findsOneWidget);
    expect(find.text('Connect AI Engine'), findsOneWidget);
  });
}
