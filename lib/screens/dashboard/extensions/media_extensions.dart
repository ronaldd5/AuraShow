part of '../dashboard_screen.dart';

/// Extension for online media search and handling (YouTube, Pixabay, Unsplash, Vimeo)
extension MediaSearchExtensions on DashboardScreenState {
  Future<void> _submitOnlineSearch(OnlineSource source) async {
    final controller = _onlineSearchControllers[source]!;
    final query = controller.text.trim();
    if (query.length < 2) {
      setState(() => _onlineSearchResults.clear());
      return;
    }

    setState(() {
      _mediaFilter = MediaFilter.online;
      _onlineSourceFilter = source;
    });

    try {
      List<MediaEntry> results = [];
      switch (source) {
        case OnlineSource.youtube:
          results = await _searchYouTubeOnline(query, musicOnly: false);
          break;
        case OnlineSource.youtubeMusic:
          results = await _searchYouTubeOnline(query, musicOnly: true);
          break;
        case OnlineSource.pixabay:
          results = await _searchPixabay(query);
          break;
        case OnlineSource.unsplash:
          results = await _searchUnsplash(query);
          break;
        case OnlineSource.vimeo:
          results = await _searchVimeo(query);
          break;
        case OnlineSource.all:
          results = [];
          break;
        default:
          results = [];
          break;
      }

      setState(() {
        _onlineSearchResults
          ..clear()
          ..addAll(results);
        if (source == OnlineSource.youtube) {
          youtubeResults = List.from(
            results.map(
              (e) => {
                'id': e.id,
                'title': e.title,
                'thumb': e.thumbnailUrl ?? '',
              },
            ),
          );
        } else if (source == OnlineSource.pixabay) {
          pixabayResults = List.from(
            results.map(
              (e) => {
                'id': e.id,
                'title': e.title,
                'thumb': e.thumbnailUrl ?? '',
              },
            ),
          );
        } else if (source == OnlineSource.unsplash) {
          unsplashResults = List.from(
            results.map(
              (e) => {
                'id': e.id,
                'title': e.title,
                'thumb': e.thumbnailUrl ?? '',
              },
            ),
          );
        }
      });
    } catch (e) {
      _showSnack('Search error: $e');
    }
  }

  Future<List<MediaEntry>> _searchYouTubeOnline(
    String query, {
    required bool musicOnly,
  }) async {
    final color = musicOnly ? Colors.deepOrangeAccent : Colors.redAccent;
    final icon = musicOnly ? Icons.music_note : Icons.smart_display;
    final source = musicOnly ? OnlineSource.youtubeMusic : OnlineSource.youtube;
    if (youtubeApiKey == null || youtubeApiKey!.isEmpty) {
      _showSnack('YouTube key missing; set YOUTUBE_API_KEY in .env');
      return [];
    }

    final params = {
      'part': 'snippet',
      'type': 'video',
      'maxResults': '12',
      'q': query,
      'key': youtubeApiKey!,
    };
    if (musicOnly) {
      params['videoCategoryId'] = '10'; // Music category
    }

    final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', params);
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      _showSnack('YouTube search failed (${resp.statusCode})');
      return [];
    }

    final body = json.decode(resp.body);
    final items = (body['items'] as List?) ?? [];

