/// Scripture parsing and indexing service for fast reference lookup
/// Implements FreeShow-style autocomplete and jump-to-verse functionality
library scripture_service;

/// Represents a parsed scripture reference
class ScriptureReference {
  final String bookName;
  final String bookAbbr;
  final int bookIndex; // 1-66
  final int chapter;
  final int? verseStart;
  final int? verseEnd;
  final int globalVerseIndex; // Unique ID across entire Bible

  ScriptureReference({
    required this.bookName,
    required this.bookAbbr,
    required this.bookIndex,
    required this.chapter,
    this.verseStart,
    this.verseEnd,
    required this.globalVerseIndex,
  });

  String get displayReference {
    final versePart = verseStart != null
        ? ':$verseStart${verseEnd != null && verseEnd != verseStart ? '-$verseEnd' : ''}'
        : '';
    return '$bookName $chapter$versePart';
  }

  @override
  String toString() => displayReference;
}

/// Static scripture parsing and indexing service
class ScriptureService {
  ScriptureService._();

  /// All 66 books with their metadata
  static const List<Map<String, dynamic>> books = [
    // Old Testament (39 books)
    {'name': 'Genesis', 'abbr': 'Gen', 'chapters': 50, 'testament': 'OT', 'index': 1},
    {'name': 'Exodus', 'abbr': 'Exod', 'chapters': 40, 'testament': 'OT', 'index': 2},
    {'name': 'Leviticus', 'abbr': 'Lev', 'chapters': 27, 'testament': 'OT', 'index': 3},
    {'name': 'Numbers', 'abbr': 'Num', 'chapters': 36, 'testament': 'OT', 'index': 4},
    {'name': 'Deuteronomy', 'abbr': 'Deut', 'chapters': 34, 'testament': 'OT', 'index': 5},
    {'name': 'Joshua', 'abbr': 'Josh', 'chapters': 24, 'testament': 'OT', 'index': 6},
    {'name': 'Judges', 'abbr': 'Judg', 'chapters': 21, 'testament': 'OT', 'index': 7},
    {'name': 'Ruth', 'abbr': 'Ruth', 'chapters': 4, 'testament': 'OT', 'index': 8},
    {'name': '1 Samuel', 'abbr': '1Sam', 'chapters': 31, 'testament': 'OT', 'index': 9},
    {'name': '2 Samuel', 'abbr': '2Sam', 'chapters': 24, 'testament': 'OT', 'index': 10},
    {'name': '1 Kings', 'abbr': '1Kgs', 'chapters': 22, 'testament': 'OT', 'index': 11},
    {'name': '2 Kings', 'abbr': '2Kgs', 'chapters': 25, 'testament': 'OT', 'index': 12},
    {'name': '1 Chronicles', 'abbr': '1Chr', 'chapters': 29, 'testament': 'OT', 'index': 13},
    {'name': '2 Chronicles', 'abbr': '2Chr', 'chapters': 36, 'testament': 'OT', 'index': 14},
    {'name': 'Ezra', 'abbr': 'Ezra', 'chapters': 10, 'testament': 'OT', 'index': 15},
    {'name': 'Nehemiah', 'abbr': 'Neh', 'chapters': 13, 'testament': 'OT', 'index': 16},
    {'name': 'Esther', 'abbr': 'Esth', 'chapters': 10, 'testament': 'OT', 'index': 17},
    {'name': 'Job', 'abbr': 'Job', 'chapters': 42, 'testament': 'OT', 'index': 18},
    {'name': 'Psalms', 'abbr': 'Ps', 'chapters': 150, 'testament': 'OT', 'index': 19},
    {'name': 'Proverbs', 'abbr': 'Prov', 'chapters': 31, 'testament': 'OT', 'index': 20},
    {'name': 'Ecclesiastes', 'abbr': 'Eccl', 'chapters': 12, 'testament': 'OT', 'index': 21},
    {'name': 'Song of Solomon', 'abbr': 'Song', 'chapters': 8, 'testament': 'OT', 'index': 22},
    {'name': 'Isaiah', 'abbr': 'Isa', 'chapters': 66, 'testament': 'OT', 'index': 23},
    {'name': 'Jeremiah', 'abbr': 'Jer', 'chapters': 52, 'testament': 'OT', 'index': 24},
    {'name': 'Lamentations', 'abbr': 'Lam', 'chapters': 5, 'testament': 'OT', 'index': 25},
    {'name': 'Ezekiel', 'abbr': 'Ezek', 'chapters': 48, 'testament': 'OT', 'index': 26},
    {'name': 'Daniel', 'abbr': 'Dan', 'chapters': 12, 'testament': 'OT', 'index': 27},
    {'name': 'Hosea', 'abbr': 'Hos', 'chapters': 14, 'testament': 'OT', 'index': 28},
    {'name': 'Joel', 'abbr': 'Joel', 'chapters': 3, 'testament': 'OT', 'index': 29},
    {'name': 'Amos', 'abbr': 'Amos', 'chapters': 9, 'testament': 'OT', 'index': 30},
    {'name': 'Obadiah', 'abbr': 'Obad', 'chapters': 1, 'testament': 'OT', 'index': 31},
    {'name': 'Jonah', 'abbr': 'Jonah', 'chapters': 4, 'testament': 'OT', 'index': 32},
    {'name': 'Micah', 'abbr': 'Mic', 'chapters': 7, 'testament': 'OT', 'index': 33},
    {'name': 'Nahum', 'abbr': 'Nah', 'chapters': 3, 'testament': 'OT', 'index': 34},
    {'name': 'Habakkuk', 'abbr': 'Hab', 'chapters': 3, 'testament': 'OT', 'index': 35},
    {'name': 'Zephaniah', 'abbr': 'Zeph', 'chapters': 3, 'testament': 'OT', 'index': 36},
    {'name': 'Haggai', 'abbr': 'Hag', 'chapters': 2, 'testament': 'OT', 'index': 37},
    {'name': 'Zechariah', 'abbr': 'Zech', 'chapters': 14, 'testament': 'OT', 'index': 38},
    {'name': 'Malachi', 'abbr': 'Mal', 'chapters': 4, 'testament': 'OT', 'index': 39},
    // New Testament (27 books)
    {'name': 'Matthew', 'abbr': 'Matt', 'chapters': 28, 'testament': 'NT', 'index': 40},
    {'name': 'Mark', 'abbr': 'Mark', 'chapters': 16, 'testament': 'NT', 'index': 41},
    {'name': 'Luke', 'abbr': 'Luke', 'chapters': 24, 'testament': 'NT', 'index': 42},
    {'name': 'John', 'abbr': 'John', 'chapters': 21, 'testament': 'NT', 'index': 43},
    {'name': 'Acts', 'abbr': 'Acts', 'chapters': 28, 'testament': 'NT', 'index': 44},
    {'name': 'Romans', 'abbr': 'Rom', 'chapters': 16, 'testament': 'NT', 'index': 45},
    {'name': '1 Corinthians', 'abbr': '1Cor', 'chapters': 16, 'testament': 'NT', 'index': 46},
    {'name': '2 Corinthians', 'abbr': '2Cor', 'chapters': 13, 'testament': 'NT', 'index': 47},
    {'name': 'Galatians', 'abbr': 'Gal', 'chapters': 6, 'testament': 'NT', 'index': 48},
    {'name': 'Ephesians', 'abbr': 'Eph', 'chapters': 6, 'testament': 'NT', 'index': 49},
    {'name': 'Philippians', 'abbr': 'Phil', 'chapters': 4, 'testament': 'NT', 'index': 50},
    {'name': 'Colossians', 'abbr': 'Col', 'chapters': 4, 'testament': 'NT', 'index': 51},
    {'name': '1 Thessalonians', 'abbr': '1Thess', 'chapters': 5, 'testament': 'NT', 'index': 52},
    {'name': '2 Thessalonians', 'abbr': '2Thess', 'chapters': 3, 'testament': 'NT', 'index': 53},
    {'name': '1 Timothy', 'abbr': '1Tim', 'chapters': 6, 'testament': 'NT', 'index': 54},
    {'name': '2 Timothy', 'abbr': '2Tim', 'chapters': 4, 'testament': 'NT', 'index': 55},
    {'name': 'Titus', 'abbr': 'Titus', 'chapters': 3, 'testament': 'NT', 'index': 56},
    {'name': 'Philemon', 'abbr': 'Phlm', 'chapters': 1, 'testament': 'NT', 'index': 57},
    {'name': 'Hebrews', 'abbr': 'Heb', 'chapters': 13, 'testament': 'NT', 'index': 58},
    {'name': 'James', 'abbr': 'Jas', 'chapters': 5, 'testament': 'NT', 'index': 59},
    {'name': '1 Peter', 'abbr': '1Pet', 'chapters': 5, 'testament': 'NT', 'index': 60},
    {'name': '2 Peter', 'abbr': '2Pet', 'chapters': 3, 'testament': 'NT', 'index': 61},
    {'name': '1 John', 'abbr': '1John', 'chapters': 5, 'testament': 'NT', 'index': 62},
    {'name': '2 John', 'abbr': '2John', 'chapters': 1, 'testament': 'NT', 'index': 63},
    {'name': '3 John', 'abbr': '3John', 'chapters': 1, 'testament': 'NT', 'index': 64},
    {'name': 'Jude', 'abbr': 'Jude', 'chapters': 1, 'testament': 'NT', 'index': 65},
    {'name': 'Revelation', 'abbr': 'Rev', 'chapters': 22, 'testament': 'NT', 'index': 66},
  ];

