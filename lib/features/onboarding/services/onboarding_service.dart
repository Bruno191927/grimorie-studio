import 'dart:convert';
import 'dart:io';
import '../../editor/services/game_folder_service.dart';

class OnboardingService {
  static bool _forceTestMode = false;
  static bool? _inMemoryOverride;

  /// Visible for testing: allows test suite to simulate first run or completed status
  static void setForceTestMode(bool value) => _forceTestMode = value;
  static void setInMemoryOverride(bool? value) => _inMemoryOverride = value;

  static File _getConfigFile() {
    try {
      final root = GameFolderService.getGamesRootDir();
      return File('${root.path}/user_preferences.json');
    } catch (_) {
      return File('${Directory.systemTemp.path}/grimoire_user_preferences.json');
    }
  }

  /// Returns true if the user has already seen or completed the initial tour.
  /// Defaults to true under FLUTTER_TEST so general regression tests run unimpeded.
  static bool hasSeenOnboarding() {
    if (_inMemoryOverride != null) return _inMemoryOverride!;
    if (!_forceTestMode && Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    try {
      final file = _getConfigFile();
      if (!file.existsSync()) return false;
      final raw = file.readAsStringSync();
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        return data['has_seen_onboarding'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Persists whether the user completed or dismissed the onboarding guide.
  static Future<void> setOnboardingCompleted({bool completed = true}) async {
    _inMemoryOverride = completed;
    try {
      final file = _getConfigFile();
      Map<String, dynamic> data = {};
      if (file.existsSync()) {
        try {
          final raw = file.readAsStringSync();
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        } catch (_) {}
      } else if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      data['has_seen_onboarding'] = completed;
      data['completed_at'] = DateTime.now().toIso8601String();
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }
}
