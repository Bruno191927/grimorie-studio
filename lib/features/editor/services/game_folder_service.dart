import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import '../models/card_project.dart';
import '../models/game_category.dart';

class PersistedWorkspaceData {
  final CardProject? project;
  final Map<String, List<GameCategory>> gameCategories;
  final Set<String> deletedGames;
  final List<Map<String, dynamic>> discoveredRows;

  const PersistedWorkspaceData({
    this.project,
    this.gameCategories = const {},
    this.deletedGames = const {},
    this.discoveredRows = const [],
  });
}

class GameFolderService {
  /// Base directory where games and their assets are organized:
  /// games/
  ///   ├── workspace_state.json
  ///   ├── `<GameName>`/
  ///   │     ├── data.csv
  ///   │     └── assets/
  ///   │           ├── image1.png
  ///   │           └── image2.png
  static Directory getGamesRootDir() {
    // 1. Direct current working directory (IDE, CLI test, terminal run)
    final cwdGames = Directory('games');
    if (cwdGames.existsSync()) {
      return cwdGames;
    }

    // 2. Relative to executable (portable deployment or runner build)
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final exeGames = Directory('${exeDir.path}/games');
      if (exeGames.existsSync()) {
        return exeGames;
      }

      // 3. In development build, walk up parents from build/windows/x64/runner/Debug to project root
      Directory? current = exeDir;
      for (int i = 0; i < 6 && current != null; i++) {
        final candidate = Directory('${current.path}/games');
        if (candidate.existsSync()) {
          return candidate;
        }
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {}

    return Directory('games');
  }

  /// Returns the workspace_state.json file inside the root games/ directory
  static File getWorkspaceStateFile({Directory? customRootDir}) {
    final root = customRootDir ?? getGamesRootDir();
    final sep = Platform.isWindows ? '\\' : '/';
    return File('${root.path}${sep}workspace_state.json');
  }

  /// Sanitizes game name for cross-platform folder naming
  static String sanitizeFolderName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Returns the folder directory for a specific game
  static Directory getGameDir(String gameName, {Directory? customRootDir}) {
    final root = customRootDir ?? getGamesRootDir();
    final folder = sanitizeFolderName(gameName);
    final sep = Platform.isWindows ? '\\' : '/';
    return Directory('${root.path}$sep$folder');
  }

  /// Returns the assets/ directory inside a specific game folder
  static Directory getGameAssetsDir(String gameName, {Directory? customRootDir}) {
    final sep = Platform.isWindows ? '\\' : '/';
    return Directory('${getGameDir(gameName, customRootDir: customRootDir).path}${sep}assets');
  }

  /// Returns the data.csv file for a specific game
  static File getGameDataCsvFile(String gameName, {Directory? customRootDir}) {
    final sep = Platform.isWindows ? '\\' : '/';
    return File('${getGameDir(gameName, customRootDir: customRootDir).path}${sep}data.csv');
  }

  /// Ensures synchronously that the game directory and its assets/ folder exist
  static void ensureGameFolderExistsSync(String gameName, {Directory? customRootDir}) {
    final assetsDir = getGameAssetsDir(gameName, customRootDir: customRootDir);
    if (!assetsDir.existsSync()) {
      assetsDir.createSync(recursive: true);
    }
  }

  /// Ensures that the game directory and its assets/ folder exist
  static Future<void> ensureGameFolderExists(String gameName, {Directory? customRootDir}) async {
    ensureGameFolderExistsSync(gameName, customRootDir: customRootDir);
  }

  /// Exports cards for a game into game/data.csv formatted in standard RFC-4180
  static Future<File> saveGameDataCsv(String gameName, List<Map<String, dynamic>> cards, {Directory? customRootDir}) async {
    return saveGameDataCsvSync(gameName, cards, customRootDir: customRootDir);
  }

  /// Normalizes a card row dictionary ensuring standard fields are populated and aligned.
  static Map<String, dynamic> normalizeCardRow(Map<String, dynamic> raw, {String? defaultGame}) {
    final card = Map<String, dynamic>.from(raw);
    final game = (card['game']?.toString().trim().isNotEmpty ?? false)
        ? card['game'].toString().trim()
        : (defaultGame != null && defaultGame.isNotEmpty ? defaultGame : 'Magic');
    card['game'] = game;

    final category = card['category']?.toString().trim();
    card['category'] = (category != null && category.isNotEmpty) ? category : 'General';

    final qty = card['qty']?.toString().trim();
    card['qty'] = (qty != null && qty.isNotEmpty) ? qty : '1';

    if (!card.containsKey('cost')) card['cost'] = '';
    if (!card.containsKey('type')) card['type'] = 'Criatura';
    if (!card.containsKey('rarity')) card['rarity'] = 'Común';
    if (!card.containsKey('attack')) card['attack'] = '';
    if (!card.containsKey('defense')) card['defense'] = '';

    final rulesText = card['rules_text']?.toString().trim() ?? '';
    final rules = card['rules']?.toString().trim() ?? '';
    if (rulesText.isNotEmpty) {
      card['rules_text'] = rulesText;
      card['rules'] = rulesText;
    } else if (rules.isNotEmpty) {
      card['rules_text'] = rules;
      card['rules'] = rules;
    } else {
      card['rules_text'] = card.containsKey('rules_text') ? '' : 'Habilidad especial para el juego $game.';
      card['rules'] = card['rules_text'];
    }

    if (!card.containsKey('art_url')) card['art_url'] = '';
    if (!card.containsKey('prompt')) card['prompt'] = '';
    if (!card.containsKey('icon') || card['icon'].toString().trim().isEmpty) card['icon'] = '🃏';
    if (!card.containsKey('creator') || card['creator'].toString().trim().isEmpty) card['creator'] = 'Grimoire Studio';

    return card;
  }

  /// Synchronously exports cards for a game into game/data.csv formatted in standard RFC-4180
  static File saveGameDataCsvSync(String gameName, List<Map<String, dynamic>> cards, {Directory? customRootDir}) {
    ensureGameFolderExistsSync(gameName, customRootDir: customRootDir);

    final csvFile = getGameDataCsvFile(gameName, customRootDir: customRootDir);
    final standardHeaders = [
      'card_name',
      'game',
      'category',
      'qty',
      'cost',
      'type',
      'rarity',
      'attack',
      'defense',
      'rules_text',
      'prompt',
      'art_url',
      'icon',
      'art_color',
      'creator',
    ];

    const internalKeys = {'template_id', 'is_category_default', 'is_game_default', 'rules'};
    final extraHeaders = <String>{};
    for (final card in cards) {
      for (final k in card.keys) {
        if (!standardHeaders.contains(k) && !internalKeys.contains(k)) {
          extraHeaders.add(k);
        }
      }
    }
    final headers = [...standardHeaders, ...extraHeaders];

    final rows = <List<dynamic>>[headers];

    for (final rawCard in cards) {
      final card = normalizeCardRow(rawCard, defaultGame: gameName);

      final row = <dynamic>[
        card['card_name']?.toString() ?? '',
        card['game']?.toString() ?? gameName,
        card['category']?.toString() ?? 'General',
        card['qty']?.toString() ?? '1',
        card['cost']?.toString() ?? '',
        card['type']?.toString() ?? 'Criatura',
        card['rarity']?.toString() ?? 'Común',
        card['attack']?.toString() ?? '',
        card['defense']?.toString() ?? '',
        card['rules_text']?.toString() ?? '',
        card['prompt']?.toString() ?? '',
        card['art_url']?.toString() ?? '',
        card['icon']?.toString() ?? '🃏',
        card['art_color'] is int
            ? '0x${(card['art_color'] as int).toRadixString(16).padLeft(8, '0').toUpperCase()}'
            : (card['art_color']?.toString() ?? '0xFF7C3AED'),
        card['creator']?.toString() ?? 'Grimoire Studio',
      ];
      for (final extra in extraHeaders) {
        row.add(card[extra]?.toString() ?? '');
      }
      rows.add(row);
    }

    final csvString = csv.encode(rows);
    // Write UTF-8 with BOM for optimal compatibility with Excel and text editors
    csvFile.writeAsStringSync('\uFEFF$csvString', encoding: utf8);
    return csvFile;
  }

  /// Reads and parses cards from game/data.csv
  static Future<List<Map<String, dynamic>>> loadGameDataCsv(String gameName, {Directory? customRootDir}) async {
    return loadGameDataCsvSync(gameName, customRootDir: customRootDir);
  }

  /// Synchronously reads and parses cards from game/data.csv
  static List<Map<String, dynamic>> loadGameDataCsvSync(String gameName, {Directory? customRootDir}) {
    final csvFile = getGameDataCsvFile(gameName, customRootDir: customRootDir);
    if (!csvFile.existsSync()) {
      return [];
    }

    try {
      var content = csvFile.readAsStringSync(encoding: utf8);
      if (content.startsWith('\uFEFF')) {
        content = content.substring(1);
      }
      if (content.trim().isEmpty) return [];

      final parsedRows = csv.decode(content);
      if (parsedRows.isEmpty) return [];

      final headers = parsedRows.first.map((e) => e.toString().trim()).toList();
      final result = <Map<String, dynamic>>[];

      for (int i = 1; i < parsedRows.length; i++) {
        final row = parsedRows[i];
        if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) continue;

        final card = <String, dynamic>{};
        for (int h = 0; h < headers.length; h++) {
          final val = h < row.length ? row[h]?.toString().trim() ?? '' : '';
          final key = headers[h];

          if (key == 'art_color') {
            if (val.startsWith('0x') || val.startsWith('0X')) {
              card[key] = int.tryParse(val.substring(2), radix: 16) ?? 0xFF7C3AED;
            } else {
              card[key] = int.tryParse(val) ?? 0xFF7C3AED;
            }
          } else {
            card[key] = val;
          }
        }

        final normalized = normalizeCardRow(card, defaultGame: gameName);
        result.add(normalized);
      }

      return result;
    } catch (e) {
      debugPrint('Error reading game CSV for $gameName: $e');
      return [];
    }
  }

