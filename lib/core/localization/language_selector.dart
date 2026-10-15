import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/grimoire_theme.dart';
import 'app_strings.dart';
import 'locale_provider.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(localeProvider);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141826),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: currentLang,
          dropdownColor: GrimoireTheme.surfaceElevated,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: GrimoireTheme.textSecondary),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          items: const [
            DropdownMenuItem(
              value: AppLanguage.es,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🇪🇸', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text('ES (Español)', style: TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: AppLanguage.en,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🇬🇧', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text('EN (English)', style: TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            ),
          ],
          onChanged: (lang) {
            if (lang != null) {
              ref.read(localeProvider.notifier).setLanguage(lang);
            }
          },
        ),
      ),
    );
  }
}
