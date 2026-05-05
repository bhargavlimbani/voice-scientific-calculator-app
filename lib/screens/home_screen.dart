import 'package:flutter/material.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../calculator/smart_calculator.dart';
import '../ai/ai_parser.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechService speech = SpeechService();
  final TTSService tts = TTSService();

  String input = "";
  String result = "0";
  bool isListening = false;

  // 🌍 Language detection
  String detectLanguage(String text) {
    if (RegExp(r'[\u0A80-\u0AFF]').hasMatch(text)) {
      return "gu-IN"; // Gujarati
    }

    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return "hi-IN"; // Hindi
    }

    return "en-US"; // Default English
  }

// 🔊 Text formatting
  String speakText(String result, String lang) {
    if (lang == "hi-IN") return "उत्तर है $result";
    if (lang == "gu-IN") return "જવાબ છે $result";
    return "Answer is $result";
  }

  // 🎤 Voice
  void startListening() async {
    if (isListening) return;

    // 🔴 STOP TTS before starting mic
    await tts.stop();

    bool available = await speech.init();
    if (!available) return;

    setState(() {
      isListening = true;
      input = "Listening...";
    });

    speech.startListening((text, isFinal) {
      setState(() {
        input = text;
      });

      if (isFinal && text.isNotEmpty) {
        process(text);
      }
    });
  }
  
  void process(String text) async {
    await speech.stop();

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      String aiText = AIParser.process(text);

      // 🔥 ADD HERE
      print("RAW INPUT: $text");
      print("AI OUTPUT: $aiText");

      double res = SmartCalculator.evaluate(aiText);

      String lang = detectLanguage(text);

      setState(() {
        result = res.toString();
        isListening = false;
      });

      await tts.stop();
      await Future.delayed(const Duration(milliseconds: 200));

      await tts.speak(speakText(result, lang), lang);
    } catch (e) {
      setState(() {
        result = "Invalid";
        isListening = false;
      });
    }
  }

  // 🔘 Button logic
  void onButtonPress(String value) {
    setState(() {
      if (value == "C") {
        input = "";
        result = "0";
      } else if (value == "=") {
        process(input);
      } else {
        input += value;
      }
    });
  }

  // 🔘 Button UI (responsive)
  Widget calcButton(String text, {Color color = const Color(0xFF2A2A2A)}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: () => onButtonPress(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: FittedBox(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Scientific Calculator"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 📟 DISPLAY
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.bottomRight,
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        input,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 🎤 MIC
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: GestureDetector(
                onTap: startListening,
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: isListening ? Colors.red : Colors.green,
                  child: const Icon(Icons.mic, color: Colors.white),
                ),
              ),
            ),

            // 🔢 KEYPAD (SCROLLABLE = NO OVERFLOW)
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(children: [
                      calcButton("sin("),
                      calcButton("cos("),
                      calcButton("tan("),
                      calcButton("√("),
                    ]),
                    Row(children: [
                      calcButton("log("),
                      calcButton("ln("),
                      calcButton("^"),
                      calcButton("π"),
                    ]),
                    Row(children: [
                      calcButton("7"),
                      calcButton("8"),
                      calcButton("9"),
                      calcButton("/"),
                    ]),
                    Row(children: [
                      calcButton("4"),
                      calcButton("5"),
                      calcButton("6"),
                      calcButton("*"),
                    ]),
                    Row(children: [
                      calcButton("1"),
                      calcButton("2"),
                      calcButton("3"),
                      calcButton("-"),
                    ]),
                    Row(children: [
                      calcButton("0"),
                      calcButton("."),
                      calcButton("=", color: Colors.orange),
                      calcButton("+"),
                    ]),
                    Row(children: [
                      calcButton("C", color: Colors.red),
                      calcButton("("),
                      calcButton(")"),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