  /// Alternative book name mappings for flexible matching
  static const Map<String, String> bookAliases = {
    // Common abbreviations
    'gen': 'Genesis', 'ge': 'Genesis', 'gn': 'Genesis',
    'exo': 'Exodus', 'ex': 'Exodus',
    'lev': 'Leviticus', 'le': 'Leviticus', 'lv': 'Leviticus',
    'num': 'Numbers', 'nu': 'Numbers', 'nm': 'Numbers',
    'deu': 'Deuteronomy', 'de': 'Deuteronomy', 'dt': 'Deuteronomy',
    'jos': 'Joshua', 'jsh': 'Joshua',
    'jdg': 'Judges', 'jg': 'Judges', 'jud': 'Judges',
    'rut': 'Ruth', 'ru': 'Ruth',
    '1sa': '1 Samuel', '1sm': '1 Samuel', '1sam': '1 Samuel',
    '2sa': '2 Samuel', '2sm': '2 Samuel', '2sam': '2 Samuel',
    '1ki': '1 Kings', '1kg': '1 Kings', '1kgs': '1 Kings',
    '2ki': '2 Kings', '2kg': '2 Kings', '2kgs': '2 Kings',
    '1ch': '1 Chronicles', '1chr': '1 Chronicles',
    '2ch': '2 Chronicles', '2chr': '2 Chronicles',
    'ezr': 'Ezra',
    'neh': 'Nehemiah', 'ne': 'Nehemiah',
    'est': 'Esther', 'esth': 'Esther',
    'jb': 'Job',
    'psa': 'Psalms', 'ps': 'Psalms', 'pss': 'Psalms', 'psalm': 'Psalms',
    'pro': 'Proverbs', 'pr': 'Proverbs', 'prv': 'Proverbs', 'prov': 'Proverbs',
    'ecc': 'Ecclesiastes', 'ec': 'Ecclesiastes', 'eccl': 'Ecclesiastes',
    'sng': 'Song of Solomon', 'sos': 'Song of Solomon', 'song': 'Song of Solomon', 'sol': 'Song of Solomon',
    'isa': 'Isaiah', 'is': 'Isaiah',
    'jer': 'Jeremiah', 'je': 'Jeremiah',
    'lam': 'Lamentations', 'la': 'Lamentations',
    'eze': 'Ezekiel', 'ezk': 'Ezekiel', 'ezek': 'Ezekiel',
    'dan': 'Daniel', 'da': 'Daniel', 'dn': 'Daniel',
    'hos': 'Hosea', 'ho': 'Hosea',
    'joe': 'Joel', 'jl': 'Joel',
    'amo': 'Amos', 'am': 'Amos',
    'oba': 'Obadiah', 'ob': 'Obadiah', 'obad': 'Obadiah',
    'jon': 'Jonah', 'jnh': 'Jonah',
    'mic': 'Micah', 'mi': 'Micah',
    'nah': 'Nahum', 'na': 'Nahum',
    'hab': 'Habakkuk', 'hb': 'Habakkuk',
    'zep': 'Zephaniah', 'zph': 'Zephaniah', 'zeph': 'Zephaniah',
    'hag': 'Haggai', 'hg': 'Haggai',
    'zec': 'Zechariah', 'zch': 'Zechariah', 'zech': 'Zechariah',
    'mal': 'Malachi', 'ml': 'Malachi',
    // New Testament
    'mat': 'Matthew', 'mt': 'Matthew', 'matt': 'Matthew',
    'mrk': 'Mark', 'mk': 'Mark', 'mr': 'Mark',
    'luk': 'Luke', 'lk': 'Luke', 'lu': 'Luke',
    'joh': 'John', 'jn': 'John', 'jhn': 'John',
    'act': 'Acts', 'ac': 'Acts',
    'rom': 'Romans', 'ro': 'Romans', 'rm': 'Romans',
    '1co': '1 Corinthians', '1cor': '1 Corinthians',
    '2co': '2 Corinthians', '2cor': '2 Corinthians',
    'gal': 'Galatians', 'ga': 'Galatians',
    'eph': 'Ephesians', 'ep': 'Ephesians',
    'php': 'Philippians', 'phil': 'Philippians', 'pp': 'Philippians',
    'col': 'Colossians', 'co': 'Colossians',
    '1th': '1 Thessalonians', '1thess': '1 Thessalonians', '1thes': '1 Thessalonians',
    '2th': '2 Thessalonians', '2thess': '2 Thessalonians', '2thes': '2 Thessalonians',
    '1ti': '1 Timothy', '1tim': '1 Timothy', '1tm': '1 Timothy',
    '2ti': '2 Timothy', '2tim': '2 Timothy', '2tm': '2 Timothy',
    'tit': 'Titus', 'ti': 'Titus',
    'phm': 'Philemon', 'phlm': 'Philemon', 'pm': 'Philemon',
    'heb': 'Hebrews', 'he': 'Hebrews',
    'jas': 'James', 'jm': 'James', 'jam': 'James',
    '1pe': '1 Peter', '1pet': '1 Peter', '1pt': '1 Peter',
    '2pe': '2 Peter', '2pet': '2 Peter', '2pt': '2 Peter',
    '1jn': '1 John', '1jo': '1 John', '1john': '1 John',
    '2jn': '2 John', '2jo': '2 John', '2john': '2 John',
    '3jn': '3 John', '3jo': '3 John', '3john': '3 John',
    'jde': 'Jude', 'jd': 'Jude',
    'rev': 'Revelation', 're': 'Revelation', 'rv': 'Revelation',
  };

