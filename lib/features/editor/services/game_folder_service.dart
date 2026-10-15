import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';

class GameFolderService {
  /// Base directory where games and their assets are organized:
  /// games/
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

  /// Sanitizes game name for cross-platform folder naming
  static String sanitizeFolderName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Returns the folder directory for a specific game
  static Directory getGameDir(String gameName) {
    final folder = sanitizeFolderName(gameName);
    final sep = Platform.isWindows ? '\\' : '/';
    return Directory('${getGamesRootDir().path}$sep$folder');
  }

  /// Returns the assets/ directory inside a specific game folder
  static Directory getGameAssetsDir(String gameName) {
    final sep = Platform.isWindows ? '\\' : '/';
    return Directory('${getGameDir(gameName).path}${sep}assets');
  }

  /// Returns the data.csv file for a specific game
  static File getGameDataCsvFile(String gameName) {
    final sep = Platform.isWindows ? '\\' : '/';
    return File('${getGameDir(gameName).path}${sep}data.csv');
  }

  /// Ensures synchronously that the game directory and its assets/ folder exist
  static void ensureGameFolderExistsSync(String gameName) {
    final assetsDir = getGameAssetsDir(gameName);
    if (!assetsDir.existsSync()) {
      assetsDir.createSync(recursive: true);
    }
  }

  /// Ensures that the game directory and its assets/ folder exist
  static Future<void> ensureGameFolderExists(String gameName) async {
    ensureGameFolderExistsSync(gameName);
  }

  /// Exports cards for a game into game/data.csv formatted in standard RFC-4180
  static Future<File> saveGameDataCsv(String gameName, List<Map<String, dynamic>> cards) async {
    await ensureGameFolderExists(gameName);

    final csvFile = getGameDataCsvFile(gameName);
    const headers = [
      'card_name',
      'cost',
      'type',
      'rarity',
      'attack',
      'defense',
      'category',
      'rules_text',
      'prompt',
      'art_url',
      'icon',
      'art_color',
      'game',
      'creator',
    ];

    final rows = <List<dynamic>>[headers];

    for (final card in cards) {
      rows.add([
        card['card_name']?.toString() ?? '',
        card['cost']?.toString() ?? '0',
        card['type']?.toString() ?? '',
        card['rarity']?.toString() ?? '',
        card['attack']?.toString() ?? '0',
        card['defense']?.toString() ?? '0',
        card['category']?.toString() ?? '',
        card['rules_text']?.toString() ?? '',
        card['prompt']?.toString() ?? '',
        card['art_url']?.toString() ?? '',
        card['icon']?.toString() ?? '🃏',
        card['art_color'] is int
            ? '0x${(card['art_color'] as int).toRadixString(16).padLeft(8, '0').toUpperCase()}'
            : (card['art_color']?.toString() ?? '0xFF7C3AED'),
        card['game']?.toString() ?? gameName,
        card['creator']?.toString() ?? 'Grimoire Studio',
      ]);
    }

    final csvString = csv.encode(rows);
    // Write UTF-8 with BOM for optimal compatibility with Excel and text editors
    await csvFile.writeAsString('\uFEFF$csvString', encoding: utf8);
    return csvFile;
  }

  /// Reads and parses cards from game/data.csv
  static Future<List<Map<String, dynamic>>> loadGameDataCsv(String gameName) async {
    final csvFile = getGameDataCsvFile(gameName);
    if (!await csvFile.exists()) {
      return [];
    }

    var content = await csvFile.readAsString(encoding: utf8);
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

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

      if (!card.containsKey('game') || card['game'].toString().isEmpty) {
        card['game'] = gameName;
      }
      result.add(card);
    }

    return result;
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
  static Future<File> importImageToGameAssets(String gameName, File sourceFile, {String? customFileName}) async {
    await ensureGameFolderExists(gameName);
    final assetsDir = getGameAssetsDir(gameName);
    final fileName = customFileName ?? sourceFile.uri.pathSegments.last;
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetFile = File('${assetsDir.path}/$sanitizedFileName');
    return await sourceFile.copy(targetFile.path);
  }

  /// Lists all valid image files currently stored in `games/<gameName>/assets/`
  static List<File> listGameAssetImages(String gameName) {
    try {
      final assetsDir = getGameAssetsDir(gameName);
      if (!assetsDir.existsSync()) return [];
      final files = assetsDir.listSync().whereType<File>();
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
    final cleanUrl = artUrl.trim();

    // 1. Direct path check
    final directFile = File(cleanUrl);
    if (directFile.existsSync()) return directFile;

    // 2. Relative to game folder: games/<game>/<artUrl>
    final inGameFile = File('${getGameDir(gameName).path}/$cleanUrl');
    if (inGameFile.existsSync()) return inGameFile;

    // 3. In assets/ subfolder: games/<game>/assets/<artUrl>
    final inAssetsFile = File('${getGameAssetsDir(gameName).path}/$cleanUrl');
    if (inAssetsFile.existsSync()) return inAssetsFile;

    // 4. By filename inside assets/
    final baseName = cleanUrl.split(RegExp(r'[\\/]')).last;
    final baseInAssetsFile = File('${getGameAssetsDir(gameName).path}/$baseName');
    if (baseInAssetsFile.existsSync()) return baseInAssetsFile;

    return null;
  }

  /// Returns the count of images currently in game/assets/
  static int getAssetsCount(String gameName) {
    try {
      final assetsDir = getGameAssetsDir(gameName);
      if (!assetsDir.existsSync()) return 0;
      final files = assetsDir.listSync().whereType<File>();
      return files.where((f) {
        final ext = f.path.toLowerCase();
        return ext.endsWith('.png') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.webp');
      }).length;
    } catch (_) {
      return 0;
    }
  }

  /// Opens the game's assets/ directory directly in the native OS file explorer (Windows Explorer, Finder, etc.)
  static Future<bool> openGameAssetsFolderInExplorer(String gameName) async {
    await ensureGameFolderExists(gameName);
    final dir = getGameAssetsDir(gameName);
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

  /// Deletes an asset image file from `games/<gameName>/assets/<fileName>`
  static bool deleteGameAsset(String gameName, String fileName) {
    try {
      final assetsDir = getGameAssetsDir(gameName);
      final sanitized = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final target = File('${assetsDir.path}/$sanitized');
      if (target.existsSync()) {
        target.deleteSync();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting game asset: $e');
    }
    return false;
  }
}

