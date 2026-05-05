import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  Future<bool> init() async {
    if (!_isInitialized) {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          print("STATUS: $status");
        },
        onError: (error) {
          print("ERROR: $error");
        },
      );
    }
    return _isInitialized;
  }

  void startListening(Function(String, bool) onResult) async {
    // 🔥 Always stop previous session
    if (_speech.isListening) {
      await _speech.stop();
    }

    await _speech.listen(
      onResult: (val) {
        onResult(val.recognizedWords, val.finalResult);
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      cancelOnError: true,
    );
  }

  Future stop() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;
}