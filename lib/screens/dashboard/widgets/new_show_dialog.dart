import 'package:flutter/material.dart';
import '../../../core/theme/palette.dart';
import '../../../services/lyrics_service.dart';
import '../../../models/song_model.dart';
import 'quick_lyrics_dialog.dart';

class NewShowDialog extends StatefulWidget {
  final List<String> availableCategories;
  final String? defaultCategory;

  const NewShowDialog({
    Key? key,
    required this.availableCategories,
    this.defaultCategory,
  }) : super(key: key);

  @override
  State<NewShowDialog> createState() => _NewShowDialogState();
}

class _NewShowDialogState extends State<NewShowDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedCategory;
  bool _isSearching = false;
  List<Song>? _searchResults;
  String? _sourceFilter; // All: null, lrclib, genius

  @override
  void initState() {
    super.initState();
    if (widget.defaultCategory != null &&
        widget.availableCategories.contains(widget.defaultCategory)) {
      _selectedCategory = widget.defaultCategory;
    } else {
      _selectedCategory = null;
    }
    // Listener removed: Search only triggers on button press
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _finish(String mode, [dynamic data]) {
    final name = _nameController.text.trim();
    if (name.isEmpty && mode != 'quick_lyrics' && mode != 'web_import') {
      return; // Name optional for smart modes? No, name is title.
    }

    Navigator.of(context).pop({
      'mode': mode,
      'name': name.isEmpty && data is Song ? data.title : name,
      'category': _selectedCategory,
      'data': data,
    });
  }

  Future<void> _performWebSearch() async {
    final query = _nameController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      // If we don't have results yet, show loading.
      // If we do, keeps showing old results until new ones arrive?
      // Or maybe clear them? Let's keep them to reduce flicker.
    });

    try {
      final results = await LyricsService.instance.searchSongs(
        query,
        sourceFilter: _sourceFilter,
        limit: 25,
      );

      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        // Don't snackbar on every type error, just log
        debugPrint('Search failed: $e');
      }
    }
  }

  /// When user selects a song from search results, fetch full lyrics and open QuickLyricsDialog
  Future<void> _selectSongAndOpenQuickLyrics(Song song) async {
    // Show loading state
    setState(() => _isSearching = true);

    String lyrics = song.content;
    String? alignmentData = song.alignmentData;

    // If Genius result, try to fetch lyrics AND look for sync bridge on LRCLIB
    if (song.source == 'genius') {
      try {
        // 1. Fetch text lyrics from Genius URL
        if (lyrics.isEmpty && song.copyright.startsWith('http')) {
          lyrics = await LyricsService.instance.fetchLyricsFromUrl(
            song.copyright,
          );
        }

        // 2. Sync Bridge: Try to find timing data on LRCLIB
        if (alignmentData == null || alignmentData.isEmpty) {
          debugPrint(
            'Sync Bridge: Attempting to find timing for ${song.title}...',
          );
          final lrcSync = await LyricsService.instance.getLrcSync(
            song.title,
            song.author,
          );
          if (lrcSync != null) {
            debugPrint('Sync Bridge: Found timing data!');
            alignmentData = lrcSync;
          }
        }
      } catch (e) {
        debugPrint('Genius Sync Bridge error: $e');
      }
    } else if (lyrics.isEmpty && song.copyright.startsWith('http')) {
      // Standard fetch for other sources
      try {
        lyrics = await LyricsService.instance.fetchLyricsFromUrl(
          song.copyright,
        );
      } catch (e) {
        debugPrint('Failed to fetch lyrics: $e');
      }
    }

    setState(() => _isSearching = false);

    // Use cleaned lyrics directly from LyricsService.
    // metadata header (Title/Author) will be added by QuickLyricsDialog if missing.
    final formattedLyrics = lyrics;

    // Close this dialog and return data for quick_lyrics mode
    // The parent will open QuickLyricsDialog with this pre-populated text
    Navigator.of(context).pop({
      'mode': 'quick_lyrics_prefilled',
      'name': song.title,
      'category': _selectedCategory,
      'author': song.author,
      'lyrics': formattedLyrics,
      'alignmentData': alignmentData,
    });
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white10,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(12),
              color: Colors.black26,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: Colors.white70),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine content to show below text field
    Widget content;

    if (_isSearching) {
      content = const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppPalette.accent),
        ),
      );
    } else if (_searchResults != null) {
      if (_searchResults!.isEmpty) {
        content = SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.white38),
                const SizedBox(height: 16),
                const Text(
                  'No results found',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try "Artist - Song Title"',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      } else {
        content = Expanded(
          child: Column(
            children: [
              // Source Filter Chips
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _sourceFilter == null,
                      onSelected: (selected) {
                        setState(() => _sourceFilter = null);
                        _performWebSearch();
                      },
                      backgroundColor: Colors.white10,
                      selectedColor: AppPalette.accent.withOpacity(0.3),
                      labelStyle: TextStyle(
                        color: _sourceFilter == null
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('LRCLIB'),
                      selected: _sourceFilter == 'lrclib',
                      onSelected: (selected) {
                        setState(() => _sourceFilter = 'lrclib');
                        _performWebSearch();
                      },
                      backgroundColor: Colors.white10,
                      selectedColor: Colors.green.withOpacity(0.3),
                      labelStyle: TextStyle(
                        color: _sourceFilter == 'lrclib'
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Genius'),
                      selected: _sourceFilter == 'genius',
                      onSelected: (selected) {
                        setState(() => _sourceFilter = 'genius');
                        _performWebSearch();
                      },
                      backgroundColor: Colors.white10,
                      selectedColor: Colors.amber.withOpacity(0.3),
                      labelStyle: TextStyle(
                        color: _sourceFilter == 'genius'
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: ListView.separated(
                  itemCount: _searchResults!.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white12),
                  itemBuilder: (context, index) {
                    final song = _searchResults![index];

                    // Determine source color
                    Color sourceColor = Colors.grey;
                    if (song.source == 'lrclib') {
                      sourceColor = Colors.green;
                    } else if (song.source == 'genius') {
                      sourceColor = Colors.amber;
                    }

                    return ListTile(
                      title: Text(
                        song.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        song.author,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      leading: Icon(
                        song.hasSyncedLyrics
                            ? Icons.mic_external_on
                            : Icons.music_note,
                        color: song.hasSyncedLyrics
                            ? Colors.greenAccent
                            : AppPalette.accent,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (song.hasSyncedLyrics) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.greenAccent.withOpacity(0.5),
                                ),
                              ),
                              child: const Text(
                                'SYNCED',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: sourceColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: sourceColor.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              song.source.toUpperCase(),
                              style: TextStyle(
                                color: sourceColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _selectSongAndOpenQuickLyrics(song),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // Default state: Show buttons
      content = SizedBox(
        height: 160,
        child: Row(
          children: [
            _buildOptionCard(
              icon: Icons.text_fields,
              label: 'Quick lyrics',
              onTap: () => _finish('quick_lyrics'),
            ),
            const SizedBox(width: 12),
            _buildOptionCard(
              icon: Icons.search,
              label: 'Web search',
              onTap: _performWebSearch,
            ),
            const SizedBox(width: 12),
            _buildOptionCard(
              icon: Icons.add,
              label: 'Empty show',
              onTap: () => _finish('empty'),
            ),
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: AppPalette.carbonBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New show',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Name',
                filled: true,
                fillColor: Colors.black26,
                border: InputBorder.none,
                suffixIcon: _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _nameController.clear();
                          setState(() {
                            _isSearching = false;
                            _searchResults = null;
                            _sourceFilter = null;
                          });
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.black26,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  hint: const Text(
                    'Category',
                    style: TextStyle(color: Colors.white54),
                  ),
                  dropdownColor: AppPalette.carbonBlack,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'No Category',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    ...widget.availableCategories.map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
              ),
            ),
            const SizedBox(height: 24),
            content,
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
