import 'package:ali_app/services/env_config.dart';

class GeminiConfig {
  GeminiConfig._();

  /// Paste the API key you created in Google AI Studio (starts with "AIza").
  /// Keep this secret — never commit it to a public repo.
  /// Set it in your `.env` file as GEMINI_API_KEY.
  static String get apiKey => EnvConfig.get('GEMINI_API_KEY');

  /// Free-tier friendly model. Change only this line to switch models.
  static String get model => EnvConfig.get('GEMINI_MODEL', fallback: 'gemini-3.6-flash');
}
