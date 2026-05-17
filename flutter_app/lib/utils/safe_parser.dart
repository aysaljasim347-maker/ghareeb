/// Utility for safe JSON parsing in Flutter.
/// Prevents runtime TypeErrors by handling String/num mismatches and nulls.
class SafeParser {
  SafeParser._();

  /// Safely converts a dynamic value to a double.
  /// Handles String, num, and null. Defaults to [defaultValue].
  static double toDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Safely converts a dynamic value to an int.
  /// Handles String, num, and null. Defaults to [defaultValue].
  static int paramInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? defaultValue;
    }
    return defaultValue;
  }

  /// Safely converts a dynamic value to a String.
  /// Handles any type. Defaults to [defaultValue].
  static String toStringSafe(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  /// Safely converts a dynamic value to a boolean.
  /// Handles bool and int (1/0). Defaults to [defaultValue].
  static bool toBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return defaultValue;
  }
}
