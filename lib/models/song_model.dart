import 'dart:convert';
import 'package:uuid/uuid.dart';

class Song {
  final String id;
  String title;
  String author;
  String copyright;
  String ccli;
  String content; // Raw text content with stanzas separated by double newlines

  Song({
    required this.id,
    required this.title,
    this.author = '',
    this.copyright = '',
    this.ccli = '',
    this.content = '',
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
  }) {
    return Song(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      copyright: copyright ?? this.copyright,
      ccli: ccli ?? this.ccli,
      content: content ?? this.content,
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
