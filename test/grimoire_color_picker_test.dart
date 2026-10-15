import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire_studio/core/widgets/grimoire_color_picker.dart';

void main() {
  group('GrimoireColorPicker & Dialog Integration', () {
    testWidgets('GrimoireColorPicker renders HSV controls, hex and updates on swatch tap', (tester) async {
      Color selected = const Color(0xFF1E2337);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrimoireColorPicker(
              initialColor: selected,
              title: 'Color de Fondo',
              onColorChanged: (newColor) {
                selected = newColor;
              },
            ),
          ),
        ),
      );

      // Verify title and initial hex displayed
      expect(find.text('Color de Fondo'), findsOneWidget);
      expect(find.text('#FF1E2337'), findsWidgets);

      // Tap on a swatch (Dragon Crimson 0xFF450A0A)
      final crimsonSwatch = find.byTooltip('Dragon Crimson');
      expect(crimsonSwatch, findsOneWidget);

      await tester.tap(crimsonSwatch);
      await tester.pumpAndSettle();

      expect(selected.toARGB32(), equals(const Color(0xFF450A0A).toARGB32()));
      expect(find.text('#FF450A0A'), findsWidgets);
    });

    testWidgets('GrimoireColorPickerDialog opens, notifies live changes and applies color', (tester) async {
      Color resultColor = const Color(0xFF000000);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final picked = await GrimoireColorPickerDialog.show(
                    context,
                    initialColor: const Color(0xFF0C0E17),
                    title: 'Seleccionar Color',
                    onLiveChanged: (c) {
                      resultColor = c;
                    },
                  );
                  if (picked != null) {
                    resultColor = picked;
                  }
                },
                child: const Text('Abrir Picker'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Abrir Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Seleccionar Color'), findsOneWidget);
      expect(find.text('Aplicar Color'), findsOneWidget);

      // Tap Mítico Dorado swatch
      await tester.tap(find.byTooltip('Mítico Dorado'));
      await tester.pumpAndSettle();

      expect(resultColor.toARGB32(), equals(const Color(0xFFF59E0B).toARGB32()));

      // Confirm with "Aplicar Color"
      await tester.tap(find.text('Aplicar Color'));
      await tester.pumpAndSettle();

      // Dialog closed and color preserved
      expect(find.text('Seleccionar Color'), findsNothing);
      expect(resultColor.toARGB32(), equals(const Color(0xFFF59E0B).toARGB32()));
    });
  });
}
