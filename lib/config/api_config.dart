import 'package:shared_preferences/shared_preferences.dart';

enum LLMProvider { gemini, anthropic }

/// Central place for the LLM settings.
///
/// The key can come from two places:
///   1. Compile time  ->  flutter run --dart-define=LLM_API_KEY=...
///   2. Run time      ->  entered by the user in the in-app key dialog
/// Nothing is ever committed to git, so the repo stays clean.
///
/// The provider is detected from the key itself, so the same field accepts
/// either a Google AI Studio key or an Anthropic key with no extra setting.
class ApiConfig {
  // --- Google Gemini (free tier) ---
  static const String geminiModel = "gemini-2.0-flash";
  static const String geminiEndpoint =
      "https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent";

  // --- Anthropic Claude ---
  static const String anthropicModel = "claude-opus-5";
  static const String anthropicEndpoint = "https://api.anthropic.com/v1/messages";
  static const String anthropicVersion = "2023-06-01";

  static const String _compileTimeKey = String.fromEnvironment('LLM_API_KEY');

  static const String _prefsKey = 'llm_api_key';
  static String _runtimeKey = "";

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _runtimeKey = prefs.getString(_prefsKey) ?? "";
  }

  static Future<void> save(String key) async {
    _runtimeKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_runtimeKey.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, _runtimeKey);
    }
  }

  static String get apiKey =>
      _runtimeKey.isNotEmpty ? _runtimeKey : _compileTimeKey;

  static bool get hasKey => apiKey.trim().isNotEmpty;

  /// Anthropic keys are the only ones with a fixed, documented prefix,
  /// so anything else is treated as a Google AI Studio key.
  static LLMProvider get provider =>
      apiKey.trim().startsWith("sk-ant") ? LLMProvider.anthropic : LLMProvider.gemini;

  static String get providerName =>
      provider == LLMProvider.anthropic ? "Claude" : "Gemini";

  static String get modelName =>
      provider == LLMProvider.anthropic ? anthropicModel : geminiModel;
}
