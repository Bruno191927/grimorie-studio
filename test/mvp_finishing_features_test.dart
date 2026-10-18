import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire_studio/features/editor/models/card_template.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/export/services/export_service.dart';
import 'package:grimoire_studio/features/ai_generator/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MVP Finishing Features', () {
    test('1. Starter template presets create valid dual-sided templates', () {
      final tcg = CardTemplate.createTcgFantasy();
      expect(tcg.layers.length, greaterThanOrEqualTo(5));
      expect(tcg.backLayers.isNotEmpty, isTrue);

      final boardgame = CardTemplate.createBoardgameAction();
      expect(boardgame.layers.any((l) => l.name.contains('Efecto') || l.name.contains('Arte')), isTrue);
      expect(boardgame.backLayers.isNotEmpty, isTrue);

      final tarot = CardTemplate.createTarotHero();
      expect(tarot.layers.any((l) => l.name.contains('Retrato') || l.name.contains('Nombre') || l.name.contains('Héroe')), isTrue);
      expect(tarot.backLayers.isNotEmpty, isTrue);
    });

    test('2. EditorNotifier applies preset templates to active project', () {
      final notifier = EditorNotifier(enableDiskPersistence: false);
      expect(notifier.state.project.templates.isNotEmpty, isTrue);

      notifier.applyPresetTemplate('boardgameAction');
      final activeTpl = notifier.state.project.activeTemplate;
      expect(activeTpl.name.contains('Acción'), isTrue);

      notifier.applyPresetTemplate('tarotHero');
      final tarotTpl = notifier.state.project.activeTemplate;
      expect(tarotTpl.name.contains('Tarot') || tarotTpl.name.contains('Héroe'), isTrue);
    });

    test('3. Export and import .grimoire package roundtrip', () async {
      final tempDir = await Directory.systemTemp.createTemp('grimoire_test_');
      try {
        // Create sample game folder and data.csv
        final gamesDir = Directory('${tempDir.path}/games');
        final testGameDir = Directory('${gamesDir.path}/TestGame');
        await testGameDir.create(recursive: true);
        final csvFile = File('${testGameDir.path}/data.csv');
        await csvFile.writeAsString('card_name,game\nDragon,TestGame\n');

        // Export package
        final packageFile = await ExportService.exportGrimoirePackage(
          packageName: 'test_backup',
          workspaceStatePayload: {'version': '1.0'},
          outputDirectory: Directory('${tempDir.path}/out'),
          gamesRootDir: gamesDir,
        );

        expect(packageFile.existsSync(), isTrue);
        expect(packageFile.path.endsWith('.grimoire'), isTrue);

        // Import package into fresh directory
        final restoreDir = Directory('${tempDir.path}/restored_games');
        final importResult = await ExportService.importGrimoirePackage(
          packageFile: packageFile,
          gamesRootDir: restoreDir,
        );

        expect(importResult.success, isTrue);
        expect(importResult.gamesRestored, 1);
        final restoredCsv = File('${restoreDir.path}/TestGame/data.csv');
        expect(restoredCsv.existsSync(), isTrue);
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('4. AiProviderType includes free cloud Pollinations.ai engine', () {
      expect(AiProviderType.values.contains(AiProviderType.pollinationsCloud), isTrue);
    });
  });
}
