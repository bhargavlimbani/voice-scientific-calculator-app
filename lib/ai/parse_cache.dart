import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers every sentence the LLM has already understood.
///
/// This is what makes the app genuinely offline-capable rather than merely
/// offline-tolerant: once a phrasing has been learnt it is answered from the
/// device forever, with no network and no API cost. A repeat query is also
/// instant, which matters more than it sounds during a live demo.
class ParseCache {
  static const String _prefsKey = 'parse_cache_v1';
  static const int _maxEntries = 200;

  /// query -> {expression, steps, language}
  static Map<String, dynamic> _entries = {};
  static bool _loaded = false;

  /// Whitespace and case should not create two cache entries.
  static String _key(String query) =>
      query.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        _entries = Map<String, dynamic>.from(json.decode(raw));
      } catch (_) {
        _entries = {};
      }
    }
    _loaded = true;
  }

  static Future<Map<String, dynamic>?> get(String query) async {
    await load();
    final hit = _entries[_key(query)];
    return hit == null ? null : Map<String, dynamic>.from(hit);
  }

  static Future<void> put(
    String query, {
    required String expression,
    required List<String> steps,
    required String language,
  }) async {
    await load();
    final k = _key(query);

    // Re-inserting moves the entry to the newest position.
    _entries.remove(k);
    _entries[k] = {
      "expression": expression,
      "steps": steps,
      "language": language,
    };

    // Dart maps keep insertion order, so the first key is the oldest.
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(_entries));
  }

  static Future<int> size() async {
    await load();
    return _entries.length;
  }

  static Future<void> clear() async {
    _entries = {};
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
