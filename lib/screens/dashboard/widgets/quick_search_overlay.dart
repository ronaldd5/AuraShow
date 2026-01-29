part of dashboard_screen;

/// Quick Search Overlay - Spotlight-style search for Bible verses and songs.
/// Triggered by Ctrl+K (Windows) or Cmd+K (Mac).
class QuickSearchOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(dynamic result, QuickSearchResultType type) onFire;

  const QuickSearchOverlay({
    super.key,
    required this.onClose,
    required this.onFire,
  });

  @override
  State<QuickSearchOverlay> createState() => _QuickSearchOverlayState();
}

enum QuickSearchResultType { bible, song }

class _QuickSearchResult {
  final String title;
  final String subtitle;
  final QuickSearchResultType type;
  final dynamic data; // BibleVerse or Song

  _QuickSearchResult({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.data,
  });
}

class _QuickSearchOverlayState extends State<QuickSearchOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<_QuickSearchResult> _results = [];
  int _selectedIndex = 0;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field when overlay opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _selectedIndex = 0;
      });
      return;
    }

    setState(() => _isSearching = true);

    // Search both services simultaneously
    final bibleFuture = BibleService.instance.search(query);
    final songs = LyricsService.instance.search(query);

    final bibleVerses = await bibleFuture;

    final List<_QuickSearchResult> combined = [];

    // Add Bible results (limit to 5)
    for (final verse in bibleVerses.take(5)) {
      combined.add(
        _QuickSearchResult(
          title: verse.reference,
          subtitle: verse.text.length > 60
              ? '${verse.text.substring(0, 60)}...'
              : verse.text,
          type: QuickSearchResultType.bible,
          data: verse,
        ),
      );
    }

    // Add Song results (limit to 5)
    for (final song in songs.take(5)) {
      combined.add(
        _QuickSearchResult(
          title: song.title,
          subtitle: song.author.isNotEmpty ? song.author : 'Unknown Artist',
          type: QuickSearchResultType.song,
          data: song,
        ),
      );
    }

    setState(() {
      _results = combined;
      _selectedIndex = 0;
      _isSearching = false;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _results.length - 1);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _results.length - 1);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_results.isNotEmpty && _selectedIndex < _results.length) {
        final result = _results[_selectedIndex];
        widget.onFire(result.data, result.type);
        widget.onClose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onClose, // Close on background tap
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping the dialog
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 500,
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search input
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search Bible verses or songs... (Esc to close)',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                  border: InputBorder.none,
                                ),
                                onChanged: _search,
                              ),
                            ),
                            if (_isSearching)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Results list
                      if (_results.isNotEmpty)
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final result = _results[index];
                              final isSelected = index == _selectedIndex;
                              return InkWell(
                                onTap: () {
                                  widget.onFire(result.data, result.type);
                                  widget.onClose();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  child: Row(
                                    children: [
                                      Icon(
                                        result.type ==
                                                QuickSearchResultType.bible
                                            ? Icons.menu_book
                                            : Icons.music_note,
                                        color:
                                            result.type ==
                                                QuickSearchResultType.bible
                                            ? Colors.amber
                                            : Colors.pink,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              result.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              result.subtitle,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.6,
                                                ),
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Enter ↵',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      // Empty state
                      if (_results.isEmpty &&
                          _controller.text.isNotEmpty &&
                          !_isSearching)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No results found',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
