import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/features/editor/presentation/providers/editor_provider.dart';
import 'package:grimoire_studio/features/editor/services/game_folder_service.dart';

void main() {
  const testGame = '__test_folder_game__';

  setUp(() {
    // Ensure clean test directory
    final gameDir = GameFolderService.getGameDir(testGame);
    if (gameDir.existsSync()) {
      gameDir.deleteSync(recursive: true);
    }
    GameFolderService.ensureGameFolderExists(testGame);
  });

  tearDown(() {
    final gameDir = GameFolderService.getGameDir(testGame);
    if (gameDir.existsSync()) {
      gameDir.deleteSync(recursive: true);
    }
  });

  test('create, list and rename asset subfolders', () {
    // Initially empty
    expect(GameFolderService.listAssetFolders(testGame), isEmpty);

    // Create subfolders
    final folder1 = GameFolderService.createAssetFolder(testGame, 'Personajes');
    final folder2 = GameFolderService.createAssetFolder(testGame, 'Fondos');

    expect(folder1, isNotNull);
    expect(folder2, isNotNull);

    var folders = GameFolderService.listAssetFolders(testGame);
    expect(folders, containsAll(['Personajes', 'Fondos']));

    // Rename subfolder
    final renamed = GameFolderService.renameAssetFolder(testGame, 'Fondos', 'Escenarios');
    expect(renamed, isNotNull);

    folders = GameFolderService.listAssetFolders(testGame);
    expect(folders, contains('Escenarios'));
    expect(folders, isNot(contains('Fondos')));
  });

  test('move asset between root and subfolders with relative path computation', () {
    final assetsDir = GameFolderService.getGameAssetsDir(testGame);
    final testFile = File('${assetsDir.path}/hero.png');
    testFile.writeAsStringSync('hero image content');

    // Root relative path and subfolder
    expect(GameFolderService.getAssetSubfolder(testGame, testFile), isNull);
    expect(GameFolderService.getRelativeAssetPath(testGame, testFile), 'assets/hero.png');

    // Create folder and move asset into it
    GameFolderService.createAssetFolder(testGame, 'Heroes');
    final moved = GameFolderService.moveAssetToFolder(testGame, testFile, 'Heroes');

    expect(moved, isNotNull);
    expect(moved!.existsSync(), isTrue);
    expect(testFile.existsSync(), isFalse);

    // Subfolder detection and relative path
    expect(GameFolderService.getAssetSubfolder(testGame, moved), 'Heroes');
    expect(GameFolderService.getRelativeAssetPath(testGame, moved), 'assets/Heroes/hero.png');

    // Move back to root
    final backToRoot = GameFolderService.moveAssetToFolder(testGame, moved, null);
    expect(backToRoot, isNotNull);
    expect(backToRoot!.existsSync(), isTrue);
    expect(GameFolderService.getAssetSubfolder(testGame, backToRoot), isNull);
    expect(GameFolderService.getRelativeAssetPath(testGame, backToRoot), 'assets/hero.png');
  });

  test('resolveCardImageFile finds file in subfolder even if referenced without folder prefix', () {
    final assetsDir = GameFolderService.getGameAssetsDir(testGame);
    final subfolder = Directory('${assetsDir.path}/Icons')..createSync(recursive: true);
    final iconFile = File('${subfolder.path}/shield.png');
    iconFile.writeAsStringSync('shield icon');

    // Exact path
    final resolvedExact = GameFolderService.resolveCardImageFile(testGame, 'assets/Icons/shield.png');
    expect(resolvedExact, isNotNull);
    expect(resolvedExact!.existsSync(), isTrue);

    // Old or unqualified path: fallback search finds it in subfolder
    final resolvedFallback = GameFolderService.resolveCardImageFile(testGame, 'assets/shield.png');
    expect(resolvedFallback, isNotNull);
    expect(resolvedFallback!.existsSync(), isTrue);
    expect(resolvedFallback.path.replaceAll('\\', '/'), iconFile.path.replaceAll('\\', '/'));
  });

  test('deleteAssetFolder moves files safely to root when moveFilesToRoot is true', () {
    final assetsDir = GameFolderService.getGameAssetsDir(testGame);
    final subfolder = Directory('${assetsDir.path}/Temporary')..createSync(recursive: true);
    final file = File('${subfolder.path}/temp_card.png');
    file.writeAsStringSync('card content');

    expect(file.existsSync(), isTrue);

    final deleted = GameFolderService.deleteAssetFolder(testGame, 'Temporary', moveFilesToRoot: true);
    expect(deleted, isTrue);
    expect(subfolder.existsSync(), isFalse);

    // The file should now be in root assets/
    final rescuedFile = File('${assetsDir.path}/temp_card.png');
    expect(rescuedFile.existsSync(), isTrue);
  });

  test('EditorNotifier.moveAsset updates physical file, rows art_url, and selectedAssetPath', () {
    final assetsDir = GameFolderService.getGameAssetsDir(testGame);
    final assetFile = File('${assetsDir.path}/dragon.png');
    assetFile.writeAsStringSync('dragon art');

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(editorProvider.notifier);
    final initialProject = container.read(editorProvider).project;

    // Create a row and template referencing dragon.png
    final updatedRows = [
      {
        'id': 'card-1',
        'name': 'Red Dragon',
        'game': testGame,
        'art_url': 'assets/dragon.png',
      }
    ];

    container.read(editorProvider.notifier).state = container.read(editorProvider).copyWith(
          project: initialProject.copyWith(rows: updatedRows),
        );

    // Select the asset
    notifier.selectAsset('assets/dragon.png');
    expect(container.read(editorProvider).selectedAssetPath, 'assets/dragon.png');

    // Create folder and move asset
    GameFolderService.createAssetFolder(testGame, 'Monsters');
    final movedSuccess = notifier.moveAsset(
      gameName: testGame,
      relativeOrFileName: 'assets/dragon.png',
      targetSubfolder: 'Monsters',
    );

    expect(movedSuccess, isTrue);

    // Check physical location
    final newPhysicalFile = File('${assetsDir.path}/Monsters/dragon.png');
    expect(newPhysicalFile.existsSync(), isTrue);
    expect(assetFile.existsSync(), isFalse);

    // Check row art_url updated
    final state = container.read(editorProvider);
    expect(state.project.rows.first['art_url'], 'assets/Monsters/dragon.png');

    // Check selectedAssetPath updated
    expect(state.selectedAssetPath, 'assets/Monsters/dragon.png');

    // Move back to root
    final moveBackSuccess = notifier.moveAsset(
      gameName: testGame,
      relativeOrFileName: 'assets/Monsters/dragon.png',
      targetSubfolder: null,
    );
    expect(moveBackSuccess, isTrue);

    final backState = container.read(editorProvider);
    expect(backState.project.rows.first['art_url'], 'assets/dragon.png');
    expect(backState.selectedAssetPath, 'assets/dragon.png');
    expect(File('${assetsDir.path}/dragon.png').existsSync(), isTrue);
  });

  test('uploadMultipleImagesToGameAssets handles multiple files and nested directories', () async {
    final tempDir = Directory.systemTemp.createTempSync('grimoire_batch_upload_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    // Create 2 loose files
    final img1 = File('${tempDir.path}/img1.png')..writeAsStringSync('png1');
    final img2 = File('${tempDir.path}/img2.jpg')..writeAsStringSync('jpg2');
    final notAnImg = File('${tempDir.path}/notes.txt')..writeAsStringSync('ignore me');

    // Create a subfolder with 1 valid image
    final subDir = Directory('${tempDir.path}/sub')..createSync();
    File('${subDir.path}/img3.webp').writeAsStringSync('webp3');

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Set active row game to testGame
    container.read(editorProvider.notifier).state = container.read(editorProvider).copyWith(
          project: container.read(editorProvider).project.copyWith(
            rows: [
              {'id': 'card-test', 'name': 'Test', 'game': testGame}
            ],
          ),
        );

    final uploaded = await container.read(editorProvider.notifier).uploadMultipleImagesToGameAssets([
      img1.path,
      img2.path,
      notAnImg.path,
      tempDir.path, // Passing directory should recursively discover valid images
    ]);

    expect(uploaded, isNotEmpty);
    // img1, img2, and from directory img1, img2, img3
    expect(uploaded.any((u) => u.contains('img1.png')), isTrue);
    expect(uploaded.any((u) => u.contains('img2.jpg')), isTrue);
    expect(uploaded.any((u) => u.contains('img3.webp')), isTrue);
    expect(uploaded.any((u) => u.contains('notes.txt')), isFalse);
  });
}

