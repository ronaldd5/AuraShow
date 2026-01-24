import 'dart:convert';
import 'package:http/http.dart' as http;

class ScriptureFetcher {
  static final ScriptureFetcher instance = ScriptureFetcher._();
  ScriptureFetcher._();

  // Cache chapters to avoid repeated network calls for adjacent verses
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  String _cacheKey(String api, String version, String book, int chapter) {
    return '$api:$version:$book:$chapter';
  }

  Future<List<Map<String, dynamic>>> fetchChapter({
    required String api,
    required String version,
    required String bookName, // e.g. "Genesis"
    required int chapter,
    required int bookIndex, // 1-66
  }) async {
    final key = _cacheKey(api, version, bookName, chapter);
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final verses = <Map<String, dynamic>>[];

    try {
      if (api == 'bolls') {
        // Bolls.life API: https://bolls.life/get-text/TRANSLATION/BOOK_ID/CHAPTER/
        final url = Uri.parse(
          'https://bolls.life/get-text/$version/$bookIndex/$chapter/',
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          for (final verse in data) {
            verses.add({
              'verse': verse['verse'] as int,
              'text': _cleanVerseText(verse['text']?.toString() ?? ''),
            });
          }
        }
      } else if (api == 'bible-api') {
        // bible-api.com: https://bible-api.com/BOOK+CHAPTER?translation=t
        final url = Uri.parse(
          'https://bible-api.com/$bookName+$chapter?translation=$version',
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['verses'] != null) {
            for (final verse in data['verses']) {
              verses.add({
                'verse': verse['verse'] as int,
                'text': _cleanVerseText(verse['text']?.toString() ?? ''),
              });
            }
          }
        }
      }

      if (verses.isNotEmpty) {
        _cache[key] = verses;
      }

      return verses;
    } catch (e) {
      print('Scripture fetch error: $e');
      return [];
    }
  }

  String _cleanVerseText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'\s+'), ' ') // Standardize whitespace
        .trim();
  }
}
