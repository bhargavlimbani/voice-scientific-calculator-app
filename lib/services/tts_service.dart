import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();

  Future speak(String text, String lang) async {
    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  Future stop() async {
    await _tts.stop(); // 🔥 IMPORTANT
  }
}