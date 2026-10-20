import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../features/editor/services/game_folder_service.dart';
import 'app_strings.dart';

class LocaleNotifier extends StateNotifier<AppLanguage> {
  LocaleNotifier() : super(_loadInitialLanguage());

  static File _getPreferencesFile() {
    try {
      final root = GameFolderService.getGamesRootDir();
      return File('${root.path}/user_preferences.json');
    } catch (_) {
      return File('${Directory.systemTemp.path}/grimoire_user_preferences.json');
    }
  }

  static AppLanguage _loadInitialLanguage() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return AppLanguage.en;
    }
    try {
      final file = _getPreferencesFile();
      if (file.existsSync()) {
        final raw = file.readAsStringSync();
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic> && data['language'] is String) {
          final langCode = data['language'].toString();
          for (final lang in AppLanguage.values) {
            if (lang.name == langCode) return lang;
          }
        }
      }
    } catch (_) {}
    return AppLanguage.es;
  }

  static void _persistLanguage(AppLanguage language) {
    try {
      final file = _getPreferencesFile();
      Map<String, dynamic> data = {};
      if (file.existsSync()) {
        try {
          final raw = file.readAsStringSync();
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        } catch (_) {}
      } else {
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
      }
      data['language'] = language.name;
      file.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  void setLanguage(AppLanguage language) {
    state = language;
    _persistLanguage(language);
  }

  void toggleLanguage() {
    final next = state == AppLanguage.en ? AppLanguage.es : AppLanguage.en;
    state = next;
    _persistLanguage(next);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, AppLanguage>((ref) {
  return LocaleNotifier();
});

// Extension to conveniently look up translated strings in Consumer widgets
extension WidgetRefStrings on WidgetRef {
  String tr(String key) {
    final lang = watch(localeProvider);
    return AppStrings.get(lang, key);
  }
}

