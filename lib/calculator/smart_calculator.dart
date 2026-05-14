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

    // Nesting Logic for Log and Trig
    while (text.contains("log(")) {
      String newText = text.replaceAllMapped(RegExp(r'log\(([^()]+)\)'), (m) => "(ln(${m[1]})/ln(10.0))");
      if (newText == text) break;
      text = newText;
    }
    while (text.contains("sin(")) {
      String newText = text.replaceAllMapped(RegExp(r'sin\(([^()]+)\)'), (m) => "sin((${math.pi}/180.0)*(${m[1]}))");
      if (newText == text) break;
      text = newText;
    }
    while (text.contains("cos(")) {
      String newText = text.replaceAllMapped(RegExp(r'cos\(([^()]+)\)'), (m) => "cos((${math.pi}/180.0)*(${m[1]}))");
      if (newText == text) break;
      text = newText;
    }
    while (text.contains("tan(")) {
      String newText = text.replaceAllMapped(RegExp(r'tan\(([^()]+)\)'), (m) => "tan((${math.pi}/180.0)*(${m[1]}))");
      if (newText == text) break;
      text = newText;
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
