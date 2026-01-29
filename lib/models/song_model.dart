import 'dart:convert';
import 'package:uuid/uuid.dart';

class Song {
  final String id;
  String title;
  String author;
  String copyright;
  String ccli;
  String content; // Raw text content with stanzas separated by double newlines
  String? audioPath;
  String? alignmentData; // JSON map of syllable timing
  bool hasSyncedLyrics; // True if LRC timing data is available
  String source; // Source provider: 'lrclib', 'genius', 'local', etc.

  Song({
    required this.id,
    required this.title,
    this.author = '',
    this.copyright = '',
    this.ccli = '',
    this.content = '',
    this.audioPath,
    this.alignmentData,
    this.hasSyncedLyrics = false,
    this.source = 'local',
  });

  factory Song.create({required String title}) {
    return Song(id: const Uuid().v4(), title: title);
  }

  Song copyWith({
    String? title,
    String? author,
    String? copyright,
    String? ccli,
    String? content,
    String? audioPath,
    String? alignmentData,
    bool? hasSyncedLyrics,
    String? source,
  }) {
    return Song(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      copyright: copyright ?? this.copyright,
      ccli: ccli ?? this.ccli,
      content: content ?? this.content,
      audioPath: audioPath ?? this.audioPath,
      alignmentData: alignmentData ?? this.alignmentData,
      hasSyncedLyrics: hasSyncedLyrics ?? this.hasSyncedLyrics,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'copyright': copyright,
      'ccli': ccli,
      'content': content,
      'audioPath': audioPath,
      'alignmentData': alignmentData,
      'hasSyncedLyrics': hasSyncedLyrics,
      'source': source,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Untitled',
      author: map['author'] ?? '',
      copyright: map['copyright'] ?? '',
      ccli: map['ccli'] ?? '',
      content: map['content'] ?? '',
      audioPath: map['audioPath'],
      alignmentData: map['alignmentData'],
      hasSyncedLyrics: map['hasSyncedLyrics'] ?? false,
      source: map['source'] ?? 'local',
    );
  }

  String toJson() => json.encode(toMap());

  factory Song.fromJson(String source) => Song.fromMap(json.decode(source));

  /// Parse content into stanza blocks
  List<String> get stanzas {
    return content
        .split(RegExp(r'\n\s*\n'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }
}
