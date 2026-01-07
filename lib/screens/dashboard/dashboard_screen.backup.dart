import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:ui' show PointerDeviceKind, ImageFilter;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' as math;
import '../../core/theme/palette.dart';

class ShowItem {
  ShowItem({required this.name, this.category});
  String name;
  String? category;
}

enum MediaFilter { all, online, screens, cameras }

enum OnlineSource { all, vimeo, youtube, youtubeMusic }

enum _SlideMediaType { image, video }

class _LiveDevice {
  _LiveDevice({required this.id, required this.name, required this.detail});
  final String id;
  final String name;
  final String detail;
}

class _MediaEntry {
  _MediaEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.tint,
    this.isLive = false,
    this.badge,
    this.onlineSource,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final MediaFilter category;
  final IconData icon;
  final Color tint;
  final bool isLive;
  final String? badge;
  final OnlineSource? onlineSource;
  final String? thumbnailUrl;
}

enum _LayerRole { background, foreground }

enum _LayerKind {
  media,
  textbox,
  camera,
  website,
  timer,
  clock,
  progress,
  events,
  weather,
  visualizer,
  captions,
  icon,
}

class _SlideLayer {
  _SlideLayer({
    required this.id,
    required this.label,
    required this.kind,
    required this.role,
    this.path,
    this.mediaType,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  final String id;
  final String label;
  final _LayerKind kind;
  final String? path;
  final _SlideMediaType? mediaType;
  final _LayerRole role;
  final DateTime addedAt;

  _SlideLayer copyWith({
    String? id,
    String? label,
    _LayerKind? kind,
    _LayerRole? role,
    String? path,
    _SlideMediaType? mediaType,
    DateTime? addedAt,
  }) {
    return _SlideLayer(
      id: id ?? this.id,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      role: role ?? this.role,
      path: path ?? this.path,
      mediaType: mediaType ?? this.mediaType,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'kind': kind.name,
        'role': role.name,
        'path': path,
        'mediaType': mediaType?.name,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };

  factory _SlideLayer.fromJson(Map<String, dynamic> json) {
    return _SlideLayer(
      id: json['id'] ?? 'layer-${DateTime.now().millisecondsSinceEpoch}',
      label: json['label'] ?? 'Layer',
      kind: _LayerKind.values.firstWhere(
        (e) => e.name == (json['kind'] ?? 'media'),
        orElse: () => _LayerKind.media,
      ),
      role: _LayerRole.values.firstWhere(
        (e) => e.name == (json['role'] ?? 'background'),
        orElse: () => _LayerRole.background,
      ),
      path: json['path'] as String?,
      mediaType: json['mediaType'] != null
          ? _SlideMediaType.values.firstWhere(
              (e) => e.name == json['mediaType'],
              orElse: () => _SlideMediaType.image,
            )
          : null,
      addedAt: json['addedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['addedAt'] as num).toInt())
          : DateTime.now(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  // State and data
  bool searchingYouTube = false;

  // Bottom drawer state
  bool drawerExpanded = false;
  final double _drawerTabHeight = 44;
  final double _drawerDefaultHeight = 280;
  // Give a couple extra pixels over the tab height to avoid fractional rounding overflow.
  final double _drawerMinHeight = 48;
  final double _drawerMaxHeight = 520;
  double _drawerHeight = 280;

  // Navigation state
  int selectedTopTab = 0; // 0=Show,1=Edit,2=Stage

  // Theme Colors (legacy backup aligned to current palette)
  final Color bgDark = AppPalette.carbonBlack;
  final Color bgMedium = AppPalette.carbonBlack;
  final Color accentBlue = AppPalette.willowGreen; // slate accent
  final Color accentPink = AppPalette.dustyMauve; // rust accent

  // Media and settings
  String? videoFolder;
  String? songFolder;
  String? lyricsFolder;
  List<FileSystemEntity> discoveredVideos = [];
  List<FileSystemEntity> discoveredSongs = [];
  List<FileSystemEntity> discoveredLyrics = [];
  String? youtubeApiKey;
  String? vimeoAccessToken;
  List<Map<String, String>> youtubeResults = [];
  List<Map<String, String>> savedYouTubeVideos = [];
  final TextEditingController _youtubeQuery = TextEditingController();
  final TextEditingController _slideTitleController = TextEditingController();
  final TextEditingController _slideBodyController = TextEditingController();
  final TextEditingController _lyricsImportController = TextEditingController();

  // FreeShow-like scaffolding data (placeholder)
  List<ShowItem> shows = [];
  List<String> showCategories = [];
  List<String> playlists = [];
  final GlobalKey _newProjectButtonKey = GlobalKey();

  // Slide + template model
  final List<_SlideTemplate> _templates = [
    _SlideTemplate(
      id: 'default',
      name: 'Default',
      textColor: Colors.white,
      background: const Color(0xFF0F172A),
      overlayAccent: AppPalette.dustyMauve,
      fontSize: 38,
      alignment: TextAlign.center,
    ),
    _SlideTemplate(
      id: 'notes',
      name: 'Notes',
      textColor: Colors.white,
      background: const Color(0xFF111827),
      overlayAccent: Colors.tealAccent.shade200,
      fontSize: 20,
      alignment: TextAlign.left,
    ),
  ];

  List<_SlideContent> _slides = [
    _SlideContent(id: 's1', title: 'Verse 1', body: 'Line 1\nLine 2', templateId: 'default'),
    _SlideContent(id: 's2', title: 'Chorus', body: 'Chorus line', templateId: 'default'),
    _SlideContent(id: 's3', title: 'Verse 2', body: 'Verse 2 lines', templateId: 'default'),
    _SlideContent(id: 's4', title: 'Bridge', body: 'Bridge lines', templateId: 'default'),
    _SlideContent(id: 's5', title: 'Tag', body: 'Tag line', templateId: 'default'),
    _SlideContent(id: 's6', title: 'Outro', body: 'Outro', templateId: 'default'),
  ];
  List<String?> _slideThumbnails = [null, null, null, null, null, null];

  final List<Map<String, dynamic>> sources = [
    {'icon': Icons.computer, 'label': 'Computer Files'},
    {'icon': Icons.cloud_download, 'label': 'Downloads'},
    {'icon': Icons.smart_display, 'label': 'YouTube'},
  ];

  int? selectedShowIndex;
  int? selectedCategoryIndex; // null means All
  int? selectedPlaylist;
  int? selectedSourceIndex = 0;
  int selectedSlideIndex = 0;
  bool isPlaying = false;
  bool autoAdvanceEnabled = false;
  Duration autoAdvanceInterval = const Duration(seconds: 8);
  Timer? _autoAdvanceTimer;
  bool isLocked = false;
  bool isBroadcastOn = false;

  final FocusNode _slidesFocusNode = FocusNode();
  final GlobalKey _slidesStackKey = GlobalKey();
  final ScrollController _slidesScrollController = ScrollController();
  final List<GlobalKey> _slideKeys = [];
  final Map<int, Rect> _slideRects = {};
  MediaFilter _mediaFilter = MediaFilter.all;
  OnlineSource _onlineSourceFilter = OnlineSource.all;
  final Map<OnlineSource, TextEditingController> _onlineSearchControllers = {
    OnlineSource.all: TextEditingController(),
    OnlineSource.vimeo: TextEditingController(),
    OnlineSource.youtube: TextEditingController(),
    OnlineSource.youtubeMusic: TextEditingController(),
  };
  final List<_MediaEntry> _onlineSearchResults = [];
  bool _onlineSearchExpanded = false;
  final List<_LiveDevice> _connectedScreens = [];
  final List<_LiveDevice> _connectedCameras = [];
  String? _hoveredMediaId;
  String? _previewingMediaId;
  Timer? _previewTimer;
  Set<int> selectedSlides = {};
  bool _dragSelecting = false;
  Offset? _dragStart;
  Offset? _dragCurrent;
  int? _draggingIndex;
  Rect? _boxDragStartRect;
  Offset? _boxDragStartPointer;
  bool _boxResizing = false;
  final Set<String> _hydratedLayerSlides = {};

  double _safeClamp(double value, double min, double max) {
    if (!min.isFinite || !max.isFinite) {
      // If bounds are not finite, just guard on the finite one.
      if (min.isFinite && value < min) return min;
      if (max.isFinite && value > max) return max;
      return value;
    }
    if (max < min) {
      // Fallback: collapse invalid ranges to the lower bound.
      return min;
    }
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  String _fileName(String path) {
    if (path.isEmpty) return path;
    final parts = path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : path;
  }

  Widget _textboxTab(_SlideContent slide, _SlideTemplate template) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _slideTitleController,
            onChanged: (v) {
              setState(() {
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(title: v);
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _slideBodyController,
            maxLines: 6,
            minLines: 4,
            onChanged: (v) {
              setState(() {
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(body: v);
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Body'),
          ),
          const SizedBox(height: 8),
          Text('Font Size: ${(slide.fontSizeOverride ?? template.fontSize).round()}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Slider(
            min: 18,
            max: 72,
            divisions: 54,
            activeColor: accentPink,
            value: (slide.fontSizeOverride ?? template.fontSize).clamp(18, 72).toDouble(),
            onChanged: (v) {
              setState(() {
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(fontSizeOverride: v);
              });
            },
          ),
          const SizedBox(height: 6),
          Text('Align', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          ToggleButtons(
            isSelected: [
              (slide.alignOverride ?? template.alignment) == TextAlign.left,
              (slide.alignOverride ?? template.alignment) == TextAlign.center,
              (slide.alignOverride ?? template.alignment) == TextAlign.right,
            ],
            onPressed: (idx) {
              final align = idx == 0
                  ? TextAlign.left
                  : idx == 1
                      ? TextAlign.center
                      : TextAlign.right;
              setState(() {
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(alignOverride: align);
              });
            },
            color: Colors.white70,
            selectedColor: Colors.white,
            fillColor: accentPink.withOpacity(0.2),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.format_align_left, size: 16)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.format_align_center, size: 16)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.format_align_right, size: 16)),
            ],
          ),
          const SizedBox(height: 10),
          _sectionHeader('Quick Lyrics'),
          const SizedBox(height: 6),
          TextField(
            controller: _lyricsImportController,
            maxLines: 5,
            minLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Paste lyrics here...'),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _importLyrics(_lyricsImportController.text),
                child: const Text('Split on blanks'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _importLyrics(_lyricsImportController.text, linesPerSlide: 4),
                child: const Text('Split every 4 lines'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemTab(_SlideContent slide, _SlideTemplate template) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Media'),
          _mediaAttachmentCard(slide),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: slide.autoSize ?? false,
                onChanged: (v) {
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(autoSize: v ?? false);
                  });
                },
                activeColor: accentPink,
              ),
              const Text('Auto-size text to box', style: TextStyle(color: Colors.white70)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _updateSlideBox(_slides[selectedSlideIndex], left: 0.1, top: 0.18, width: 0.8, height: 0.64);
                },
                child: const Text('Reset box', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Text color', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final c in [Colors.white, Colors.amberAccent, Colors.cyanAccent, Colors.pinkAccent, Colors.limeAccent, Colors.redAccent])
                _colorDot(
                  c,
                  selected: (slide.textColorOverride ?? template.textColor).value == c.value,
                  onTap: () {
                    setState(() {
                      _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(textColorOverride: c);
                    });
                  },
                ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(textColorOverride: null);
                  });
                },
                child: const Text('Use template', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: TextEditingController(text: slide.overlayNote ?? ''),
            decoration: const InputDecoration(labelText: 'Item note (overlay)'),
            onChanged: (v) {
              setState(() {
                _slides[selectedSlideIndex] =
                    _slides[selectedSlideIndex].copyWith(overlayNote: v.trim().isEmpty ? null : v.trim());
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _itemsTab(_SlideContent slide, _SlideTemplate template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _itemButton('Textbox', Icons.title, () => _addUtilityLayer(_LayerKind.textbox, 'Textbox')),
            _itemButton('Media', Icons.image, _showMediaPickerSheet),
            _itemButton('Website', Icons.language, () => _addUtilityLayer(_LayerKind.website, 'Website')),
            _itemButton('Timer', Icons.timer, () => _addUtilityLayer(_LayerKind.timer, 'Timer')),
            _itemButton('Clock', Icons.access_time, () => _addUtilityLayer(_LayerKind.clock, 'Clock')),
            _itemButton('Camera', Icons.videocam, () => _addUtilityLayer(_LayerKind.camera, 'Camera')),
            _itemButton('Progress', Icons.percent, () => _addUtilityLayer(_LayerKind.progress, 'Progress')),
            _itemButton('Events', Icons.event, () => _addUtilityLayer(_LayerKind.events, 'Events')),
            _itemButton('Weather', Icons.cloud, () => _addUtilityLayer(_LayerKind.weather, 'Weather')),
            _itemButton('Visualizer', Icons.graphic_eq, () => _addUtilityLayer(_LayerKind.visualizer, 'Visualizer')),
            _itemButton('Captions', Icons.closed_caption, () => _addUtilityLayer(_LayerKind.captions, 'Captions')),
            _itemButton('Icon', Icons.star, () => _addUtilityLayer(_LayerKind.icon, 'Icon')),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  isScrollable: false,
                  indicatorColor: accentPink,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [Tab(text: 'Slide'), Tab(text: 'Filters')],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      _slideTab(slide, template),
                      _filtersTab(slide, template),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _slideTab(_SlideContent slide, _SlideTemplate template) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Background color', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in [
                Colors.black,
                Colors.blueGrey.shade900,
                Colors.indigo.shade900,
                Colors.deepPurple.shade900,
                Colors.red.shade900,
                Colors.green.shade900,
                template.background,
              ])
                _colorDot(
                  c,
                  selected: (slide.backgroundColor ?? template.background).value == c.value,
                  onTap: () {
                    setState(() {
                      _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(backgroundColor: c);
                    });
                  },
                ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(backgroundColor: null);
                  });
                },
                child: const Text('Use template', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: slide.templateId,
            decoration: const InputDecoration(labelText: 'Slide template'),
            dropdownColor: bgMedium,
            items: _templates
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(templateId: v);
              });
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: TextEditingController(text: slide.overlayNote ?? ''),
            decoration: const InputDecoration(labelText: 'Slide notes'),
            maxLines: 3,
            onChanged: (v) {
              setState(() {
                _slides[selectedSlideIndex] =
                    _slides[selectedSlideIndex].copyWith(overlayNote: v.trim().isEmpty ? null : v.trim());
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _filtersTab(_SlideContent slide, _SlideTemplate template) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sliderControl('Hue rotate', slide.hueRotate ?? 0, -180, 180, (v) => _setFilter(slide, hue: v)),
          _sliderControl('Invert', (slide.invert ?? 0), 0, 1, (v) => _setFilter(slide, invert: v)),
          _sliderControl('Blur', (slide.blur ?? 0), 0, 20, (v) => _setFilter(slide, blur: v)),
          _sliderControl('Brightness', (slide.brightness ?? 1), 0, 2, (v) => _setFilter(slide, brightness: v)),
          _sliderControl('Contrast', (slide.contrast ?? 1), 0, 2, (v) => _setFilter(slide, contrast: v)),
          _sliderControl('Saturate', (slide.saturate ?? 1), 0, 2, (v) => _setFilter(slide, saturate: v)),
        ],
      ),
    );
  }

  Widget _sliderControl(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            activeColor: accentPink,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _setFilter(_SlideContent slide, {double? hue, double? invert, double? blur, double? brightness, double? contrast, double? saturate}) {
    setState(() {
      _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(
        hueRotate: hue ?? slide.hueRotate,
        invert: invert ?? slide.invert,
        blur: blur ?? slide.blur,
        brightness: brightness ?? slide.brightness,
        contrast: contrast ?? slide.contrast,
        saturate: saturate ?? slide.saturate,
      );
    });
  }

  Widget _mediaAttachmentCard(_SlideContent slide) {
    if (slide.layers.isEmpty && !_hydratedLayerSlides.contains(slide.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateLegacyLayers(selectedSlideIndex));
    }

    final bgLayer = _backgroundLayerFor(slide);
    final hasMedia = (bgLayer?.path?.isNotEmpty ?? false) || (slide.mediaPath != null && slide.mediaPath!.isNotEmpty && slide.mediaType != null);
    final name = hasMedia ? _fileName(bgLayer?.path ?? slide.mediaPath!) : 'None';
    final _SlideMediaType? effectiveType = bgLayer?.mediaType ?? slide.mediaType;
    final typeLabel = effectiveType == _SlideMediaType.image
        ? 'Picture'
        : effectiveType == _SlideMediaType.video
            ? 'Video'
            : 'Media';
    final layers = slide.layers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(hasMedia ? Icons.check_circle : Icons.cloud_upload, size: 18, color: hasMedia ? accentPink : Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasMedia ? '$typeLabel · $name' : 'No media attached',
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasMedia)
                    TextButton(
                      onPressed: _clearSlideMedia,
                      child: const Text('Remove', style: TextStyle(color: Colors.white70)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickMediaForSlide(_SlideMediaType.image),
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: const Text('Add picture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black38,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      side: BorderSide(color: accentPink.withOpacity(0.6)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickMediaForSlide(_SlideMediaType.video),
                    icon: const Icon(Icons.videocam_outlined, size: 16),
                    label: const Text('Add video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black38,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      side: BorderSide(color: accentBlue.withOpacity(0.6)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (layers.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Layers', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SizedBox(
            height: math.min(260, 68.0 * layers.length + 8),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: _reorderLayers,
              itemCount: layers.length,
              itemBuilder: (context, index) {
                final layer = layers[index];
                return Container(
                  key: ValueKey(layer.id),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_indicator, color: Colors.white54),
                        ),
                        const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              layer.role == _LayerRole.background ? accentBlue.withOpacity(0.2) : accentPink.withOpacity(0.2),
                          child: Icon(
                            _layerIcon(layer),
                            size: 16,
                            color: layer.role == _LayerRole.background ? accentBlue : accentPink,
                          ),
                        ),
                      ],
                    ),
                    title: Text(layer.label, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      '${layer.role.name} • ${_layerKindLabel(layer)}',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Move up',
                          icon: const Icon(Icons.arrow_upward, color: Colors.white54),
                          onPressed: index > 0 ? () => _nudgeLayer(index, -1) : null,
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          icon: const Icon(Icons.arrow_downward, color: Colors.white54),
                          onPressed: index < layers.length - 1 ? () => _nudgeLayer(index, 1) : null,
                        ),
                        DropdownButton<_LayerRole>(
                          value: layer.role,
                          dropdownColor: bgMedium,
                          underline: const SizedBox.shrink(),
                          onChanged: (v) {
                            if (v == null) return;
                            _setLayerRole(layer.id, v);
                          },
                          items: const [
                            DropdownMenuItem(value: _LayerRole.background, child: Text('Background')),
                            DropdownMenuItem(value: _LayerRole.foreground, child: Text('Foreground')),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Delete layer',
                          icon: const Icon(Icons.delete_outline, color: Colors.white70),
                          onPressed: () => _deleteLayer(layer.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (layers.isEmpty) ...[
          const SizedBox(height: 10),
          const Text('No layers yet — add media to start layering.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _itemButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 120,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black26,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          side: BorderSide(color: accentPink.withOpacity(0.5)),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: accentPink),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  void _addUtilityLayer(_LayerKind kind, String label) {
    if (_slides.isEmpty || selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    setState(() {
      final slide = _slides[selectedSlideIndex];
      final layer = _SlideLayer(
        id: 'layer-${DateTime.now().millisecondsSinceEpoch}',
        label: label,
        kind: kind,
        role: _LayerRole.foreground,
      );
      final updated = [...slide.layers, layer];
      _slides[selectedSlideIndex] = slide.copyWith(layers: updated);
    });
  }

  Widget _applyFilters(Widget child, _SlideContent slide) {
    final matrix = _colorMatrix(slide);
    final blurSigma = (slide.blur ?? 0).clamp(0, 40).toDouble();
    Widget filtered = ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: child);
    if (blurSigma > 0) {
      filtered = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma), child: filtered);
    }
    return filtered;
  }

  List<double> _colorMatrix(_SlideContent slide) {
    List<double> matrix = _identityMatrix();
    matrix = _matrixMultiply(matrix, _hueMatrix((slide.hueRotate ?? 0) * math.pi / 180));
    matrix = _matrixMultiply(matrix, _saturationMatrix(slide.saturate ?? 1));
    matrix = _matrixMultiply(matrix, _contrastMatrix(slide.contrast ?? 1));
    matrix = _matrixMultiply(matrix, _brightnessMatrix(slide.brightness ?? 1));
    final invertAmount = (slide.invert ?? 0).clamp(0, 1).toDouble();
    if (invertAmount > 0) {
      matrix = _lerpMatrix(matrix, _invertMatrix(), invertAmount);
    }
    return matrix;
  }

  List<double> _identityMatrix() => [
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ];

  List<double> _invertMatrix() => [
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ];

  List<double> _saturationMatrix(double s) {
    const rw = 0.2126, gw = 0.7152, bw = 0.0722;
    final inv = 1 - s;
    final r = inv * rw;
    final g = inv * gw;
    final b = inv * bw;
    return [
      r + s, g, b, 0, 0,
      r, g + s, b, 0, 0,
      r, g, b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _hueMatrix(double radians) {
    final cosR = math.cos(radians);
    final sinR = math.sin(radians);
    const rw = 0.213, gw = 0.715, bw = 0.072;
    return [
      rw + cosR * (1 - rw) + sinR * (-rw), gw + cosR * (-gw) + sinR * (-gw), bw + cosR * (-bw) + sinR * (1 - bw), 0, 0,
      rw + cosR * (-rw) + sinR * 0.143, gw + cosR * (1 - gw) + sinR * 0.14, bw + cosR * (-bw) + sinR * (-0.283), 0, 0,
      rw + cosR * (-rw) + sinR * (-(1 - rw)), gw + cosR * (-gw) + sinR * gw, bw + cosR * (1 - bw) + sinR * bw, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _contrastMatrix(double c) {
    final t = 128 * (1 - c);
    return [
      c, 0, 0, 0, t,
      0, c, 0, 0, t,
      0, 0, c, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _brightnessMatrix(double b) {
    final offset = 255 * (b - 1);
    return [
      1, 0, 0, 0, offset,
      0, 1, 0, 0, offset,
      0, 0, 1, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _lerpMatrix(List<double> a, List<double> b, double t) {
    final out = List<double>.filled(20, 0);
    for (int i = 0; i < 20; i++) {
      out[i] = a[i] + (b[i] - a[i]) * t;
    }
    return out;
  }

  List<double> _matrixMultiply(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 5; c++) {
        double v = 0;
        for (int k = 0; k < 4; k++) {
          v += a[r * 5 + k] * b[k * 5 + c];
        }
        if (c == 4) {
          v += a[r * 5 + 4];
        }
        out[r * 5 + c] = v;
      }
    }
    return out;
  }

  int _safeIntClamp(int value, int min, int max) {
    if (max < min) return min;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _syncSlideThumbnails();
    if (_slides.isNotEmpty) {
      selectedSlides = {0};
      _syncSlideEditors();
    }
    _seedDefaultCategories();
    _drawerHeight = drawerExpanded ? _drawerDefaultHeight : _drawerMinHeight;
    _seedDemoDevices();
    _loadSettings();
  }

  @override
  void dispose() {
    _youtubeQuery.dispose();
    _slideTitleController.dispose();
    _slideBodyController.dispose();
    _lyricsImportController.dispose();
    _previewTimer?.cancel();
    _cancelAutoAdvanceTimer();
    _slidesFocusNode.dispose();
    _slidesScrollController.dispose();
    for (final controller in _onlineSearchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final envYoutubeKey = dotenv.isInitialized ? (dotenv.env['YOUTUBE_API_KEY'] ?? '') : '';
    final envVimeoToken = dotenv.isInitialized ? (dotenv.env['VIMEO_ACCESS_TOKEN'] ?? '') : '';
    final osYoutubeKey = Platform.environment['YOUTUBE_API_KEY'] ?? '';
    final osVimeoToken = Platform.environment['VIMEO_ACCESS_TOKEN'] ?? '';
    setState(() {
      videoFolder = prefs.getString('video_folder');
      songFolder = prefs.getString('song_folder');
      lyricsFolder = prefs.getString('lyrics_folder');
      final prefYoutubeKey = prefs.getString('youtube_api_key');
      final prefVimeoToken = prefs.getString('vimeo_access_token');
      youtubeApiKey = _firstNonEmpty([prefYoutubeKey, envYoutubeKey, osYoutubeKey]);
      vimeoAccessToken = _firstNonEmpty([prefVimeoToken, envVimeoToken, osVimeoToken]);
      savedYouTubeVideos = (prefs.getStringList('youtube_saved') ?? [])
          .map((e) => Map<String, String>.from(json.decode(e)))
          .toList();
    });
    await _scanLibraries();
  }

  Future<void> _scanLibraries() async {
    if (videoFolder != null) {
      _scanFolder(videoFolder!, ['.mp4', '.mov', '.mkv'],
          (list) => discoveredVideos = list);
    }
    if (songFolder != null) {
      _scanFolder(songFolder!, ['.mp3', '.wav', '.flac'],
          (list) => discoveredSongs = list);
    }
    if (lyricsFolder != null) {
      _scanFolder(lyricsFolder!, ['.txt', '.srt', '.lrc'],
          (list) => discoveredLyrics = list);
    }
  }

  void _scanFolder(String path, List<String> extensions,
      void Function(List<FileSystemEntity>) onUpdate) {
    final dir = Directory(path);
    if (dir.existsSync()) {
      final filtered = dir
          .listSync()
          .where((f) => extensions.any((ext) => f.path.toLowerCase().endsWith(ext)))
          .toList();
      setState(() => onUpdate(filtered));
    }
  }

  Future<void> _pickLibraryFolder(String key) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, selectedDirectory);
      _loadSettings();
    }
  }

  Future<void> _uploadVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
    if (result == null) return;

    List<String> importedPaths = [];
    for (final file in result.files) {
      if (file.path == null) continue;
      final source = File(file.path!);
      if (videoFolder != null) {
        final destPath = videoFolder! + Platform.pathSeparator + source.uri.pathSegments.last;
        await source.copy(destPath);
      }
      importedPaths.add(file.path!);
    }

    _scanLibraries();
    _showSnack('Added ${importedPaths.length} video(s)');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submitOnlineSearch(OnlineSource source) async {
    final controller = _onlineSearchControllers[source]!;
        final query = controller.text.trim(); // This line is unchanged
    if (query.length < 2) {
      setState(() => _onlineSearchResults.clear());
      return;
    }

    setState(() {
      _mediaFilter = MediaFilter.online;
      _onlineSourceFilter = source;
    });

    try {
      List<_MediaEntry> results = [];
      switch (source) {
        case OnlineSource.youtube:
          results = await _searchYouTubeOnline(query, musicOnly: false);
          break;
        case OnlineSource.youtubeMusic:
          results = await _searchYouTubeOnline(query, musicOnly: true);
          break;
        case OnlineSource.vimeo:
          results = await _searchVimeo(query);
          break;
        case OnlineSource.all:
          // No search for "All"; just clear results.
          results = [];
          break;
      }

      setState(() {
        _onlineSearchResults
          ..clear()
          ..addAll(results);
      });
    } catch (e) {
      _showSnack('Search error: $e');
    } finally {
      // no-op cleanup for now
    }
  }

  Future<List<_MediaEntry>> _searchYouTubeOnline(String query, {required bool musicOnly}) async {
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

    return items.map<_MediaEntry>((item) {
      final id = item['id']?['videoId'] ?? '';
      final snippet = item['snippet'] ?? {};
      final title = snippet['title'] ?? 'Untitled';
      final channel = snippet['channelTitle'] ?? 'YouTube';
      final thumb = snippet['thumbnails']?['medium']?['url'] ??
          snippet['thumbnails']?['high']?['url'] ??
          snippet['thumbnails']?['default']?['url'] ??
          '';
      return _MediaEntry(
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

  Future<List<_MediaEntry>> _searchVimeo(String query) async {
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
    final resp = await http.get(uri, headers: {
      'Authorization': 'bearer $vimeoAccessToken',
    });
    if (resp.statusCode != 200) {
      _showSnack('Vimeo search failed (${resp.statusCode})');
      return [];
    }

    final body = json.decode(resp.body);
    final data = (body['data'] as List?) ?? [];
    return data.map<_MediaEntry>((item) {
      final name = item['name'] ?? 'Untitled';
      final user = item['user']?['name'] ?? 'Vimeo';
      final uriStr = item['uri'] ?? '';
      final id = uriStr.split('/').isNotEmpty ? uriStr.split('/').last : 'vimeo-$query';
      final pics = item['pictures']?['sizes'] as List?;
      final thumb = (pics != null && pics.isNotEmpty)
          ? (pics.last['link'] ?? pics.first['link'] ?? '')
          : '';
      return _MediaEntry(
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
    });
    for (final c in _onlineSearchControllers.values) {
      c.clear();
    }
  }

  void _seedDemoDevices() {
    if (_connectedScreens.isEmpty) {
      _connectedScreens.addAll([
        _LiveDevice(id: 'screen-1', name: 'Main Display', detail: '1920x1080 @60Hz'),
        _LiveDevice(id: 'screen-2', name: 'Projector', detail: '1280x720 @60Hz'),
      ]);
    }
    if (_connectedCameras.isEmpty) {
      _connectedCameras.add(
        _LiveDevice(id: 'cam-1', name: 'USB Camera', detail: 'Front stage'),
      );
    }
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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
          )
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
          youtubeResults = items.map<Map<String, String>>((item) {
            final id = item['id']?['videoId'] ?? '';
            final snippet = item['snippet'] ?? {};
            return {
              'id': id,
              'title': snippet['title'] ?? 'Untitled',
              'thumb': snippet['thumbnails']?['default']?['url'] ?? '',
            };
          }).where((m) => (m['id'] ?? '').isNotEmpty).toList();
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

  Future<void> _addYouTubeVideo(String id, String title) async {
    if (savedYouTubeVideos.any((v) => v['id'] == id)) {
      _showSnack('Video already saved');
      return;
    }
    final newList = [...savedYouTubeVideos, {'id': id, 'title': title}];
    setState(() => savedYouTubeVideos = newList);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'youtube_saved',
      newList.map((e) => json.encode(e)).toList(),
    );
    _showSnack('Added "$title"');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: null,
      body: Column(
        children: [
          _buildTopNavBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShowListPanel(),
                Expanded(child: _buildCenterContent()),
                _buildRightPanel(),
              ],
            ),
          ),
          _buildBottomDrawer(),
        ],
      ),
    );
  }

  Widget _buildYouTubeSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: bgDark,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _youtubeQuery,
              decoration: const InputDecoration(
                hintText: 'Search YouTube videos',
                filled: true,
                fillColor: Color(0xFF1A2336),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _searchYouTube(),
            ),
          ),
          const SizedBox(width: 10),
          _toolbarButton(
            searchingYouTube ? 'SEARCHING...' : 'SEARCH',
            Icons.search,
            searchingYouTube ? () {} : _searchYouTube,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSaved() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Search Results', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: youtubeResults.isEmpty
                      ? const Center(child: Text('No results yet'))
                      : ListView.builder(
                          itemCount: youtubeResults.length,
                          itemBuilder: (context, i) {
                            final item = youtubeResults[i];
                            return Card(
                              color: const Color(0xFF1A2336),
                              child: ListTile(
                                leading: item['thumb']!.isNotEmpty
                                    ? Image.network(item['thumb']!, width: 60, fit: BoxFit.cover)
                                    : const Icon(Icons.smart_display),
                                title: Text(item['title'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _addYouTubeVideo(item['id']!, item['title'] ?? 'YouTube'),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saved YouTube', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: savedYouTubeVideos.isEmpty
                      ? const Center(child: Text('Nothing saved yet'))
                      : ListView.builder(
                          itemCount: savedYouTubeVideos.length,
                          itemBuilder: (context, i) {
                            final item = savedYouTubeVideos[i];
                            return ListTile(
                              leading: const Icon(Icons.play_circle_outline),
                              title: Text(item['title'] ?? ''),
                              subtitle: Text('https://youtu.be/${item['id']}'),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomDrawer() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final tabs = [
      _drawerTab(Icons.playlist_play, 'Shows'),
      _drawerTab(Icons.collections, 'Media'),
      _drawerTab(Icons.music_note, 'Audio'),
      _drawerTab(Icons.menu_book, 'Scripture'),
      _drawerTab(Icons.text_snippet, 'Lyrics'),
    ];
    final tabViews = [
      _drawerShowsList(),
      _buildMediaDrawerTab(),
      _drawerList('Audio', discoveredSongs, Icons.music_note),
      _emptyTab('Scripture'),
      _drawerList('Lyrics', discoveredLyrics, Icons.text_snippet),
    ];

    final double collapsedHeight = _safeClamp(_drawerTabHeight + 4, _drawerMinHeight, double.infinity);
    // Only render the heavy tab content when we have enough height to avoid overflow.
    final bool showContent = drawerExpanded && _drawerHeight > (_drawerMinHeight + 80);
    final targetHeight = (drawerExpanded ? _drawerHeight : collapsedHeight) + bottomInset;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: targetHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF152038),
        border: const Border(top: BorderSide(color: Colors.white10)),
        boxShadow: drawerExpanded
            ? [const BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -4))]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DefaultTabController(
          length: tabs.length,
          child: Builder(
            builder: (context) => Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (_) => setState(() => drawerExpanded = true),
                  onVerticalDragUpdate: (details) => setState(() {
                    _drawerHeight = _safeClamp(
                      _drawerHeight - details.delta.dy,
                      _drawerMinHeight,
                      _drawerMaxHeight,
                    );
                    drawerExpanded = _drawerHeight > _drawerMinHeight + 4;
                  }),
                  onVerticalDragEnd: (_) => setState(() {
                    drawerExpanded = _drawerHeight > _drawerMinHeight + 4;
                  }),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() {
                        drawerExpanded = !drawerExpanded;
                        _drawerHeight = drawerExpanded ? _drawerDefaultHeight : _drawerMinHeight;
                      }),
                      splashColor: Colors.white10,
                      highlightColor: Colors.white10,
                      child: Container(
                        height: _drawerTabHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TabBar(
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: accentPink,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            isScrollable: true,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 34),
                            indicatorPadding: const EdgeInsets.symmetric(horizontal: 14),
                            tabs: tabs,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showContent)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: TabBarView(children: tabViews),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyTab(String label) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2336),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(
          '$label coming soon',
          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }


  Widget _buildMediaDrawerTab() {
    final entries = _filteredMediaEntries();
    final counts = {
      MediaFilter.all: _countFor(MediaFilter.all),
      MediaFilter.online: _countFor(MediaFilter.online),
      MediaFilter.screens: _countFor(MediaFilter.screens),
      MediaFilter.cameras: _countFor(MediaFilter.cameras),
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2336),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10182B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sources', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      _mediaFilterTile(MediaFilter.all, counts[MediaFilter.all] ?? 0, Icons.apps),
                      _mediaFilterTile(MediaFilter.online, counts[MediaFilter.online] ?? 0, Icons.wifi_tethering),
                      _mediaFilterTile(MediaFilter.screens, counts[MediaFilter.screens] ?? 0, Icons.monitor_heart),
                      _mediaFilterTile(MediaFilter.cameras, counts[MediaFilter.cameras] ?? 0, Icons.videocam),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10182B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Folders', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: playlists.isEmpty
                              ? const Center(
                                  child: Text('No folders', style: TextStyle(color: Colors.grey)),
                                )
                              : ListView.builder(
                                  itemCount: playlists.length,
                                  itemBuilder: (context, i) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.folder, size: 16, color: Colors.white70),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              playlists[i],
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _promptAddMediaFolder,
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add folder', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            minimumSize: const Size.fromHeight(34),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                if (_mediaFilter == MediaFilter.online) ...[
                  _onlineSubfilterTabs(),
                  const SizedBox(height: 10),
                ],
                Expanded(
                  child: Stack(
                    children: [
                      if (_mediaFilter == MediaFilter.online && _onlineSourceFilter != OnlineSource.all)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: _onlineSearchBar(),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: _mediaFilter == MediaFilter.online && _onlineSourceFilter != OnlineSource.all ? 64 : 0,
                        ),
                        child: _buildMediaGrid(entries),
                      ),
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

  List<_MediaEntry> _mediaEntries() {
    final items = <_MediaEntry>[];

    for (final screen in _connectedScreens) {
      items.add(
        _MediaEntry(
          id: 'screen-${screen.id}',
          title: screen.name,
          subtitle: screen.detail,
          category: MediaFilter.screens,
          icon: Icons.monitor,
          tint: accentBlue,
          isLive: true,
          badge: 'Screen',
        ),
      );
    }

    for (final cam in _connectedCameras) {
      items.add(
        _MediaEntry(
          id: 'camera-${cam.id}',
          title: cam.name,
          subtitle: cam.detail,
          category: MediaFilter.cameras,
          icon: Icons.videocam,
          tint: accentPink,
          isLive: true,
          badge: 'Camera',
        ),
      );
    }

    for (final yt in savedYouTubeVideos) {
      final title = yt['title'] ?? 'Online video';
      items.add(
        _MediaEntry(
          id: 'online-${yt['id'] ?? title}-${items.length}',
          title: title,
          subtitle: 'Online video',
          category: MediaFilter.online,
          icon: Icons.wifi_tethering,
          tint: Colors.orangeAccent,
          isLive: false,
          badge: 'Online',
          onlineSource: OnlineSource.youtube,
        ),
      );
    }

    for (final vid in discoveredVideos) {
      final name = vid.path.split(Platform.pathSeparator).last;
      items.add(
        _MediaEntry(
          id: 'local-$name-${items.length}',
          title: name,
          subtitle: 'Local media',
          category: MediaFilter.all,
          icon: Icons.collections,
          tint: Colors.tealAccent.shade100,
          isLive: false,
          badge: 'File',
        ),
      );
    }

    return items;
  }

  List<_MediaEntry> _filteredMediaEntries() {
    final items = _mediaEntries();

    if (_mediaFilter == MediaFilter.online && _onlineSearchResults.isNotEmpty) {
      final results = _onlineSearchResults.where((e) {
        if (_onlineSourceFilter == OnlineSource.all) return true;
        return e.onlineSource == _onlineSourceFilter;
      }).toList();
      return results;
    }

    if (_mediaFilter == MediaFilter.all) return items;
    final filtered = items.where((e) => e.category == _mediaFilter).toList();
    if (_mediaFilter == MediaFilter.online && _onlineSourceFilter != OnlineSource.all) {
      return filtered.where((e) => e.onlineSource == _onlineSourceFilter).toList();
    }
    return filtered;
  }

  int _countFor(MediaFilter filter) {
    final items = _mediaEntries();
    if (filter == MediaFilter.all) return items.length;
    return items.where((e) => e.category == filter).length;
  }

  int _countForOnlineSource(OnlineSource source) {
    final items = _mediaEntries().where((e) => e.category == MediaFilter.online);
    if (source == OnlineSource.all) return items.length;
    return items.where((e) => e.onlineSource == source).length;
  }

  Color _onlineSourceColor(OnlineSource source) {
    switch (source) {
      case OnlineSource.vimeo:
        return Colors.lightBlueAccent;
      case OnlineSource.youtube:
        return Colors.redAccent;
      case OnlineSource.youtubeMusic:
        return Colors.deepOrangeAccent;
      case OnlineSource.all:
        return accentPink;
    }
  }

  Widget _onlineSearchBar() {
    final activeSource = _onlineSourceFilter == OnlineSource.all ? OnlineSource.youtube : _onlineSourceFilter;
    final canSearch = _onlineSourceFilter != OnlineSource.all;
    final controller = _onlineSearchControllers[activeSource]!;
    final color = _onlineSourceColor(activeSource);
    final showExpanded = _onlineSearchExpanded && canSearch;
    final sourceLabel = _mediaFilterLabelForOnline(activeSource);

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: showExpanded ? 420 : 52,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF111A2D),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white24),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 6))],
        ),
        padding: EdgeInsets.symmetric(horizontal: showExpanded ? 10 : 6),
        child: Row(
          children: [
            if (showExpanded) ...[
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: canSearch,
                  onChanged: (_) => _submitOnlineSearch(activeSource),
                  onSubmitted: (_) => _submitOnlineSearch(activeSource),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search $sourceLabel...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  constraints: BoxConstraints.tight(const Size(36, 36)),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _onlineSearchExpanded = false;
                    });
                    _clearOnlineSearch();
                  },
                  splashRadius: 18,
                ),
              ),
            ],
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: IconButton(
                constraints: BoxConstraints.tight(const Size(36, 36)),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.search, color: Colors.white, size: 18),
                splashRadius: 20,
                onPressed: canSearch
                    ? () {
                        setState(() => _onlineSearchExpanded = true);
                        _submitOnlineSearch(activeSource);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mediaFilterLabel(MediaFilter filter) {
    switch (filter) {
      case MediaFilter.online:
        return 'Online';
      case MediaFilter.screens:
        return 'Screens';
      case MediaFilter.cameras:
        return 'Cameras';
      case MediaFilter.all:
        return 'All';
    }
  }

  // ignore: unused_element
  // Label helper kept for clarity; currently unused by UI.
  String _mediaFilterLabelForOnline(OnlineSource src) {
    switch (src) {
      case OnlineSource.vimeo:
        return 'Vimeo';
      case OnlineSource.youtube:
        return 'YouTube';
      case OnlineSource.youtubeMusic:
        return 'YouTube Music';
      case OnlineSource.all:
        return 'Online';
    }
  }

  Widget _mediaFilterTile(MediaFilter filter, int count, IconData icon) {
    final selected = _mediaFilter == filter;
    final label = _mediaFilterLabel(filter);
    return InkWell(
      onTap: () => setState(() => _mediaFilter = filter),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.white70,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? accentPink.withOpacity(0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _onlineSubfilterTabs() {
    final labels = [
      {'label': 'All', 'source': OnlineSource.all, 'icon': Icons.wifi_tethering},
      {'label': 'Vimeo', 'source': OnlineSource.vimeo, 'icon': Icons.video_library},
      {'label': 'YouTube', 'source': OnlineSource.youtube, 'icon': Icons.smart_display},
      {'label': 'YT Music', 'source': OnlineSource.youtubeMusic, 'icon': Icons.music_note},
    ];

    final currentIndex = labels.indexWhere((m) => m['source'] == _onlineSourceFilter);
    final safeIndex = currentIndex >= 0 ? currentIndex : 0;

    return DefaultTabController(
      length: labels.length,
      initialIndex: safeIndex,
      child: SizedBox(
        height: 40,
        child: Builder(
          builder: (context) {
            return TabBar(
              isScrollable: false,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: accentPink,
              indicatorWeight: 2,
              indicatorPadding: EdgeInsets.zero,
              indicatorSize: TabBarIndicatorSize.label,
              labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              overlayColor: WidgetStateProperty.all(Colors.white10),
              onTap: (i) {
                final src = labels[i]['source'] as OnlineSource;
                setState(() {
                  _onlineSourceFilter = src;
                  if (src == OnlineSource.all) {
                    _onlineSearchExpanded = false;
                  }
                });
              },
              tabs: labels.map((m) {
                final src = m['source'] as OnlineSource;
                final count = _countForOnlineSource(src);
                final label = m['label'] as String;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(m['icon'] as IconData, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '$label ($count)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.0),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMediaGrid(List<_MediaEntry> entries) {
    if (entries.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF10182B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text('No media yet', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = 210.0;
        final crossAxisCount = math.max(2, (width / itemWidth).floor());
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.22,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) => _mediaCard(entries[i]),
        );
      },
    );
  }

  Widget _mediaCard(_MediaEntry entry) {
    final hovered = _hoveredMediaId == entry.id;
    final previewing = _previewingMediaId == entry.id;
    final overlay = hovered || entry.isLive || previewing;
    Widget buildCardContent({double? opacity}) {
      final content = MouseRegion(
        onEnter: (_) {
          _previewTimer?.cancel();
          setState(() {
            _hoveredMediaId = entry.id;
            _previewingMediaId = null;
          });
          _previewTimer = Timer(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            setState(() => _previewingMediaId = entry.id);
          });
        },
        onExit: (_) {
          _previewTimer?.cancel();
          setState(() {
            if (_previewingMediaId == entry.id) _previewingMediaId = null;
            _hoveredMediaId = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [entry.tint.withOpacity(0.2), entry.tint.withOpacity(0.07)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: overlay ? accentPink.withOpacity(0.5) : Colors.white12),
            boxShadow: overlay
                ? [const BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 6))]
                : [const BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Stack(
            children: [
              Positioned.fill(child: _mediaPreviewSurface(entry, overlay, previewing)),
              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: [
                    _mediaBadge(_mediaFilterLabel(entry.category), Colors.white10),
                    if (entry.badge != null) ...[
                      const SizedBox(width: 6),
                      _mediaBadge(entry.badge!, accentPink.withOpacity(0.2)),
                    ],
                    if (entry.isLive) ...[
                      const SizedBox(width: 6),
                      _mediaBadge('LIVE', Colors.red.withOpacity(0.25)),
                    ],
                  ],
                ),
              ),
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(entry.icon, size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      if (opacity != null) {
        return Opacity(opacity: opacity, child: IgnorePointer(child: content));
      }
      return content;
    }

    return Draggable<_MediaEntry>(
      data: entry,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      maxSimultaneousDrags: 1,
      onDragStarted: () {
        _previewTimer?.cancel();
      },
      onDragEnd: (_) {
        setState(() {
          _hoveredMediaId = null;
          _previewingMediaId = null;
        });
      },
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 210, height: 170),
          child: buildCardContent(opacity: 0.95),
        ),
      ),
      childWhenDragging: buildCardContent(opacity: 0.35),
      child: buildCardContent(),
    );
  }

  Widget _mediaPreviewSurface(_MediaEntry entry, bool overlay, bool previewing) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: previewing
                  ? _buildHoverPreview(entry)
                  : _thumbnailOrFallback(entry),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.35)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _GridNoisePainter(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        AnimatedOpacity(
          opacity: overlay && !previewing ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withOpacity(entry.isLive ? 0.12 : 0.22),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(entry.isLive ? Icons.play_circle : Icons.preview, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(entry.isLive ? 'Live preview' : 'Hover preview', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbnailOrFallback(_MediaEntry entry) {
    if (entry.thumbnailUrl != null && entry.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        entry.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackPreview(entry),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _fallbackPreview(entry);
        },
      );
    }
    return _fallbackPreview(entry);
  }

  Widget _buildHoverPreview(_MediaEntry entry) {
    final isYoutube = entry.onlineSource == OnlineSource.youtube || entry.onlineSource == OnlineSource.youtubeMusic;
    final supportsInlineWebView = kIsWeb ||
        Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS; // Windows/Linux builds lack WebView by default.

    if (isYoutube && entry.id.isNotEmpty && supportsInlineWebView) {
      return IgnorePointer(
        child: YoutubePlayer(
          key: ValueKey('yt-preview-${entry.id}'),
          aspectRatio: 16 / 9,
          controller: YoutubePlayerController.fromVideoId(
            videoId: entry.id,
            autoPlay: true,
            params: const YoutubePlayerParams(
              mute: true,
              showFullscreenButton: false,
              showControls: false,
              playsInline: true,
              enableJavaScript: true,
            ),
          ),
        ),
      );
    }
    // Fallback: show static thumbnail when preview video isn't available.
    return _thumbnailOrFallback(entry);
  }

  Widget _fallbackPreview(_MediaEntry entry) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [entry.tint.withOpacity(0.22), entry.tint.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _mediaBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _colorDot(Color color, {bool selected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 2 : 1),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
    );
  }

  Widget _buildTopNavBar() {
    final tabSwitcher = Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF152038),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _topTab(icon: Icons.tv, label: 'Show', selected: selectedTopTab == 0, onTap: () => setState(() => selectedTopTab = 0)),
          _topTab(icon: Icons.edit, label: 'Edit', selected: selectedTopTab == 1, onTap: () => setState(() => selectedTopTab = 1)),
          _topTab(icon: Icons.personal_video, label: 'Stage', selected: selectedTopTab == 2, onTap: () => setState(() => selectedTopTab = 2)),
        ],
      ),
    );

    return Container(
      height: 52,
      color: const Color(0xFF1A2336),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('FreeShow', style: TextStyle(color: Color(0xFFE0007A), fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(width: 24),
                _miniNavItem('File'),
                _miniNavItem('Edit'),
                _miniNavItem('View'),
                _miniNavItem('Help'),
              ],
            ),
          ),
          Center(child: tabSwitcher),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: _openSettingsModal, icon: const Icon(Icons.extension, size: 18, color: Colors.white70)),
                IconButton(onPressed: _openSettingsModal, icon: const Icon(Icons.settings, size: 18, color: Colors.white70)),
                IconButton(onPressed: _openSettingsModal, icon: const Icon(Icons.folder_open, size: 18, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowListPanel() {
    return Container(
      width: 260,
      color: const Color(0xFF182237),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text('Projects', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _frostedBox(
              child: Container(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: _newProjectButtonKey,
              onPressed: _promptNewProjectMenu,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLibrarySidebar() {
    return _frostedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < sources.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _selectableRow(
                icon: sources[i]['icon'] as IconData,
                label: sources[i]['label'] as String,
                selected: selectedSourceIndex == i,
                onTap: () => setState(() => selectedSourceIndex = i),
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add source'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterContent() {
    switch (selectedTopTab) {
      case 0: // Show
        return _buildShowsWorkspace();
      case 1: // Edit
        return _buildSlideEditorShell();
      case 2: // Stage
        return _buildStageViewPanel();
      default:
        return _buildShowsWorkspace();
    }
  }

  Widget _buildStageViewPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _frostedBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Stage View'),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _slides.isEmpty
                              ? _emptyStageBox('No current slide')
                              : _renderSlidePreview(_slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _slides.length < 2
                              ? _emptyStageBox('No next slide')
                              : _renderSlidePreview(
                                  _slides[(_safeIntClamp(selectedSlideIndex + 1, 0, _slides.length - 1))],
                                  compact: true,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 260, child: _buildStagePreviewCard()),
        ],
      ),
    );
  }

  Widget _emptyStageBox(String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Text(label, style: const TextStyle(color: Colors.white54)),
      ),
    );
  }

  Widget _buildShowsMetaPanel() {
    final meta = {
      'Created': '',
      'Modified': '',
      'Used': '',
      'Category': 'None',
      'Slides': '',
      'Words': '',
      'Template': 'None',
    };
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF182237),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unnamed', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...meta.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                    Text(e.value.isEmpty ? '—' : e.value, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildShowsWorkspace() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: _buildSlidesCanvasOnly(),
    );
  }

  Widget _buildSlideEditorShell() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(flex: 7, child: _buildSingleSlideEditSurface()),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: _buildSlideEditorPanel()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleSlideEditSurface() {
    final hasSlide = _slides.isNotEmpty && selectedSlideIndex >= 0 && selectedSlideIndex < _slides.length;
    final slide = hasSlide ? _slides[selectedSlideIndex] : null;
    return _frostedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader('Slide Preview'),
              const Spacer(),
              Text(hasSlide ? 'Slide ${selectedSlideIndex + 1}/${_slides.length}' : 'No slide',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: hasSlide
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      // Render at a fixed stage resolution and scale to fit so the edit preview matches output sizing.
                      const double stageWidth = 1920;
                      const double stageHeight = 1080;
                      return Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: stageWidth,
                            height: stageHeight,
                            child: _buildEditableCanvas(slide!),
                          ),
                        ),
                      );
                    },
                  )
                : _emptyStageBox('No slide selected'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableCanvas(_SlideContent slide) {
    final template = _templateFor(slide.templateId);
    final bg = slide.backgroundColor ?? template.background;
    final align = slide.alignOverride ?? template.alignment;

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = _resolvedBoxRect(slide);
        final boxLeft = box.left * constraints.maxWidth;
        final boxTop = box.top * constraints.maxHeight;
        final boxWidth = box.width * constraints.maxWidth;
        final boxHeight = box.height * constraints.maxHeight;
        final hasTextboxLayer = slide.layers.any((l) => l.kind == _LayerKind.textbox);

        return MouseRegion(
          cursor: _boxResizing ? SystemMouseCursors.resizeUpLeftDownRight : SystemMouseCursors.basic,
          child: Stack(
            children: [
              Positioned.fill(
                child: _applyFilters(_buildSlideBackground(slide, template), slide),
              ),
              if (_foregroundLayerFor(slide) != null)
                Positioned.fill(
                  child: _buildLayerWidget(_foregroundLayerFor(slide)!, fit: BoxFit.contain),
                ),
              if (hasTextboxLayer)
                Positioned(
                  left: boxLeft,
                  top: boxTop,
                  width: boxWidth,
                  height: boxHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      _boxDragStartPointer = details.localPosition;
                      _boxDragStartRect = box;
                      _boxResizing = _isInResizeCorner(details.localPosition, boxWidth, boxHeight);
                    },
                    onPanUpdate: (details) {
                      if (_boxDragStartRect == null || _boxDragStartPointer == null) return;
                      final dx = details.localPosition.dx - _boxDragStartPointer!.dx;
                      final dy = details.localPosition.dy - _boxDragStartPointer!.dy;
                      final totalW = constraints.maxWidth;
                      final totalH = constraints.maxHeight;

                      if (_boxResizing) {
                        final newWidth = (_boxDragStartRect!.width * totalW + dx) / totalW;
                        final newHeight = (_boxDragStartRect!.height * totalH + dy) / totalH;
                        _updateSlideBox(slide, width: newWidth, height: newHeight);
                      } else {
                        final newLeft = (_boxDragStartRect!.left * totalW + dx) / totalW;
                        final newTop = (_boxDragStartRect!.top * totalH + dy) / totalH;
                        _updateSlideBox(slide, left: newLeft, top: newTop);
                      }
                    },
                    onPanEnd: (_) {
                      _boxDragStartPointer = null;
                      _boxDragStartRect = null;
                      _boxResizing = false;
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentPink.withOpacity(0.8), width: 1.5),
                      ),
                      padding: const EdgeInsets.all(8),
                      alignment: _textAlignToAlignment(align),
                      child: Text(
                        slide.body,
                        textAlign: align,
                        style: TextStyle(
                          color: slide.textColorOverride ?? template.textColor,
                          fontSize: _autoSizedFont(slide, slide.fontSizeOverride ?? template.fontSize, box),
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasTextboxLayer)
                Positioned(
                  left: boxLeft + boxWidth - 14,
                  top: boxTop + boxHeight - 14,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (d) {
                      _boxDragStartPointer = d.localPosition;
                      _boxDragStartRect = box;
                      _boxResizing = true;
                    },
                    onPanUpdate: (d) {
                      if (_boxDragStartRect == null || _boxDragStartPointer == null) return;
                      final dx = d.localPosition.dx - _boxDragStartPointer!.dx;
                      final dy = d.localPosition.dy - _boxDragStartPointer!.dy;
                      final totalW = constraints.maxWidth;
                      final totalH = constraints.maxHeight;
                      final newWidth = (_boxDragStartRect!.width * totalW + dx) / totalW;
                      final newHeight = (_boxDragStartRect!.height * totalH + dy) / totalH;
                      _updateSlideBox(slide, width: newWidth, height: newHeight);
                    },
                    onPanEnd: (_) {
                      _boxDragStartPointer = null;
                      _boxDragStartRect = null;
                      _boxResizing = false;
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: accentPink,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                      ),
                      child: const Icon(Icons.open_with, color: Colors.white, size: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _isInResizeCorner(Offset localPos, double width, double height) {
    const double cornerSize = 28;
    return localPos.dx > width - cornerSize && localPos.dy > height - cornerSize;
  }

  void _updateSlideBox(_SlideContent slide, {double? left, double? top, double? width, double? height}) {
    final rect = _resolvedBoxRect(slide);
    final next = Rect.fromLTWH(
      left ?? rect.left,
      top ?? rect.top,
      width ?? rect.width,
      height ?? rect.height,
    );
    setState(() {
      final clampedWidth = _safeClamp(next.width, 0.08, 1);
      final clampedHeight = _safeClamp(next.height, 0.08, 1);
      final clampedLeft = _safeClamp(next.left, 0, 1 - clampedWidth);
      final clampedTop = _safeClamp(next.top, 0, 1 - clampedHeight);
      final clamped = Rect.fromLTWH(clampedLeft, clampedTop, clampedWidth, clampedHeight);
      _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(
        boxLeft: clamped.left,
        boxTop: clamped.top,
        boxWidth: clamped.width,
        boxHeight: clamped.height,
      );
    });
  }

  Widget _buildSlideEditorPanel() {
    final hasSlide = _slides.isNotEmpty && selectedSlideIndex >= 0 && selectedSlideIndex < _slides.length;
    final slide = hasSlide ? _slides[selectedSlideIndex] : null;
    final template = slide != null ? _templateFor(slide.templateId) : _templates.first;
    if (!hasSlide) {
      return _frostedBox(child: const Text('No slide selected', style: TextStyle(color: Colors.white54)));
    }

    return _frostedBox(
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _sectionHeader('Slide Editor'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add slide',
                  onPressed: _addSlide,
                ),
              ],
            ),
            const SizedBox(height: 6),
            TabBar(
              isScrollable: false,
              indicatorColor: accentPink,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Textbox'),
                Tab(text: 'Item'),
                Tab(text: 'Items'),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                children: [
                  _textboxTab(slide!, template),
                  _itemTab(slide, template),
                  _itemsTab(slide, template),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _importLyrics(String raw, {int? linesPerSlide}) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final blocks = text.split(RegExp(r'\n\s*\n')).where((b) => b.trim().isNotEmpty).toList();
    final List<_SlideContent> newSlides = [];

    for (final block in blocks) {
      final lines = block.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (linesPerSlide == null || linesPerSlide <= 0) {
        newSlides.add(
          _SlideContent(
            id: 'slide-${DateTime.now().microsecondsSinceEpoch}-${newSlides.length}',
            title: lines.first,
            body: lines.join('\n'),
            templateId: _templates.first.id,
          ),
        );
      } else {
        for (int i = 0; i < lines.length; i += linesPerSlide) {
          final end = (i + linesPerSlide).clamp(0, lines.length).toInt();
          final chunk = lines.sublist(i, end);
          newSlides.add(
            _SlideContent(
              id: 'slide-${DateTime.now().microsecondsSinceEpoch}-$i',
              title: chunk.first,
              body: chunk.join('\n'),
              templateId: _templates.first.id,
            ),
          );
        }
      }
    }

    if (newSlides.isEmpty) return;
    setState(() {
      _slides = [..._slides, ...newSlides];
      _syncSlideThumbnails();
      selectedSlideIndex = _slides.length - newSlides.length;
      selectedSlides = {selectedSlideIndex};
    });
    _syncSlideEditors();
  }

  // ignore: unused_element
  Widget _buildShowsListSidebar() {
    final visible = _filteredShows();
    if (visible.isEmpty) {
      return const Center(child: Text('No shows yet', style: TextStyle(color: Colors.white54)));
    }
    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
      itemBuilder: (context, i) {
        final globalIndex = shows.indexOf(visible[i]);
        final selected = selectedShowIndex == globalIndex;
        return _selectableRow(
          icon: Icons.featured_play_list_outlined,
          label: visible[i].name,
          selected: selected,
          onTap: () => setState(() => selectedShowIndex = globalIndex),
        );
      },
    );
  }

  void _ensureSlideKeys() {
    _syncSlideThumbnails();
    while (_slideKeys.length < _slides.length) {
      _slideKeys.add(GlobalKey());
    }
    while (_slideKeys.length > _slides.length) {
      _slideKeys.removeLast();
    }
    _slideRects.removeWhere((key, value) => key >= _slides.length);
  }

  void _syncSlideThumbnails() {
    while (_slideThumbnails.length < _slides.length) {
      _slideThumbnails.add(null);
    }
    while (_slideThumbnails.length > _slides.length) {
      _slideThumbnails.removeLast();
    }
  }

  void _captureTileRect(int index) {
    if (index < 0 || index >= _slideKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _slideKeys[index].currentContext;
      if (context == null) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;
      final topLeftGlobal = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final stackBox = _slidesStackKey.currentContext?.findRenderObject() as RenderBox?;
      if (stackBox == null) return;
      final topLeftLocal = stackBox.globalToLocal(topLeftGlobal);
      _slideRects[index] = Rect.fromLTWH(topLeftLocal.dx, topLeftLocal.dy, size.width, size.height);
    });
  }

  void _updateSelectionFromRect(Rect selectionRect) {
    final hits = <int>{};
    _slideRects.forEach((index, rect) {
      if (selectionRect.overlaps(rect)) {
        hits.add(index);
      }
    });
    final sorted = hits.toList()..sort();
    setState(() {
      selectedSlides = sorted.toSet();
      if (sorted.isNotEmpty) {
        selectedSlideIndex = sorted.first;
      }
    });
  }

  void _requestSlidesFocus() {
    if (!_slidesFocusNode.hasFocus) {
      _slidesFocusNode.requestFocus();
    }
  }

  void _selectSlide(int index) {
    if (index < 0 || index >= _slides.length) return;
    setState(() {
      selectedSlideIndex = index;
      selectedSlides = {index};
    });
    _syncSlideEditors();
  }

  void _syncSlideEditors() {
    if (_slides.isEmpty || selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    final slide = _slides[selectedSlideIndex];
    _slideTitleController.text = slide.title;
    _slideBodyController.text = slide.body;
  }

  int _mapIndexOnMove(int idx, int from, int to) {
    if (idx == from) return to;
    if (from < to && idx > from && idx <= to) return idx - 1;
    if (to < from && idx >= to && idx < from) return idx + 1;
    return idx;
  }

  void _moveSlide(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= _slides.length || to > _slides.length) return;
    _syncSlideThumbnails();
    setState(() {
      final item = _slides.removeAt(from);
      _slides.insert(to, item);

      final thumb = _slideThumbnails.removeAt(from);
      _slideThumbnails.insert(to, thumb);

      selectedSlideIndex = _mapIndexOnMove(selectedSlideIndex, from, to);
      selectedSlides = selectedSlides.map((i) => _mapIndexOnMove(i, from, to)).toSet();
    });
    _syncSlideEditors();
  }

  void _addMediaToSlide(_MediaEntry entry, int slideIndex) {
    if (slideIndex < 0 || slideIndex >= _slides.length) return;
    _syncSlideThumbnails();
    setState(() {
      _slides[slideIndex] = _slides[slideIndex].copyWith(
        title: entry.title,
        body: entry.title,
      );
      _slideThumbnails[slideIndex] = entry.thumbnailUrl;
      selectedSlideIndex = slideIndex;
      selectedSlides = {slideIndex};
    });
    _syncSlideEditors();
    _showSnack('Added "${entry.title}" to slide ${slideIndex + 1}');
  }

  void _addMediaAsNewSlide(_MediaEntry entry) {
    _syncSlideThumbnails();
    setState(() {
      _slides.add(
        _SlideContent(
          id: 'slide-${DateTime.now().millisecondsSinceEpoch}',
          title: entry.title,
          body: entry.title,
          templateId: _templates.first.id,
        ),
      );
      _slideThumbnails.add(entry.thumbnailUrl);
      selectedSlideIndex = _slides.length - 1;
      selectedSlides = {selectedSlideIndex};
    });
    _ensureSlideKeys();
    _syncSlideEditors();
    _showSnack('Created slide with "${entry.title}"');
  }

  _LayerRole _defaultLayerRoleForSlide(_SlideContent slide) {
    final hasBackground = slide.layers.any((l) => l.role == _LayerRole.background && l.kind == _LayerKind.media);
    return hasBackground ? _LayerRole.foreground : _LayerRole.background;
  }

  _SlideLayer? _backgroundLayerFor(_SlideContent slide) {
    for (final layer in slide.layers.reversed) {
      if (layer.role == _LayerRole.background && layer.kind == _LayerKind.media && layer.mediaType != null) return layer;
    }
    return null;
  }

  _SlideLayer? _foregroundLayerFor(_SlideContent slide) {
    for (final layer in slide.layers.reversed) {
      if (layer.role == _LayerRole.foreground) return layer;
    }
    return null;
  }

  String _layerKindLabel(_SlideLayer layer) {
    switch (layer.kind) {
      case _LayerKind.media:
        if (layer.mediaType == _SlideMediaType.video) return 'Video';
        if (layer.mediaType == _SlideMediaType.image) return 'Picture';
        return 'Media';
      case _LayerKind.textbox:
        return 'Textbox';
      case _LayerKind.camera:
        return 'Camera';
      case _LayerKind.website:
        return 'Website';
      case _LayerKind.timer:
        return 'Timer';
      case _LayerKind.clock:
        return 'Clock';
      case _LayerKind.progress:
        return 'Progress';
      case _LayerKind.events:
        return 'Events';
      case _LayerKind.weather:
        return 'Weather';
      case _LayerKind.visualizer:
        return 'Visualizer';
      case _LayerKind.captions:
        return 'Captions';
      case _LayerKind.icon:
        return 'Icon';
    }
  }

  IconData _layerIcon(_SlideLayer layer) {
    switch (layer.kind) {
      case _LayerKind.media:
        return layer.mediaType == _SlideMediaType.video ? Icons.videocam_outlined : Icons.image_outlined;
      case _LayerKind.textbox:
        return Icons.title;
      case _LayerKind.camera:
        return Icons.videocam;
      case _LayerKind.website:
        return Icons.language;
      case _LayerKind.timer:
        return Icons.timer;
      case _LayerKind.clock:
        return Icons.access_time;
      case _LayerKind.progress:
        return Icons.percent;
      case _LayerKind.events:
        return Icons.event;
      case _LayerKind.weather:
        return Icons.cloud;
      case _LayerKind.visualizer:
        return Icons.graphic_eq;
      case _LayerKind.captions:
        return Icons.closed_caption;
      case _LayerKind.icon:
        return Icons.star;
    }
  }

  void _updateSlideThumbnailFromLayers(int slideIndex) {
    if (slideIndex < 0 || slideIndex >= _slides.length) return;
    _syncSlideThumbnails();
    final bg = _backgroundLayerFor(_slides[slideIndex]);
    if (bg != null && bg.mediaType == _SlideMediaType.image && bg.path != null) {
      _slideThumbnails[slideIndex] = bg.path;
    } else {
      _slideThumbnails[slideIndex] = null;
    }
  }

  void _hydrateLegacyLayers(int slideIndex) {
    if (slideIndex < 0 || slideIndex >= _slides.length) return;
    final slide = _slides[slideIndex];
    if (_hydratedLayerSlides.contains(slide.id)) return;

    // If slide already has layers, just mark hydrated so we don't re-run.
    if (slide.layers.isNotEmpty) {
      _hydratedLayerSlides.add(slide.id);
      return;
    }

    // Convert legacy mediaPath/mediaType into a background media layer.
    if (slide.mediaPath != null && slide.mediaPath!.isNotEmpty && slide.mediaType != null) {
      final layer = _SlideLayer(
        id: 'layer-${DateTime.now().millisecondsSinceEpoch}',
        label: _fileName(slide.mediaPath!),
        kind: _LayerKind.media,
        path: slide.mediaPath!,
        mediaType: slide.mediaType!,
        role: _LayerRole.background,
      );
      setState(() {
        _slides[slideIndex] = slide.copyWith(layers: [layer]);
        _hydratedLayerSlides.add(slide.id);
        _applyLayerUpdate(_slides[slideIndex].layers, slideIndex: slideIndex, triggerSetState: false);
      });
      return;
    }

    // No legacy media: seed a default textbox layer so the stack is populated.
    final defaultTextbox = _SlideLayer(
      id: 'layer-${DateTime.now().millisecondsSinceEpoch}',
      label: 'Textbox',
      kind: _LayerKind.textbox,
      role: _LayerRole.foreground,
    );
    setState(() {
      _slides[slideIndex] = slide.copyWith(layers: [defaultTextbox]);
      _hydratedLayerSlides.add(slide.id);
      _applyLayerUpdate(_slides[slideIndex].layers, slideIndex: slideIndex, triggerSetState: false);
    });
  }

  void _reorderLayers(int oldIndex, int newIndex) {
    if (_slides.isEmpty || selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    setState(() {
      final layers = [..._slides[selectedSlideIndex].layers];
      if (newIndex > oldIndex) newIndex -= 1;
      final layer = layers.removeAt(oldIndex);
      layers.insert(newIndex, layer);
      _applyLayerUpdate(layers, triggerSetState: false);
    });
  }

  void _setLayerRole(String layerId, _LayerRole role) {
    if (_slides.isEmpty || selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    final layers = _slides[selectedSlideIndex].layers.map((layer) {
      if (layer.id == layerId) {
        return layer.copyWith(role: role);
      }
      return layer;
    }).toList();
    setState(() {
      _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(layers: layers);
      if (role == _LayerRole.background) {
        final target = layers.firstWhere((l) => l.id == layerId);
        if (target.kind == _LayerKind.media) {
          _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(
            mediaPath: target.path,
            mediaType: target.mediaType,
          );
        }
      }
      _updateSlideThumbnailFromLayers(selectedSlideIndex);
    });
  }

  void _deleteLayer(String layerId) {
    if (_slides.isEmpty || selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    setState(() {
      final slide = _slides[selectedSlideIndex];
      _SlideLayer? removedLayer;
      for (final l in slide.layers) {
        if (l.id == layerId) {
          removedLayer = l;
          break;
        }
      }
      final layers = slide.layers.where((l) => l.id != layerId).toList();
      _applyLayerUpdate(layers, triggerSetState: false);

      // If the removed layer was a background media, drop the slide media mapping immediately.
      final wasBackgroundMedia = removedLayer?.kind == _LayerKind.media && removedLayer?.role == _LayerRole.background;
      final hasMedia = layers.any((l) => l.kind == _LayerKind.media);
      if (wasBackgroundMedia || !hasMedia) {
        _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(mediaPath: null, mediaType: null);
        _slideThumbnails[selectedSlideIndex] = null;
        _updateSlideThumbnailFromLayers(selectedSlideIndex);
      }

      // If the removed layer was the only textbox, clear textbox content so it disappears from the slide.
      final hasTextbox = layers.any((l) => l.kind == _LayerKind.textbox);
      if (removedLayer?.kind == _LayerKind.textbox && !hasTextbox) {
        _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(body: '');
        _slideBodyController.text = '';
      }
    });
  }

  void _nudgeLayer(int index, int delta) {
    if (_slides.isEmpty || selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    final layers = [..._slides[selectedSlideIndex].layers];
    final target = (index + delta).clamp(0, layers.length - 1);
    if (target == index) return;
    setState(() {
      final layer = layers.removeAt(index);
      layers.insert(target, layer);
      _applyLayerUpdate(layers, triggerSetState: false);
    });
  }

  void _applyLayerUpdate(List<_SlideLayer> layers, {int? slideIndex, bool triggerSetState = true}) {
    void apply() {
      final idx = slideIndex ?? selectedSlideIndex;
      if (idx < 0 || idx >= _slides.length) return;
      final slide = _slides[idx].copyWith(layers: layers);
      final bg = _backgroundLayerFor(slide);
      final hasMediaLayer = layers.any((l) => l.kind == _LayerKind.media);
      final updated = slide.copyWith(
        mediaPath: hasMediaLayer ? bg?.path : null,
        mediaType: hasMediaLayer ? bg?.mediaType : null,
      );
      _slides[idx] = updated;
      _updateSlideThumbnailFromLayers(idx);
    }

    if (triggerSetState) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<void> _showMediaPickerSheet() async {
    if (!mounted) return;
    final choice = await showDialog<_SlideMediaType>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          backgroundColor: bgMedium,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Add media', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          children: [
            _mediaOptionTile(
              icon: Icons.image_outlined,
              color: accentPink,
              label: 'Picture',
              onTap: () => Navigator.of(context).pop(_SlideMediaType.image),
            ),
            _mediaOptionTile(
              icon: Icons.videocam_outlined,
              color: accentBlue,
              label: 'Video',
              onTap: () => Navigator.of(context).pop(_SlideMediaType.video),
            ),
          ],
        );
      },
    );

    if (choice != null) {
      await _pickMediaForSlide(choice);
    }
  }

  Widget _mediaOptionTile({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withOpacity(0.18),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  Future<void> _pickMediaForSlide(_SlideMediaType type) async {
    if (kIsWeb) {
      _showSnack('Media picking not supported in web build');
      return;
    }
    if (_slides.isEmpty || selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    final result = await FilePicker.platform.pickFiles(type: type == _SlideMediaType.image ? FileType.image : FileType.video);
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;

    setState(() {
      final slide = _slides[selectedSlideIndex];
      final role = _defaultLayerRoleForSlide(slide);
      final newLayer = _SlideLayer(
        id: 'layer-${DateTime.now().millisecondsSinceEpoch}',
        label: _fileName(path),
        kind: _LayerKind.media,
        path: path,
        mediaType: type,
        role: role,
      );
      final updatedLayers = [...slide.layers, newLayer];
      _slides[selectedSlideIndex] = slide.copyWith(
        mediaPath: role == _LayerRole.background ? path : slide.mediaPath ?? path,
        mediaType: role == _LayerRole.background ? type : slide.mediaType ?? type,
        layers: updatedLayers,
      );
      _updateSlideThumbnailFromLayers(selectedSlideIndex);
    });
    _syncSlideEditors();
    _showSnack('Attached ${type == _SlideMediaType.image ? 'picture' : 'video'} to slide ${selectedSlideIndex + 1}');
  }

  void _clearSlideMedia() {
    if (_slides.isEmpty || selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    setState(() {
      _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(mediaPath: null, mediaType: null, layers: []);
      _slideThumbnails[selectedSlideIndex] = null;
    });
    _syncSlideEditors();
  }

  void _onGridPointerDown(PointerDownEvent event) {
    _requestSlidesFocus();
    final stackBox = _slidesStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    if (event.kind == PointerDeviceKind.mouse && event.buttons == kPrimaryButton) {
      final localPos = stackBox.globalToLocal(event.position);
      final hitTile = _slideRects.values.any((rect) => rect.contains(localPos));
      if (hitTile) return; // let drag/selection of tile handle it
      setState(() {
        _dragSelecting = true;
        _dragStart = localPos;
        _dragCurrent = localPos;
        selectedSlides = {};
      });
    }
  }

  void _maybeAutoscroll(RenderBox stackBox, double localDy) {
    if (!_slidesScrollController.hasClients) return;

    const double edgeThreshold = 32;
    const double scrollStep = 40;
    final height = stackBox.size.height;
    double? delta;

    if (localDy < edgeThreshold) {
      delta = -scrollStep;
    } else if (localDy > height - edgeThreshold) {
      delta = scrollStep;
    }

    if (delta == null) return;

    final position = _slidesScrollController.position;
    final target = _safeClamp(
      position.pixels + delta,
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) {
      _slidesScrollController.jumpTo(target);
    }
  }

  void _onGridPointerMove(PointerMoveEvent event) {
    if (!_dragSelecting || _dragStart == null) return;
    final stackBox = _slidesStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;
    final localPos = stackBox.globalToLocal(event.position);
    _maybeAutoscroll(stackBox, localPos.dy);
    setState(() {
      _dragCurrent = localPos;
    });
    _updateSelectionFromRect(Rect.fromPoints(_dragStart!, localPos));
  }

  void _onGridPointerUp(PointerUpEvent event) {
    if (!_dragSelecting) return;
    final stackBox = _slidesStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox != null && _dragStart != null) {
      final localPos = stackBox.globalToLocal(event.position);
      _updateSelectionFromRect(Rect.fromPoints(_dragStart!, localPos));
    }
    setState(() {
      _dragSelecting = false;
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  KeyEventResult _handleSlidesKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
      setState(() {
        selectedSlides = {for (int i = 0; i < _slides.length; i++) i};
        selectedSlideIndex = selectedSlides.isNotEmpty ? selectedSlides.first : 0;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  int _reorderTargetIndex({required int from, required int desiredInsertIndex}) {
    // desiredInsertIndex is the position to insert before (0..length) where length means append
    final clamped = _safeIntClamp(desiredInsertIndex, 0, _slides.length);
    if (from < clamped) return clamped - 1; // after removal, indices shift left
    return clamped;
  }

  Widget _buildSlidesCanvasOnly() {
    _ensureSlideKeys();

    return Focus(
      focusNode: _slidesFocusNode,
      autofocus: true,
      onKey: _handleSlidesKey,
      child: Stack(
        key: _slidesStackKey,
        children: [
          Positioned.fill(
            child: DragTarget<Object>(
              onWillAcceptWithDetails: (details) => details.data is _MediaEntry,
              onAcceptWithDetails: (details) {
                final data = details.data;
                if (data is _MediaEntry) {
                  _addMediaAsNewSlide(data);
                }
              },
              builder: (context, candidate, rejected) => const IgnorePointer(child: SizedBox.expand()),
            ),
          ),
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onGridPointerDown,
            onPointerMove: _onGridPointerMove,
            onPointerUp: _onGridPointerUp,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _slides.isEmpty
                      ? const Center(
                          child: Text('No slides', style: TextStyle(color: Colors.white54, fontSize: 18)),
                        )
                      : GridView.builder(
                          controller: _slidesScrollController,
                          padding: const EdgeInsets.fromLTRB(2, 2, 2, 56),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 6,
                            childAspectRatio: 4 / 3,
                          ),
                          itemCount: _slides.length,
                          itemBuilder: (context, i) {
                            final isSelected = selectedSlides.contains(i);
                            final key = _slideKeys[i];
                            _captureTileRect(i);
                            final isDragging = _draggingIndex == i;
                            final tile = GestureDetector(
                              key: key,
                              behavior: HitTestBehavior.opaque,
                              onSecondaryTapDown: (details) => _showSlideContextMenu(i, details),
                              onTap: () {
                                _requestSlidesFocus();
                                _selectSlide(i);
                              },
                              child: Opacity(
                                opacity: isDragging ? 0.35 : 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF182237),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isSelected ? accentPink : Colors.white12, width: isSelected ? 2 : 1),
                                    boxShadow: isSelected
                                        ? [const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))]
                                        : null,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_slides[i].title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Expanded(
                                        child: _renderSlidePreview(_slides[i], compact: true),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );

                            return Row(
                              children: [
                                _slideReorderDropZone(insertIndex: i, width: 6),
                                Expanded(
                                  child: DragTarget<Object>(
                                    onWillAcceptWithDetails: (details) {
                                      final data = details.data;
                                      if (data is int) return true;
                                      if (data is _MediaEntry) return true;
                                      return false;
                                    },
                                    onAcceptWithDetails: (details) {
                                      final data = details.data;
                                      if (data is int) {
                                        _moveSlide(data, i);
                                      } else if (data is _MediaEntry) {
                                        _addMediaToSlide(data, i);
                                      }
                                    },
                                    builder: (context, candidateData, rejectedData) {
                                      final isActive = candidateData.isNotEmpty;
                                      return Draggable<int>(
                                        data: i,
                                        dragAnchorStrategy: pointerDragAnchorStrategy,
                                        maxSimultaneousDrags: 1,
                                        onDragStarted: () => setState(() {
                                          _draggingIndex = i;
                                          _dragSelecting = false;
                                        }),
                                        onDragEnd: (_) => setState(() => _draggingIndex = null),
                                        feedback: Material(
                                          color: Colors.transparent,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints.tightFor(width: 180, height: 135),
                                            child: Opacity(opacity: 0.9, child: tile),
                                          ),
                                        ),
                                        childWhenDragging: const SizedBox.shrink(),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 120),
                                          decoration: isActive
                                              ? BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: accentPink.withOpacity(0.6), width: 2),
                                                )
                                              : null,
                                          child: tile,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                _slideReorderDropZone(insertIndex: i + 1, width: 6),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          if (_dragSelecting && _dragStart != null && _dragCurrent != null)
            Positioned.fromRect(
              rect: Rect.fromPoints(_dragStart!, _dragCurrent!),
              child: Container(
                decoration: BoxDecoration(
                  color: accentPink.withOpacity(0.12),
                  border: Border.all(color: accentPink.withOpacity(0.6), width: 1),
                ),
              ),
            ),
          Positioned(
            bottom: 6,
            left: 6,
            child: OutlinedButton.icon(
              onPressed: _addSlide,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New slide'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                backgroundColor: Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagePreviewCard() {
    return _frostedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Stage Preview'),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _slides.isEmpty
                ? _emptyStageBox('No slide')
                : _renderSlidePreview(_slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)]),
          ),
          const SizedBox(height: 10),
          const Text('Current layout ready', style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildMediaExplorerPanel() {
    return _frostedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader('Media Bin'),
              const Spacer(),
              _toolbarButton('UPLOAD', Icons.upload_file, _uploadVideo),
              const SizedBox(width: 8),
              _toolbarButton('YOUTUBE', Icons.smart_display_outlined, _addYouTubeLink),
            ],
          ),
          const SizedBox(height: 10),
          _buildYouTubeSearchBar(),
          const SizedBox(height: 10),
          Expanded(child: _buildSearchAndSaved()),
        ],
      ),
    );
  }

  Widget _frostedBox({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF152038),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: child,
    );
  }

  Widget _miniNavItem(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }

  Widget _topTab({required IconData icon, required String label, bool selected = false, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE0007A) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.white70),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerList(String title, List<FileSystemEntity> items, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2336),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentBlue),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Empty', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final name = items[i].path.split(Platform.pathSeparator).last;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(name, style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _drawerShowsList() {
    final visible = _filteredShows();
    final selectedShow = (selectedShowIndex != null &&
            selectedShowIndex! >= 0 &&
            selectedShowIndex! < shows.length)
        ? shows[selectedShowIndex!]
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2336),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.playlist_play, size: 16, color: Color(0xFFE0007A)),
                  SizedBox(width: 6),
                  Text('Shows', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    // Categories column
                    SizedBox(
                      width: 170,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            child: Text('Categories', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white70, fontSize: 12)),
                          ),
                          Expanded(
                            child: ListView(
                              children: [
                                InkWell(
                                  onTap: () => setState(() {
                                    selectedCategoryIndex = null;
                                    _clampSelectedShow();
                                  }),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selectedCategoryIndex == null ? Colors.white10 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.all_inclusive, size: 16, color: Colors.white70),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'All',
                                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(color: Colors.white10),
                                if (showCategories.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: Text('No categories yet', style: TextStyle(color: Colors.grey)),
                                    ),
                                  )
                                else
                                  ...List.generate(showCategories.length, (i) {
                                    final selected = selectedCategoryIndex == i;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: InkWell(
                                        onTap: () => setState(() {
                                          selectedCategoryIndex = i;
                                          _clampSelectedShow();
                                        }),
                                        onSecondaryTapDown: (details) => _showCategoryContextMenu(i, details),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: selected ? Colors.white10 : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.label_outline, size: 16, color: selected ? accentPink : Colors.white70),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  showCategories[i],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: selected ? Colors.white : Colors.white70,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _promptAddCategory,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('New category', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size.fromHeight(36),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Shows list column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: const [
                                Expanded(child: Text('Name', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white70)) ),
                                SizedBox(width: 12),
                                Text('Modified', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white70)),
                              ],
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 0.5, thickness: 0.5),
                          Expanded(
                            child: visible.isEmpty
                                ? const Center(child: Text('No shows yet', style: TextStyle(color: Colors.grey)))
                                : ListView.separated(
                                    itemCount: visible.length,
                                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                                    itemBuilder: (context, i) {
                                      final globalIndex = shows.indexOf(visible[i]);
                                      final selected = selectedShowIndex == globalIndex;
                                      return InkWell(
                                        onTap: () => setState(() => selectedShowIndex = globalIndex),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                          decoration: BoxDecoration(
                                            color: selected ? Colors.white10 : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  visible[i].name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: selected ? Colors.white : Colors.white70,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                '—',
                                                style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Metadata column
                    SizedBox(
                      width: 210,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2336),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: selectedShow == null
                            ? const Center(
                                child: Text('Select a show', style: TextStyle(color: Colors.white54)),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(selectedShow.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    _metaRow('Created', '—'),
                                    _metaRow('Modified', '—'),
                                    _metaRow('Used', '—'),
                                    _metaRow('Category', selectedShow.category ?? 'None'),
                                    _metaRow('Slides', _slides.length.toString()),
                                    _metaRow('Words', '—'),
                                    _metaRow('Template', '—'),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _promptAddShow,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New show'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Tab _drawerTab(IconData icon, String label) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(color: accentPink, size: 22),
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      width: 320,
      color: const Color(0xFF182237),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewPane(),
            const SizedBox(height: 12),
            _buildLayerTimeline(),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  onPressed: _prevSlide,
                  icon: const Icon(Icons.chevron_left, size: 18, color: Colors.white70),
                  tooltip: 'Previous slide',
                ),
                IconButton(
                  onPressed: _nextSlide,
                  icon: const Icon(Icons.chevron_right, size: 18, color: Colors.white70),
                  tooltip: 'Next slide',
                ),
                const Spacer(),
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 18, color: Colors.white70),
                  tooltip: isPlaying ? 'Pause' : 'Play',
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => setState(() => isLocked = !isLocked),
                  icon: Icon(isLocked ? Icons.lock : Icons.lock_open, size: 18, color: Colors.white70),
                  tooltip: isLocked ? 'Unlock' : 'Lock',
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => setState(() => isBroadcastOn = !isBroadcastOn),
                  icon: Icon(isBroadcastOn ? Icons.wifi_tethering : Icons.wifi_tethering_off, size: 18, color: Colors.white70),
                  tooltip: isBroadcastOn ? 'Stop broadcast' : 'Start broadcast',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: autoAdvanceEnabled,
                  activeThumbColor: accentPink,
                  onChanged: (v) {
                    setState(() => autoAdvanceEnabled = v);
                    if (v && isPlaying) {
                      _restartAutoAdvanceTimer();
                    } else {
                      _cancelAutoAdvanceTimer();
                    }
                  },
                ),
                const SizedBox(width: 6),
                const Text('Auto-advance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                Text('${autoAdvanceInterval.inSeconds}s', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: autoAdvanceInterval.inSeconds.toDouble(),
                    min: 3,
                    max: 30,
                    divisions: 27,
                    activeColor: accentPink,
                    onChanged: (v) {
                      setState(() => autoAdvanceInterval = Duration(seconds: v.round()));
                      if (isPlaying && autoAdvanceEnabled) {
                        _restartAutoAdvanceTimer();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _frostedBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Groups', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Divider(color: Colors.white12),
                  SizedBox(height: 50, child: Center(child: Text('No groups', style: TextStyle(color: Colors.white54)))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildShowsMetaPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPane() {
    if (_slides.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(12),
        child: const Center(
          child: Text('No slides', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final safeIndex = _safeIntClamp(selectedSlideIndex, 0, _slides.length - 1);
    final slideName = _slides[safeIndex].title;
    final thumb = _slideThumbnails.isNotEmpty && safeIndex < _slideThumbnails.length ? _slideThumbnails[safeIndex] : null;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(slideName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: _renderSlidePreview(_slides[safeIndex]),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerTimeline() {
    if (_slides.isEmpty || selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) {
      return _frostedBox(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Layer Stack', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('No slide selected', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final slide = _slides[selectedSlideIndex];
    if (slide.layers.isEmpty && slide.mediaPath != null && slide.mediaType != null && !_hydratedLayerSlides.contains(slide.id)) {
      _hydrateLegacyLayers(selectedSlideIndex);
    }
    final layers = slide.layers;

    return _frostedBox(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.layers, size: 16, color: Colors.white70),
                SizedBox(width: 8),
                Text('Layer Stack', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            if (layers.isEmpty)
              const Text('No media layers yet.', style: TextStyle(color: Colors.white54, fontSize: 12))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: layers.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 10),
                itemBuilder: (context, index) {
                  final layer = layers[index];
                  final roleLabel = layer.role == _LayerRole.background ? 'Background' : 'Foreground';
                  final typeLabel = _layerKindLabel(layer);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            layer.role == _LayerRole.background ? accentBlue.withOpacity(0.2) : accentPink.withOpacity(0.2),
                        child: Icon(
                          _layerIcon(layer),
                          size: 16,
                          color: layer.role == _LayerRole.background ? accentBlue : accentPink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(layer.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('$roleLabel • $typeLabel', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text('Added ${layer.addedAt.toLocal()}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Move up',
                            icon: const Icon(Icons.arrow_upward, color: Colors.white54, size: 18),
                            onPressed: index > 0 ? () => _nudgeLayer(index, -1) : null,
                          ),
                          IconButton(
                            tooltip: 'Move down',
                            icon: const Icon(Icons.arrow_downward, color: Colors.white54, size: 18),
                            onPressed: index < layers.length - 1 ? () => _nudgeLayer(index, 1) : null,
                          ),
                          IconButton(
                            tooltip: 'Delete layer',
                            icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 18),
                            onPressed: () => _deleteLayer(layer.id),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _nextSlide() {
    if (_slides.isEmpty) return;
    setState(() {
      selectedSlideIndex = (selectedSlideIndex + 1) % _slides.length;
      selectedSlides = {selectedSlideIndex};
    });
    _restartAutoAdvanceTimer();
  }

  void _prevSlide() {
    if (_slides.isEmpty) return;
    setState(() {
      selectedSlideIndex = (selectedSlideIndex - 1 + _slides.length) % _slides.length;
      selectedSlides = {selectedSlideIndex};
    });
    _restartAutoAdvanceTimer();
  }

  void _togglePlayPause() {
    setState(() {
      isPlaying = !isPlaying;
    });
    if (isPlaying && autoAdvanceEnabled) {
      _restartAutoAdvanceTimer();
    } else {
      _cancelAutoAdvanceTimer();
    }
  }

  void _restartAutoAdvanceTimer() {
    _cancelAutoAdvanceTimer();
    if (!isPlaying || !autoAdvanceEnabled || _slides.isEmpty) return;
    _autoAdvanceTimer = Timer(autoAdvanceInterval, () {
      if (!mounted) return;
      _nextSlide();
    });
  }

  void _cancelAutoAdvanceTimer() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }

  void _addSlide() {
    _syncSlideThumbnails();
    setState(() {
      final newIndex = _slides.length + 1;
      _slides = [
        ..._slides,
        _SlideContent(
          id: 'slide-${DateTime.now().millisecondsSinceEpoch}',
          title: 'New Slide $newIndex',
          body: 'Edit me',
          templateId: _templates.first.id,
        ),
      ];
      _slideThumbnails = [..._slideThumbnails, null];
      selectedSlideIndex = _slides.length - 1;
      selectedSlides = {selectedSlideIndex};
    });
    _syncSlideEditors();
  }

  Future<void> _showSlideContextMenu(int index, TapDownDetails details) async {
    _requestSlidesFocus();
    if (!selectedSlides.contains(index)) {
      setState(() {
        selectedSlideIndex = index;
        selectedSlides = {index};
      });
    }

    final activeSelection = selectedSlides.isNotEmpty ? selectedSlides : {index};
    final selectionList = activeSelection.toList()..sort();
    final selectionCount = selectionList.length;

    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
        Offset.zero & overlayBox.size,
      ),
      items: [
        PopupMenuItem(
          value: 'edit',
          enabled: selectionCount == 1,
          child: Text(selectionCount == 1 ? 'Edit slide' : 'Edit (select one)'),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(selectionCount > 1 ? 'Delete $selectionCount slides' : 'Delete slide'),
        ),
      ],
    );

    switch (selection) {
      case 'edit':
        await _promptRenameSlide(selectionList.first);
        break;
      case 'delete':
        _deleteSlides(activeSelection);
        break;
      default:
        break;
    }
  }

  Future<void> _promptRenameSlide(int index) async {
    if (index < 0 || index >= _slides.length) return;
    final controller = TextEditingController(text: _slides[index].title);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgMedium,
          title: const Text('Edit slide'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Slide title'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Save')),
          ],
        );
      },
    );
    final newName = result?.trim();
    if (newName == null || newName.isEmpty) return;

    setState(() {
      _slides[index] = _slides[index].copyWith(title: newName);
      selectedSlideIndex = index;
      selectedSlides = {index};
    });
  }

  void _seedDefaultCategories() {
    if (showCategories.isEmpty) {
      showCategories = ['Presentations', 'Songs'];
    }
  }

  void _ensureShowItems() {
    // Placeholder: ensures show list is initialized; items are already typed.
  }

  void _removeCategoryAt(int index) {
    if (index < 0 || index >= showCategories.length) return;
    setState(() {
      showCategories.removeAt(index);
      if (selectedCategoryIndex != null) {
        if (showCategories.isEmpty) {
          selectedCategoryIndex = null;
        } else if (selectedCategoryIndex! == index) {
          selectedCategoryIndex = null;
        } else if (selectedCategoryIndex! > index) {
          selectedCategoryIndex = selectedCategoryIndex! - 1;
        }
      }
      _clampSelectedShow();
    });
  }

  Future<void> _showCategoryContextMenu(int index, TapDownDetails details) async {
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
        Offset.zero & overlayBox.size,
      ),
      items: const [
        PopupMenuItem(value: 'delete', child: Text('Delete category')),
      ],
    );

    if (action == 'delete') {
      _removeCategoryAt(index);
    }
  }

  List<ShowItem> _filteredShows() {
    _ensureShowItems();
    if (selectedCategoryIndex == null) return shows;
    if (selectedCategoryIndex != null && selectedCategoryIndex! < showCategories.length) {
      final cat = showCategories[selectedCategoryIndex!];
      return shows.where((s) => s.category == cat).toList();
    }
    return shows;
  }

  String? _selectedCategoryName() {
    if (selectedCategoryIndex == null) return null;
    if (selectedCategoryIndex! >= 0 && selectedCategoryIndex! < showCategories.length) {
      return showCategories[selectedCategoryIndex!];
    }
    return null;
  }

  void _clampSelectedShow() {
    final visible = _filteredShows();
    if (visible.isEmpty) {
      selectedShowIndex = null;
      return;
    }
    if (selectedShowIndex == null || selectedShowIndex! >= shows.length) {
      selectedShowIndex = shows.indexOf(visible.first);
    } else {
      final current = selectedShowIndex!;
      if (!visible.contains(shows[current])) {
        selectedShowIndex = shows.indexOf(visible.first);
      }
    }
  }

  Future<void> _promptAddShow() async {
    final controller = TextEditingController();
    final existingCategory = _selectedCategoryName() ?? '';
    final categoryController = TextEditingController(text: existingCategory);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgMedium,
          title: const Text('New show'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Show name'),
                onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category (optional)'),
                onSubmitted: (_) {},
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Create')),
          ],
        );
      },
    );

    final name = result?.trim();
    if (name == null || name.isEmpty) return;
    final cat = categoryController.text.trim().isEmpty ? null : categoryController.text.trim();
    setState(() {
      if (cat != null && !showCategories.contains(cat)) {
        showCategories = [...showCategories, cat];
        selectedCategoryIndex ??= showCategories.length - 1;
      }
      final newItem = ShowItem(name: name, category: cat);
      shows = [...shows, newItem];
      selectedShowIndex = shows.length - 1;
    });
    _clampSelectedShow();
  }

  Future<void> _promptAddCategory() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgMedium,
          title: const Text('New category'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category name'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Create')),
          ],
        );
      },
    );

    final name = result?.trim();
    if (name == null || name.isEmpty) return;
    setState(() {
      if (!showCategories.contains(name)) {
        showCategories = [...showCategories, name];
        selectedCategoryIndex = showCategories.indexOf(name);
      }
    });
  }

  Future<void> _promptAddPlaylist() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgMedium,
          title: const Text('New playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Playlist name'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Create')),
          ],
        );
      },
    );

    final name = result?.trim();
    if (name == null || name.isEmpty) return;
    setState(() {
      playlists = [...playlists, name];
      selectedPlaylist = playlists.length - 1;
    });
  }

  Future<void> _promptAddMediaFolder() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgMedium,
          title: const Text('Add folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Folder name'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Create')),
          ],
        );
      },
    );

    final name = result?.trim();
    if (name == null || name.isEmpty) return;
    setState(() {
      playlists = [...playlists, name];
    });
  }

  void _deleteSlides(Set<int> indices) {
    if (indices.isEmpty) return;
    final sorted = indices.where((i) => i >= 0 && i < _slides.length).toList()..sort();
    if (sorted.isEmpty) return;

    setState(() {
      for (final idx in sorted.reversed) {
        _slides.removeAt(idx);
        _slideThumbnails.removeAt(idx);
      }
      selectedSlides = selectedSlides.where((i) => i < _slides.length).toSet();
      if (selectedSlides.isEmpty && _slides.isNotEmpty) {
        selectedSlides = {_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)};
      }
      if (_slides.isEmpty) {
        selectedSlideIndex = 0;
      } else {
        final next = selectedSlides.isNotEmpty ? (selectedSlides.toList()..sort()).first : 0;
        selectedSlideIndex = _safeIntClamp(next, 0, _slides.length - 1);
      }
    });
    _syncSlideEditors();
  }

  void _openSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgMedium,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.build_outlined),
                    const SizedBox(width: 8),
                    const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                _settingsFolderTile('Video Folder', videoFolder, 'video_folder'),
                _settingsFolderTile('Song Folder', songFolder, 'song_folder'),
                _settingsFolderTile('Lyrics Folder', lyricsFolder, 'lyrics_folder'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    _scanLibraries();
                    Navigator.pop(context);
                  },
                  child: const Text('Rescan Libraries'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _settingsTile({required String title, required String value, required String hint, required ValueChanged<String> onSubmit}) {
    final controller = TextEditingController(text: value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: title,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFF1A2336),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: onSubmit,
      ),
    );
  }

  Widget _settingsFolderTile(String label, String? path, String key) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      subtitle: Text(path ?? 'Not Set', style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1),
      trailing: const Icon(Icons.folder_open, size: 18),
      onTap: () => _pickLibraryFolder(key),
    );
  }

  Widget _sectionHeader(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(t, style: TextStyle(color: accentBlue, fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Future<void> _promptNewProjectMenu() async {
    final buttonContext = _newProjectButtonKey.currentContext;
    final overlay = Overlay.of(context);
    if (buttonContext == null) return;

    final box = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final offset = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    const menuWidth = 170.0;
    const menuHeight = 200.0; // approximate; we only use for positioning
    const gap = 6.0;

    final left = _safeClamp(
      offset.dx + box.size.width / 2 - menuWidth / 2,
      8.0,
      overlayBox.size.width - menuWidth - 8.0,
    );
    final top = _safeClamp(
      offset.dy - menuHeight - gap,
      8.0,
      overlayBox.size.height - menuHeight - 8.0,
    );

    final position = RelativeRect.fromLTRB(
      left,
      top,
      overlayBox.size.width - left - menuWidth,
      overlayBox.size.height - top - menuHeight,
    );

    final selection = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: const [
        PopupMenuItem(value: 'playlist', child: Text('Playlist')),
        PopupMenuItem(value: 'show', child: Text('Show')),
        PopupMenuItem(value: 'folder', child: Text('Folder')),
        PopupMenuItem(value: 'project', child: Text('Project')),
      ],
    );

    switch (selection) {
      case 'playlist':
        await _promptAddPlaylist();
        break;
      case 'show':
        await _promptAddShow();
        break;
      case 'folder':
        // Placeholder: hook up real folder creation later
        _showSnack('Folder creation coming soon');
        break;
      case 'project':
        // Placeholder: hook up real project creation later
        _showSnack('Project creation coming soon');
        break;
      default:
        break;
    }
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Text(value.isEmpty ? '—' : value, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _selectableRow({required IconData icon, required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton(String label, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: accentBlue),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }

  _SlideTemplate _templateFor(String id) {
    return _templates.firstWhere((t) => t.id == id, orElse: () => _templates.first);
  }

  Widget _renderSlidePreview(_SlideContent slide, {bool compact = false}) {
    final template = _templateFor(slide.templateId);
    final align = slide.alignOverride ?? template.alignment;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resolvedBox = _resolvedBoxRect(slide);
          final baseFontSize = (slide.fontSizeOverride ?? template.fontSize) * (compact ? 0.6 : 1.0);
          final fontSize = _autoSizedFont(slide, baseFontSize, resolvedBox);
          final textStyle = TextStyle(
            color: slide.textColorOverride ?? template.textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.3,
          );

          final boxLeft = resolvedBox.left * constraints.maxWidth;
          final boxTop = resolvedBox.top * constraints.maxHeight;
          final boxWidth = resolvedBox.width * constraints.maxWidth;
          final boxHeight = resolvedBox.height * constraints.maxHeight;

          return Stack(
            children: [
              Positioned.fill(
                child: _applyFilters(_buildSlideBackground(slide, template, compact: compact), slide),
              ),
              if (_foregroundLayerFor(slide) != null)
                Positioned.fill(
                  child: _buildLayerWidget(_foregroundLayerFor(slide)!, compact: compact, fit: BoxFit.contain),
                ),
              Positioned(
                left: boxLeft,
                top: boxTop,
                width: boxWidth,
                height: boxHeight,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  alignment: _textAlignToAlignment(align),
                  child: Text(
                    slide.body,
                    textAlign: align,
                    style: textStyle,
                    maxLines: compact ? 6 : 12,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (slide.overlayNote != null && slide.overlayNote!.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: template.overlayAccent.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      slide.overlayNote!,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 10),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSlideBackground(_SlideContent slide, _SlideTemplate template, {bool compact = false}) {
    final fallbackBg = slide.backgroundColor ?? template.background;
    final overlay = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(compact ? 0.15 : 0.2), Colors.black.withOpacity(compact ? 0.05 : 0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );

    final bgLayer = _backgroundLayerFor(slide);
    final mediaPath = bgLayer?.path ?? slide.mediaPath;
    final mediaType = bgLayer?.mediaType ?? slide.mediaType;

    if (mediaPath == null || mediaPath.isEmpty || mediaType == null) {
      return Stack(fit: StackFit.expand, children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [fallbackBg, Color.lerp(fallbackBg, Colors.black, 0.12)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        overlay,
      ]);
    }

    if (kIsWeb) {
      return Stack(fit: StackFit.expand, children: [
        Container(color: fallbackBg),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mediaType == _SlideMediaType.image ? Icons.image_outlined : Icons.video_library_outlined,
                  color: Colors.white70, size: compact ? 28 : 40),
              const SizedBox(height: 6),
              Text('Media preview unsupported on web', style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
        overlay,
      ]);
    }

    final file = File(mediaPath);
    if (mediaType == _SlideMediaType.image && file.existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(file, fit: BoxFit.cover),
          overlay,
        ],
      );
    }

    if (mediaType == _SlideMediaType.video && file.existsSync()) {
      final name = _fileName(mediaPath);
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [fallbackBg, Colors.black.withOpacity(0.55)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.smart_display, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 8),
                Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          overlay,
        ],
      );
    }

    return Stack(fit: StackFit.expand, children: [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [fallbackBg, Color.lerp(fallbackBg, Colors.black, 0.12)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      overlay,
    ]);
  }

  Widget _buildLayerWidget(_SlideLayer layer, {bool compact = false, BoxFit fit = BoxFit.contain}) {
    if (layer.kind == _LayerKind.media && layer.path != null) {
      final file = File(layer.path!);
      if (layer.mediaType == _SlideMediaType.image && file.existsSync()) {
        return IgnorePointer(
          child: Image.file(
            file,
            fit: fit,
            opacity: AlwaysStoppedAnimation(compact ? 0.9 : 1.0),
          ),
        );
      }
    }

    final icon = _layerIcon(layer);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: compact ? 26 : 40),
          const SizedBox(height: 6),
          Text(layer.label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Rect _resolvedBoxRect(_SlideContent slide) {
    const defaultBox = Rect.fromLTWH(0.1, 0.18, 0.8, 0.64);
    final left = slide.boxLeft ?? defaultBox.left;
    final top = slide.boxTop ?? defaultBox.top;
    final width = slide.boxWidth ?? defaultBox.width;
    final height = slide.boxHeight ?? defaultBox.height;
    return Rect.fromLTWH(
      _safeClamp(left, 0, 1).toDouble(),
      _safeClamp(top, 0, 1).toDouble(),
      _safeClamp(width, 0.08, 1),
      _safeClamp(height, 0.08, 1),
    );
  }

  double _autoSizedFont(_SlideContent slide, double base, Rect box) {
    if (slide.autoSize != true) return base;
    final lineCount = slide.body.split('\n').length;
    final charCount = slide.body.length.clamp(1, 4000);
    final areaFactor = (box.width * box.height).clamp(0.2, 1.0);
    double scale = 1.0;
    if (lineCount > 4) scale -= 0.08;
    if (lineCount > 8) scale -= 0.12;
    scale -= (charCount / 1200) * 0.12;
    scale *= areaFactor;
    return base * _safeClamp(scale, 0.35, 1.0);
  }

  Alignment _textAlignToAlignment(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.center:
      default:
        return Alignment.center;
    }
  }

  Widget _slideThumbOrPlaceholder(String? url, {required String label}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.white12),
        ),
        child: () {
          if (url == null || url.isEmpty) {
            return Center(child: Text(label, style: const TextStyle(color: Colors.white54)));
          }

          final isHttp = url.startsWith('http://') || url.startsWith('https://');
          if (!kIsWeb && !isHttp) {
            final file = File(url);
            if (file.existsSync()) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(child: Text(label, style: const TextStyle(color: Colors.white54))),
                    ),
                  ),
                  _thumbLabel(label),
                ],
              );
            }
          }

          if (isHttp) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(child: Text(label, style: const TextStyle(color: Colors.white54))),
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : Center(child: Text(label, style: const TextStyle(color: Colors.white54))),
                  ),
                ),
                _thumbLabel(label),
              ],
            );
          }

          return Center(child: Text(label, style: const TextStyle(color: Colors.white54)));
        }(),
      ),
    );
  }

  Positioned _thumbLabel(String label) {
    return Positioned(
      left: 6,
      bottom: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _slideReorderDropZone({required int insertIndex, required double width}) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        return data is int && data >= 0 && data < _slides.length;
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is int) {
          final target = _reorderTargetIndex(from: data, desiredInsertIndex: insertIndex);
          _moveSlide(data, target);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(vertical: 6),
          width: width,
          decoration: BoxDecoration(
            color: active ? accentPink.withOpacity(0.35) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }
}

class _GridNoisePainter extends CustomPainter {
  _GridNoisePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const double step = 14;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridNoisePainter oldDelegate) => oldDelegate.color != color;
}

class _SlideTemplate {
  _SlideTemplate({
    required this.id,
    required this.name,
    required this.textColor,
    required this.background,
    required this.overlayAccent,
    required this.fontSize,
    required this.alignment,
  });

  final String id;
  final String name;
  final Color textColor;
  final Color background;
  final Color overlayAccent;
  final double fontSize;
  final TextAlign alignment;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'textColor': textColor.value,
        'background': background.value,
        'overlayAccent': overlayAccent.value,
        'fontSize': fontSize,
        'alignment': alignment.name,
      };

  factory _SlideTemplate.fromJson(Map<String, dynamic> json) {
    return _SlideTemplate(
      id: json['id'] ?? 'default',
      name: json['name'] ?? 'Default',
      textColor: Color(json['textColor'] ?? Colors.white.value),
      background: Color(json['background'] ?? const Color(0xFF0F172A).value),
      overlayAccent: Color(json['overlayAccent'] ?? const Color(0xFFE0007A).value),
      fontSize: (json['fontSize'] ?? 38).toDouble(),
      alignment: TextAlign.values.firstWhere(
        (e) => e.name == (json['alignment'] ?? 'center'),
        orElse: () => TextAlign.center,
      ),
    );
  }
}

class _SlideContent {
  _SlideContent({
    required this.id,
    required this.title,
    required this.body,
    required this.templateId,
    this.overlayNote,
    this.autoAdvanceSeconds,
    this.fontSizeOverride,
    this.textColorOverride,
    this.alignOverride,
    this.boxLeft,
    this.boxTop,
    this.boxWidth,
    this.boxHeight,
    this.autoSize,
    this.backgroundColor,
    this.hueRotate,
    this.invert,
    this.blur,
    this.brightness,
    this.contrast,
    this.saturate,
    this.mediaPath,
    this.mediaType,
    List<_SlideLayer>? layers,
  }) : layers = layers ?? const [];

  final String id;
  String title;
  String body;
  String templateId;
  String? overlayNote;
  int? autoAdvanceSeconds;
  double? fontSizeOverride;
  Color? textColorOverride;
  TextAlign? alignOverride;
  double? boxLeft;
  double? boxTop;
  double? boxWidth;
  double? boxHeight;
  bool? autoSize;
  Color? backgroundColor;
  double? hueRotate;
  double? invert;
  double? blur;
  double? brightness;
  double? contrast;
  double? saturate;
  String? mediaPath;
  _SlideMediaType? mediaType;
  List<_SlideLayer> layers;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'templateId': templateId,
        'overlayNote': overlayNote,
        'autoAdvanceSeconds': autoAdvanceSeconds,
        'fontSizeOverride': fontSizeOverride,
        'textColorOverride': textColorOverride?.value,
        'alignOverride': alignOverride?.name,
        'boxLeft': boxLeft,
        'boxTop': boxTop,
        'boxWidth': boxWidth,
        'boxHeight': boxHeight,
        'autoSize': autoSize,
        'backgroundColor': backgroundColor?.value,
        'hueRotate': hueRotate,
        'invert': invert,
        'blur': blur,
        'brightness': brightness,
        'contrast': contrast,
        'saturate': saturate,
        'mediaPath': mediaPath,
        'mediaType': mediaType?.name,
        'layers': layers.map((l) => l.toJson()).toList(),
      };

  _SlideContent copyWith({
    String? id,
    String? title,
    String? body,
    String? templateId,
    String? overlayNote,
    int? autoAdvanceSeconds,
    double? fontSizeOverride,
    Color? textColorOverride,
    TextAlign? alignOverride,
    double? boxLeft,
    double? boxTop,
    double? boxWidth,
    double? boxHeight,
    bool? autoSize,
    Color? backgroundColor,
    double? hueRotate,
    double? invert,
    double? blur,
    double? brightness,
    double? contrast,
    double? saturate,
    String? mediaPath,
    _SlideMediaType? mediaType,
    List<_SlideLayer>? layers,
  }) {
    return _SlideContent(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      templateId: templateId ?? this.templateId,
      overlayNote: overlayNote ?? this.overlayNote,
      autoAdvanceSeconds: autoAdvanceSeconds ?? this.autoAdvanceSeconds,
      fontSizeOverride: fontSizeOverride ?? this.fontSizeOverride,
      textColorOverride: textColorOverride ?? this.textColorOverride,
      alignOverride: alignOverride ?? this.alignOverride,
      boxLeft: boxLeft ?? this.boxLeft,
      boxTop: boxTop ?? this.boxTop,
      boxWidth: boxWidth ?? this.boxWidth,
      boxHeight: boxHeight ?? this.boxHeight,
      autoSize: autoSize ?? this.autoSize,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      hueRotate: hueRotate ?? this.hueRotate,
      invert: invert ?? this.invert,
      blur: blur ?? this.blur,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturate: saturate ?? this.saturate,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      layers: layers ?? this.layers,
    );
  }

  factory _SlideContent.fromJson(Map<String, dynamic> json) {
    return _SlideContent(
      id: json['id'],
      title: json['title'] ?? 'Slide',
      body: json['body'] ?? '',
      templateId: json['templateId'] ?? 'default',
      overlayNote: json['overlayNote'],
      autoAdvanceSeconds: json['autoAdvanceSeconds'],
      fontSizeOverride: (json['fontSizeOverride'] as num?)?.toDouble(),
      textColorOverride: json['textColorOverride'] != null ? Color(json['textColorOverride']) : null,
      alignOverride: json['alignOverride'] != null
          ? TextAlign.values.firstWhere(
              (e) => e.name == json['alignOverride'],
              orElse: () => TextAlign.center,
            )
          : null,
      boxLeft: (json['boxLeft'] as num?)?.toDouble(),
      boxTop: (json['boxTop'] as num?)?.toDouble(),
      boxWidth: (json['boxWidth'] as num?)?.toDouble(),
      boxHeight: (json['boxHeight'] as num?)?.toDouble(),
      autoSize: json['autoSize'] as bool?,
      backgroundColor: json['backgroundColor'] != null ? Color(json['backgroundColor']) : null,
      hueRotate: (json['hueRotate'] as num?)?.toDouble(),
      invert: (json['invert'] as num?)?.toDouble(),
      blur: (json['blur'] as num?)?.toDouble(),
      brightness: (json['brightness'] as num?)?.toDouble(),
      contrast: (json['contrast'] as num?)?.toDouble(),
      saturate: (json['saturate'] as num?)?.toDouble(),
      mediaPath: json['mediaPath'] as String?,
      mediaType: json['mediaType'] != null
          ? _SlideMediaType.values.firstWhere(
              (e) => e.name == json['mediaType'],
              orElse: () => _SlideMediaType.image,
            )
          : null,
      layers: (json['layers'] as List?)
              ?.map((e) => _SlideLayer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}