/// Which AI writes the AI 리포트. Set once in `lib/main.dart`; the server
/// holds the keys (Railway variables), so switching here only works if the
/// matching key is set there.
enum AiProvider {
  /// Railway variable `MODEL_API_KEY` (or `GEMINI_API_KEY`).
  gemini,

  /// Railway variable `ANTHROPIC_API_KEY`.
  claude,
}

class AiSettings {
  AiSettings._();

  static AiProvider provider = AiProvider.gemini;
}
