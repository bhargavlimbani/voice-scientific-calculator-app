import 'dart:math' as math;
import 'package:math_expressions/math_expressions.dart';

class SmartCalculator {
  static double evaluate(String input) {
    try {
      String expr = _prepareExpression(input);
      print("Final Expr for Parser: $expr");

      Parser p = Parser();
      Expression exp = p.parse(expr);
      ContextModel cm = ContextModel();

      double result = exp.evaluate(EvaluationType.REAL, cm);

      if (result.isNaN || result.isInfinite) {
        throw Exception("Calculation Error");
      }

      if (result.abs() < 1e-12) result = 0;

      return result;
    } catch (e) {
      print("Eval Error: $e");
      throw Exception("Invalid Expression");
    }
  }

  static String _prepareExpression(String input) {
    String text = input.toLowerCase().replaceAll(" ", "");
    
    // Basic Mappings
    text = text.replaceAll("×", "*");
    text = text.replaceAll("÷", "/");
    text = text.replaceAll("π", math.pi.toString());
    text = text.replaceAll("e", math.e.toString());
    text = text.replaceAll("√", "sqrt");

    // Handle Factorials
    text = text.replaceAllMapped(RegExp(r'(\d+)!'), (m) {
      int n = int.parse(m[1]!);
      return n > 20 ? "1.0e10" : _calculateFactorial(n).toString();
    });

    // --- ENHANCED PERCENTAGE LOGIC ---
    // Handle 'X % Y' as 'X percent of Y' -> (X/100)*Y
    text = text.replaceAllMapped(RegExp(r'(\d+\.?\d*)%(\d+\.?\d*)'), (m) => "((${m[1]}/100)*${m[2]})");
    
    // Handle 'X %' as 'X / 100'
    text = text.replaceAllMapped(RegExp(r'(\d+\.?\d*)%'), (m) => "(${m[1]}/100)");
    
    // Safety: If % is left alone by mistake, remove it to prevent crash
    text = text.replaceAll("%", "");

    // Handle missing brackets for scientific functions
    List<String> funcs = ['sin', 'cos', 'tan', 'log', 'ln', 'sqrt'];
    for (var f in funcs) {
      text = text.replaceAllMapped(RegExp('$f(\\d+\\.?\\d*)'), (m) => "$f(${m[1]})");
    }

    // Nesting Logic for Log and Trig.
    // Bracket matched, so nested calls like log(log(1000)) work. The old
    // [^()]+ regex silently gave up as soon as an argument held brackets.
    const double deg = math.pi / 180.0;
    text = _expandFunc(text, "log", (a) => "(ln($a)/ln(10.0))");
    text = _expandFunc(text, "sin", (a) => "@SIN@(($deg)*($a))");
    text = _expandFunc(text, "cos", (a) => "@COS@(($deg)*($a))");
    text = _expandFunc(text, "tan", (a) => "@TAN@(($deg)*($a))");

    // Placeholders keep the expansion from re-matching its own output.
    text = text.replaceAll("@SIN@", "sin");
    text = text.replaceAll("@COS@", "cos");
    text = text.replaceAll("@TAN@", "tan");

    return text;
  }

  /// Rewrites every `name(...)` call, matching brackets properly so that
  /// nested arguments survive. Outermost call is rewritten first; the loop
  /// then picks up whatever was nested inside it.
  static String _expandFunc(
      String text, String name, String Function(String arg) build) {
    final String open = "$name(";
    for (int guard = 0; guard < 50; guard++) {
      final int start = text.indexOf(open);
      if (start == -1) break;

      final int argStart = start + open.length;
      int depth = 1;
      int close = -1;
      for (int i = argStart; i < text.length; i++) {
        if (text[i] == "(") depth++;
        if (text[i] == ")") {
          depth--;
          if (depth == 0) {
            close = i;
            break;
          }
        }
      }
      if (close == -1) break; // unbalanced brackets, leave it for the parser

      final String arg = text.substring(argStart, close);
      text = text.substring(0, start) + build(arg) + text.substring(close + 1);
    }
    return text;
  }

  static double _calculateFactorial(int n) {
    if (n < 0) return 0;
    double res = 1;
    for (int i = 2; i <= n; i++) res *= i;
    return res;
  }
}
