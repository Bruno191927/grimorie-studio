import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../editor/services/game_folder_service.dart';
import '../models/playtest_models.dart';

class PlaymatService {
  static String get _sep => Platform.isWindows ? '\\' : '/';

  /// Devuelve el archivo JSON de configuración de tapete para el juego especificado
  static File getConfigFile(String gameName) {
    final sanitized = GameFolderService.sanitizeFolderName(gameName.trim());
    if (sanitized.isNotEmpty && sanitized.toLowerCase() != 'all') {
      final gameDir = GameFolderService.getGameDir(sanitized);
      if (!gameDir.existsSync()) {
        try {
          gameDir.createSync(recursive: true);
        } catch (_) {}
      }
      return File('${gameDir.path}${_sep}playmat_config.json');
    }

    final rootDir = GameFolderService.getGamesRootDir();
    if (!rootDir.existsSync()) {
      try {
        rootDir.createSync(recursive: true);
      } catch (_) {}
    }
    return File('${rootDir.path}${_sep}default_playmat_config.json');
  }

  /// Carga la configuración guardada del tapete para un juego
  static Future<CustomPlaymatConfig?> loadConfig(String gameName) async {
    try {
      final file = getConfigFile(gameName);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      final json = jsonDecode(content) as Map<String, dynamic>;
      final config = CustomPlaymatConfig.fromJson(json);

      // Si tiene una imagen configurada, verificar si el archivo existe
      if (config.imagePath != null && !File(config.imagePath!).existsSync()) {
        final targetDir = _getPlaymatsDir(gameName);
        final baseName = File(config.imagePath!).uri.pathSegments.last;
        final fallback = File('${targetDir.path}$_sep$baseName');
        if (fallback.existsSync()) {
          return config.copyWith(imagePath: fallback.path);
        }
      }

      return config;
    } catch (e) {
      debugPrint('Error al cargar configuración de tapete: $e');
      return null;
    }
  }

  /// Guarda la configuración de tapete para un juego
  static Future<bool> saveConfig(String gameName, CustomPlaymatConfig config) async {
    try {
      final file = getConfigFile(gameName);
      final parent = file.parent;
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
      final jsonStr = const JsonEncoder.withIndent('  ').convert(config.toJson());
      await file.writeAsString(jsonStr);
      return true;
    } catch (e) {
      debugPrint('Error al guardar configuración de tapete: $e');
      return false;
    }
  }

  /// Directorio donde se almacenan las imágenes de tapetes personalizados
  static Directory _getPlaymatsDir(String gameName) {
    final sanitized = GameFolderService.sanitizeFolderName(gameName.trim());
    if (sanitized.isNotEmpty && sanitized.toLowerCase() != 'all') {
      final gameDir = GameFolderService.getGameDir(sanitized);
      return Directory('${gameDir.path}${_sep}playmats');
    }
    return Directory('${GameFolderService.getGamesRootDir().path}${_sep}playmats');
  }

  /// Importa una imagen de mesa al directorio local del proyecto para que sea portable
  static Future<String?> importPlaymatImage(String gameName, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;

      final targetDir = _getPlaymatsDir(gameName);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final dotIndex = sourcePath.lastIndexOf('.');
      final ext = dotIndex != -1 ? sourcePath.substring(dotIndex).toLowerCase() : '.png';
      final targetFile = File('${targetDir.path}${_sep}custom_playmat$ext');

      // Copiar el archivo
      await sourceFile.copy(targetFile.path);
      return targetFile.path;
    } catch (e) {
      debugPrint('Error al importar imagen de tapete: $e');
      return sourcePath;
    }
  }
}