    return items.map<MediaEntry>((item) {
      final id = item['id']?['videoId'] ?? '';
      final snippet = item['snippet'] ?? {};
      final title = snippet['title'] ?? 'Untitled';
      final channel = snippet['channelTitle'] ?? 'YouTube';
      final thumb =
          snippet['thumbnails']?['medium']?['url'] ??
          snippet['thumbnails']?['high']?['url'] ??
          snippet['thumbnails']?['default']?['url'] ??
          '';
      return MediaEntry(
        id: id.isNotEmpty ? id : 'yt-$query-${items.indexOf(item)}',
        title: title,
        subtitle: channel,
        category: MediaFilter.online,
        icon: icon,
        tint: color,
        isLive: false,
        badge: 'Online',
        onlineSource: source,
        thumbnailUrl: thumb,
      );
    }).toList();
  }

  Future<List<MediaEntry>> _searchPixabay(String query) async {
    setState(() => searchingPixabay = true);
    try {
      final results = await ImageService.instance.searchPixabay(query);
      return results.map<MediaEntry>((item) {
        return MediaEntry(
          id: item['id'],
          title: item['title'],
          subtitle: 'by ${item['author'] ?? 'Unknown'}',
          category: MediaFilter.online,
          icon: Icons.image_outlined,
          tint: AppPalette.teaGreen,
          isLive: false,
          badge: 'Pixabay',
          onlineSource: OnlineSource.pixabay,
          thumbnailUrl: item['thumb'],
        );
      }).toList();
    } catch (e) {
      _showSnack('Pixabay search failed: $e');
      return [];
    } finally {
      setState(() => searchingPixabay = false);
    }
  }

  Future<List<MediaEntry>> _searchUnsplash(String query) async {
    setState(() => searchingUnsplash = true);
    try {
      final results = await ImageService.instance.searchUnsplash(query);
      return results.map<MediaEntry>((item) {
        return MediaEntry(
          id: item['id'],
          title: item['title'],
          subtitle: 'by ${item['author'] ?? 'Unknown'}',
          category: MediaFilter.online,
          icon: Icons.image_outlined,
          tint: AppPalette.willowGreen,
          isLive: false,
          badge: 'Unsplash',
          onlineSource: OnlineSource.unsplash,
          thumbnailUrl: item['thumb'],
        );
      }).toList();
    } catch (e) {
      _showSnack('Unsplash search failed: $e');
      return [];
    } finally {
      setState(() => searchingUnsplash = false);
    }
  }

  Future<List<MediaEntry>> _searchVimeo(String query) async {
    const color = Colors.lightBlueAccent;
    const icon = Icons.video_library;
    if (vimeoAccessToken == null || vimeoAccessToken!.isEmpty) {
      _showSnack('Vimeo token missing; set VIMEO_ACCESS_TOKEN in .env');
      return [];
    }

    final uri = Uri.https('api.vimeo.com', '/videos', {
      'query': query,
      'per_page': '12',
    });
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'bearer $vimeoAccessToken'},
    );
    if (resp.statusCode != 200) {
      _showSnack('Vimeo search failed (${resp.statusCode})');
      return [];
    }

    final body = json.decode(resp.body);
    final data = (body['data'] as List?) ?? [];
    return data.map<MediaEntry>((item) {
      final name = item['name'] ?? 'Untitled';
      final user = item['user']?['name'] ?? 'Vimeo';
      final uriStr = item['uri'] ?? '';
      final id = uriStr.split('/').isNotEmpty
          ? uriStr.split('/').last
          : 'vimeo-$query';
      final pics = item['pictures']?['sizes'] as List?;
      final thumb = (pics != null && pics.isNotEmpty)
          ? (pics.last['link'] ?? pics.first['link'] ?? '')
          : '';
      return MediaEntry(
        id: id,
        title: name,
        subtitle: user,
        category: MediaFilter.online,
        icon: icon,
        tint: color,
        isLive: false,
        badge: 'Online',
        onlineSource: OnlineSource.vimeo,
        thumbnailUrl: thumb,
      );
    }).toList();
  }

  void _clearOnlineSearch() {
    setState(() {
      _onlineSearchExpanded = false;
      _onlineSearchResults.clear();
      pixabayResults.clear();
      unsplashResults.clear();
      youtubeResults.clear();
    });
    for (final c in _onlineSearchControllers.values) {
      c.clear();
    }
  }

  void _addMediaFromOnline(MediaEntry entry) async {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;

    if (entry.thumbnailUrl == null) {
      _showSnack('Cannot add media without a URL');
      return;
    }

    final slide = _slides[selectedSlideIndex];
    final idx = slide.layers.length;
    final double baseLeft = 0.15;
    final double baseTop = 0.15;
    final double baseWidth = 0.6;
    final double baseHeight = 0.6;
    final double offset = 0.04 * (idx % 4);
    final left = (baseLeft + offset).clamp(
      -DashboardScreenState._overflowAllowance,
      1 - baseWidth + DashboardScreenState._overflowAllowance,
    );
    final top = (baseTop + offset).clamp(
      -DashboardScreenState._overflowAllowance,
      1 - baseHeight + DashboardScreenState._overflowAllowance,
    );

    SlideMediaType mediaType;
    if (entry.onlineSource == OnlineSource.youtube ||
        entry.onlineSource == OnlineSource.vimeo ||
        entry.onlineSource == OnlineSource.youtubeMusic) {
      mediaType = SlideMediaType.video;
    } else {
      mediaType = SlideMediaType.image;
    }

    final layer = SlideLayer(
      id: 'layer-${DateTime.now().microsecondsSinceEpoch}',
      label: entry.title,
      kind: LayerKind.media,
      role: LayerRole.foreground,
      path: entry.thumbnailUrl,
      mediaType: mediaType,
      left: left,
      top: top,
      width: baseWidth,
      height: baseHeight,
    );

    setState(() {
      final updated = [...slide.layers, layer];
      _slides[selectedSlideIndex] = slide.copyWith(layers: updated);
    });
    _showSnack('Added ${entry.title} to slide');
  }

  Future<void> _saveOnlineSearchResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'youtube_saved',
      savedYouTubeVideos.map((e) => json.encode(e)).toList(),
    );
    await prefs.setStringList(
      'pixabay_saved',
      pixabayResults.map((e) => json.encode(e)).toList(),
    );
    await prefs.setStringList(
      'unsplash_saved',
      unsplashResults.map((e) => json.encode(e)).toList(),
    );
  }

  // UI for adding YouTube
  void _addYouTubeLink() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgMedium,
        title: const Text("Add YouTube Video"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Paste YouTube URL here"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              final id = YoutubePlayerController.convertUrlToId(url);
              if (id != null) {
                _addYouTubeVideo(id, 'Manual add');
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _searchYouTube() async {
    final query = _youtubeQuery.text.trim();
    if (query.isEmpty) return;
    if (youtubeApiKey == null || youtubeApiKey!.isEmpty) {
      _showSnack('Set a YouTube API key in Settings first');
      return;
    }

    setState(() => searchingYouTube = true);
    try {
      final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', {
        'part': 'snippet',
        'type': 'video',
        'maxResults': '8',
        'q': query,
        'key': youtubeApiKey!,
      });
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final items = (body['items'] as List?) ?? [];
        setState(() {
          youtubeResults = items
              .map<Map<String, String>>((item) {
                final id = item['id']?['videoId'] ?? '';
                final snippet = item['snippet'] ?? {};
                return {
                  'id': id,
                  'title': snippet['title'] ?? 'Untitled',
                  'thumb': snippet['thumbnails']?['default']?['url'] ?? '',
                };
              })
              .where((m) => (m['id'] ?? '').isNotEmpty)
              .toList();
        });
      } else {
        _showSnack('YouTube search failed (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('YouTube search error: $e');
    } finally {
      if (mounted) setState(() => searchingYouTube = false);
    }
  }

  void _addYouTubeVideo(String id, String title) {
    if (_slides.isEmpty || selectedSlideIndex < 0) return;
    _addMediaFromOnline(
      MediaEntry(
        id: id,
        title: title,
        subtitle: 'YouTube',
        category: MediaFilter.online,
        icon: Icons.video_library,
        tint: Colors.red,
        isLive: false,
        badge: 'YT',
        onlineSource: OnlineSource.youtube,
        thumbnailUrl: 'https://img.youtube.com/vi/$id/0.jpg',
      ),
    );
  }

  InputDecoration _denseLabel(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      isDense: true,
    );
  }

  Future<void> _showMediaPickerSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: bgMedium,
      builder: (ctx) => Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Add Media',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _mediaOption(Icons.image, 'Image', Colors.blue, () {
                  Navigator.pop(ctx);
                  _pickImages();
                }),
                _mediaOption(Icons.videocam, 'Video', Colors.red, () {
                  Navigator.pop(ctx);
                  _pickVideos();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) {
          _addMediaLayer(file.path!, SlideMediaType.image);
        }
      }
    }
  }

  Future<void> _pickVideos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) {
          _addMediaLayer(file.path!, SlideMediaType.video);
        }
      }
    }
  }

  void _addMediaAsNewSlide(MediaEntry entry) {
    if (_slides.isEmpty) return;

    // Determine Layer definitions based on media category
    LayerKind kind = LayerKind.media;
    SlideMediaType mediaType = SlideMediaType.image;

    if (entry.category == MediaFilter.videos ||
        (entry.category == MediaFilter.online &&
            entry.onlineSource != OnlineSource.all)) {
      mediaType = SlideMediaType.video;
    } else if (entry.category == MediaFilter.audio) {
      mediaType = SlideMediaType.audio;
    }

    if (entry.category == MediaFilter.cameras) {
      kind = LayerKind.camera;
    }

    final newSlide = SlideContent(
      id: const Uuid().v4(),
      templateId: _slides.first.templateId,
      title: entry.title,
      body: '',
      createdAt: DateTime.now(),
      layers: [
        SlideLayer(
          id: const Uuid().v4(),
          kind: kind,
          role: LayerRole.background,
          mediaType: mediaType,
          path: entry.category == MediaFilter.online
              ? entry.id
              : entry.thumbnailUrl,
          label: kind == LayerKind.camera ? 'Camera' : 'Background',

          // Default full screen
          left: 0,
          top: 0,
          width: 1,
          height: 1,
        ),
      ],
    );

    setState(() {
      _slides.add(newSlide);
      selectedSlideIndex = _slides.length - 1;
      selectedSlides = {selectedSlideIndex};
    });
    _saveSlides();
    _showSnack('Added slide: ${entry.title}');
  }
}
