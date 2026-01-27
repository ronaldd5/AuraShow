import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env/env.dart';

class ImageService {
  static final ImageService instance = ImageService._();
  ImageService._();

  Future<List<Map<String, dynamic>>> searchPixabay(String query) async {
    final apiKey = Env.pixabayApiKey;
    if (apiKey.isEmpty) {
      return [];
    }

    try {
      final uri = Uri.parse('https://pixabay.com/api/').replace(
        queryParameters: {
          'key': apiKey,
          'q': query,
          'image_type': 'photo',
          'safesearch': 'true',
          'per_page': '30',
        },
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hits = data['hits'] as List<dynamic>;
        return hits.map<Map<String, dynamic>>((hit) {
          return {
            'id': hit['id'].toString(),
            'title': (hit['tags'] as String?) ?? 'Pixabay Image',
            'thumb': hit['webformatURL'] as String,
            'full': hit['largeImageURL'] as String,
            'source': 'pixabay',
            'author': hit['user'] as String?,
          };
        }).toList();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Pixabay Error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchUnsplash(String query) async {
    final accessKey = Env.unsplashAccessKey;
    if (accessKey.isEmpty) {
      return [];
    }

    try {
      final uri = Uri.parse('https://api.unsplash.com/search/photos').replace(
        queryParameters: {
          'query': query,
          'per_page': '30',
          'content_filter': 'high',
        },
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Client-ID $accessKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        return results.map<Map<String, dynamic>>((item) {
          final urls = item['urls'] as Map<String, dynamic>;
          final user = item['user'] as Map<String, dynamic>?;
          return {
            'id': item['id'].toString(),
            'title':
                (item['description'] as String?) ??
                (item['alt_description'] as String?) ??
                'Unsplash Image',
            'thumb':
                urls['regular']
                    as String, // Unsplash 'regular' is good for grids/previews
            'full': urls['full'] as String,
            'source': 'unsplash',
            'author': user?['name'] as String?,
          };
        }).toList();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Unsplash Error: $e');
    }
    return [];
  }
}
