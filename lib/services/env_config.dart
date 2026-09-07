import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central helper for reading environment variables from `.env`.
///
/// Call [load] once before the app starts (see `lib/main.dart`), then read
/// values with [get] or the typed helpers below.
class EnvConfig {
  EnvConfig._();

  static bool _loaded = false;

  /// Loads the `.env` file bundled as an asset.
  /// Safe to call multiple times; subsequent calls are no-ops.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
    } catch (e, st) {
      // In release mode a missing .env is fatal; in debug we just warn so
      // developers know to create the file from .env.example.
      if (kDebugMode) {
        debugPrint('[EnvConfig] Failed to load .env: $e');
        debugPrint('$st');
      }
    }
  }

  /// Reloads the environment (useful after hot-restart with a new .env).
  static Future<void> reload() async {
    _loaded = false;
    await load();
  }

  /// Returns the raw value for [key], or [fallback] if it is missing/empty.
  static String get(String key, {String fallback = ''}) {
    final value = dotenv.env[key];
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  /// Returns true if [key] is present and non-empty.
  static bool has(String key) {
    final value = dotenv.env[key];
    return value != null && value.trim().isNotEmpty;
  }

  /// Parses [key] as an integer, returning [fallback] on failure.
  static int getInt(String key, {int fallback = 0}) {
    return int.tryParse(get(key)) ?? fallback;
  }

  /// Parses [key] as a double, returning [fallback] on failure.
  static double getDouble(String key, {double fallback = 0.0}) {
    return double.tryParse(get(key)) ?? fallback;
  }

  /// Returns true when [key] equals 'true', '1', or 'yes' (case-insensitive).
  static bool getBool(String key, {bool fallback = false}) {
    final value = get(key).toLowerCase();
    if (value.isEmpty) return fallback;
    return value == 'true' || value == '1' || value == 'yes';
  }
}
