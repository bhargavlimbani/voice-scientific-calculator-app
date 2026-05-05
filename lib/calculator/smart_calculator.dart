import 'dart:math';

class SmartCalculator {
  static double evaluate(String input) {
    String expr = input.toLowerCase();

    expr = expr.replaceAll("plus", "+");
    expr = expr.replaceAll("minus", "-");
    expr = expr.replaceAll("times", "*");
    expr = expr.replaceAll("multiplied by", "*");
    expr = expr.replaceAll("divided by", "/");
    expr = expr.replaceAll("divided", "/");

    expr = expr.replaceAll("pi", pi.toString());
    expr = expr.replaceAll("e", e.toString());

    expr = expr.replaceAll("square root", "sqrt");
    expr = expr.replaceAll("power", "^");

    try {
      return _process(expr);
    } catch (e) {
      throw Exception("Invalid Expression");
    }
  }

  static double _process(String expr) {
    expr = expr.replaceAll(" ", "");
    

    // sin cos tan (degree)
    expr = expr.replaceAllMapped(
        RegExp(r'sin(\d+)'), (m) => sin(_deg(double.parse(m[1]!))).toString());

    expr = expr.replaceAllMapped(
        RegExp(r'cos(\d+)'), (m) => cos(_deg(double.parse(m[1]!))).toString());

    expr = expr.replaceAllMapped(
        RegExp(r'tan(\d+)'), (m) => tan(_deg(double.parse(m[1]!))).toString());

    // log
    expr = expr.replaceAllMapped(RegExp(r'log(\d+)'),
        (m) => (log(double.parse(m[1]!)) / ln10).toString());

    // ln
    expr = expr.replaceAllMapped(
        RegExp(r'ln(\d+)'), (m) => log(double.parse(m[1]!)).toString());

    // sqrt
    expr = expr.replaceAllMapped(
        RegExp(r'sqrt(\d+)'), (m) => sqrt(double.parse(m[1]!)).toString());

    // factorial
    expr = expr.replaceAllMapped(
        RegExp(r'(\d+)!'), (m) => _factorial(int.parse(m[1]!)).toString());

    // power
    expr = expr.replaceAllMapped(RegExp(r'(\d+)\^(\d+)'),
        (m) => pow(double.parse(m[1]!), double.parse(m[2]!)).toString());

    // percentage
    expr = expr.replaceAllMapped(RegExp(r'(\d+)%'), (m) => "(${m[1]}/100)");

    // Add before evaluation

    expr = expr.replaceAll("square of", "");
    expr = expr.replaceAll("cube of", "");

    expr = expr.replaceAllMapped(
        RegExp(r'square(\d+)'), (m) => pow(double.parse(m[1]!), 2).toString());

    expr = expr.replaceAllMapped(
        RegExp(r'cube(\d+)'), (m) => pow(double.parse(m[1]!), 3).toString());

// percentage smart
    expr = expr.replaceAllMapped(RegExp(r'(\d+)\+(\d+)%'), (m) {
      double a = double.parse(m[1]!);
      double b = double.parse(m[2]!);
      return (a + (a * b / 100)).toString();
    });

    return _calculate(expr);
  }

  static double _calculate(String expr) {
    List<String> tokens = _tokenize(expr);
    return _solve(tokens);
  }

  static List<String> _tokenize(String expr) {
    List<String> tokens = [];
    String num = "";

    for (int i = 0; i < expr.length; i++) {
      String ch = expr[i];

      if ("0123456789.".contains(ch)) {
        num += ch;
      } else {
        if (num.isNotEmpty) {
          tokens.add(num);
          num = "";
        }
        tokens.add(ch);
      }
    }

    if (num.isNotEmpty) tokens.add(num);
    return tokens;
  }

  static double _solve(List<String> tokens) {
    // *, /
    for (int i = 0; i < tokens.length; i++) {
      if (tokens[i] == "*" || tokens[i] == "/") {
        double a = double.parse(tokens[i - 1]);
        double b = double.parse(tokens[i + 1]);

        double res = tokens[i] == "*" ? a * b : a / b;

        tokens.removeRange(i - 1, i + 2);
        tokens.insert(i - 1, res.toString());
        i--;
      }
    }

    // +, -
    double result = double.parse(tokens[0]);

    for (int i = 1; i < tokens.length; i += 2) {
      double val = double.parse(tokens[i + 1]);

      if (tokens[i] == "+") {
        result += val;
      } else {
        result -= val;
      }
    }

    return result;
  }

  static double _deg(double val) => val * pi / 180;

  static int _factorial(int n) {
    if (n <= 1) return 1;
    return n * _factorial(n - 1);
  }
}
