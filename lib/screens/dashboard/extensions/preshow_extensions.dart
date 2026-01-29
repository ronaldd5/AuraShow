part of '../dashboard_screen.dart';

extension PreShowExtensions on DashboardScreenState {
  Widget _buildPreShowLeftPanel() {
    return SizedBox(
      width: _leftPaneWidth,
      child: _frostedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Pre-Show Tools'),
            const SizedBox(height: 12),
            _preShowToolItem(
              icon: Icons.dashboard,
              title: 'Dashboard',
              subtitle: 'Overview & Quick actions',
              selected: _preShowSubTab == 0,
              onTap: () => setState(() => _preShowSubTab = 0),
            ),
            _preShowToolItem(
              icon: Icons.playlist_play,
              title: 'Playlists',
              subtitle: 'Videos & Music loops',
              selected: _preShowSubTab == 1,
              onTap: () => setState(() => _preShowSubTab = 1),
            ),
            _preShowToolItem(
              icon: Icons.timer,
              title: 'Countdowns',
              subtitle: 'Manage event timing',
              selected: _preShowSubTab == 2,
              onTap: () => setState(() => _preShowSubTab = 2),
            ),
            _preShowToolItem(
              icon: Icons.message,
              title: 'Announcements',
              subtitle: 'Crawl text & Notices',
              selected: _preShowSubTab == 3,
              onTap: () => setState(() => _preShowSubTab = 3),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentPink.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pre-Show runs before the main event starts.',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80), // Clear bottom drawer
          ],
        ),
      ),
    );
  }

  Widget _preShowToolItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? accentBlue.withOpacity(0.15)
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accentBlue.withOpacity(0.5) : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? accentBlue.withOpacity(0.3)
                      : accentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : accentBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: selected ? Colors.white54 : Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: selected ? Colors.white24 : Colors.transparent,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreShowWorkspace() {
    switch (_preShowSubTab) {
      case 1:
        return _buildPreShowPlaylistManager();
      default:
        return _buildPreShowDashboard();
    }
  }

  Widget _buildPreShowDashboard() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _workspaceHeader(
            'Pre-Show Dashboard',
            'Configure atmosphere and announcements',
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.5,
              children: [
                _preShowCard(
                  title: 'Active Countdown',
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '00:00:00',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w100,
                            fontFamily: 'monospace',
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Set Target Time'),
                        ),
                      ],
                    ),
                  ),
                ),
                _preShowCard(
                  title: 'Current Loop',
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.music_note,
                          size: 48,
                          color: _preshowPlaylists.isNotEmpty
                              ? accentBlue
                              : Colors.white24,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _preshowPlaylists.isNotEmpty
                              ? 'Playlists available'
                              : 'No playlist active',
                          style: const TextStyle(color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                ),
                _preShowCard(
                  title: 'Live Crawl',
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter scrolling announcement text...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                _preShowCard(
                  title: 'Quick Actions',
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _miniAction('Blackout Screens', Icons.power_settings_new),
                      _miniAction('Clear Announcements', Icons.clear_all),
                      _miniAction('Play Welcome Video', Icons.video_library),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreShowPlaylistManager() {
    if (_selectedPreShowPlaylistId != null) {
      final playlist = _preshowPlaylists.firstWhereOrNull(
        (p) => p.id == _selectedPreShowPlaylistId,
      );
      if (playlist != null) {
        return _buildPreShowPlaylistDetail(playlist);
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _workspaceHeader('Playlists', 'Manage videos and music loops'),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addPreShowPlaylist,
                icon: const Icon(Icons.add),
                label: const Text('Create Playlist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _preshowPlaylists.isEmpty
                ? _emptyState(
                    Icons.playlist_add,
                    'No playlists yet',
                    'Create a playlist to start adding videos and music.',
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: _preshowPlaylists.length,
                    itemBuilder: (context, index) {
                      final playlist = _preshowPlaylists[index];
                      return _playlistCard(playlist);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreShowPlaylistDetail(PreShowPlaylist playlist) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    setState(() => _selectedPreShowPlaylistId = null),
              ),
              const SizedBox(width: 8),
              _workspaceHeader(playlist.name, '${playlist.items.length} items'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _renamePreShowPlaylist(playlist),
                tooltip: 'Rename',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _deletePreShowPlaylist(playlist.id),
                tooltip: 'Delete',
              ),
              const VerticalDivider(width: 24, indent: 8, endIndent: 8),
              _buildViewSwitcher(),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _addItemToPlaylist(playlist.id),
                icon: const Icon(Icons.add),
                label: const Text('Add Media'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: playlist.items.isEmpty
                ? _emptyState(
                    Icons.library_add,
                    'Empty Playlist',
                    'Add videos or music files to this loop.',
                  )
                : _buildPlaylistItemsContent(playlist),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewButton(Icons.list, PlaylistViewType.list),
          _viewButton(Icons.grid_view, PlaylistViewType.grid),
          _viewButton(Icons.view_carousel, PlaylistViewType.carousel),
        ],
      ),
    );
  }

  Widget _viewButton(IconData icon, PlaylistViewType type) {
    final isSelected = _playlistViewType == type;
    return IconButton(
      icon: Icon(icon, size: 18),
      color: isSelected ? accentBlue : Colors.white38,
      onPressed: () => setState(() => _playlistViewType = type),
      tooltip: type.name.toUpperCase(),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildPlaylistItemsContent(PreShowPlaylist playlist) {
    switch (_playlistViewType) {
      case PlaylistViewType.grid:
        return _buildPlaylistGridView(playlist);
      case PlaylistViewType.carousel:
        return _buildPlaylistCarouselView(playlist);
      case PlaylistViewType.list:
      default:
        return _buildPlaylistListView(playlist);
    }
  }

  Widget _buildPlaylistListView(PreShowPlaylist playlist) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: true,
      itemCount: playlist.items.length,
      onReorder: (oldIndex, newIndex) =>
          _reorderPlaylistItem(playlist.id, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final item = playlist.items[index];
        return _playlistItemTile(item, index, playlist.id);
      },
    );
  }

  Widget _buildPlaylistGridView(PreShowPlaylist playlist) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: playlist.items.length,
      itemBuilder: (context, index) {
        final item = playlist.items[index];
        return _playlistGridItem(item, index, playlist.id);
      },
    );
  }

  Widget _buildPlaylistCarouselView(PreShowPlaylist playlist) {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.8),
            itemCount: playlist.items.length,
            itemBuilder: (context, index) {
              final item = playlist.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _playlistCarouselItem(item),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Divider(color: Colors.white10),
        const SizedBox(height: 12),
        Expanded(child: _buildPlaylistListView(playlist)),
      ],
    );
  }

  Widget _playlistGridItem(
    PreShowPlaylistItem item,
    int index,
    String playlistId,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Column(
          children: [
            Expanded(child: _buildItemThumbnail(item, isGrid: true)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        _removeItemFromPlaylist(playlistId, item.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playlistCarouselItem(PreShowPlaylistItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentBlue.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildItemThumbnail(item),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.type.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: accentBlue,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemThumbnail(PreShowPlaylistItem item, {bool isGrid = false}) {
    if (item.type == PlaylistItemType.video) {
      return _VideoThumbnailGenerator(
        videoPath: item.path,
        fallbackBg: Colors.black26,
        dashboardState: this,
        overlay: Center(
          child: Icon(
            Icons.play_circle_fill,
            color: Colors.white.withOpacity(0.5),
            size: isGrid ? 32 : 48,
          ),
        ),
      );
    } else {
      return Container(
        color: accentBlue.withOpacity(0.1),
        child: Center(
          child: Icon(
            Icons.music_note,
            color: accentBlue.withOpacity(0.5),
            size: isGrid ? 32 : 48,
          ),
        ),
      );
    }
  }

  Widget _playlistCard(PreShowPlaylist playlist) {
    return InkWell(
      onTap: () => setState(() => _selectedPreShowPlaylistId = playlist.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.carbonBlack.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: IconButton(
                      icon: Icon(
                        playlist.id == _activePreShowPlaylistId &&
                                _isPreShowPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        size: 64,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      onPressed: () {
                        if (playlist.id == _activePreShowPlaylistId &&
                            _isPreShowPlaying) {
                          _stopPreShow();
                        } else {
                          _playPreShowPlaylist(playlist, 0);
                        }
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${playlist.items.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Text(
                playlist.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playlistItemTile(
    PreShowPlaylistItem item,
    int index,
    String playlistId,
  ) {
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: item.type == PlaylistItemType.video
                ? Colors.redAccent.withOpacity(0.1)
                : Colors.blueAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            item.type == PlaylistItemType.video
                ? Icons.play_circle
                : Icons.music_note,
            color: item.type == PlaylistItemType.video
                ? Colors.redAccent
                : Colors.blueAccent,
            size: 20,
          ),
        ),
        title: Text(item.title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          path.basename(item.path),
          style: const TextStyle(fontSize: 11, color: Colors.white38),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_activePreShowPlaylistId == playlistId &&
                _currentPreShowIndex == index &&
                _isPreShowPlaying)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.equalizer, color: accentBlue, size: 18),
              ),
            IconButton(
              icon: Icon(
                _activePreShowPlaylistId == playlistId &&
                        _currentPreShowIndex == index &&
                        _isPreShowPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                size: 20,
                color: Colors.white70,
              ),
              onPressed: () {
                if (_activePreShowPlaylistId == playlistId &&
                    _currentPreShowIndex == index &&
                    _isPreShowPlaying) {
                  _stopPreShow();
                } else {
                  // Find playlist again to be safe
                  final playlist = _preshowPlaylists.firstWhereOrNull(
                    (p) => p.id == playlistId,
                  );
                  if (playlist != null) {
                    _playPreShowPlaylist(playlist, index);
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _removeItemFromPlaylist(playlistId, item.id),
            ),
            const Icon(Icons.drag_handle, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  // --- Logic ---

  void _addPreShowPlaylist() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.carbonBlack,
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Playlist Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _preshowPlaylists.add(PreShowPlaylist.create(name: name));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _renamePreShowPlaylist(PreShowPlaylist playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.carbonBlack,
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  final idx = _preshowPlaylists.indexWhere(
                    (p) => p.id == playlist.id,
                  );
                  if (idx != -1) {
                    _preshowPlaylists[idx] = _preshowPlaylists[idx].copyWith(
                      name: name,
                    );
                  }
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _deletePreShowPlaylist(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.carbonBlack,
        title: const Text('Delete Playlist'),
        content: const Text('Are you sure you want to delete this playlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _preshowPlaylists.removeWhere((p) => p.id == id);
                if (_selectedPreShowPlaylistId == id) {
                  _selectedPreShowPlaylistId = null;
                }
              });
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addItemToPlaylist(String playlistId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'mp3', 'wav', 'm4a'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        final idx = _preshowPlaylists.indexWhere((p) => p.id == playlistId);
        if (idx != -1) {
          final newItems = List<PreShowPlaylistItem>.from(
            _preshowPlaylists[idx].items,
          );
          for (final file in result.files) {
            if (file.path == null) continue;
            final isVideo = [
              'mp4',
              'mov',
            ].contains(file.extension?.toLowerCase());
            newItems.add(
              PreShowPlaylistItem.create(
                title: file.name,
                path: file.path!,
                type: isVideo ? PlaylistItemType.video : PlaylistItemType.audio,
              ),
            );
          }
          _preshowPlaylists[idx] = _preshowPlaylists[idx].copyWith(
            items: newItems,
          );
        }
      });
    }
  }

  void _removeItemFromPlaylist(String playlistId, String itemId) {
    setState(() {
      final idx = _preshowPlaylists.indexWhere((p) => p.id == playlistId);
      if (idx != -1) {
        final newItems = _preshowPlaylists[idx].items
            .where((i) => i.id != itemId)
            .toList();
        _preshowPlaylists[idx] = _preshowPlaylists[idx].copyWith(
          items: newItems,
        );
      }
    });
  }

  void _reorderPlaylistItem(String playlistId, int oldIndex, int newIndex) {
    setState(() {
      final idx = _preshowPlaylists.indexWhere((p) => p.id == playlistId);
      if (idx != -1) {
        final items = List<PreShowPlaylistItem>.from(
          _preshowPlaylists[idx].items,
        );
        if (newIndex > oldIndex) newIndex -= 1;
        final item = items.removeAt(oldIndex);
        items.insert(newIndex, item);
        _preshowPlaylists[idx] = _preshowPlaylists[idx].copyWith(items: items);
      }
    });
  }

  // --- Helper Widgets ---

  Widget _workspaceHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
        ),
      ],
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _preShowCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _miniAction(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 16, color: accentBlue),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Playback Logic ---

  Future<void> _playPreShowPlaylist(PreShowPlaylist playlist, int index) async {
    // Stop current without clearing state fully yet
    await _stopPreShow(clearState: false);

    if (index < 0 || index >= playlist.items.length) {
      _stopPreShow();
      return;
    }

    setState(() {
      _activePreShowPlaylistId = playlist.id;
      _currentPreShowIndex = index;
      _isPreShowPlaying = true;
    });

    final item = playlist.items[index];

    try {
      if (item.type == PlaylistItemType.audio) {
        if (_audioPlayer == null) {
          _audioPlayer = ja.AudioPlayer();
        }
        await _audioPlayer!.setFilePath(item.path);
        await _audioPlayer!.play();

        // Listen for completion
        _audioPlayerStateSubscription?.cancel();
        _audioPlayerStateSubscription = _audioPlayer!.playerStateStream.listen((
          state,
        ) {
          if (state.processingState == ja.ProcessingState.completed) {
            _nextPreShowItem();
          }
        });
      } else {
        // Video
        // Dispose old controller if exists
        _preShowVideoController?.dispose();

        _preShowVideoController = VideoPlayerController.file(File(item.path));
        await _preShowVideoController!.initialize();
        await _preShowVideoController!.play();

        // Force outputs to update (will pick up new video path via _getCurrentSlideVideoPath)
        _sendCurrentSlideToOutputs();

        // Listen for completion
        _preShowVideoController!.addListener(_preShowVideoListener);
      }
    } catch (e) {
      debugPrint('PreShow Playback Error: $e');
      _showSnack('Failed to play ${item.title}');
      _nextPreShowItem();
    }

    // Refresh UI
    if (mounted) setState(() {});
  }

  void _preShowVideoListener() {
    if (_preShowVideoController != null &&
        _preShowVideoController!.value.isInitialized &&
        (_preShowVideoController!.value.position >=
            _preShowVideoController!.value.duration)) {
      _preShowVideoController!.removeListener(_preShowVideoListener);
      _nextPreShowItem();
    }
  }

  Future<void> _stopPreShow({bool clearState = true}) async {
    // Stop Audio
    _audioPlayerStateSubscription?.cancel();
    if (_audioPlayer != null && _audioPlayer!.playing) {
      await _audioPlayer!.stop();
    }

    // Stop Video
    if (_preShowVideoController != null) {
      _preShowVideoController!.removeListener(_preShowVideoListener);
      await _preShowVideoController!.pause();
    }

    if (clearState) {
      _preShowVideoController?.dispose();
      _preShowVideoController = null;
      setState(() {
        _activePreShowPlaylistId = null;
        _currentPreShowIndex = -1;
        _isPreShowPlaying = false;
      });
      // Clear outputs (remove video layer)
      _sendCurrentSlideToOutputs();
    }
  }

  void _nextPreShowItem() {
    if (_activePreShowPlaylistId == null) return;

    final playlist = _preshowPlaylists.firstWhereOrNull(
      (p) => p.id == _activePreShowPlaylistId,
    );
    if (playlist == null) {
      _stopPreShow();
      return;
    }

    int nextIndex = _currentPreShowIndex + 1;
    if (nextIndex >= playlist.items.length) {
      if (playlist.isLooping) {
        nextIndex = 0;
      } else {
        _stopPreShow();
        return;
      }
    }

    _playPreShowPlaylist(playlist, nextIndex);
  }
}
