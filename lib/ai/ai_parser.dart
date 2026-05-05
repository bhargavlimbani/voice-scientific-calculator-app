class AIParser {
  static String process(String input) {
    String text = input.toLowerCase().trim();

    // 🔥 DEBUG (optional)
    print("RAW AI INPUT: $text");


    if (RegExp(r'^[0-9 ]+$').hasMatch(text)) {
      text = text.replaceAll(" ", "");

      // Example: 8523 → take last 2 digits → 2+3
      if (text.length >= 2) {
        String a = text[text.length - 2];
        String b = text[text.length - 1];
        return "$a+$b";
      }
    }


    List<String> removeWords = [
      "what is",
      "calculate",
      "please",
      "answer",
      "find",
      "the value of",
    ];

    for (var word in removeWords) {
      text = text.replaceAll(word, "");
    }


    if (text.contains("add") && text.contains("to")) {
      List<String> numbers =
          RegExp(r'\d+').allMatches(text).map((m) => m.group(0)!).toList();

      if (numbers.length >= 2) {
        return "${numbers[1]}+${numbers[0]}";
      }
    }

    // subtract 2 from 10 → 10-2
    text = text.replaceAllMapped(
      RegExp(r'subtract (\d+) from (\d+)'),
      (m) => "${m[2]}-${m[1]}",
    );

    // multiply 4 and 5 → 4*5
    text = text.replaceAllMapped(
      RegExp(r'multiply (\d+) and (\d+)'),
      (m) => "${m[1]}*${m[2]}",
    );

    // divide 10 by 2 → 10/2
    text = text.replaceAllMapped(
      RegExp(r'divide (\d+) by (\d+)'),
      (m) => "${m[1]}/${m[2]}",
    );


    text = text.replaceAll("plus", "+");
    text = text.replaceAll("minus", "-");
    text = text.replaceAll("times", "*");
    text = text.replaceAll("multiplied by", "*");
    text = text.replaceAll("x", "*");

    text = text.replaceAll("divided by", "/");
    text = text.replaceAll("divide", "/");


    text = text.replaceAll("too", "2");
    text = text.replaceAll("for", "4");

 
    text = text.replaceAll(" ", "");


    if (!RegExp(r'^[0-9+\-*/().]+$').hasMatch(text)) {
      print("AI FAILED → returning original cleaned input");
    }

    print("AI FINAL OUTPUT: $text");

    return text;
  }
}
