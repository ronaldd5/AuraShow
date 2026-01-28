import 'package:flutter/material.dart';
import '../../../models/song_model.dart';
import '../../../services/lyrics_service.dart';
import '../../../services/bible_service.dart';
import '../../../services/label_color_service.dart';

import '../../../models/slide_model.dart';
import 'song_editor_dialog.dart';
import '../../../core/theme/palette.dart';

class LeftLibraryPanel extends StatefulWidget {
  final Function(Song) onSongSelected;
  final Function(BibleVerse) onVerseSelected;
  final double bottomPadding;

  const LeftLibraryPanel({
    super.key,
    required this.onSongSelected,
    required this.onVerseSelected,
    this.bottomPadding = 0,
  });

  @override
  State<LeftLibraryPanel> createState() => _LeftLibraryPanelState();
}

class _LeftLibraryPanelState extends State<LeftLibraryPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    LyricsService.instance.initialize();
    LabelColorService.instance.load(); // Load group colors
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: AppPalette.surface,
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
              style: const TextStyle(color: AppPalette.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search Library...',
                hintStyle: const TextStyle(color: AppPalette.textMuted),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppPalette.textSecondary,
                ),
                filled: true,
                fillColor: AppPalette.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppPalette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppPalette.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: AppPalette.primary,
            labelColor: AppPalette.textPrimary,
            unselectedLabelColor: AppPalette.textSecondary,
            dividerColor: AppPalette.border,
            tabs: const [
              Tab(text: 'Songs'),
              Tab(text: 'Bible'),
              Tab(text: 'Media'),
            ],
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSongsTab(),
                _buildBibleTab(),
                _buildMediaTab(), // Placeholder for existing media or future work
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBibleTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bible Verses (Mock)',
                style: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<BibleVerse>>(
            future: BibleService.instance.search(_searchQuery),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No verses found',
                    style: TextStyle(color: AppPalette.textMuted),
                  ),
                );
              }

              final verses = snapshot.data!;
              return ListView.builder(
                padding: EdgeInsets.only(bottom: widget.bottomPadding + 20),
                itemCount: verses.length,
                itemBuilder: (context, index) {
                  final verse = verses[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      verse.reference,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      verse.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppPalette.textSecondary),
                    ),
                    onTap: () => widget.onVerseSelected(verse),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Songs',
                style: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add,
                  size: 20,
                  color: AppPalette.primary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _editSong(null),
                tooltip: 'Add Song',
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Song>>(
            stream: LyricsService.instance.songsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final songs = snapshot.data!;
              final filtered = _searchQuery.isEmpty
                  ? songs
                  : LyricsService.instance.search(_searchQuery);

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'No songs yet' : 'No matches',
                    style: const TextStyle(color: AppPalette.textMuted),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.only(bottom: widget.bottomPadding + 20),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final song = filtered[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      song.title,
                      style: const TextStyle(color: AppPalette.textPrimary),
                    ),
                    subtitle: song.author.isNotEmpty
                        ? Text(
                            song.author,
                            style: const TextStyle(
                              color: AppPalette.textSecondary,
                            ),
                          )
                        : null,
                    onTap: () => widget.onSongSelected(song),
                    // Right click / Long press menu
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        size: 16,
                        color: AppPalette.textSecondary,
                      ),
                      color: AppPalette.surfaceHighlight,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text(
                            'Edit',
                            style: TextStyle(color: AppPalette.textPrimary),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: AppPalette.dustyMauve),
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editSong(song);
                        } else if (value == 'delete') {
                          _confirmDelete(song);
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMediaTab() {
    return const Center(
      child: Text(
        'Media Library\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppPalette.textMuted),
      ),
    );
  }

  Future<void> _editSong(Song? song) async {
    final result = await showDialog<Song>(
      context: context,
      builder: (context) => SongEditorDialog(song: song),
    );

    if (result != null) {
      await LyricsService.instance.saveSong(result);
    }
  }

  Future<void> _confirmDelete(Song song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppPalette.border),
        ),
        title: const Text(
          'Delete Song',
          style: TextStyle(color: AppPalette.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${song.title}"?',
          style: const TextStyle(color: AppPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppPalette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppPalette.dustyMauve),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LyricsService.instance.deleteSong(song.id);
    }
  }
}
