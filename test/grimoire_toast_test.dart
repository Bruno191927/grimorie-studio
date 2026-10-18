import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';
import 'package:grimoire_studio/core/widgets/grimoire_toast.dart';

void main() {
  testWidgets('GrimoireToast displays floating notification with message and action', (tester) async {
    bool actionClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: GrimoireTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  GrimoireToast.success(
                    context,
                    'Categoría "Bloqueo" guardada y carta Preset creada.',
                    actionLabel: 'Ver en Editor',
                    onAction: () {
                      actionClicked = true;
                    },
                  );
                },
                child: const Text('Mostrar Notificación'),
              );
            },
          ),
        ),
      ),
    );

    // Initial state: no notification
    expect(find.text('Categoría "Bloqueo" guardada y carta Preset creada.'), findsNothing);

    // Trigger toast
    await tester.tap(find.text('Mostrar Notificación'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 300)); // Finish entrance animation

    // Notification is now visible
    expect(find.text('Categoría "Bloqueo" guardada y carta Preset creada.'), findsOneWidget);
    expect(find.text('Ver en Editor'), findsOneWidget);
    expect(find.byType(GrimoireToastCard), findsOneWidget);

    // Tap action
    await tester.tap(find.text('Ver en Editor'));
    await tester.pump();

    expect(actionClicked, isTrue);
  });

  testWidgets('GrimoireToast displays different types with appropriate accents', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GrimoireTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () => GrimoireToast.error(context, 'Error al guardar'),
                    child: const Text('Error Toast'),
                  ),
                  ElevatedButton(
                    onPressed: () => GrimoireToast.warning(context, 'Aviso de prueba'),
                    child: const Text('Warning Toast'),
                  ),
                  ElevatedButton(
                    onPressed: () => GrimoireToast.info(context, 'Información general'),
                    child: const Text('Info Toast'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Error toast
    await tester.tap(find.text('Error Toast'));
    await tester.pumpAndSettle();
    expect(find.text('Error al guardar'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

    // Warning toast
    await tester.tap(find.text('Warning Toast'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso de prueba'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    // Close button dismisses toast
    final closeButtons = find.byIcon(Icons.close_rounded);
    expect(closeButtons, findsOneWidget);
    await tester.tap(closeButtons);
    await tester.pumpAndSettle();
    expect(find.text('Aviso de prueba'), findsNothing);
  });
}
