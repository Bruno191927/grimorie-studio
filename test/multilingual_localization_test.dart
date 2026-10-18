import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grimoire_studio/core/localization/app_strings.dart';
import 'package:grimoire_studio/core/localization/locale_provider.dart';

void main() {
  group('Multilingual Localization Tests (ES, EN, FR, IT, JA)', () {
    test('All 5 languages provide valid translations for core UI navigation keys', () {
      const keysToCheck = [
        'nav_gallery',
        'nav_editor',
        'nav_database',
        'nav_playtest',
        'btn_batch_export',
        'delete_card',
        'delete_game',
        'new_category_btn',
        'create_preset_card_model',
      ];

      for (final lang in AppLanguage.values) {
        for (final key in keysToCheck) {
          final translated = AppStrings.get(lang, key);
          expect(translated, isNotEmpty, reason: 'Key $key in $lang should not be empty');
          expect(translated, isNot(equals(key)), reason: 'Key $key in $lang should not fallback to its raw key name');
        }
      }
    });

    test('AppLanguage.fr returns accurate French translations', () {
      expect(AppStrings.get(AppLanguage.fr, 'nav_gallery'), 'Galerie de Cartes');
      expect(AppStrings.get(AppLanguage.fr, 'nav_editor'), 'Éditeur de Canevas');
      expect(AppStrings.get(AppLanguage.fr, 'nav_database'), 'Base de Données & CSV');
      expect(AppStrings.get(AppLanguage.fr, 'nav_playtest'), 'Tapis de Jeu (Playtest)');
      expect(AppStrings.get(AppLanguage.fr, 'delete_game'), 'Supprimer le Jeu');
      expect(AppStrings.get(AppLanguage.fr, 'create_preset_card_model'), '+ Modèle Prédéfini');
    });

    test('AppLanguage.it returns accurate Italian translations', () {
      expect(AppStrings.get(AppLanguage.it, 'nav_gallery'), 'Galleria Carte');
      expect(AppStrings.get(AppLanguage.it, 'nav_editor'), 'Editor Canvas');
      expect(AppStrings.get(AppLanguage.it, 'nav_database'), 'Database & CSV');
      expect(AppStrings.get(AppLanguage.it, 'nav_playtest'), 'Tappeto di Playtest');
      expect(AppStrings.get(AppLanguage.it, 'delete_game'), 'Elimina Gioco');
      expect(AppStrings.get(AppLanguage.it, 'create_preset_card_model'), '+ Modello Preset');
    });

    test('AppLanguage.ja returns accurate Japanese translations', () {
      expect(AppStrings.get(AppLanguage.ja, 'nav_gallery'), 'カードギャラリー');
      expect(AppStrings.get(AppLanguage.ja, 'nav_editor'), 'キャンバスエディタ');
      expect(AppStrings.get(AppLanguage.ja, 'nav_database'), 'データベース & CSV');
      expect(AppStrings.get(AppLanguage.ja, 'nav_playtest'), 'プレイテストマット');
      expect(AppStrings.get(AppLanguage.ja, 'delete_game'), 'ゲーム削除');
      expect(AppStrings.get(AppLanguage.ja, 'create_preset_card_model'), '+ プリセットモデル');
    });

    test('LocaleNotifier correctly switches between all supported languages', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(localeProvider), AppLanguage.es);

      container.read(localeProvider.notifier).setLanguage(AppLanguage.en);
      expect(container.read(localeProvider), AppLanguage.en);

      container.read(localeProvider.notifier).setLanguage(AppLanguage.fr);
      expect(container.read(localeProvider), AppLanguage.fr);

      container.read(localeProvider.notifier).setLanguage(AppLanguage.it);
      expect(container.read(localeProvider), AppLanguage.it);

      container.read(localeProvider.notifier).setLanguage(AppLanguage.ja);
      expect(container.read(localeProvider), AppLanguage.ja);
    });
  });
}