  /// Pre-built index for fast book name matching
  static final Map<String, Map<String, dynamic>> _bookIndex = _buildBookIndex();
  
  static Map<String, Map<String, dynamic>> _buildBookIndex() {
    final index = <String, Map<String, dynamic>>{};
    for (final book in books) {
      final name = (book['name'] as String).toLowerCase().replaceAll(' ', '');
      final abbr = (book['abbr'] as String).toLowerCase();
      index[name] = book;
      index[abbr] = book;
    }
    // Add aliases
    for (final entry in bookAliases.entries) {
      final book = books.firstWhere(
        (b) => b['name'] == entry.value,
        orElse: () => <String, dynamic>{},
      );
      if (book.isNotEmpty) {
        index[entry.key] = book;
      }
    }
    return index;
  }

  /// Parse input string and return matching book(s)
  /// Returns list of potential matches, sorted by relevance
  static List<Map<String, dynamic>> findMatchingBooks(String input) {
    if (input.isEmpty) return [];
    
    final normalized = input.toLowerCase().replaceAll(' ', '');
    
    // Check for exact alias match first
    if (_bookIndex.containsKey(normalized)) {
      return [_bookIndex[normalized]!];
    }
    
    // Find all books that start with the input
    final matches = <Map<String, dynamic>>[];
    for (final book in books) {
      final name = (book['name'] as String).toLowerCase().replaceAll(' ', '');
      final abbr = (book['abbr'] as String).toLowerCase();
      
      if (name.startsWith(normalized) || abbr.startsWith(normalized)) {
        matches.add(book);
      }
    }
    
    // Also check aliases
    for (final entry in bookAliases.entries) {
      if (entry.key.startsWith(normalized)) {
        final book = books.firstWhere(
          (b) => b['name'] == entry.value,
          orElse: () => <String, dynamic>{},
        );
        if (book.isNotEmpty && !matches.contains(book)) {
          matches.add(book);
        }
      }
    }
    
    return matches;
  }

