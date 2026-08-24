import 'dart:convert';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'ai_parser.dart';
import 'parse_cache.dart';

/// Which brain produced the answer, for the badge in the UI.
enum ParseSource { ai, cache, offline }

/// Everything the UI needs after one natural-language query is understood.
class ParseResult {
  final String expression; // clean, evaluable math, e.g. "800+(18/100)*800"
  final List<String> steps; // human readable working
  final String language; // en-US | hi-IN | gu-IN
  final String? answer; // model's own answer, used only as a last resort
  final bool isValid;
  final String errorMessage;
  final String suggestion;
  final ParseSource source;

  ParseResult({
    required this.expression,
    this.steps = const [],
    this.language = "en-US",
    this.answer,
    this.isValid = true,
    this.errorMessage = "",
    this.suggestion = "",
    this.source = ParseSource.offline,
  });

  /// True when the understanding came from the language model, live or learnt.
  bool get usedAI => source != ParseSource.offline;
}

/// Prompt-engineered natural language -> math expression engine.
///
/// Technique stack:
///   * Role / system prompting     - fixes the persona and the output contract
///   * Few-shot prompting          - 10 curated speech-to-math examples
///   * Chain-of-thought            - the "steps" field forces explicit working
///   * Structured output prompting - JSON schema enforced by the API itself
///
/// The model only *understands* the query. The arithmetic is still done
/// locally by SmartCalculator, so the number on screen can never be a
/// hallucination.
class LLMParser {
  static const String _systemPrompt = r'''
You are the natural-language understanding engine inside a scientific
calculator app. You convert a spoken or typed question into a single
mathematical expression that a strict parser can evaluate, plus a short
step-by-step explanation.

You never chat, greet, apologise, or add commentary. You only return data.

EXPRESSION RULES (the local parser is strict - obey exactly):
1. Allowed tokens only: digits . + - * / ^ ( ) ! and the functions
   sin cos tan log ln sqrt abs
2. log means base 10. ln means natural log.
3. Trigonometric arguments are in DEGREES. sin(90) is 1.
4. Never output the letter e for Euler's number - write 2.718281828 instead.
   Never output the % sign - expand it, so 18% of 800 becomes (18/100)*800.
   Never output commas inside numbers - write 25000, not 25,000.
5. Every function call must have brackets: sqrt(16), not sqrt 16.
6. The expression must contain no words and no spaces.

SPEECH RECOGNITION REPAIR:
Voice input is noisy. Repair obvious mishearings before converting:
sign / sine -> sin, course / cause / coz / cosign -> cos, tangent -> tan,
logarithm / log of -> log, route / root -> sqrt, power / raised to -> ^,
"for" often means 4, "too" and "to" often mean 2, "won" often means 1.
Read the whole sentence before deciding - "divide hundred by for" is 100/4.

LANGUAGE:
Understand English, Hindi, Gujarati and mixed Hinglish, in any script.
Set "language" to gu-IN for Gujarati, hi-IN for Hindi (including Hinglish
typed in Latin script), otherwise en-US. Write the "steps" in that same
language so the user can read their own working.

WORD PROBLEMS AND CONVERSIONS:
Real questions are allowed - taxes, discounts, averages, percentages, unit
conversion, simple interest. Turn the story into one expression and put the
reasoning in "steps".

INVALID INPUT:
If the text is not a solvable maths question, set isValid to false, leave
expression as "", write a short friendly errorMessage, and put your best
guess of what they meant in suggestion. Never invent a calculation.

EXAMPLES

Input: what is sine ninety plus square root of sixteen
Output: {"isValid":true,"expression":"sin(90)+sqrt(16)","steps":["sin(90) = 1","sqrt(16) = 4","1 + 4 = 5"],"answer":"5","language":"en-US","errorMessage":"","suggestion":""}

Input: twenty five plus thirty two times two
Output: {"isValid":true,"expression":"25+32*2","steps":["Multiply first: 32 x 2 = 64","Then add: 25 + 64 = 89"],"answer":"89","language":"en-US","errorMessage":"","suggestion":""}

Input: divide hundred by for
Output: {"isValid":true,"expression":"100/4","steps":["Heard 'for' but the number 4 was meant","100 / 4 = 25"],"answer":"25","language":"en-US","errorMessage":"","suggestion":""}

Input: a shirt costs 800 rupees add 18 percent gst what is the total
Output: {"isValid":true,"expression":"800+(18/100)*800","steps":["GST = 18% of 800 = 144","Total = 800 + 144 = 944"],"answer":"944","language":"en-US","errorMessage":"","suggestion":""}

Input: log of log of thousand
Output: {"isValid":true,"expression":"log(log(1000))","steps":["log(1000) = 3","log(3) = 0.477"],"answer":"0.477","language":"en-US","errorMessage":"","suggestion":""}

Input: paanch factorial batao
Output: {"isValid":true,"expression":"5!","steps":["5! = 5 x 4 x 3 x 2 x 1","= 120"],"answer":"120","language":"hi-IN","errorMessage":"","suggestion":""}

Input: saat sau ka pandrah pratishat kitna hoga
Output: {"isValid":true,"expression":"(15/100)*700","steps":["700 ka 15% = (15/100) x 700","= 105"],"answer":"105","language":"hi-IN","errorMessage":"","suggestion":""}

Input: convert 5 kilometres into metres
Output: {"isValid":true,"expression":"5*1000","steps":["1 km = 1000 m","5 x 1000 = 5000 m"],"answer":"5000","language":"en-US","errorMessage":"","suggestion":""}

Input: cube root of 27 plus 2 raised to the power 5
Output: {"isValid":true,"expression":"27^(1/3)+2^5","steps":["Cube root of 27 = 3","2^5 = 32","3 + 32 = 35"],"answer":"35","language":"en-US","errorMessage":"","suggestion":""}

Input: what is the weather tomorrow
Output: {"isValid":false,"expression":"","steps":[],"answer":"","language":"en-US","errorMessage":"That is not a maths question.","suggestion":"Try: what is 15 percent of 700"}
''';