  /// Saves the complete workspace state (Project, Templates, Layers, Categories, Rows, DeletedGames) to disk
  static void saveWorkspaceStateSync({
    required CardProject project,
    required Map<String, List<GameCategory>> gameCategories,
    required Set<String> deletedGames,
    Directory? customRootDir,
  }) {
    try {
      final root = customRootDir ?? getGamesRootDir();
      if (!root.existsSync()) {
        root.createSync(recursive: true);
      }

      final stateFile = getWorkspaceStateFile(customRootDir: customRootDir);
      final payload = <String, dynamic>{
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'project': project.toJson(),
        'gameCategories': gameCategories.map(
          (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()),
        ),
        'deletedGames': deletedGames.toList(),
      };

      stateFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(payload),
        encoding: utf8,
      );
    } catch (e) {
      debugPrint('Error saving workspace state: $e');
    }
  }

  /// Loads the persisted workspace state from `games/workspace_state.json` AND
  /// auto-discovers any existing `<GameName>/data.csv` folders on disk.
  static PersistedWorkspaceData? loadWorkspaceStateSync({Directory? customRootDir}) {
    try {
      final root = customRootDir ?? getGamesRootDir();
      if (!root.existsSync()) return null;

      CardProject? loadedProject;
      final loadedCategories = <String, List<GameCategory>>{};
      final loadedDeletedGames = <String>{};

      final stateFile = getWorkspaceStateFile(customRootDir: customRootDir);
      if (stateFile.existsSync()) {
        final raw = stateFile.readAsStringSync(encoding: utf8).trim();
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          if (decoded['project'] is Map<String, dynamic>) {
            final proj = CardProject.fromJson(decoded['project'] as Map<String, dynamic>);
            final normalizedRows = proj.rows.map((r) => normalizeCardRow(r)).toList();
            loadedProject = proj.copyWith(rows: normalizedRows);
          }
          if (decoded['gameCategories'] is Map) {
            final rawCats = decoded['gameCategories'] as Map;
            rawCats.forEach((key, value) {
              if (value is List) {
                loadedCategories[key.toString()] = value
                    .whereType<Map>()
                    .map((m) => GameCategory.fromJson(Map<String, dynamic>.from(m)))
                    .toList();
              }
            });
          }
          if (decoded['deletedGames'] is List) {
            for (final g in (decoded['deletedGames'] as List)) {
              loadedDeletedGames.add(g.toString());
            }
          }
        }
      }

      // Also scan subdirectories in games/ for any existing <GameName>/data.csv
      final existingGameNamesInProject = <String>{};
      if (loadedProject != null) {
        for (final r in loadedProject.rows) {
          final g = (r['game'] ?? '').toString().trim();
          if (g.isNotEmpty) existingGameNamesInProject.add(g.toLowerCase());
        }
      }

      final discoveredRows = <Map<String, dynamic>>[];
      final subDirs = root.listSync().whereType<Directory>();
      for (final dir in subDirs) {
        final dirName = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (dirName.startsWith('.')) continue;

        final isDeleted = loadedDeletedGames.any((d) => d.toLowerCase() == dirName.toLowerCase());
        if (isDeleted) continue;

        final csvCards = loadGameDataCsvSync(dirName, customRootDir: customRootDir);
        if (csvCards.isEmpty) continue;

        final canonicalGameName = (csvCards.first['game'] ?? dirName).toString().trim();
        if (!existingGameNamesInProject.contains(canonicalGameName.toLowerCase())) {
          discoveredRows.addAll(csvCards);
          existingGameNamesInProject.add(canonicalGameName.toLowerCase());
        }

        // Reconstruct category models from CSV cards if not already present in loadedCategories
        final currentCatList = List<GameCategory>.from(loadedCategories[canonicalGameName] ?? []);
        for (final card in csvCards) {
          final catName = (card['category'] ?? '').toString().trim();
          if (catName.isEmpty) continue;
          final alreadyExists = currentCatList.any((c) => c.name.toLowerCase() == catName.toLowerCase());
          if (!alreadyExists) {
            final cardCost = (card['cost']?.toString() ?? '').trim();
            final cardAtk = (card['attack']?.toString() ?? '').trim();
            final cardDef = (card['defense']?.toString() ?? '').trim();
            final cardRarity = (card['rarity']?.toString() ?? '').trim();
            final cardRules = (card['rules_text']?.toString() ?? '').trim();
            final cardType = (card['type']?.toString() ?? '').trim();
            final cardIcon = (card['icon']?.toString() ?? '').trim();
            final cardColor = card['art_color'] is int ? card['art_color'] as int : 0xFF7C3AED;

            currentCatList.add(
              GameCategory(
                id: 'cat_${canonicalGameName.hashCode}_${catName.hashCode}',
                name: catName,
                icon: cardIcon.isNotEmpty ? cardIcon : '🃏',
                defaultType: cardType.isNotEmpty ? cardType : catName,
                defaultColor: cardColor,
                hasCost: cardCost.isNotEmpty,
                defaultCost: cardCost,
                hasCombatStats: cardAtk.isNotEmpty || cardDef.isNotEmpty,
                defaultAttack: cardAtk,
                defaultDefense: cardDef,
                hasRarity: cardRarity.isNotEmpty,
                defaultRarity: cardRarity,
                hasRules: cardRules.isNotEmpty,
                defaultRules: cardRules,
              ),
            );
          }
        }
        if (currentCatList.isNotEmpty) {
          loadedCategories[canonicalGameName] = currentCatList;
        }
      }

      if (loadedProject == null && discoveredRows.isEmpty && loadedCategories.isEmpty) {
        return null;
      }

      return PersistedWorkspaceData(
        project: loadedProject,
        gameCategories: loadedCategories,
        deletedGames: loadedDeletedGames,
        discoveredRows: discoveredRows,
      );
    } catch (e) {
      debugPrint('Error loading workspace state: $e');
      return null;
    }
  }

  /// Saves an image buffer directly into `game/assets/<fileName>`
  static Future<File> saveCardImage(String gameName, String fileName, Uint8List imageBytes) async {
    await ensureGameFolderExists(gameName);
    final assetsDir = getGameAssetsDir(gameName);
    final targetFile = File('${assetsDir.path}/$fileName');
    await targetFile.writeAsBytes(imageBytes);
    return targetFile;
  }

  /// Copies an image file from the user's PC into `games/<gameName>/assets/<fileName>`
  /// Copies an image file from the user's PC into `games/<gameName>/assets/<targetSubfolder>/<fileName>`
  static Future<File> importImageToGameAssets(
    String gameName,
    File sourceFile, {
    String? customFileName,
    String? subfolder,
  }) async {
    await ensureGameFolderExists(gameName);
    var targetDir = getGameAssetsDir(gameName);
    if (subfolder != null && subfolder.trim().isNotEmpty) {
      final sanitizedSub = sanitizeFolderName(subfolder.trim());
      targetDir = Directory('${targetDir.path}/$sanitizedSub');
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
    }
    final fileName = customFileName ?? sourceFile.uri.pathSegments.last;
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetFile = File('${targetDir.path}/$sanitizedFileName');
    return await sourceFile.copy(targetFile.path);
  }

  /// Computes the normalized relative asset URL (e.g. `assets/hero.png` or `assets/Personajes/hero.png`)
  static String getRelativeAssetPath(String gameName, File assetFile) {
    final assetsDirPath = getGameAssetsDir(gameName).path.replaceAll('\\', '/');
    final filePath = assetFile.path.replaceAll('\\', '/');
    if (filePath.startsWith(assetsDirPath)) {
      final sub = filePath.substring(assetsDirPath.length).replaceAll(RegExp(r'^/'), '');
      return 'assets/$sub';
    }
    return 'assets/${assetFile.uri.pathSegments.last}';
  }

  /// Returns the subfolder name containing the asset file, or null if in root assets/
  static String? getAssetSubfolder(String gameName, File assetFile) {
    try {
      final assetsDirPath = getGameAssetsDir(gameName).path.replaceAll('\\', '/');
      final parentPath = assetFile.parent.path.replaceAll('\\', '/');
      if (parentPath == assetsDirPath) return null;
      if (parentPath.startsWith(assetsDirPath)) {
        final sub = parentPath.substring(assetsDirPath.length).replaceAll(RegExp(r'^/'), '');
        return sub.isNotEmpty ? sub : null;
      }
    } catch (_) {}
    return null;
  }

  /// Lists all subfolder names inside `games/<gameName>/assets/`
  static List<String> listAssetFolders(String gameName) {
    try {
      final assetsDir = getGameAssetsDir(gameName);
      if (!assetsDir.existsSync()) return [];
      final dirs = assetsDir.listSync(recursive: false).whereType<Directory>();
      final names = dirs
          .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .where((name) => !name.startsWith('.'))
          .toList();
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return names;
    } catch (_) {
      return [];
    }
  }

  /// Creates a subfolder inside `games/<gameName>/assets/<folderName>`
  static Directory? createAssetFolder(String gameName, String folderName) {
    try {
      ensureGameFolderExistsSync(gameName);
      final assetsDir = getGameAssetsDir(gameName);
      final sanitized = sanitizeFolderName(folderName);
      if (sanitized.isEmpty) return null;
      final targetDir = Directory('${assetsDir.path}/$sanitized');
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      return targetDir;
    } catch (e) {
      debugPrint('Error creating asset folder: $e');
      return null;
    }
  }

  /// Renames a subfolder inside `games/<gameName>/assets/`
  static bool renameAssetFolder(String gameName, String oldFolderName, String newFolderName) {
    try {
      final assetsDir = getGameAssetsDir(gameName);
      final sanitizedOld = sanitizeFolderName(oldFolderName);
      final sanitizedNew = sanitizeFolderName(newFolderName);
      if (sanitizedOld.isEmpty || sanitizedNew.isEmpty || sanitizedOld == sanitizedNew) return false;

      final oldDir = Directory('${assetsDir.path}/$sanitizedOld');
      final newDir = Directory('${assetsDir.path}/$sanitizedNew');

      if (!oldDir.existsSync()) return false;
      if (newDir.existsSync()) return false;

      oldDir.renameSync(newDir.path);
      return true;
    } catch (e) {
      debugPrint('Error renaming asset folder: $e');
      return false;
    }
  }

  /// Deletes a subfolder inside `games/<gameName>/assets/`
  /// If [moveFilesToRoot] is true, moves all contained files to `assets/` root before deleting the directory.
  static bool deleteAssetFolder(String gameName, String folderName, {bool moveFilesToRoot = true}) {
    try {
      final assetsDir = getGameAssetsDir(gameName);
      final sanitized = sanitizeFolderName(folderName);
      final targetDir = Directory('${assetsDir.path}/$sanitized');
      if (!targetDir.existsSync()) return false;

      if (moveFilesToRoot) {
        final containedFiles = targetDir.listSync(recursive: true).whereType<File>();
        for (final f in containedFiles) {
          final fName = f.uri.pathSegments.last;
          final rootDest = File('${assetsDir.path}/$fName');
          if (!rootDest.existsSync()) {
            f.renameSync(rootDest.path);
          } else {
            final ext = fName.contains('.') ? fName.split('.').last : '';
            final base = fName.contains('.') ? fName.substring(0, fName.lastIndexOf('.')) : fName;
            f.renameSync('${assetsDir.path}/${base}_${DateTime.now().millisecondsSinceEpoch}.$ext');
          }
        }
      }
      targetDir.deleteSync(recursive: true);
      return true;
    } catch (e) {
      debugPrint('Error deleting asset folder: $e');
      return false;
    }
  }

  /// Moves an asset file to a specified subfolder (or to root assets if targetSubfolder is null/empty)
  static File? moveAssetToFolder(String gameName, File sourceFile, String? targetSubfolder) {
    try {
      if (!sourceFile.existsSync()) return null;
      final assetsDir = getGameAssetsDir(gameName);
      Directory destinationDir;
      if (targetSubfolder != null && targetSubfolder.trim().isNotEmpty) {
        final sanitized = sanitizeFolderName(targetSubfolder.trim());
        destinationDir = Directory('${assetsDir.path}/$sanitized');
        if (!destinationDir.existsSync()) {
          destinationDir.createSync(recursive: true);
        }
      } else {
        destinationDir = assetsDir;
      }

      final fileName = sourceFile.uri.pathSegments.last;
      final newPath = '${destinationDir.path}/$fileName';
      if (sourceFile.path.replaceAll('\\', '/') == newPath.replaceAll('\\', '/')) {
        return sourceFile; // Already in target directory
      }

      final targetFile = File(newPath);
      if (targetFile.existsSync() && targetFile.path.toLowerCase() != sourceFile.path.toLowerCase()) {
        final ext = fileName.contains('.') ? fileName.split('.').last : '';
        final base = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final disambiguated = '${base}_$timestamp.$ext';
        return sourceFile.renameSync('${destinationDir.path}/$disambiguated');
      }

      return sourceFile.renameSync(targetFile.path);
    } catch (e) {
      debugPrint('Error moving asset to folder: $e');
      return null;
    }
  }

  /// Lists all valid image files in `games/<gameName>/assets/`
  /// If [subfolder] is provided, lists images inside that subfolder.
  /// If [subfolder] is null:
  /// - If [recursive] is true: lists all images across all subfolders.
  /// - If [recursive] is false: lists only images in root assets/.
  static List<File> listGameAssetImages(String gameName, {String? subfolder, bool recursive = true}) {
    try {
      final assetsDir = getGameAssetsDir(gameName);
      if (!assetsDir.existsSync()) return [];

      Directory searchDir = assetsDir;
      bool doRecursive = recursive;

      if (subfolder != null && subfolder.trim().isNotEmpty) {
        final sanitized = sanitizeFolderName(subfolder.trim());
        searchDir = Directory('${assetsDir.path}/$sanitized');
        if (!searchDir.existsSync()) return [];
        doRecursive = false;
      }

      final files = searchDir.listSync(recursive: doRecursive).whereType<File>();
      final validImages = files.where((f) {
        final ext = f.path.toLowerCase();
        return ext.endsWith('.png') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.webp');
      }).toList();
      validImages.sort((a, b) => a.uri.pathSegments.last.toLowerCase().compareTo(b.uri.pathSegments.last.toLowerCase()));
      return validImages;
    } catch (_) {
      return [];
    }
  }

  /// Resolves an art_url string to a physical File on disk if it exists
  static File? resolveCardImageFile(String gameName, String? artUrl) {
    if (artUrl == null || artUrl.trim().isEmpty) return null;
    final cleanUrl = artUrl.trim().replaceAll('\\', '/');

    // 1. Direct path check
    final directFile = File(cleanUrl);
    if (directFile.existsSync()) return directFile;

    // 2. Relative to game folder: games/<game>/<artUrl>
    final inGameFile = File('${getGameDir(gameName).path}/$cleanUrl');
    if (inGameFile.existsSync()) return inGameFile;

    // 3. In assets/ subfolder: games/<game>/assets/<artUrl>
    final inAssetsFile = File('${getGameAssetsDir(gameName).path}/$cleanUrl');
    if (inAssetsFile.existsSync()) return inAssetsFile;

    // 3b. Strip leading "assets/" if present: games/<game>/assets/<stripped>
    final strippedAssets = cleanUrl.startsWith('assets/') ? cleanUrl.substring(7) : cleanUrl;
    final inAssetsStripped = File('${getGameAssetsDir(gameName).path}/$strippedAssets');
    if (inAssetsStripped.existsSync()) return inAssetsStripped;

    // 4. By filename inside assets/ root
    final baseName = cleanUrl.split('/').last;
    final baseInAssetsFile = File('${getGameAssetsDir(gameName).path}/$baseName');
    if (baseInAssetsFile.existsSync()) return baseInAssetsFile;

    // 5. Recursive search across all subfolders in assets/
    try {
      final assetsDir = getGameAssetsDir(gameName);
      if (assetsDir.existsSync()) {
        final matches = assetsDir.listSync(recursive: true).whereType<File>().where((f) {
          final fName = f.path.replaceAll('\\', '/').split('/').last;
          return fName.toLowerCase() == baseName.toLowerCase();
        });
        if (matches.isNotEmpty) {
          return matches.first;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Returns the count of images currently in game/assets/
  static int getAssetsCount(String gameName) {
    try {
      final assetsDir = getGameAssetsDir(gameName);
      if (!assetsDir.existsSync()) return 0;
      final files = assetsDir.listSync(recursive: true).whereType<File>();
      return files.where((f) {
        final ext = f.path.toLowerCase();
        return ext.endsWith('.png') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.webp');
      }).length;
    } catch (_) {
      return 0;
    }
  }

  /// Opens the game's assets/ directory directly in the native OS file explorer (Windows Explorer, Finder, etc.)
  static Future<bool> openGameAssetsFolderInExplorer(String gameName, {String? subfolder}) async {
    await ensureGameFolderExists(gameName);
    var dir = getGameAssetsDir(gameName);
    if (subfolder != null && subfolder.trim().isNotEmpty) {
      final sanitized = sanitizeFolderName(subfolder.trim());
      dir = Directory('${dir.path}/$sanitized');
    }
    return await openDirectoryInExplorer(dir);
  }

  /// Opens the game's directory in the native OS file explorer (Windows Explorer, Finder, etc.)
  static Future<bool> openGameFolderInExplorer(String gameName) async {
    await ensureGameFolderExists(gameName);
    final dir = getGameDir(gameName);
    return await openDirectoryInExplorer(dir);
  }

  /// Opens the root games/ directory in the native OS file explorer
  static Future<bool> openGamesRootDirInExplorer() async {
    final root = getGamesRootDir();
    return await openDirectoryInExplorer(root);
  }

  /// Helper to reliably open any Directory in the OS native file explorer
  static Future<bool> openDirectoryInExplorer(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final rawPath = dir.absolute.path;

    try {
      if (Platform.isWindows) {
        final windowsPath = rawPath.replaceAll('/', '\\');
        // 'cmd.exe /c start "" "<path>"' invokes Windows ShellExecute cleanly without switch-parsing bugs
        final res = await Process.run('cmd.exe', ['/c', 'start', '', windowsPath]);
        if (res.exitCode == 0) return true;
        // Fallback to direct explorer.exe
        await Process.run('explorer.exe', [windowsPath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [rawPath]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [rawPath]);
        return true;
      }
    } catch (e) {
      debugPrint('Error opening directory in explorer: $e');
    }
    return false;
  }

  /// Renames an asset image file in `games/<gameName>/assets/` from oldPathOrFileName to newFileName.
  /// Returns the renamed File if successful, or null if failed.
  static File? renameGameAsset(String gameName, String oldPathOrFileName, String newFileName) {
    try {
      final targetFile = resolveCardImageFile(gameName, oldPathOrFileName);
      if (targetFile == null || !targetFile.existsSync()) return null;

      var sanitizedNew = newFileName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (sanitizedNew.isEmpty) return null;

      final oldExt = targetFile.path.contains('.') ? targetFile.path.split('.').last : '';
      if (oldExt.isNotEmpty && !sanitizedNew.contains('.')) {
        sanitizedNew = '$sanitizedNew.$oldExt';
      }

      final newFile = File('${targetFile.parent.path}/$sanitizedNew');
      if (newFile.existsSync() && targetFile.path.toLowerCase() != newFile.path.toLowerCase()) {
        return null; // Don't overwrite an existing different file
      }

      return targetFile.renameSync(newFile.path);
    } catch (e) {
      debugPrint('Error renaming game asset: $e');
      return null;
    }
  }

  /// Deletes an asset image file from `games/<gameName>/assets/`
  static bool deleteGameAsset(String gameName, String relativeOrFileName) {
    try {
      final targetFile = resolveCardImageFile(gameName, relativeOrFileName);
      if (targetFile != null && targetFile.existsSync()) {
        targetFile.deleteSync();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting game asset: $e');
    }
    return false;
  }
}
