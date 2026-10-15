import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'app_strings.dart';

class LocaleNotifier extends StateNotifier<AppLanguage> {
  LocaleNotifier() : super(AppLanguage.es);

  void setLanguage(AppLanguage language) {
    state = language;
  }

  void toggleLanguage() {
    state = state == AppLanguage.es ? AppLanguage.en : AppLanguage.es;
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