  static const Map<String, dynamic> _schema = {
    "type": "object",
    "properties": {
      "isValid": {"type": "boolean"},
      "expression": {"type": "string"},
      "steps": {
        "type": "array",
        "items": {"type": "string"},
      },
      "answer": {"type": "string"},
      "language": {
        "type": "string",
        "enum": ["en-US", "hi-IN", "gu-IN"],
      },
      "errorMessage": {"type": "string"},
      "suggestion": {"type": "string"},
    },
    "required": [
      "isValid",
      "expression",
      "steps",
      "answer",
      "language",
      "errorMessage",
      "suggestion",
    ],
    "additionalProperties": false,
  };

  /// Why the last query fell back to the offline parser (null when AI was used).
  static String? lastFallbackReason;

  static Future<ParseResult> parse(String query) async {
    // 1. Already learnt? Answer from the device - free, instant, offline.
    final cached = await ParseCache.get(query);
    if (cached != null) {
      lastFallbackReason = null;
      return ParseResult(
        expression: (cached["expression"] ?? "").toString(),
        steps: List<String>.from(cached["steps"] ?? const []),
        language: (cached["language"] ?? "en-US").toString(),
        source: ParseSource.cache,
      );
    }

    // 2. No key at all -> straight to the rule based parser.
    if (!ApiConfig.hasKey) return _offline(query, "No API key");

    // 3. Ask the model.
    try {
      final raw = await ApiService.complete(
        systemPrompt: _systemPrompt,
        userMessage: query,
        schema: _schema,
      );

      final Map<String, dynamic> data = json.decode(raw);
      lastFallbackReason = null;

      final bool valid = data["isValid"] == true;
      final String expr = (data["expression"] ?? "").toString();

      if (!valid || expr.trim().isEmpty) {
        return ParseResult(
          expression: "",
          isValid: false,
          language: (data["language"] ?? "en-US").toString(),
          errorMessage:
              (data["errorMessage"] ?? "I could not understand that.").toString(),
          suggestion: (data["suggestion"] ?? "").toString(),
          source: ParseSource.ai,
        );
      }

      final steps = List<String>.from(data["steps"] ?? const []);
      final language = (data["language"] ?? "en-US").toString();

      // Learn it, so this phrasing works offline from now on.
      await ParseCache.put(query,
          expression: expr, steps: steps, language: language);

      return ParseResult(
        expression: expr,
        steps: steps,
        language: language,
        answer: (data["answer"] ?? "").toString(),
        isValid: true,
        source: ParseSource.ai,
      );
    } on ApiException catch (e) {
      // Key missing, offline, rate limited, declined -> keep the app working.
      return _offline(query, e.message);
    } catch (e) {
      return _offline(query, "Parse error");
    }
  }

  /// The original rule-based parser, kept as the offline safety net.
  static ParseResult _offline(String query, String reason) {
    lastFallbackReason = reason;
    return ParseResult(
      expression: AIParser.process(query),
      language: _detectByScript(query),
      source: ParseSource.offline,
    );
  }

  static String _detectByScript(String text) {
    if (RegExp(r'[઀-૿]').hasMatch(text)) return "gu-IN";
    if (RegExp(r'[ऀ-ॿ]').hasMatch(text)) return "hi-IN";
    return "en-US";
  }
}
