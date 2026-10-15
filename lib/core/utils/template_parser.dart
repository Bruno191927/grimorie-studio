class TemplateParser {
  static final RegExp _variablePattern = RegExp(r'\{\{\s*([a-zA-Z0-9_\.\-]+)\s*\}\}');

  /// Replaces all {{key}} in [template] with the matching value from [data].
  /// If the key is not present in [data], keeps the token or falls back to [fallback].
  static String parse(
    String template,
    Map<String, dynamic> data, {
    String? fallback,
  }) {
    if (template.isEmpty) return '';

    return template.replaceAllMapped(_variablePattern, (match) {
      final key = match.group(1);
      if (key == null) return match.group(0) ?? '';

      // Check exact match, case-insensitive match, or underscored key
      if (data.containsKey(key)) {
        return data[key]?.toString() ?? '';
      }

      // Check lower case
      final lowerKey = key.toLowerCase();
      for (final entry in data.entries) {
        if (entry.key.toLowerCase() == lowerKey) {
          return entry.value?.toString() ?? '';
        }
      }

      return fallback ?? match.group(0) ?? '';
    });
  }

  /// Extracts all {{variable}} keys from a template string
  static List<String> extractKeys(String template) {
    final matches = _variablePattern.allMatches(template);
    return matches.map((m) => m.group(1) ?? '').where((k) => k.isNotEmpty).toList();
  }
}
