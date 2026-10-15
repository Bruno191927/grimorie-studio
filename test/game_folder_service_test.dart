import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameFolderService Directory & CSV Serialization', () {
    const testGame = 'Test Game Deck';

    tearDown(() async {
      final testDir = GameFolderService.getGameDir(testGame);
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('ensureGameFolderExists creates games/<game>/assets structure', () async {
      await GameFolderService.ensureGameFolderExists(testGame);

      final gameDir = GameFolderService.getGameDir(testGame);
      final assetsDir = GameFolderService.getGameAssetsDir(testGame);

      expect(await gameDir.exists(), isTrue);
      expect(await assetsDir.exists(), isTrue);
    });

    test('saveGameDataCsv writes RFC-4180 CSV with UTF-8 BOM and loadGameDataCsv reads it back', () async {
      final sampleCards = [
        {
          'card_name': 'Alpha Dragon',
          'cost': '5',
          'type': 'Creature',
          'rarity': 'Mythic',
          'attack': '6',
          'defense': '5',
          'category': 'Criaturas',
          'rules_text': 'Flying, Trample.',
          'prompt': 'Epic red dragon flying over obsidian mountains',
          'art_url': 'assets/alpha_dragon.png',
          'icon': '🐉',
          'art_color': 0xFFDC2626,
          'game': testGame,
          'creator': 'Studio Author',
        },
        {
          'card_name': 'Mana Surge',
          'cost': '1',
          'type': 'Instant',
          'rarity': 'Common',
          'attack': '0',
          'defense': '0',
          'category': 'Instantáneos',
          'rules_text': 'Add 3 mana of any color.',
          'prompt': 'Blue glowing energy sphere exploding into sparks',
          'art_url': 'assets/mana_surge.png',
          'icon': '⚡',
          'art_color': 0xFF2563EB,
          'game': testGame,
          'creator': 'Studio Author',
        },
      ];

      // Save CSV
      final csvFile = await GameFolderService.saveGameDataCsv(testGame, sampleCards);
      expect(await csvFile.exists(), isTrue);

      // Verify file content has headers and BOM
      final rawBytes = await csvFile.readAsBytes();
      expect(rawBytes[0] == 0xEF && rawBytes[1] == 0xBB && rawBytes[2] == 0xBF, isTrue);
      final rawContent = await csvFile.readAsString();
      expect(rawContent, contains('card_name'));
      expect(rawContent, contains('Alpha Dragon'));
      expect(rawContent, contains('Mana Surge'));

      // Load back
      final loaded = await GameFolderService.loadGameDataCsv(testGame);
      expect(loaded.length, equals(2));
      expect(loaded[0]['card_name'], equals('Alpha Dragon'));
      expect(loaded[0]['cost'], equals('5'));
      expect(loaded[0]['type'], equals('Creature'));
      expect(loaded[0]['category'], equals('Criaturas'));
      expect(loaded[0]['art_url'], equals('assets/alpha_dragon.png'));
      expect(loaded[0]['art_color'], equals(0xFFDC2626));

      expect(loaded[1]['card_name'], equals('Mana Surge'));
      expect(loaded[1]['cost'], equals('1'));
      expect(loaded[1]['icon'], equals('⚡'));
    });

    test('resolveCardImageFile locates image inside assets/ folder', () async {
      await GameFolderService.ensureGameFolderExists(testGame);
      final assetsDir = GameFolderService.getGameAssetsDir(testGame);
      final testImg = File('${assetsDir.path}/test_card.png');
      await testImg.writeAsBytes([0x89, 0x50, 0x4E, 0x47]); // PNG signature

      // Resolve by assets/test_card.png
      final resolved = GameFolderService.resolveCardImageFile(testGame, 'assets/test_card.png');
      expect(resolved, isNotNull);
      expect(resolved!.existsSync(), isTrue);

      // Resolve by test_card.png directly
      final resolvedDirect = GameFolderService.resolveCardImageFile(testGame, 'test_card.png');
      expect(resolvedDirect, isNotNull);

      // Null or non-existing returns null
      expect(GameFolderService.resolveCardImageFile(testGame, null), isNull);
      expect(GameFolderService.resolveCardImageFile(testGame, 'non_existent.png'), isNull);
    });

    test('getAssetsCount returns correct count of image files in assets folder', () async {
      await GameFolderService.ensureGameFolderExists(testGame);
      final assetsDir = GameFolderService.getGameAssetsDir(testGame);

      await File('${assetsDir.path}/img1.png').writeAsBytes([1, 2, 3]);
      await File('${assetsDir.path}/img2.jpg').writeAsBytes([1, 2, 3]);
      await File('${assetsDir.path}/readme.txt').writeAsString('Not an image');

      final count = GameFolderService.getAssetsCount(testGame);
      expect(count, equals(2));
    });

    test('getGameAssetsDir provides proper path and openGameAssetsFolderInExplorer ensures folder exists', () async {
      final assetsDir = GameFolderService.getGameAssetsDir(testGame);
      expect(assetsDir.path, contains('assets'));

      // Calling openGameAssetsFolderInExplorer should ensure folder exists
      await GameFolderService.ensureGameFolderExists(testGame);
      expect(assetsDir.existsSync(), isTrue);

      final rootDir = GameFolderService.getGamesRootDir();
      expect(rootDir.existsSync(), isTrue);
    });
  });
}
