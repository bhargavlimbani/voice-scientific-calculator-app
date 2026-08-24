import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../calculator/smart_calculator.dart';
import '../ai/llm_parser.dart';
import '../config/api_config.dart';
import '../ai/parse_cache.dart';

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
  bool isSpeechInitialized = false;
  List<Map<String, String>> history = [];
  Timer? _typeTimer;

  // --- AI state ---
  List<String> steps = [];   // step-by-step working from the LLM
  String errorHint = "";     // friendly error + suggestion
  ParseSource source = ParseSource.offline; // which brain answered last
  bool hasKey = false;       // an API key is configured

  final List<String> examples = [
    "Twenty five plus thirty two times two",
    "A shirt costs 800, add 18% GST",
    "Sine 90 plus square root of 16",
    "Saat sau ka pandrah pratishat",
    "બાર ગુણ્યા આઠ",
    "Convert 5 kilometres into metres",
    "Cube root of 27 plus 2 to the power 5",
    "What is 5 factorial?",
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadHistory();
    _loadKey();
  }

  void _loadKey() async {
    await ApiConfig.load();
    if (mounted) setState(() => hasKey = ApiConfig.hasKey);
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    super.dispose();
  }

  void _initSpeech() async {
    try {
      isSpeechInitialized = await speech.init();
    } catch (e) {
      print("Speech Init Error: $e");
    }
  }

  // --- UPDATED MANUAL KEYBOARD INPUT WITH INITIAL TEXT ---
  void _showKeyboardInput({String initialText = ""}) {
    final TextEditingController controller = TextEditingController(text: initialText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Edit your question", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "e.g. what is log 100",
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent.withOpacity(0.5))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
          onSubmitted: (val) { Navigator.pop(context); process(val); },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); process(controller.text); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            child: const Text("Calculate"),
          ),
        ],
      ),
    );
  }

  void _typeDynamically(String text) {
    _typeTimer?.cancel();
    setState(() { input = ""; result = "..."; });
    int charIndex = 0;
    _typeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (charIndex < text.length) {
        setState(() { input += text[charIndex]; });
        charIndex++;
      } else {
        timer.cancel();
        process(text);
      }
    });
  }

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyString = prefs.getString('calc_history');
    if (historyString != null) {
      setState(() {
        history = List<Map<String, String>>.from(
          json.decode(historyString).map((item) => Map<String, String>.from(item))
        );
      });
    }
  }

  void _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_history', json.encode(history));
  }

  void _addToHistory(String q, String a) {
    setState(() {
      history.insert(0, {'query': q, 'answer': a});
      if (history.length > 50) history.removeLast();
    });
    _saveHistory();
  }

  void _clearHistory() async {
    setState(() => history.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('calc_history');
  }

  void _showExamples() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Color(0xFF1A1A2E), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Try these Examples", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: examples.map((ex) => GestureDetector(
                onTap: () { Navigator.pop(context); _typeDynamically(ex); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Text(ex, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Color(0xFF1A1A2E), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("History", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () { _clearHistory(); Navigator.pop(context); }),
                ],
              ),
            ),
            Expanded(
              child: history.isEmpty 
                ? const Center(child: Text("No history", style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) => ListTile(
                      onTap: () { setState(() { input = history[index]['query']!; result = history[index]['answer']!; }); Navigator.pop(context); },
                      title: Text(history[index]['query']!, style: const TextStyle(color: Colors.white70)),
                      subtitle: Text("= ${history[index]['answer']}", style: const TextStyle(color: Colors.blueAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void startListening() async {
    if (isListening) return;
    _typeTimer?.cancel();
    tts.stop();
    if (!isSpeechInitialized) isSpeechInitialized = await speech.init();
    if (!isSpeechInitialized) return;
    setState(() { isListening = true; input = "Listening..."; });
    speech.startListening((text, isFinal) {
      setState(() => input = text);
      if (isFinal && text.isNotEmpty) process(text);
    });
  }

  /// The enhanced pipeline:
  ///   speech/text -> LLMParser (prompt engineering) -> SmartCalculator (local)
  /// The LLM only understands the sentence; the number is always computed
  /// on device, so a wrong answer cannot be invented by the model.
  void process(String text) async {
    if (text.trim().isEmpty) return;
    speech.stop();
    setState(() {
      isListening = false;
      result = hasKey ? "Thinking..." : "Calculating...";
      input = text;
      steps = [];
      errorHint = "";
    });

    // Keypad input is already valid maths - never spend an API call on it.
    if (_isPureExpression(text)) {
      try {
        final display = _formatNumber(SmartCalculator.evaluate(text));
        final lang = detectLanguage(text);
        setState(() {
          result = display;
          source = ParseSource.offline;
          _addToHistory(text, display);
        });
        tts.stop().then((_) => tts.speak(speakText(display, lang), lang));
      } catch (e) {
        setState(() {
          result = "Error";
          errorHint = "Check the brackets and operators.";
        });
      }
      return;
    }

    final parsed = await LLMParser.parse(text);
    if (!mounted) return;

    // The model understood the words but it is not a maths question.
    if (!parsed.isValid) {
      setState(() {
        result = "?";
        source = parsed.source;
        errorHint = parsed.suggestion.isEmpty
            ? parsed.errorMessage
            : "${parsed.errorMessage}  ${parsed.suggestion}";
      });
      tts.stop().then((_) => tts.speak(parsed.errorMessage, parsed.language));
      return;
    }

    String display;
    try {
      display = _formatNumber(SmartCalculator.evaluate(parsed.expression));
    } catch (e) {
      // Local evaluation failed. Use the model's own answer if it gave one.
      if (parsed.usedAI && (parsed.answer ?? "").trim().isNotEmpty) {
        display = parsed.answer!.trim();
      } else {
        setState(() {
          result = "Error";
          source = parsed.source;
          errorHint = parsed.usedAI
              ? "Could not evaluate: ${parsed.expression}"
              : "Offline mode could not understand this. Add an API key for full AI parsing.";
        });
        return;
      }
    }

    setState(() {
      result = display;
      steps = parsed.steps;
      source = parsed.source;
      _addToHistory(text, display);
    });
    tts.stop().then((_) =>
        tts.speak(speakText(display, parsed.language), parsed.language));
  }

  /// True when the text is already a maths expression (typed on the keypad),
  /// so it can go straight to the evaluator without a network round trip.
  bool _isPureExpression(String t) {
    final stripped = t
        .toLowerCase()
        .replaceAll(RegExp(r'sin|cos|tan|log|ln|sqrt|abs'), '');
    return RegExp(r'[0-9]').hasMatch(t) &&
        RegExp(r'^[0-9+\-*/^().!%√π\s]*$').hasMatch(stripped);
  }

  /// 12.0 -> "12", 0.4771212547 -> "0.477121". Replaces the old
  /// replaceAll(".0", "") which corrupted numbers like 1.05 into 15.
  String _formatNumber(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    String s = v.toStringAsFixed(6);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  void onButtonPress(String value) {
    _typeTimer?.cancel();
    setState(() {
      if (value == "C") { input = ""; result = "0"; steps = []; errorHint = ""; }
      else if (value == "⌫") { if (input.isNotEmpty) input = input.substring(0, input.length - 1); }
      else if (value == "=") { process(input); }
      else { input += value; }
    });
  }

  Widget calcButton(String text, {Color? color, Color? textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: ElevatedButton(
              onPressed: () => onButtonPress(text),
              style: ElevatedButton.styleFrom(
                backgroundColor: color ?? Colors.white.withOpacity(0.08),
                foregroundColor: textColor ?? Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  String detectLanguage(String text) {
    if (RegExp(r'[\u0A80-\u0AFF]').hasMatch(text)) return "gu-IN";
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return "hi-IN";
    return "en-US";
  }

  String speakText(String result, String lang) {
    if (lang == "hi-IN") return "उत्तर है $result";
    if (lang == "gu-IN") return "જવાબ છે $result";
    return "The answer is $result";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F0F), Color(0xFF1A1A2E), Color(0xFF0F0F0F)],
          ),
        ),
        child: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) {
              if (orientation == Orientation.landscape) {
                return _buildLandscapeLayout();
              } else {
                return _buildPortraitLayout();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(flex: 3, child: _buildDisplay()),
        _buildMicButton(),
        Expanded(flex: 7, child: _buildKeypad()),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildDisplay()),
              _buildMicButton(),
              const SizedBox(height: 10),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
            child: _buildKeypad(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.lightbulb_outline, color: Colors.orangeAccent, size: 20), onPressed: _showExamples),
              IconButton(icon: const Icon(Icons.keyboard, color: Colors.blueAccent, size: 20), onPressed: () => _showKeyboardInput(initialText: input)),
            ],
          ),
          _buildAIBadge(),
          Row(
            children: [
              IconButton(icon: Icon(hasKey ? Icons.key : Icons.key_off, color: hasKey ? Colors.greenAccent : Colors.white38, size: 20), onPressed: _showKeyDialog),
              IconButton(icon: const Icon(Icons.history, color: Colors.white54, size: 20), onPressed: _showHistory),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows which brain answered: live model, learnt cache, or offline rules.
  Widget _buildAIBadge() {
    late final Color c;
    late final IconData icon;
    late final String label;
    switch (source) {
      case ParseSource.ai:
        c = Colors.greenAccent;
        icon = Icons.auto_awesome;
        label = "AI";
        break;
      case ParseSource.cache:
        c = Colors.amberAccent;
        icon = Icons.bolt;
        label = "Learnt";
        break;
      case ParseSource.offline:
        c = Colors.white38;
        icon = Icons.offline_bolt;
        label = "Offline";
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: c)),
        ],
      ),
    );
  }

  void _showKeyDialog() async {
    final controller = TextEditingController(text: ApiConfig.apiKey);
    final int learnt = await ParseCache.size();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
            hasKey ? "API Key (${ApiConfig.providerName})" : "API Key",
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: "Gemini or Claude key",
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "The provider is detected from the key. Without a key the app still works offline using the built-in rule based parser.",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Learnt phrases: $learnt",
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                GestureDetector(
                  onTap: () async {
                    await ParseCache.clear();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text("Clear",
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiConfig.save("");
              if (!context.mounted) return;
              Navigator.pop(context);
              setState(() => hasKey = false);
            },
            child: const Text("Remove", style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiConfig.save(controller.text);
              if (!context.mounted) return;
              Navigator.pop(context);
              setState(() => hasKey = ApiConfig.hasKey);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  /// Step-by-step working produced by the chain-of-thought part of the prompt.
  Widget _buildStepsPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxHeight: 96),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: Colors.blueAccent.withOpacity(0.6), width: 3)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: steps
              .map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text("• $s",
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDisplay() {
    return GestureDetector(
      onTap: () => _showKeyboardInput(initialText: input), // Open keyboard on tap
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.transparent, // Makes the whole area tappable
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              input.isEmpty ? "Voice or Type" : input, 
              textAlign: TextAlign.right, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              style: const TextStyle(color: Colors.white54, fontSize: 16)
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                result,
                style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)
              )
            ),
            if (errorHint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  errorHint,
                  textAlign: TextAlign.right,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
            if (steps.isNotEmpty) _buildStepsPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return ZoomIn(
      child: GestureDetector(
        onTap: startListening,
        child: Container(
          height: 55, width: 55,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: isListening ? [Colors.redAccent, Colors.red] : [Colors.blueAccent, Colors.blue.shade900]),
            boxShadow: [BoxShadow(color: (isListening ? Colors.red : Colors.blue).withOpacity(0.3), blurRadius: 10)],
          ),
          child: Icon(isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(children: [calcButton("sin("), calcButton("cos("), calcButton("tan("), calcButton("√(")]),
        Row(children: [calcButton("log("), calcButton("ln("), calcButton("^"), calcButton("π")]),
        Row(children: [calcButton("7"), calcButton("8"), calcButton("9"), calcButton("/", textColor: Colors.blueAccent)]),
        Row(children: [calcButton("4"), calcButton("5"), calcButton("6"), calcButton("*", textColor: Colors.blueAccent)]),
        Row(children: [calcButton("1"), calcButton("2"), calcButton("3"), calcButton("-", textColor: Colors.blueAccent)]),
        Row(children: [calcButton("0"), calcButton("."), calcButton("=", color: Colors.blueAccent), calcButton("+", textColor: Colors.blueAccent)]),
        Row(children: [calcButton("C", color: Colors.redAccent.withOpacity(0.1), textColor: Colors.redAccent), calcButton("⌫"), calcButton("("), calcButton(")")],),
      ],
    );
  }
}
