import 'package:flutter_test/flutter_test.dart';
import 'package:calculator_app/calculator/smart_calculator.dart';

/// Guards the contract between the LLM prompt and the local evaluator.
/// Every expression here is a shape the system prompt promises to emit,
/// so if SmartCalculator ever stops accepting one of them the prompt
/// (or the parser) has drifted.
void main() {
  final cases = <String, double>{
    "sin(90)+sqrt(16)": 5,
    "25+32*2": 89,
    "100/4": 25,
    "800+(18/100)*800": 944,
    "(15/100)*700": 105,
    "12*8": 96,
    "5*1000": 5000,
    "5!": 120,
    "2^5": 32,
    "27^(1/3)": 3,
    "log(1000)": 3,
    "cos(0)": 1,
    "tan(45)": 1,
    "abs(0-7)": 7,
  };

  group('LLM expression shapes evaluate locally', () {
    cases.forEach((expr, expected) {
      test(expr, () {
        expect(SmartCalculator.evaluate(expr), closeTo(expected, 1e-6));
      });
    });
  });

  group('nested calls (regression: bracket matching)', () {
    test('log(log(1000))', () {
      expect(SmartCalculator.evaluate("log(log(1000))"), closeTo(0.47712125, 1e-6));
    });
    test('sin(sin(90)*90)', () {
      expect(SmartCalculator.evaluate("sin(sin(90)*90)"), closeTo(1, 1e-6));
    });
    test('sqrt(sin(90)+15)', () {
      expect(SmartCalculator.evaluate("sqrt(sin(90)+15)"), closeTo(4, 1e-6));
    });
    test('log(sqrt(1000000))', () {
      expect(SmartCalculator.evaluate("log(sqrt(1000000))"), closeTo(3, 1e-6));
    });
  });

  test('invalid expression throws', () {
    expect(() => SmartCalculator.evaluate("what is the weather"), throwsException);
  });
}
