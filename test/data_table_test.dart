import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/database/presentation/widgets/data_table_view.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';

void main() {
  testWidgets('Test DataTableView layout for overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(editorProvider.notifier).addRow({
      'card_name': 'Bloqueo Bloqueo Bloqueo',
      'game': 'policritic',
      'qty': '1',
      'cost': '',
      'type': 'Bloqueo',
      'rarity': '',
      'attack': '',
      'defense': '',
      'rules_text': 'Bloquea una accion de otro jugador',
      'category': 'Bloqueo',
      'prompt': '',
      'art_url': 'assets/Gemini_Generated_Image_example.png',
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: DataTableView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}