  /// Find the best matching book for a partial input
  static Map<String, dynamic>? findBestMatch(String input) {
    final matches = findMatchingBooks(input);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Main parsing regex patterns
  static final RegExp _fullReferencePattern = RegExp(
    r'^(\d?\s?[a-zA-Z]+(?:\s+[a-zA-Z]+)?)\s*(\d+)\s*[:.,]\s*(\d+)(?:\s*[-–—]\s*(\d+))?$',
    caseSensitive: false,
  );
  
  static final RegExp _chapterOnlyPattern = RegExp(
    r'^(\d?\s?[a-zA-Z]+(?:\s+[a-zA-Z]+)?)\s+(\d+)$',
    caseSensitive: false,
  );
  
  static final RegExp _chapterWithColonPattern = RegExp(
    r'^(\d?\s?[a-zA-Z]+(?:\s+[a-zA-Z]+)?)\s+(\d+)\s*[:.,]$',
    caseSensitive: false,
  );
  
  static final RegExp _bookOnlyPattern = RegExp(
    r'^(\d?\s?[a-zA-Z]+)$',
    caseSensitive: false,
  );

  /// Parse input and determine the type of reference
  static ParseResult parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return ParseResult.empty();
    }

    // Try full reference first: "John 3:16" or "John 3:16-18"
    var match = _fullReferencePattern.firstMatch(trimmed);
    if (match != null) {
      final bookInput = match.group(1)!.trim();
      final chapter = int.tryParse(match.group(2)!);
      final verseStart = int.tryParse(match.group(3)!);
      final verseEnd = match.group(4) != null ? int.tryParse(match.group(4)!) : null;
      
      final book = findBestMatch(bookInput);
      if (book != null && chapter != null && verseStart != null) {
        final maxChapters = book['chapters'] as int;
        if (chapter >= 1 && chapter <= maxChapters) {
          return ParseResult.verseReference(
            book: book,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd,
            inputBookText: bookInput,
          );
        }
      }
    }

