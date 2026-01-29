import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import '../env/env.dart';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/song_model.dart';
import 'package:uuid/uuid.dart';
import '../models/slide_model.dart';

/// Result from Genius API search
class GeniusSongResult {
  final int id;
  final String title;
  final String artist;
  final String url;
  final String imageUrl;

  GeniusSongResult({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    required this.imageUrl,
  });
}

class LyricsService {
  LyricsService._();
  static final LyricsService instance = LyricsService._();

  // Genius API token loaded from .env
  static String get _geniusToken => Env.geniusApiKey;

  final _songsController = StreamController<List<Song>>.broadcast();
  Stream<List<Song>> get songsStream => _songsController.stream;

  List<Song> _songs = [];
  List<Song> get songs => List.unmodifiable(_songs);

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadSongs();
    _isInitialized = true;
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final songsDir = Directory(path.join(directory.path, 'AuraShow', 'Songs'));
    if (!await songsDir.exists()) {
      await songsDir.create(recursive: true);
    }
    return songsDir.path;
  }

  Future<void> _loadSongs() async {
    try {
      final songsPath = await _localPath;
      final dir = Directory(songsPath);
      final List<Song> loadedSongs = [];

      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final jsonStr = await entity.readAsString();
            final song = Song.fromJson(jsonStr);
            loadedSongs.add(song);
          } catch (e) {
            debugPrint('Error loading song ${entity.path}: $e');
          }
        }
      }

      loadedSongs.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

      _songs = loadedSongs;
      _notifyListeners();
    } catch (e) {
      debugPrint('Error initializing song library: $e');
    }
  }

  Future<void> saveSong(Song song) async {
    try {
      final songsPath = await _localPath;
      final file = File(path.join(songsPath, '${song.id}.json'));
      await file.writeAsString(song.toJson());

      final index = _songs.indexWhere((s) => s.id == song.id);
      if (index >= 0) {
        _songs[index] = song;
      } else {
        _songs.add(song);
      }

      _songs.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

      _notifyListeners();
    } catch (e) {
      debugPrint('Error saving song: $e');
      rethrow;
    }
  }

  Future<void> deleteSong(String id) async {
    try {
      final songsPath = await _localPath;
      final file = File(path.join(songsPath, '$id.json'));
      if (await file.exists()) {
        await file.delete();
      }

      _songs.removeWhere((s) => s.id == id);
      _notifyListeners();
    } catch (e) {
      debugPrint('Error deleting song: $e');
      rethrow;
    }
  }

  /// Search local song library
  List<Song> search(String query) {
    if (query.isEmpty) return _songs;
    final lowerQuery = query.toLowerCase();
    return _songs
        .where(
          (s) =>
              s.title.toLowerCase().contains(lowerQuery) ||
              s.content.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  // ============================================================

  /// The "Magic" one-click search method.
  /// Tries lrclib.net first (no Cloudflare), then Genius as fallback.
  /// Includes YouTube URL support, auto-labeling, and section expansion.
  Future<String> smartSearch(String query) async {
    try {
      String searchTerm = query.trim();
      if (searchTerm.isEmpty) return "No lyrics found.";

      // A. Check for YouTube Link - extract title and search
      if (searchTerm.contains('youtube.com') ||
          searchTerm.contains('youtu.be')) {
        debugPrint('Detected YouTube URL');
        return await _handleYouTubeLink(searchTerm);
      }

      // B. URL Detection: Did the user paste a Genius/other link?
      if (searchTerm.startsWith('http')) {
        final scraped = await _scrapeGeniusPage(searchTerm);
        return _processLyrics(scraped);
      }

      // C. Sanitize Query
      String cleanQuery = _sanitizeQuery(searchTerm);
      debugPrint('Smart Search: "$searchTerm" -> "$cleanQuery"');

      // D. Try LRCLIB first (free, no Cloudflare, fast)
      final lrclibResult = await _searchLrclib(cleanQuery);
      if (lrclibResult != null && lrclibResult.isNotEmpty) {
        debugPrint('LRCLIB found lyrics!');
        return _processLyrics(lrclibResult);
      }

      // E. Try with original query
      final lrclibFallback = await _searchLrclib(searchTerm);
      if (lrclibFallback != null && lrclibFallback.isNotEmpty) {
        return _processLyrics(lrclibFallback);
      }

      // F. Try Genius API as fallback
      final results = await _searchGeniusAPI(cleanQuery);
      if (results.isNotEmpty) {
        final lyrics = await _fetchAndCleanLyrics(results, cleanQuery);
        return _processLyrics(lyrics);
      }

      // G. Final fallback - try Genius with original query
      final fallbackResults = await _searchGeniusAPI(searchTerm);
      if (fallbackResults.isNotEmpty) {
        final lyrics = await _fetchAndCleanLyrics(fallbackResults, searchTerm);
        return _processLyrics(lyrics);
      }

      return "No lyrics found.";
    } catch (e) {
      debugPrint('Smart search error: $e');
      return "Error: $e";
    }
  }

  /// Search and return a list of potential song matches (for user selection)
  /// Combines results from LRCLIB and Genius, sorted by sync availability
  Future<List<Song>> searchSongs(
    String query, {
    int limit = 20,
    String? sourceFilter,
  }) async {
    try {
      String cleanQuery = _sanitizeQuery(query);
      debugPrint(
        'Search songs: "$query" -> "$cleanQuery" (limit: $limit, filter: $sourceFilter)',
      );

      final List<Song> allResults = [];

      // 1. Search LRCLIB (unless filtering to Genius only)
      if (sourceFilter == null || sourceFilter == 'lrclib') {
        final lrclibResults = await _searchLrclibForSongs(cleanQuery);
        allResults.addAll(lrclibResults);
      }

      // 2. Search Genius (unless filtering to LRCLIB only)
      if (sourceFilter == null || sourceFilter == 'genius') {
        final geniusResults = await _searchGeniusAPI(cleanQuery);
        final geniusSongs = geniusResults
            .map(
              (r) => Song(
                id: 'genius_${r.id}',
                title: r.title,
                author: r.artist,
                copyright: r.url, // Store URL for fetching
                content: '',
                hasSyncedLyrics: false, // Genius doesn't have sync data
                source: 'genius',
              ),
            )
            .toList();
        allResults.addAll(geniusSongs);
      }

      // 3. Sort: synced first, then by source (LRCLIB first), then by title
      allResults.sort((a, b) {
        // Synced lyrics first
        if (a.hasSyncedLyrics && !b.hasSyncedLyrics) return -1;
        if (!a.hasSyncedLyrics && b.hasSyncedLyrics) return 1;

        // LRCLIB source next
        if (a.source == 'lrclib' && b.source != 'lrclib') return -1;
        if (a.source != 'lrclib' && b.source == 'lrclib') return 1;

        // Then alphabetically
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      // 4. Limit results
      if (allResults.length > limit) {
        return allResults.sublist(0, limit);
      }

      return allResults;
    } catch (e) {
      debugPrint('Search songs error: $e');
      return [];
    }
  }

  /// Updates song metadata (title, author) if found in the content headers
  Song updateMetaFromContent(Song song) {
    if (song.content.isEmpty) return song;

    String title = song.title;
    String author = song.author;
    String copyright = song.copyright;
    String ccli = song.ccli;

    final lines = song.content.split('\n');
    final cleanedLines = <String>[];

    // Helper for finding separator index
    int tmRemoved(String s) {
      final idx = s.indexOf(RegExp(r'[:=]'));
      return idx == -1 ? 0 : idx + 1;
    }

    for (var line in lines) {
      final trimmedLine = line.trim();
      final lowerLine = trimmedLine.toLowerCase();

      if (lowerLine.startsWith('title:') || lowerLine.startsWith('title=')) {
        title = trimmedLine.substring(tmRemoved(trimmedLine)).trim();
      } else if (lowerLine.startsWith('author:') ||
          lowerLine.startsWith('author=')) {
        author = trimmedLine.substring(tmRemoved(trimmedLine)).trim();
      } else if (lowerLine.startsWith('copyright:') ||
          lowerLine.startsWith('copyright=')) {
        copyright = trimmedLine.substring(tmRemoved(trimmedLine)).trim();
      } else if (lowerLine.startsWith('ccli:') ||
          lowerLine.startsWith('ccli=')) {
        ccli = trimmedLine.substring(tmRemoved(trimmedLine)).trim();
      } else {
        cleanedLines.add(line);
      }
    }

    return song.copyWith(
      title: title,
      author: author,
      copyright: copyright,
      ccli: ccli,
      content: cleanedLines.join('\n').trim(),
    );
  }

  /// Apply all post-processing: auto-label, expand sections, theological casing
  String _processLyrics(String lyrics) {
    if (lyrics.startsWith("Error") ||
        lyrics.startsWith("No lyrics") ||
        lyrics.startsWith("Could not")) {
      return lyrics;
    }

    // Wrap in try-catch to be safe
    try {
      return cleanLyrics(lyrics);
    } catch (e) {
      debugPrint('Lyrics processing error: $e');
      return lyrics;
    }
  }

  /// Handle YouTube URL - extract video title and search for lyrics
  Future<String> _handleYouTubeLink(String url) async {
    try {
      // Use noembed.com to get video title without API key
      final apiUrl = Uri.parse(
        'https://noembed.com/embed?url=${Uri.encodeComponent(url)}',
      );
      debugPrint('Fetching YouTube title from: $apiUrl');

      final response = await http
          .get(apiUrl)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final title = data['title'] as String?;

        if (title != null && title.isNotEmpty) {
          debugPrint('YouTube video title: $title');

          // Clean the title and search
          final cleanTitle = _sanitizeQuery(title);
          debugPrint('Cleaned title: $cleanTitle');

          // Recursive search with the extracted title
          return await smartSearch(cleanTitle);
        }
      }

      return "Could not extract song title from YouTube URL.";
    } catch (e) {
      debugPrint('YouTube URL handling error: $e');
      return "Error processing YouTube URL: $e";
    }
  }

  /// "The Detective" - Auto-label raw text by detecting repeated blocks as chorus
  String _autoLabelRawText(String rawText) {
    if (rawText.isEmpty) {
      return rawText;
    }

    // Skip if already has labels.
    final headerPattern = RegExp(
      r'\[(Verse|Chorus|Bridge|Intro|Outro|Pre-Chorus|Hook|Vamp|Tag|Refrain)',
      caseSensitive: false,
    );
    if (headerPattern.hasMatch(rawText)) {
      return rawText;
    }

    // Normalize: If there are NO double newlines, but many single ones,
    // let's assume they are blocks of 4 lines for heuristic purposes
    String normalized = rawText.trim();
    if (!normalized.contains('\n\n')) {
      final lines = normalized.split('\n');
      if (lines.length > 5) {
        final buffer = StringBuffer();
        for (int i = 0; i < lines.length; i++) {
          buffer.write(lines[i]);
          // Heuristic: break every 4 lines if no other breaks found
          if ((i + 1) % 4 == 0 && i != lines.length - 1) {
            buffer.write('\n\n');
          } else {
            buffer.write('\n');
          }
        }
        normalized = buffer.toString().trim();
      }
    }

    // Split into blocks by double newlines
    final blocks = normalized.split(RegExp(r'\n\n+'));
    if (blocks.length < 2) {
      return rawText;
    }

    // Count frequency using "Fuzzy Keys" (ignore ad-libs/punctuation)
    final Map<String, int> frequency = {};
    final Map<String, String> fuzzyToOriginal =
        {}; // Map fuzzy key to one exemplar

    for (var block in blocks) {
      final fuzzyKey = _getFuzzyKey(block);
      if (fuzzyKey.isEmpty) continue;

      frequency[fuzzyKey] = (frequency[fuzzyKey] ?? 0) + 1;
      fuzzyToOriginal[fuzzyKey] = block.trim();
    }

    // Find the chorus (most frequent fuzzy block appearing > 1 time)
    String? chorusFuzzyKey;
    int maxCount = 1;
    frequency.forEach((fuzzyKey, count) {
      if (count > maxCount) {
        maxCount = count;
        chorusFuzzyKey = fuzzyKey;
      }
    });

    // Rebuild with tags
    final List<String> labeledBlocks = [];
    int verseCount = 1;
    int chorusCount = 0;

    for (var block in blocks) {
      final fuzzyKey = _getFuzzyKey(block);
      if (fuzzyKey.isEmpty) continue;

      if (chorusFuzzyKey != null && fuzzyKey == chorusFuzzyKey) {
        chorusCount++;
        if (chorusCount == 1) {
          labeledBlocks.add('[CHORUS]\n${block.trim()}');
        } else {
          labeledBlocks.add('[CHORUS]'); // Will be expanded by _expandStructure
        }
      } else {
        labeledBlocks.add('[VERSE $verseCount]\n${block.trim()}');
        verseCount++;
      }
    }

    return labeledBlocks.join('\n\n');
  }

  /// Generates a "fuzzy" version of a block for comparison.
  /// Strips ad-libs (parentheses), punctuationholders, and whitespace.
  String _getFuzzyKey(String text) {
    // 1. Remove everything in parentheses (ad-libs)
    String fuzzy = text.replaceAll(RegExp(r'\(.*?\)', dotAll: true), '');
    // 2. Remove punctuation
    fuzzy = fuzzy.replaceAll(RegExp(r'[.,!?/\\-]'), '');
    // 3. Lowercase and normalize whitespace
    return fuzzy.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// "The Cloner" - Expand empty section headers with previously defined text
  String _expandStructure(String lyrics) {
    if (lyrics.isEmpty) return lyrics;
    final lines = lyrics.split('\n');
    final Map<String, String> definedSections = {}; // "CHORUS" -> actual text
    final List<String> finalOutput = [];

    String currentLabel = '';
    StringBuffer currentBuffer = StringBuffer();

    void commitSection() {
      if (currentLabel.isEmpty) return;

      String body = currentBuffer.toString().trim();
      // Normalize label key (remove numbers for matching)
      String key = currentLabel.toUpperCase().replaceAll(
        RegExp(r'\s+\d+$'),
        '',
      );

      if (body.isNotEmpty) {
        // Save this as the master text for this section type
        if (!definedSections.containsKey(key)) {
          definedSections[key] = body;
        }
        finalOutput.add('[$currentLabel]\n$body');
      } else {
        // Empty section! Try to fill from previously defined
        if (definedSections.containsKey(key)) {
          finalOutput.add('[$currentLabel]\n${definedSections[key]}');
          debugPrint('Cloner: Expanded empty [$currentLabel] with saved text');
        } else {
          // Keep empty header
          finalOutput.add('[$currentLabel]');
        }
      }

      currentBuffer.clear();
      currentLabel = '';
    }

    for (String line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('[') &&
          trimmed.endsWith(']') &&
          !trimmed.contains(':')) {
        if (trimmed == '[_VB]') {
          if (currentLabel.isNotEmpty) {
            currentBuffer.writeln('[_VB]');
          }
          continue;
        }
        if (trimmed.startsWith('[#')) {
          // Internal reference, ignore for structure expansion
          continue;
        }

        commitSection();
        currentLabel = trimmed.substring(1, trimmed.length - 1);
        continue;
      }

      currentBuffer.writeln(line);
    }
    commitSection();

    return finalOutput.join('\n\n');
  }

  /// Fetches raw LRC sync data from LRCLIB for a given artist/title.
  /// Used to "bridge" sync data to Genius lyrics results.
  Future<String?> getLrcSync(String track, String artist) async {
    try {
      final query = '$artist $track';
      final searchUrl = Uri.parse(
        'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}',
      );

      final response = await http
          .get(
            searchUrl,
            headers: {'User-Agent': 'AuraShow/1.0.0 (https://github.com)'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          // Look for an exact match or close match with synced lyrics
          final match = data.firstWhere(
            (item) =>
                item['syncedLyrics'] != null &&
                item['syncedLyrics'].toString().isNotEmpty,
            orElse: () => null,
          );
          return match?['syncedLyrics'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Sync bridge fetch error: $e');
      return null;
    }
  }

  Future<String?> _searchLrclib(String query) async {
    try {
      // Try search endpoint
      final searchUrl = Uri.parse(
        'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}',
      );
      debugPrint('LRCLIB Search: $searchUrl');

      final searchResponse = await http
          .get(
            searchUrl,
            headers: {'User-Agent': 'AuraShow/1.0.0 (https://github.com)'},
          )
          .timeout(const Duration(seconds: 10));

      if (searchResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(searchResponse.body);
        if (data.isNotEmpty) {
          final first = data.first;
          if (first['plainLyrics'] != null) {
            return cleanLyrics(first['plainLyrics']);
          }
          if (first['syncedLyrics'] != null) {
            return cleanLyrics(_stripTimestamps(first['syncedLyrics']));
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('LRCLIB error: $e');
      return null;
    }
  }

  /// Search LRCLIB and return list of Song objects
  Future<List<Song>> _searchLrclibForSongs(String query) async {
    try {
      final searchUrl = Uri.parse(
        'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}',
      );

      final response = await http
          .get(
            searchUrl,
            headers: {'User-Agent': 'AuraShow/1.0.0 (https://github.com)'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Song> results = [];

        for (var item in data) {
          try {
            final id = item['id'].toString();
            final title = item['trackName'] ?? 'Unknown Title';
            final artist = item['artistName'] ?? 'Unknown Artist';
            final album = item['albumName'] ?? '';

            String content = '';
            bool hasSynced = false;
            String? alignmentData;

            if (item['syncedLyrics'] != null &&
                item['syncedLyrics'].toString().isNotEmpty) {
              hasSynced = true;
              alignmentData = item['syncedLyrics'];

              // --- HYBRID LOGIC START ---
              String? geniusStructure;
              try {
                // Background search to Genius for Structure
                final geniusHits = await _searchGeniusAPI('$title $artist');
                if (geniusHits.isNotEmpty) {
                  geniusStructure = await _scrapeGeniusPage(
                    geniusHits.first.url,
                  );
                  geniusStructure = cleanLyrics(geniusStructure);
                }
              } catch (e) {
                debugPrint('Genius hybrid fallback failed: $e');
              }

              if (geniusStructure != null && geniusStructure.isNotEmpty) {
                debugPrint('Merging Genius Structure into LRCLIB Timing...');
                final merged = _mergeGeniusStructureWithLrc(
                  geniusStructure,
                  alignmentData!,
                );

                if (merged.contains('[VERSE') ||
                    merged.contains('[CHORUS') ||
                    merged.contains('[BRIDGE') ||
                    merged.contains('[INTRO')) {
                  alignmentData = merged;
                  content = cleanLyrics(
                    _stripTimestamps(merged),
                    autoLabel: false,
                  );
                } else {
                  final structured = _smartStructureFromLrc(alignmentData);
                  content = cleanLyrics(
                    _stripTimestamps(structured),
                    autoLabel: false,
                  );
                  alignmentData = structured;
                }
              } else {
                final structured = _smartStructureFromLrc(alignmentData!);
                content = cleanLyrics(
                  _stripTimestamps(structured),
                  autoLabel: false,
                );
                alignmentData = structured;
              }
              // --- HYBRID LOGIC END ---
            } else if (item['plainLyrics'] != null) {
              content = cleanLyrics(_autoLabelRawText(item['plainLyrics']));
            }

            results.add(
              Song(
                id: 'lrclib_$id',
                title: title,
                author: artist,
                ccli: album,
                copyright: 'lrclib:$id',
                content: content,
                hasSyncedLyrics: hasSynced,
                alignmentData: alignmentData,
                source: 'lrclib',
              ),
            );
          } catch (itemError) {
            debugPrint('Error parsing LRCLIB item: $itemError');
            continue;
          }
        }
        return results;
      }
      return [];
    } catch (e) {
      debugPrint('LRCLIB list search error: $e');
      return [];
    }
  }

  /// Helper to remove timestamps from synced lyrics
  String _stripTimestamps(String syncedLyrics) {
    // Robustly remove all LRC timestamps: [mm:ss], [mm:ss.xx], [mm:ss.xxx]
    return syncedLyrics
        .replaceAll(RegExp(r'\[\d{1,3}:\d{1,2}(?:\.\d+)?\]\s*'), '')
        .trim();
  }

  Future<String> _fetchAndCleanLyrics(
    List<GeniusSongResult> results,
    String query,
  ) async {
    final bestMatch = _findBestMatch(results, query) ?? results.first;
    debugPrint('Best match: ${bestMatch.title} by ${bestMatch.artist}');

    String rawLyrics = await _scrapeGeniusPage(bestMatch.url);
    if (rawLyrics.startsWith("Error") || rawLyrics.startsWith("Could not")) {
      return rawLyrics;
    }

    String cleanedLyrics = cleanLyrics(rawLyrics);
    final header = 'Title: ${bestMatch.title}\nAuthor: ${bestMatch.artist}\n\n';
    return header + cleanedLyrics;
  }

  /// Search for songs and return list of results (for UI picker)
  Future<List<Song>> webSearch(String query) async {
    return searchSongs(query);
  }

  /// Fetch lyrics from a URL
  Future<String> fetchLyricsFromUrl(String url) async {
    if (!url.startsWith('http')) return '';
    try {
      final lyrics = await _scrapeGeniusPage(url);
      if (lyrics.startsWith("Error") || lyrics.startsWith("Could not")) {
        return '';
      }
      return cleanLyrics(lyrics);
    } catch (e) {
      debugPrint('Fetch lyrics error: $e');
      return '';
    }
  }

  // ============================================================
  // QUERY SANITIZATION
  // ============================================================

  String _sanitizeQuery(String query) {
    String clean = query;

    if (clean.contains(' - ')) {
      clean = clean.replaceFirst(' - ', ' ');
    } else if (clean.toLowerCase().contains(' by ')) {
      clean = clean.replaceAll(RegExp(r' by ', caseSensitive: false), ' ');
    }

    final junkPattern = RegExp(
      r'\b(official\s+video|official\s+audio|lyrics|lyric|live|hd|4k|mv|music\s+video|audio)\b',
      caseSensitive: false,
    );
    clean = clean.replaceAll(junkPattern, '');

    clean = clean.replaceAll(
      RegExp(r'\s(ft\.|feat\.|featuring)\s+.*$', caseSensitive: false),
      '',
    );
    clean = clean.replaceAll(
      RegExp(r'\s\(feat\..*?\)', caseSensitive: false),
      '',
    );
    clean = clean.replaceAll(
      RegExp(r'\s\((?!remix|reprise).+?\)', caseSensitive: false),
      '',
    );

    // Don't remove brackets if they might contain the song title or version
    // Only remove if they contain common junk
    clean = clean.replaceAll(
      RegExp(r'\[(Official|MV|HD|4K|Lyrics)\]', caseSensitive: false),
      '',
    );

    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ============================================================
  // GENIUS API
  // ============================================================

  Future<List<GeniusSongResult>> _searchGeniusAPI(String query) async {
    try {
      final url = Uri.parse(
        'https://api.genius.com/search?q=${Uri.encodeComponent(query)}',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $_geniusToken',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final hits = data['response']?['hits'] as List<dynamic>? ?? [];

      return hits.take(10).map<GeniusSongResult>((hit) {
        final result = hit['result'] as Map<String, dynamic>;
        return GeniusSongResult(
          id: result['id'] as int? ?? 0,
          title: result['title_with_featured'] ?? result['title'] ?? '',
          artist: result['primary_artist']?['name'] ?? '',
          url: result['url'] ?? '',
          imageUrl: result['song_art_image_thumbnail_url'] ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('Genius API error: $e');
      return [];
    }
  }

  GeniusSongResult? _findBestMatch(
    List<GeniusSongResult> results,
    String originalQuery,
  ) {
    if (results.isEmpty) return null;

    GeniusSongResult? bestResult;
    int bestScore = 999;
    final queryLower = originalQuery.toLowerCase();

    for (final result in results) {
      int score = _levenshtein(result.title.toLowerCase(), queryLower);
      int combinedScore = _levenshtein(
        '${result.title} ${result.artist}'.toLowerCase(),
        queryLower,
      );
      score = min(score, combinedScore);

      if (result.title.toLowerCase().contains('tracklist')) score += 50;
      if (result.title.toLowerCase().contains('script')) score += 50;
      if (result.title.toLowerCase().contains('sample')) score += 30;

      if (score < bestScore) {
        bestScore = score;
        bestResult = result;
      }
    }
    return bestResult;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < t.length + 1; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  Future<String> _scrapeGeniusPage(String url) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return "Error reading lyrics page.";

      final document = parse(response.body);
      var lyricsContainers = document.querySelectorAll(
        '[data-lyrics-container="true"]',
      );
      if (lyricsContainers.isEmpty) {
        lyricsContainers = document.querySelectorAll(
          'div[class^="Lyrics__Container"]',
        );
      }
      if (lyricsContainers.isEmpty) {
        lyricsContainers = document.querySelectorAll('.lyrics');
      }

      if (lyricsContainers.isEmpty) return "Could not parse lyrics text.";

      final buffer = StringBuffer();
      for (final container in lyricsContainers) {
        String html = container.innerHtml;
        html = html.replaceAll(RegExp(r'<br\s*/?>'), '\n');
        html = html.replaceAll(RegExp(r'<[^>]+>'), '');
        buffer.writeln(html);
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('Scrape error: $e');
      return "Error: $e";
    }
  }

  String cleanLyrics(String text, {bool autoLabel = true}) {
    String cleaned = text;

    // 0. Remove Genius "Contributors" Header Junk
    cleaned = cleaned.replaceAll(
      RegExp(r'\(?\d+\s*Contributors.*?Lyrics\)?', caseSensitive: false),
      '',
    );

    // A. Remove Genius Artifacts (Body)
    cleaned = cleaned.replaceAll(RegExp(r'\d*Embed$', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\d*Embed\s*$', multiLine: true), '');
    cleaned = cleaned.replaceAll('You might also like', '');
    cleaned = cleaned.replaceAll('See upcoming rap shows', '');
    cleaned = cleaned.replaceAll('Get tickets as low as', '');
    cleaned = cleaned.replaceAll(RegExp(r'See .+ Live'), '');
    cleaned = cleaned.replaceAll(RegExp(r'Get tickets.*'), '');

    // B. Strip Noise (Chords) - Skip if it looks like a section header
    final headerKeywords =
        'Intro|Verse|Chorus|Bridge|Pre-Chorus|Pre Chorus|Outro|Hook|Vamp|Tag|Refrain';
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[([A-G][b#]?[a-zA-Z0-9/]*)\]'),
      (match) {
        final inside = match.group(1) ?? '';
        if (RegExp(headerKeywords, caseSensitive: false).hasMatch(inside)) {
          return match.group(0)!;
        }
        return '';
      },
    );

    // C. Normalize Headers
    cleaned = cleaned.replaceAllMapped(
      RegExp(
        r'^[\(\[]?(Verse|Chorus|Bridge|Pre-Chorus|Pre Chorus|Intro|Outro|Hook|Vamp|Tag|Refrain)(\s*\d*)[^\)\]\:]*[\)\]\:]?',
        caseSensitive: false,
        multiLine: true,
      ),
      (match) {
        final section = match.group(1)!.toUpperCase();
        final num = match.group(2)?.trim() ?? '';
        return '\n\n[$section${num.isNotEmpty ? ' $num' : ''}]\n';
      },
    );

    // D. Simplify "[VERSE 1: Artist Name]" -> "[VERSE 1]"
    cleaned = cleaned.replaceAllMapped(
      RegExp(
        r'\[(VERSE|CHORUS|BRIDGE|HOOK|PRE-CHORUS|INTRO|OUTRO)(\s\d+)?:.*?\]',
        caseSensitive: false,
      ),
      (match) {
        final section = match.group(1)!.toUpperCase();
        final num = match.group(2) ?? '';
        return '[$section$num]';
      },
    );

    // E. Smart Detective: Auto-Label if missing
    if (autoLabel) {
      cleaned = _autoLabelRawText(cleaned);
    }

    // E2. The Cloner: Expand empty section headers
    cleaned = _expandStructure(cleaned);

    // F. Smart Title Casing
    if (_isAllUpper(cleaned)) {
      cleaned = _convertToTitleCase(cleaned);
    }

    // G. Theological Casing (for church use)
    cleaned = _applyTheologicalCasing(cleaned);

    // H. Fix Spacing (Normalize to max 2 newlines)
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // I. Clean up HTML entities
    cleaned = _cleanHtmlEntities(cleaned);

    return cleaned.trim();
  }

  bool _isAllUpper(String text) {
    final letters = text.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    return letters.isNotEmpty && letters == letters.toUpperCase();
  }

  /// Merges Genius Structure (Headers) into LRCLIB Synced Lyrics
  String _mergeGeniusStructureWithLrc(String geniusText, String lrcText) {
    // 1. Parse Genius into Sections with Multi-Line Anchors
    // Map<SectionHeader, List<FuzzyLine>>
    final Map<String, List<String>> sectionAnchors = {};
    final geniusLines = geniusText.split('\n');
    String currentHeader = '';

    for (var line in geniusLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        currentHeader = trimmed;
        sectionAnchors[currentHeader] = [];
        continue;
      }

      if (currentHeader.isNotEmpty &&
          sectionAnchors[currentHeader]!.length < 2) {
        final fuzzy = _getFuzzySignature(trimmed);
        if (fuzzy.isNotEmpty) {
          sectionAnchors[currentHeader]!.add(fuzzy);
        }
      }
    }

    // 2. Process LRC Line by Line
    final lrcLines = lrcText.split('\n');
    final buffer = StringBuffer();
    final Set<String> matchedHeaders = {};

    for (var line in lrcLines) {
      final cleanLrcLine = _getFuzzySignature(
        line.replaceAll(RegExp(r'\[.*?\]'), ''),
      );

      if (cleanLrcLine.isNotEmpty) {
        String? foundHeader;
        for (var entry in sectionAnchors.entries) {
          if (matchedHeaders.contains(entry.key)) continue;

          // Match if ANY of the first 2 lines of the section match
          bool isMatch = entry.value.any(
            (anchor) =>
                cleanLrcLine.contains(anchor) || anchor.contains(cleanLrcLine),
          );

          if (isMatch) {
            foundHeader = entry.key;
            break;
          }
        }

        if (foundHeader != null) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.writeln(foundHeader);
          matchedHeaders.add(foundHeader);
        }
      }
      buffer.writeln(line);
    }

    return buffer.toString().trim();
  }

  /// "Time Knife" - Automatically insert structure based on timestamp gaps
  String _smartStructureFromLrc(String lrcText) {
    if (lrcText.isEmpty) return lrcText;

    final lines = lrcText.split('\n');
    final buffer = StringBuffer();
    double lastTime = -1.0;
    int sectionCount = 0;
    bool hasInitialHeader = false;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect existing headers to avoid double insertion
      if (trimmed.startsWith('[') && !trimmed.contains(':')) {
        buffer.writeln(line);
        hasInitialHeader = true;
        continue;
      }

      final match = RegExp(
        r'\[(\d+):(\d{1,2}(?:\.\d+)?)\]',
      ).firstMatch(trimmed);
      if (match != null) {
        final m = int.parse(match.group(1)!);
        final s = double.parse(match.group(2)!);
        final currentTime = m * 60.0 + s;

        if (lastTime < 0) {
          if (!hasInitialHeader) {
            sectionCount++;
            buffer.writeln('[VERSE $sectionCount]');
          }
        } else {
          final gap = currentTime - lastTime;
          // Typical gap between sections is > 5s
          if (gap > 6.0 &&
              !trimmed.contains('[VERSE') &&
              !trimmed.contains('[CHORUS')) {
            sectionCount++;
            buffer.writeln();
            // Try to guess if it's a verse or bridge
            String label = 'VERSE';
            if (currentTime > 120 && gap > 10) label = 'BRIDGE/OUTRO';
            buffer.writeln('[$label $sectionCount]');
          }
        }
        lastTime = currentTime;
      }
      buffer.writeln(line);
    }
    return buffer.toString().trim();
  }

  /// Normalize text for comparison (alphanumeric only)
  String _getFuzzySignature(String text) {
    // Remove ad-libs and non-alphanumeric chars
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)', dotAll: true), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _convertToTitleCase(String text) {
    return text
        .split('\n')
        .map((line) {
          if (line.startsWith('[')) return line;
          if (line.isEmpty) return line;
          return line.substring(0, 1).toUpperCase() +
              line.substring(1).toLowerCase();
        })
        .join('\n');
  }

  String _applyTheologicalCasing(String text) {
    String fixed = text;
    final deityTitles = [
      'god',
      'jesus',
      'lord',
      'savior',
      'christ',
      'father',
      'yahweh',
      'holy spirit',
    ];
    for (final title in deityTitles) {
      fixed = fixed.replaceAllMapped(
        RegExp(r'\b' + title + r'\b', caseSensitive: false),
        (match) {
          return match
              .group(0)!
              .split(' ')
              .map(
                (w) => w.isNotEmpty
                    ? w[0].toUpperCase() + w.substring(1).toLowerCase()
                    : w,
              )
              .join(' ');
        },
      );
    }
    return fixed;
  }

  String _cleanHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&apos;', "'");
  }

  List<SlideContent> parseSlides(Song song, {int maxLines = 8}) {
    final slides = <SlideContent>[];
    final content = song.content.replaceAll('\r\n', '\n');
    final lines = content.split('\n');

    StringBuffer mainBody = StringBuffer();
    Map<String, StringBuffer> layerBuffers = {};
    String currentTarget = 'main';
    String currentLabel = 'Slide';

    void commitSlide() {
      bool hasMain = mainBody.toString().trim().isNotEmpty;
      bool hasLayers = layerBuffers.values.any(
        (b) => b.toString().trim().isNotEmpty,
      );

      if (!hasMain && !hasLayers) return;

      final bodyText = mainBody.toString().trim();
      final generatedLayers = <SlideLayer>[];

      layerBuffers.forEach((key, buffer) {
        final text = buffer.toString().trim();
        if (text.isNotEmpty) {
          generatedLayers.add(
            SlideLayer(
              id: const Uuid().v4(),
              label: 'Text Box $key',
              kind: LayerKind.textbox,
              role: LayerRole.foreground,
              text: text,
              left: 0.1,
              top: 0.1,
              width: 0.8,
              height: 0.8,
            ),
          );
        }
      });

      final bodyLines = bodyText.split('\n');
      if (bodyLines.length > maxLines && maxLines > 0) {
        int chunks = (bodyLines.length / maxLines).ceil();
        for (int i = 0; i < chunks; i++) {
          final start = i * maxLines;
          final end = (start + maxLines < bodyLines.length)
              ? start + maxLines
              : bodyLines.length;
          final chunkText = bodyLines.sublist(start, end).join('\n');
          slides.add(
            SlideContent(
              id: const Uuid().v4(),
              title: '$currentLabel ${i + 1}',
              body: chunkText,
              templateId: 'default',
              fontSizeOverride: 60,
              alignOverride: TextAlign.center,
              verticalAlign: VerticalAlign.middle,
              layers: i == 0 ? generatedLayers : [],
              audioPath: song.audioPath,
              alignmentData: song.alignmentData,
            ),
          );
        }
      } else {
        slides.add(
          SlideContent(
            id: const Uuid().v4(),
            title: currentLabel,
            body: bodyText,
            templateId: 'default',
            fontSizeOverride: 60,
            alignOverride: TextAlign.center,
            verticalAlign: VerticalAlign.middle,
            layers: generatedLayers,
            audioPath: song.audioPath,
            alignmentData: song.alignmentData,
          ),
        );
      }
      mainBody.clear();
      layerBuffers.clear();
      currentTarget = 'main';
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Title=') ||
          trimmed.startsWith('Author=') ||
          trimmed.startsWith('CCLI=') ||
          trimmed.startsWith('Copyright=')) {
        continue;
      }

      if (trimmed.startsWith('[') &&
          trimmed.endsWith(']') &&
          !trimmed.contains(':')) {
        if (trimmed == '[_VB]') {
          if (currentTarget == 'main') {
            mainBody.writeln('[_VB]');
          } else {
            layerBuffers[currentTarget]?.writeln('[_VB]');
          }
          continue;
        }
        if (trimmed.startsWith('[#')) {
          currentTarget = trimmed.substring(1, trimmed.length - 1);
          layerBuffers.putIfAbsent(currentTarget, () => StringBuffer());
          continue;
        }
        commitSlide();
        currentLabel = trimmed.substring(1, trimmed.length - 1);
        continue;
      }
      if (trimmed.isEmpty) {
        commitSlide();
        continue;
      }
      if (currentTarget == 'main') {
        mainBody.writeln(line);
      } else {
        layerBuffers[currentTarget]?.writeln(line);
      }
    }
    commitSlide();

    if (slides.isEmpty) {
      slides.add(
        SlideContent(
          id: const Uuid().v4(),
          title: 'Slide 1',
          body: '',
          templateId: 'default',
        ),
      );
    }
    return slides;
  }

  void _notifyListeners() {
    _songsController.add(_songs);
  }
}
