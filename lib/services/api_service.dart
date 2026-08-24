import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Thrown whenever the LLM round trip could not produce a usable answer.
/// [recoverable] means "just fall back to the offline parser, don't shout".
class ApiException implements Exception {
  final String message;
  final bool recoverable;
  ApiException(this.message, {this.recoverable = true});

  @override
  String toString() => message;
}

/// Raw-HTTP client for the language model.
///
/// Supports Google Gemini (free tier) and Anthropic Claude behind one call.
/// Neither has an official Dart SDK, so both talk to the REST endpoint
/// directly. The prompt, the JSON contract and the fallback logic are
/// identical for both - only the request envelope differs.
class ApiService {
  /// Sends one prompt and returns the raw JSON text the model produced.
  ///
  /// [schema] describes the required reply shape. Both providers enforce it
  /// server side, so the caller never has to scrape markdown fences off the
  /// response.
  static Future<String> complete({
    required String systemPrompt,
    required String userMessage,
    required Map<String, dynamic> schema,
    int maxTokens = 1024,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!ApiConfig.hasKey) {
      throw ApiException("No API key set");
    }

    return ApiConfig.provider == LLMProvider.anthropic
        ? _claude(systemPrompt, userMessage, schema, maxTokens, timeout)
        : _gemini(systemPrompt, userMessage, schema, maxTokens, timeout);
  }

  // ---------------------------------------------------------------- Gemini

  static Future<String> _gemini(
    String systemPrompt,
    String userMessage,
    Map<String, dynamic> schema,
    int maxTokens,
    Duration timeout,
  ) async {
    final body = {
      "system_instruction": {
        "parts": [
          {"text": systemPrompt}
        ]
      },
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": userMessage}
          ]
        }
      ],
      "generationConfig": {
        // Deterministic: the same sentence must always give the same maths.
        "temperature": 0,
        "maxOutputTokens": maxTokens,
        "responseMimeType": "application/json",
        "responseSchema": _toGeminiSchema(schema),
      },
    };

    final res = await _post(
      ApiConfig.geminiEndpoint,
      // Key goes in a header, never in the URL query string.
      {"content-type": "application/json", "x-goog-api-key": ApiConfig.apiKey},
      body,
      timeout,
    );

    final Map<String, dynamic> data = json.decode(utf8.decode(res.bodyBytes));

    final List candidates = data["candidates"] ?? [];
    if (candidates.isEmpty) {
      // Safety block or empty generation.
      final reason = data["promptFeedback"]?["blockReason"];
      throw ApiException(reason == null ? "Empty response" : "Blocked: $reason");
    }

    final List parts = candidates[0]["content"]?["parts"] ?? [];
    for (final p in parts) {
      if (p is Map && p["text"] != null) return p["text"].toString();
    }
    throw ApiException("Empty response");
  }

  /// Gemini wants the OpenAPI flavour of JSON Schema: upper case type names
  /// and no additionalProperties.
  static dynamic _toGeminiSchema(dynamic node) {
    if (node is Map) {
      final out = <String, dynamic>{};
      node.forEach((k, v) {
        if (k == "additionalProperties") return; // unsupported
        if (k == "type" && v is String) {
          out["type"] = v.toUpperCase();
        } else {
          out[k.toString()] = _toGeminiSchema(v);
        }
      });
      return out;
    }
    if (node is List) return node.map(_toGeminiSchema).toList();
    return node;
  }

  // ---------------------------------------------------------------- Claude

  static Future<String> _claude(
    String systemPrompt,
    String userMessage,
    Map<String, dynamic> schema,
    int maxTokens,
    Duration timeout,
  ) async {
    final body = {
      "model": ApiConfig.anthropicModel,
      "max_tokens": maxTokens,
      // Opus 5 thinks by default; "low" effort keeps a calculator snappy.
      // NOTE: temperature / top_p are removed on Opus 5 - sending them is a 400.
      "output_config": {
        "effort": "low",
        "format": {"type": "json_schema", "schema": schema},
      },
      "system": systemPrompt,
      "messages": [
        {"role": "user", "content": userMessage},
      ],
    };

    final res = await _post(
      ApiConfig.anthropicEndpoint,
      {
        "content-type": "application/json",
        "x-api-key": ApiConfig.apiKey,
        "anthropic-version": ApiConfig.anthropicVersion,
      },
      body,
      timeout,
    );

    final Map<String, dynamic> data = json.decode(utf8.decode(res.bodyBytes));

    // A safety decline arrives as HTTP 200 with stop_reason "refusal".
    if (data["stop_reason"] == "refusal") {
      throw ApiException("Request declined");
    }

    final List blocks = data["content"] ?? [];
    for (final b in blocks) {
      if (b is Map && b["type"] == "text") return (b["text"] ?? "").toString();
    }
    throw ApiException("Empty response");
  }

  // ----------------------------------------------------------------- Shared

  static Future<http.Response> _post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body,
    Duration timeout,
  ) async {
    late http.Response res;
    try {
      res = await http
          .post(Uri.parse(url), headers: headers, body: json.encode(body))
          .timeout(timeout);
    } on SocketException {
      throw ApiException("Offline");
    } catch (e) {
      throw ApiException("Network error: $e");
    }

    if (res.statusCode == 400) {
      // Gemini reports a bad key as 400 with API_KEY_INVALID in the body.
      final bad = res.body.contains("API_KEY_INVALID") ||
          res.body.contains("API key not valid");
      throw ApiException(bad ? "Invalid API key" : "Bad request",
          recoverable: !bad);
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw ApiException("Invalid API key", recoverable: false);
    }
    if (res.statusCode == 429) {
      throw ApiException("Rate limited, try again in a moment");
    }
    if (res.statusCode >= 400) {
      throw ApiException("API error ${res.statusCode}");
    }
    return res;
  }
}