    // Try chapter with trailing colon: "John 3:"
    match = _chapterWithColonPattern.firstMatch(trimmed);
    if (match != null) {
      final bookInput = match.group(1)!.trim();
      final chapter = int.tryParse(match.group(2)!);
      
      final book = findBestMatch(bookInput);
      if (book != null && chapter != null) {
        final maxChapters = book['chapters'] as int;
        if (chapter >= 1 && chapter <= maxChapters) {
          return ParseResult.chapterReady(
            book: book,
            chapter: chapter,
            inputBookText: bookInput,
          );
        }
      }
    }

    // Try chapter only: "John 3"
    match = _chapterOnlyPattern.firstMatch(trimmed);
    if (match != null) {
      final bookInput = match.group(1)!.trim();
      final chapter = int.tryParse(match.group(2)!);
      
      final book = findBestMatch(bookInput);
      if (book != null && chapter != null) {
        final maxChapters = book['chapters'] as int;
        if (chapter >= 1 && chapter <= maxChapters) {
          return ParseResult.chapterReference(
            book: book,
            chapter: chapter,
            inputBookText: bookInput,
          );
        }
      }
    }

    // Try book only: "John" or "joh" or "ma"
    match = _bookOnlyPattern.firstMatch(trimmed);
    if (match != null) {
      final bookInput = match.group(1)!.trim();
      final matches = findMatchingBooks(bookInput);
      
      if (matches.isNotEmpty) {
        return ParseResult.bookMatch(
          matches: matches,
          bestMatch: matches.first,
          inputBookText: bookInput,
        );
      }
    }

