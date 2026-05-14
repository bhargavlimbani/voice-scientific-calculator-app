class AIParser {
  static String process(String input) {
    String text = input.toLowerCase().trim();

    // 1. ADVANCED CONVERSATIONAL REMOVAL
    List<String> removeWords = [
      "what is", "calculate", "please", "answer", "find", 
      "the value of", "give me", "show me", "of", "result of",
      "could you", "tell me", "solve", "evaluate"
    ];
    for (var word in removeWords) {
      text = text.replaceAll(word, " "); 
    }

    // 2. CONVERSATIONAL MATH PATTERNS (The "AI" Logic)
    
    // "sum of X and Y" -> X+Y
    if (text.contains("sum") && text.contains("and")) {
      text = text.replaceAll("sum", "").replaceAll("and", "+");
    }
    // "difference between X and Y" -> X-Y
    if (text.contains("difference") && text.contains("between") && text.contains("and")) {
      text = text.replaceAll("difference", "").replaceAll("between", "").replaceAll("and", "-");
    }
    // "product of X and Y" -> X*Y
    if (text.contains("product") && text.contains("and")) {
      text = text.replaceAll("product", "").replaceAll("and", "*");
    }
    // "X percent of Y" -> (X/100)*Y
    text = text.replaceAllMapped(RegExp(r'(\d+)\s*percent\s*(\d+)'), (m) => "(${m[1]}/100)*${m[2]}");
    
    // "half of X" -> X/2
    text = text.replaceAllMapped(RegExp(r'half\s*(\d+)'), (m) => "${m[1]}/2");
    // "twice of X" or "double X" -> 2*X
    text = text.replaceAllMapped(RegExp(r'(twice|double)\s*(\d+)'), (m) => "2*${m[2]}");
    // "triple X" -> 3*X
    text = text.replaceAllMapped(RegExp(r'triple\s*(\d+)'), (m) => "3*${m[2]}");

    // 3. CORE SCIENTIFIC MAPPING
    
    // Factorial
    text = text.replaceAllMapped(RegExp(r'(\d+)\s*factorial'), (m) => "${m[1]}!");
    // Squared/Cubed
    text = text.replaceAllMapped(RegExp(r'square\s*(\d+)'), (m) => "${m[1]}^2");
    text = text.replaceAllMapped(RegExp(r'(\d+)\s*squared'), (m) => "${m[1]}^2");
    text = text.replaceAllMapped(RegExp(r'cube\s*(\d+)'), (m) => "${m[1]}^3");
    text = text.replaceAllMapped(RegExp(r'(\d+)\s*cubed'), (m) => "${m[1]}^3");

    // 4. PHONETIC & KEYWORD MAPPING
    Map<String, String> mappings = {
      "plus": "+", "and": "+", "add": "+",
      "minus": "-", "less": "-", "subtract": "-", "difference": "-",
      "times": "*", "multiplied by": "*", "multiply": "*", "into": "*",
      "divided by": "/", "divide": "/", "over": "/", "by": "/",
      
      "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
      "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10",
      
      "sine": "sin", "sign": "sin", 
      "cosine": "cos", "cos": "cos", "course": "cos", "cause": "cos", "coz": "cos",
      "tangent": "tan", "tan": "tan",
      
      "square root": "sqrt", "root": "sqrt", "cube root": "cbrt",
      "logarithm": "log", "log": "log", "natural log": "ln",
      "power": "^", "raised to": "^", "to the": "^",
      "open bracket": "(", "close bracket": ")", "bracket": "(",
      "too": "2", "for": "4", "absolute": "abs", "reciprocal": "1/"
    };

    mappings.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    // 5. FINAL CLEANUP
    if (RegExp(r'^[0-9 ]+$').hasMatch(text)) {
      text = text.replaceAll(" ", "");
    }
    text = text.replaceAll(" ", "");

    print("AI FINAL OUTPUT: $text");
    return text;
  }
}
