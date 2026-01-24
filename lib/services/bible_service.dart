import 'dart:async';

class BibleVerse {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  BibleVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  String get reference => '$book $chapter:$verse';
}

class BibleService {
  BibleService._();
  static final BibleService instance = BibleService._();

  // Mock database
  final List<BibleVerse> _mockVerses = [
    BibleVerse(
      book: 'John',
      chapter: 3,
      verse: 16,
      text:
          'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.',
    ),
    BibleVerse(
      book: 'Genesis',
      chapter: 1,
      verse: 1,
      text: 'In the beginning God created the heavens and the earth.',
    ),
    BibleVerse(
      book: 'Psalm',
      chapter: 23,
      verse: 1,
      text: 'The Lord is my shepherd, I lack nothing.',
    ),
    BibleVerse(
      book: 'Philippians',
      chapter: 4,
      verse: 13,
      text: 'I can do all this through him who gives me strength.',
    ),
    BibleVerse(
      book: 'Jeremiah',
      chapter: 29,
      verse: 11,
      text:
          '"For I know the plans I have for you," declares the Lord, "plans to prosper you and not to harm you, plans to give you hope and a future."',
    ),
    BibleVerse(
      book: 'Romans',
      chapter: 8,
      verse: 28,
      text:
          'And we know that in all things God works for the good of those who love him, who have been called according to his purpose.',
    ),
  ];

  Future<List<BibleVerse>> search(String query) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    if (query.isEmpty) return _mockVerses;

    final lowerQuery = query.toLowerCase();
    return _mockVerses.where((verse) {
      return verse.book.toLowerCase().contains(lowerQuery) ||
          verse.text.toLowerCase().contains(lowerQuery) ||
          verse.reference.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  Future<BibleVerse?> getVerse(String reference) async {
    // Very basic exact match for now
    try {
      return _mockVerses.firstWhere((v) => v.reference == reference);
    } catch (_) {
      return null;
    }
  }
}