    return ParseResult.noMatch(input: trimmed);
  }

  /// Validate chapter number for a book
  static bool isValidChapter(Map<String, dynamic> book, int chapter) {
    final maxChapters = book['chapters'] as int? ?? 0;
    return chapter >= 1 && chapter <= maxChapters;
  }

  /// Get chapter count for a book
  static int getChapterCount(Map<String, dynamic> book) {
    return book['chapters'] as int? ?? 0;
  }
}

/// Result of parsing a scripture reference input
class ParseResult {
  final ParseResultType type;
  final Map<String, dynamic>? book;
  final List<Map<String, dynamic>>? matchingBooks;
  final int? chapter;
  final int? verseStart;
  final int? verseEnd;
  final String? inputBookText;
  final String? originalInput;

  ParseResult._({
    required this.type,
    this.book,
    this.matchingBooks,
    this.chapter,
    this.verseStart,
    this.verseEnd,
    this.inputBookText,
    this.originalInput,
  });

  factory ParseResult.empty() => ParseResult._(type: ParseResultType.empty);

  factory ParseResult.noMatch({required String input}) => ParseResult._(
    type: ParseResultType.noMatch,
    originalInput: input,
  );

  factory ParseResult.bookMatch({
    required List<Map<String, dynamic>> matches,
    required Map<String, dynamic> bestMatch,
    required String inputBookText,
  }) => ParseResult._(
    type: ParseResultType.bookMatch,
    book: bestMatch,
    matchingBooks: matches,
    inputBookText: inputBookText,
  );

  factory ParseResult.chapterReference({
    required Map<String, dynamic> book,
    required int chapter,
    required String inputBookText,
  }) => ParseResult._(
    type: ParseResultType.chapterReference,
    book: book,
    chapter: chapter,
    inputBookText: inputBookText,
  );

  factory ParseResult.chapterReady({
    required Map<String, dynamic> book,
    required int chapter,
    required String inputBookText,
  }) => ParseResult._(
    type: ParseResultType.chapterReady,
    book: book,
    chapter: chapter,
    inputBookText: inputBookText,
  );

  factory ParseResult.verseReference({
    required Map<String, dynamic> book,
    required int chapter,
    required int verseStart,
    int? verseEnd,
    required String inputBookText,
  }) => ParseResult._(
    type: ParseResultType.verseReference,
    book: book,
    chapter: chapter,
    verseStart: verseStart,
    verseEnd: verseEnd,
    inputBookText: inputBookText,
  );

  String? get bookName => book?['name'] as String?;
  String? get bookAbbr => book?['abbr'] as String?;
  int? get bookIndex => book?['index'] as int?;
  int? get maxChapters => book?['chapters'] as int?;

  /// Get the autocomplete text to fill into the search field
  String? get autocompleteText {
    if (book == null) return null;
    final name = book!['name'] as String;
    
    switch (type) {
      case ParseResultType.bookMatch:
        return '$name '; // Add space for chapter
      case ParseResultType.chapterReference:
        return '$name $chapter'; // Just the chapter
      case ParseResultType.chapterReady:
        return '$name $chapter:'; // Ready for verse
      case ParseResultType.verseReference:
        final verseRange = verseEnd != null && verseEnd != verseStart
            ? '$verseStart-$verseEnd'
            : '$verseStart';
        return '$name $chapter:$verseRange';
      default:
        return null;
    }
  }

  /// Check if input book text differs from actual book name (needs autocomplete)
  bool get needsAutocomplete {
    if (book == null || inputBookText == null) return false;
    final name = (book!['name'] as String).toLowerCase();
    return inputBookText!.toLowerCase() != name;
  }
}

enum ParseResultType {
  empty,
  noMatch,
  bookMatch,
  chapterReference,
  chapterReady,
  verseReference,
}
