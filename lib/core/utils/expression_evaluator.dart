class ExpressionEvaluator {
  /// Evaluates an expression like 'cost > 5' or 'type == "Creature"' against [data].
  /// Returns true if condition holds, false otherwise.
  static bool evaluate(String expression, Map<String, dynamic> data) {
    final exp = expression.trim();
    if (exp.isEmpty) return true;

    // Supported operators in order of tokenization
    final operators = ['>=', '<=', '!=', '==', '>', '<'];

    for (final op in operators) {
      if (exp.contains(op)) {
        final parts = exp.split(op);
        if (parts.length == 2) {
          final leftKey = parts[0].trim();
          final rightRaw = parts[1].trim();

          final leftVal = _resolveValue(leftKey, data);
          final rightVal = _parseConstant(rightRaw);

          return _compare(leftVal, rightVal, op);
        }
      }
    }

    // Direct boolean check (e.g. "is_foil")
    final val = _resolveValue(exp, data);
    if (val is bool) return val;
    if (val is num) return val > 0;
    if (val is String) {
      final lower = val.toLowerCase();
      return lower == 'true' || lower == 'yes' || lower == '1';
    }

    return true;
  }

  static dynamic _resolveValue(String key, Map<String, dynamic> data) {
    if (data.containsKey(key)) return data[key];
    final lowerKey = key.toLowerCase();
    for (final entry in data.entries) {
      if (entry.key.toLowerCase() == lowerKey) {
        return entry.value;
      }
    }
    return null;
  }

  static dynamic _parseConstant(String raw) {
    // String literal with quotes
    if ((raw.startsWith('"') && raw.endsWith('"')) || (raw.startsWith("'") && raw.endsWith("'"))) {
      return raw.substring(1, raw.length - 1);
    }
    // Number
    final numVal = num.tryParse(raw);
    if (numVal != null) return numVal;
    // Boolean
    if (raw.toLowerCase() == 'true') return true;
    if (raw.toLowerCase() == 'false') return false;

    return raw;
  }

  static bool _compare(dynamic left, dynamic right, String op) {
    if (left == null) return false;

    // Convert both to numbers if comparable
    if (left is num || right is num) {
      final leftNum = (left is num) ? left : num.tryParse(left.toString());
      final rightNum = (right is num) ? right : num.tryParse(right.toString());

      if (leftNum != null && rightNum != null) {
        switch (op) {
          case '>':
            return leftNum > rightNum;
          case '<':
            return leftNum < rightNum;
          case '>=':
            return leftNum >= rightNum;
          case '<=':
            return leftNum <= rightNum;
          case '==':
            return leftNum == rightNum;
          case '!=':
            return leftNum != rightNum;
        }
      }
    }

    // String comparison
    final leftStr = left.toString();
    final rightStr = right?.toString() ?? '';

    switch (op) {
      case '==':
        return leftStr.toLowerCase() == rightStr.toLowerCase();
      case '!=':
        return leftStr.toLowerCase() != rightStr.toLowerCase();
      case '>=':
        return leftStr.compareTo(rightStr) >= 0;
      case '<=':
        return leftStr.compareTo(rightStr) <= 0;
      case '>':
        return leftStr.compareTo(rightStr) > 0;
      case '<':
        return leftStr.compareTo(rightStr) < 0;
      default:
        return false;
    }
  }
}
