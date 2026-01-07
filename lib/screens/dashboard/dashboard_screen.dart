library dashboard_screen;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui'
    show
        PointerDeviceKind,
        ImageFilter,
        FontFeature,
        Rect,
        Offset;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' as math;
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:just_audio/just_audio.dart' as ja;
import '../../core/theme/palette.dart';
import '../../core/utils/debouncer.dart';
import '../../services/scripture_service.dart';
import '../../services/device_service.dart';
import '../../services/win32_capture_service.dart';

part 'models/layer_models.dart';
part 'models/slide_models.dart';
part 'helpers/render_helpers.dart';
part 'widgets/view_widgets.dart';
part 'widgets/slide_editor_widgets.dart';
part 'services/output_window_service.dart';

class ShowItem {
  ShowItem({required this.name, this.category});
  String name;
  String? category;
}

enum MediaFilter { all, online, screens, cameras, ndi }

enum OnlineSource { all, youtube, youtubeMusic, vimeo }

enum _OutputDestination { screen, ndi, virtual }

enum _OutputStyleProfile { audienceFull, streamLowerThird, stageNotes }

enum _SettingsTab {
  general,
  outputs,
  styles,
  connection,
  files,
  profiles,
  theme,
  other,
}

class _LiveDevice {
  _LiveDevice({
    required this.id,
    required this.name,
    required this.detail,
    this.thumbnail,
    this.isActive = true,
  });
  final String id;
  final String name;
  final String detail;
  final Uint8List? thumbnail;
  final bool isActive;

  _LiveDevice copyWithThumbnail(Uint8List? newThumbnail) {
    return _LiveDevice(
      id: id,
      name: name,
      detail: detail,
      thumbnail: newThumbnail,
      isActive: isActive,
    );
  }
}

class _NdiSource {
  _NdiSource({
    required this.id,
    required this.name,
    required this.url,
    this.thumbnail,
    this.isOnline = true,
  });
  final String id;
  final String name;
  final String url;
  final Uint8List? thumbnail;
  final bool isOnline;

  _NdiSource copyWithThumbnail(Uint8List? newThumbnail) {
    return _NdiSource(
      id: id,
      name: name,
      url: url,
      thumbnail: newThumbnail,
      isOnline: isOnline,
    );
  }
}

class _MediaEntry {
  _MediaEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.tint,
    this.subtitle,
    this.badge,
    this.thumbnailUrl,
    this.thumbnailBytes,
    this.isLive = false,
    this.onlineSource = OnlineSource.all,
  });

  final String id;
  final String title;
  final String? subtitle;
  final MediaFilter category;
  final IconData icon;
  final Color tint;
  final bool isLive;
  final String? badge;
  final String? thumbnailUrl;
  final Uint8List? thumbnailBytes;
  final OnlineSource onlineSource;
}

class _VideoControllerEntry {
  _VideoControllerEntry({required this.controller, required this.initialize});
  final VideoPlayerController controller;
  final Future<void> initialize;
}

class _MiniNavAction {
  const _MiniNavAction({
    required this.label,
    required this.onSelected,
    this.icon,
    this.shortcut,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
  final String? shortcut;
  final bool enabled;
}

class _StageElement {
  const _StageElement({required this.id, required this.kind, this.label});
  final String id;
  final String kind;
  final String? label;
}

class _StageLayout {
  const _StageLayout({
    required this.id,
    required this.name,
    this.elements = const [],
  });
  final String id;
  final String name;
  final List<_StageElement> elements;

  _StageLayout copyWith({
    String? id,
    String? name,
    List<_StageElement>? elements,
  }) {
    return _StageLayout(
      id: id ?? this.id,
      name: name ?? this.name,
      elements: elements ?? this.elements,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const double _minBoxFraction = 0.05;
  static const double _overflowAllowance =
      0.5; // allow dragging/resizing farther off-canvas
  static const double _snapTolerancePx = 10;
  static const double _resizeHandleSize =
      46; // larger hit target for easier grab
  static const double _resizeDampening =
      0.35; // reduce per-move delta so cursor matches movement

  // Performance optimization: Debouncer for multi-window communication
  // Limits output updates to every 16ms (~60fps) to prevent UI jank
  final Debouncer _outputDebouncer = Debouncer(
    duration: const Duration(milliseconds: 16),
  );
  final Throttler _outputThrottler = Throttler(
    duration: const Duration(milliseconds: 32),
  );

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
  final GlobalKey _fileNavKey = GlobalKey();
  final GlobalKey _editNavKey = GlobalKey();
  final GlobalKey _viewNavKey = GlobalKey();
  final GlobalKey _helpNavKey = GlobalKey();

  // Theme Colors (mutable to support theme presets)
  Color bgDark = AppPalette.carbonBlack;
  Color bgMedium = AppPalette.carbonBlack;
  Color accentBlue = AppPalette.willowGreen; // slate accent
  Color accentPink = AppPalette.dustyMauve; // rust accent
  final GlobalKey _stageKey = GlobalKey();

  // Resizable panel state
  double _leftPaneWidth = 260;
  double _rightPaneWidth = 320;
  final double _minPaneWidth = 180;

  // Scripture state
  String _selectedBibleApi = 'bolls'; // 'bible-api' or 'bolls'
  String _selectedBibleVersion = 'KJV';
  String? _selectedBook;
  int? _selectedBookId; // For Bolls API (1-66)
  int? _selectedChapter;
  int? _selectedVerseStart;
  int? _selectedVerseEnd;
  final TextEditingController _scriptureSearchController =
      TextEditingController();
  List<Map<String, dynamic>> _scriptureSearchResults = [];
  bool _scriptureSearching = false;
  // FreeShow-style search state
  final Debouncer _scriptureSearchDebouncer = Debouncer(duration: const Duration(milliseconds: 100));
  bool _showScriptureSearchResults = false;
  List<Map<String, dynamic>> _loadedVerses = [];
  bool _loadingVerses = false;
  // Scroll controller for jump-to-verse functionality
  final ScrollController _versesScrollController = ScrollController();
  // Track if we're in the middle of autocomplete to avoid loops
  bool _isAutoCompleting = false;
  List<Map<String, dynamic>> _availableTranslations = [];
  bool _loadingTranslations = false;
  List<Map<String, dynamic>> _customBibleApiSources = []; // User-added custom APIs
  Map<String, List<Map<String, String>>> _customApiTranslations = {}; // Translations for custom APIs
  String _testamentFilter = 'all'; // 'all', 'OT', or 'NT'

  // Media and settings
  String? videoFolder;
  String? songFolder;
  String? lyricsFolder;
  String? saveFolder;
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

  // Lyrics tab state
  final TextEditingController _lyricsSearchController = TextEditingController();
  bool _lyricsSearching = false;
  String? _rawLyricsResult;
  String? _processedLyrics;
  final Map<String, _VideoControllerEntry> _videoControllers = {};

  // Audio tab state
  String _audioTabMode = 'files'; // 'files', 'playlists', 'effects', 'metronome'
  List<Map<String, dynamic>> _audioPlaylists = []; // User-created playlists
  String? _selectedPlaylistId;
  String? _currentlyPlayingAudioPath;
  bool _isAudioPlaying = false;
  bool _isAudioPaused = false;
  double _audioVolume = 1.0;
  double _audioPosition = 0.0;
  double _audioDuration = 0.0;
  bool _audioLoop = false;
  bool _audioShuffle = false;
  // Audio player instance
  ja.AudioPlayer? _audioPlayer;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration?>? _audioDurationSubscription;
  StreamSubscription<ja.PlayerState>? _audioPlayerStateSubscription;
  // Include video files in audio list
  bool _showVideoFilesInAudio = true;
  // Metronome state
  int _metronomeBpm = 120;
  int _metronomeBeatsPerMeasure = 4;
  bool _metronomeRunning = false;
  int _metronomeCurrentBeat = 0;

  // Stage layouts (Stage tab)
  List<_StageLayout> _stageLayouts = const [];
  String? _selectedStageLayoutId;

  // Output routing
  List<OutputConfig> _outputs = [];
  final Set<String> _armedOutputs = {};
  final Map<String, int> _outputWindowIds = {};
  final Set<String> _pendingOutputCreates = {};
  bool _isSendingOutputs = false;
  final Map<String, Map<String, dynamic>> _headlessOutputPayloads = {};
  bool outputsLocked = false;
  bool outputBackgroundActive = true;
  bool outputForegroundMediaActive = true;
  bool outputSlideActive = true;
  bool outputOverlayActive = true;
  bool outputAudioActive = true;
  bool outputTimerActive = false;

  // Presentation state (Show Output button)
  bool _isPresenting = false;
  bool _awaitingPresentStopConfirm = false;
  DateTime? _presentStopRequestedAt;
  final Duration _presentStopConfirmWindow = const Duration(seconds: 3);
  String outputTransition = 'fade';
  final Map<String, _OutputRuntimeState> _outputRuntime = {};
  bool outputPreviewCleared = false;
  final Map<String, bool> _outputPreviewVisible = {};

  // Settings state
  _SettingsTab _settingsTab = _SettingsTab.general;
  bool use24HourClock = false;
  bool disableLabels = false;
  bool showProjectsOnStartup = true;
  bool autoLaunchOutput = false;
  bool hideCursorInOutput = false;
  bool enableNdiOutput = false;
  bool enableRemoteShow = false;
  bool enableStageShow = true;
  bool enableControlShow = false;
  bool enableApiAccess = false;
  bool autoUpdates = true;
  bool alertOnUpdate = true;
  bool alertOnBeta = false;
  bool enableCloseConfirm = false;
  bool logSongUsage = false;
  bool autoErrorReporting = true;
  bool disableHardwareAcceleration = false;
  String selectedThemeName = 'Default';
  double lowerThirdHeight = 0.32;
  bool lowerThirdGradient = true;
  double stageNotesScale = 0.9;
  List<String> profiles = [];
  List<_StylePreset> _styles = [
    _StylePreset(
      id: 'audience',
      name: 'Audience Full',
      mediaFit: 'Contain',
      aspectRatio: '16:9',
      activeBackground: true,
      activeSlide: true,
      activeOverlays: true,
    ),
    _StylePreset(
      id: 'stream',
      name: 'Stream Lower Third',
      mediaFit: 'Contain',
      aspectRatio: '16:9',
      activeBackground: true,
      activeSlide: true,
      activeOverlays: true,
    ),
    _StylePreset(
      id: 'stage',
      name: 'Stage Notes',
      mediaFit: 'Contain',
      aspectRatio: '16:9',
      activeBackground: true,
      activeSlide: true,
      activeOverlays: false,
    ),
  ];

  // FreeShow-like scaffolding data (placeholder)
  List<ShowItem> shows = [];
  List<String> showCategories = [];
  List<String> playlists = [];
  List<String> projects = [];
  List<String> folders = [];
  final GlobalKey _newProjectButtonKey = GlobalKey();
  String? _hoverFontPreview;
  final List<String?> _recentFonts = [];

  // Slide + template model
  final List<_SlideTemplate> _templates = [
    _SlideTemplate(
      id: 'default',
      name: 'Default',
      textColor: Colors.white,
      background: AppPalette.carbonBlack,
      overlayAccent: AppPalette.dustyMauve,
      fontSize: 38,
      alignment: TextAlign.center,
    ),
    _SlideTemplate(
      id: 'notes',
      name: 'Notes',
      textColor: Colors.white,
      background: AppPalette.carbonBlack,
      overlayAccent: AppPalette.dustyRose,
      fontSize: 20,
      alignment: TextAlign.left,
    ),
  ];

  // Limited set of font families exposed for text layers; null uses the template default.
  final List<String?> _fontFamilies = [
    null,
    'Roboto',
    'Montserrat',
    'Oswald',
    'Lato',
    'Georgia',
    'Courier New',
  ];

  void _recordRecentFont(String? font) {
    setState(() {
      _recentFonts.remove(font);
      _recentFonts.insert(0, font);
      if (_recentFonts.length > 6) _recentFonts.removeLast();
    });
  }

  List<_SlideContent> _slides = [
    _SlideContent(
      id: 's1',
      title: 'Verse 1',
      body: 'Line 1\nLine 2',
      templateId: 'default',
    ),
    _SlideContent(
      id: 's2',
      title: 'Chorus',
      body: 'Chorus line',
      templateId: 'default',
    ),
    _SlideContent(
      id: 's3',
      title: 'Verse 2',
      body: 'Verse 2 lines',
      templateId: 'default',
    ),
    _SlideContent(
      id: 's4',
      title: 'Bridge',
      body: 'Bridge lines',
      templateId: 'default',
    ),
    _SlideContent(
      id: 's5',
      title: 'Tag',
      body: 'Tag line',
      templateId: 'default',
    ),
    _SlideContent(
      id: 's6',
      title: 'Outro',
      body: 'Outro',
      templateId: 'default',
    ),
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
  final List<_NdiSource> _ndiSources = [];
  Timer? _deviceThumbnailTimer;
  StreamSubscription<List<LiveDevice>>? _deviceServiceSubscription;
  String? _hoveredMediaId;
  String? _previewingMediaId;
  Timer? _previewTimer;
  Set<int> selectedSlides = {};
  bool _isInlineTextEditing = false;
  bool _dragSelecting = false;
  Offset? _dragStart;
  Offset? _dragCurrent;
  int? _draggingIndex;
  Rect? _boxDragStartRect;
  Offset? _boxDragStartPointer;
  bool _isBoxResizing = false;
  Rect? _layerDragStartRect;
  Offset? _layerDragStartPointer;
  Offset _layerDragAccum = Offset.zero;
  Offset _boxDragAccum = Offset.zero;
  bool _isLayerResizing = false;
  Offset _layerResizeAccum = Offset.zero;
  Offset _boxResizeAccum = Offset.zero;
  String? _selectedLayerId;
  final FocusNode _inlineTextFocusNode = FocusNode();
  String? _editingLayerId;
  final TextEditingController _layerTextController = TextEditingController();
  final TextEditingController _overlayNoteController = TextEditingController();
  final FocusNode _layerInlineFocusNode = FocusNode();
  final Set<String> _hydratedLayerSlides = {};
  int _slideEditorTabIndex = 0;
  TabController? _slideEditorTabController;
  bool _itemsExtrasExpanded = false;
  int _itemsSubTabIndex = 0; // 0 = Slide, 1 = Filters
  String? _renamingFolder;
  int? _renamingProjectIndex;
  final TextEditingController _folderRenameController = TextEditingController();
  final TextEditingController _projectRenameController =
      TextEditingController();

  String _fileName(String path) {
    if (path.isEmpty) return path;
    final parts = path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : path;
  }

  _SlideLayer? _currentSelectedLayer(_SlideContent slide) {
    if (_selectedLayerId == null) return null;
    for (final layer in slide.layers) {
      if (layer.id == _selectedLayerId) return layer;
    }
    return null;
  }

  void _ensureSelectedLayerValid({bool forcePickFirst = false}) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length) {
      _selectedLayerId = null;
      _editingLayerId = null;
      return;
    }
    final layers = _slides[selectedSlideIndex].layers;
    final exists =
        _selectedLayerId != null && layers.any((l) => l.id == _selectedLayerId);
    if (exists) return;
    if (forcePickFirst && layers.isNotEmpty) {
      _selectedLayerId = layers.first.id;
    } else if (!forcePickFirst) {
      _selectedLayerId = null;
    }
    _editingLayerId = null;
  }

  void _updateLayerField(
    String layerId,
    _SlideLayer Function(_SlideLayer layer) updater,
  ) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    final layers = _slides[selectedSlideIndex].layers.map((l) {
      if (l.id == layerId) return updater(l);
      return l;
    }).toList();
    setState(() {
      _selectedLayerId = layerId;
      _applyLayerUpdate(layers, triggerSetState: false);
    });
  }

  Widget _textboxTab(_SlideContent slide, _SlideTemplate template) {
    final textAlign = slide.alignOverride ?? template.alignment;
    final verticalAlign = slide.verticalAlign ?? _VerticalAlign.middle;
    final textColor = slide.textColorOverride ?? template.textColor;
    final gradient = slide.textGradientOverride;

    Widget toolbarButton({
      required Widget child,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? accentPink.withOpacity(0.18)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? accentPink : Colors.white24,
                width: selected ? 2 : 1,
              ),
            ),
            child: child,
          ),
        ),
      );
    }

    Widget alignButton(IconData icon, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? accentPink.withOpacity(0.18)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: selected ? accentPink : Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    InputDecoration _denseLabel(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: accentPink, fontSize: 12),
        isDense: true,
      );
    }

    TextAlign _cycleAlign(TextAlign current) {
      const order = [
        TextAlign.left,
        TextAlign.center,
        TextAlign.right,
        TextAlign.justify,
      ];
      final idx = order.indexOf(current);
      final next = (idx + 1) % order.length;
      return order[next];
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Font family',
                            style: TextStyle(color: accentPink, fontSize: 12),
                          ),
                          DropdownButton<String?>(
                            value: slide.fontFamilyOverride,
                            isExpanded: true,
                            dropdownColor: bgMedium,
                            iconEnabledColor: Colors.white70,
                            style: const TextStyle(color: Colors.white),
                            underline: const SizedBox.shrink(),
                            items: _fontFamilies
                                .map(
                                  (f) => DropdownMenuItem<String?>(
                                    value: f,
                                    child: MouseRegion(
                                      onEnter: (_) =>
                                          setState(() => _hoverFontPreview = f),
                                      onExit: (_) => setState(
                                        () => _hoverFontPreview = null,
                                      ),
                                      child: Text(
                                        f ?? 'Use template',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _slides[selectedSlideIndex] =
                                    _slides[selectedSlideIndex].copyWith(
                                      fontFamilyOverride: value,
                                    );
                              });
                              _recordRecentFont(value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _openTextColorPicker(slide, template),
                      child: Container(
                        width: 42,
                        height: 38,
                        decoration: gradient != null && gradient.isNotEmpty
                            ? BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 2,
                                ),
                              )
                            : BoxDecoration(
                                color: textColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            (slide.fontSizeOverride ?? template.fontSize)
                                .toStringAsFixed(0),
                        decoration: _denseLabel('Font size'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (v) {
                          final parsed = double.tryParse(v);
                          if (parsed != null) {
                            final double clamped = parsed
                                .clamp(10, 400)
                                .toDouble();
                            setState(() {
                              _slides[selectedSlideIndex] =
                                  _slides[selectedSlideIndex].copyWith(
                                    fontSizeOverride: clamped,
                                  );
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        value: slide.autoSize ?? false,
                        decoration: _denseLabel('Auto size'),
                        dropdownColor: bgMedium,
                        iconEnabledColor: Colors.white70,
                        items: const [
                          DropdownMenuItem(
                            value: false,
                            child: Text(
                              'None',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: true,
                            child: Text(
                              'Auto',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  autoSize: v,
                                );
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    toolbarButton(
                      child: const Text(
                        'B',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      selected: slide.isBold ?? true,
                      onTap: () {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                isBold: !(slide.isBold ?? true),
                              );
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    toolbarButton(
                      child: const Text(
                        'I',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                        ),
                      ),
                      selected: slide.isItalic ?? false,
                      onTap: () {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                isItalic: !(slide.isItalic ?? false),
                              );
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    toolbarButton(
                      child: const Text(
                        'U',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: Colors.white,
                        ),
                      ),
                      selected: slide.isUnderline ?? false,
                      onTap: () {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                isUnderline: !(slide.isUnderline ?? false),
                              );
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    toolbarButton(
                      child: const Icon(
                        Icons.format_align_center,
                        color: Colors.white,
                      ),
                      selected: true,
                      onTap: () {
                        final nextAlign = _cycleAlign(textAlign);
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                alignOverride: nextAlign,
                              );
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _accordionSection(
            icon: Icons.format_align_left,
            label: 'Align',
            children: [
              Row(
                children: [
                  alignButton(
                    Icons.format_align_left,
                    textAlign == TextAlign.left,
                    () {
                      setState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              alignOverride: TextAlign.left,
                            );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  alignButton(
                    Icons.format_align_center,
                    textAlign == TextAlign.center,
                    () {
                      setState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              alignOverride: TextAlign.center,
                            );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  alignButton(
                    Icons.format_align_right,
                    textAlign == TextAlign.right,
                    () {
                      setState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              alignOverride: TextAlign.right,
                            );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  alignButton(
                    Icons.format_align_justify,
                    textAlign == TextAlign.justify,
                    () {
                      setState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              alignOverride: TextAlign.justify,
                            );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  alignButton(
                    Icons.vertical_align_top,
                    verticalAlign == _VerticalAlign.top,
                    () {
                      setState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              verticalAlign: _VerticalAlign.top,
                            );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  alignButton(
                    Icons.vertical_align_center,
                    verticalAlign == _VerticalAlign.middle,
                    () {
                      setState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              verticalAlign: _VerticalAlign.middle,
                            );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  alignButton(
                    Icons.vertical_align_bottom,
                    verticalAlign == _VerticalAlign.bottom,
                    () {
                      setState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              verticalAlign: _VerticalAlign.bottom,
                            );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  const Spacer(),
                ],
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.text_fields,
            label: 'Text',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: (slide.letterSpacing ?? 0).toStringAsFixed(
                        1,
                      ),
                      decoration: _denseLabel('Letter spacing'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          setState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  letterSpacing: parsed.clamp(-2, 10),
                                );
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: (slide.wordSpacing ?? 0).toStringAsFixed(1),
                      decoration: _denseLabel('Word spacing'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          setState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  wordSpacing: parsed.clamp(-4, 16),
                                );
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButton<_TextTransform>(
                value: slide.textTransform ?? _TextTransform.none,
                isExpanded: true,
                dropdownColor: bgMedium,
                iconEnabledColor: Colors.white70,
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox.shrink(),
                items: _TextTransform.values
                    .map(
                      (t) => DropdownMenuItem<_TextTransform>(
                        value: t,
                        child: Text(
                          t.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(textTransform: value);
                  });
                },
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: slide.singleLine ?? false,
                onChanged: (v) {
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(singleLine: v ?? false);
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: accentPink,
                title: const Text(
                  'Text on one line',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.notes,
            label: 'Lines',
            children: [
              Text(
                'Line spacing: ${(slide.lineHeight ?? 1.3).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Slider(
                min: 0.6,
                max: 2.5,
                divisions: 38,
                activeColor: accentPink,
                value: (slide.lineHeight ?? 1.3).clamp(0.6, 2.5),
                onChanged: (v) {
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(lineHeight: v);
                  });
                },
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.list_alt,
            label: 'List',
            children: [
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        final lines = _slides[selectedSlideIndex].body.split(
                          '\n',
                        );
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              body: lines
                                  .map((l) => l.isEmpty ? l : '- $l')
                                  .join('\n'),
                            );
                      });
                    },
                    child: const Text('Bullet'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        final lines = _slides[selectedSlideIndex].body.split(
                          '\n',
                        );
                        int i = 1;
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              body: lines
                                  .map((l) => l.isEmpty ? l : '${i++}. $l')
                                  .join('\n'),
                            );
                      });
                    },
                    child: const Text('Numbered'),
                  ),
                ],
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.border_style,
            label: 'Outline',
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final c in [
                    AppPalette.carbonBlack,
                    Colors.white,
                    AppPalette.dustyRose,
                    AppPalette.dustyMauve,
                    AppPalette.dustyRose.withOpacity(0.6),
                  ])
                    _colorDot(
                      c,
                      selected:
                          (slide.outlineColor ?? Colors.black).value == c.value,
                      onTap: () {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                outlineColor: c,
                              );
                        });
                      },
                    ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              outlineColor: null,
                              outlineWidth: 0,
                            );
                      });
                    },
                    child: const Text(
                      'Clear outline',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
              Text(
                'Outline width: ${(slide.outlineWidth ?? 0).toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Slider(
                min: 0,
                max: 8,
                divisions: 32,
                activeColor: accentPink,
                value: (slide.outlineWidth ?? 0).clamp(0, 8),
                onChanged: (v) {
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(outlineWidth: v);
                  });
                },
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.layers,
            label: 'Shadow',
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final c in [
                    AppPalette.carbonBlack,
                    Colors.white,
                    AppPalette.dustyRose,
                    AppPalette.dustyMauve,
                    AppPalette.dustyRose.withOpacity(0.6),
                    AppPalette.teaGreen.withOpacity(0.6),
                  ])
                    _colorDot(
                      c,
                      selected:
                          (slide.shadowColor ?? Colors.black).value == c.value,
                      onTap: () {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                shadowColor: c,
                              );
                        });
                      },
                    ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              shadowColor: null,
                              shadowBlur: 0,
                              shadowOffsetX: 0,
                              shadowOffsetY: 0,
                            );
                      });
                    },
                    child: const Text(
                      'Clear shadow',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
              Text(
                'Shadow blur: ${(slide.shadowBlur ?? 0).toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Slider(
                min: 0,
                max: 20,
                divisions: 40,
                activeColor: accentPink,
                value: (slide.shadowBlur ?? 0).clamp(0, 20),
                onChanged: (v) {
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(shadowBlur: v);
                  });
                },
              ),
              Text(
                'Shadow offset X: ${(slide.shadowOffsetX ?? 0).toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Slider(
                min: -10,
                max: 10,
                divisions: 40,
                activeColor: accentPink,
                value: (slide.shadowOffsetX ?? 0).clamp(-10, 10),
                onChanged: (v) {
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(shadowOffsetX: v);
                  });
                },
              ),
              Text(
                'Shadow offset Y: ${(slide.shadowOffsetY ?? 0).toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Slider(
                min: -10,
                max: 10,
                divisions: 40,
                activeColor: accentPink,
                value: (slide.shadowOffsetY ?? 0).clamp(-10, 10),
                onChanged: (v) {
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(shadowOffsetY: v);
                  });
                },
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.music_note,
            label: 'Chords',
            children: const [
              Text(
                'Chords styling not available yet.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.swap_vert,
            label: 'Scrolling',
            children: [
              DropdownButton<_ScrollDirection>(
                value: slide.scrollDirection ?? _ScrollDirection.none,
                isExpanded: true,
                dropdownColor: bgMedium,
                iconEnabledColor: Colors.white70,
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: _ScrollDirection.none,
                    child: Text('None'),
                  ),
                  DropdownMenuItem(
                    value: _ScrollDirection.rightToLeft,
                    child: Text('Right to left'),
                  ),
                  DropdownMenuItem(
                    value: _ScrollDirection.leftToRight,
                    child: Text('Left to right'),
                  ),
                  DropdownMenuItem(
                    value: _ScrollDirection.topToBottom,
                    child: Text('Top to bottom'),
                  ),
                  DropdownMenuItem(
                    value: _ScrollDirection.bottomToTop,
                    child: Text('Bottom to top'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(scrollDirection: value);
                  });
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: (slide.scrollDurationSeconds ?? 30).toString(),
                decoration: _denseLabel('Scrolling duration'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null) {
                    setState(() {
                      _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                          .copyWith(
                            scrollDurationSeconds: parsed.clamp(1, 999),
                          );
                    });
                  }
                },
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.auto_fix_high,
            label: 'Special',
            children: const [
              Text(
                'Special effects are not configurable yet.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.code,
            label: 'CSS',
            children: [
              const Text(
                'Custom CSS (stored locally only)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: const SizedBox(
                  width: double.infinity,
                  height: 120,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text('CSS', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openTextColorPicker(
    _SlideContent slide,
    _SlideTemplate template,
  ) async {
    final List<Color> normalSwatches = [
      Colors.white,
      const Color(0xFFE0E0E0),
      const Color(0xFFCCCCCC),
      const Color(0xFF888888),
      const Color(0xFF555555),
      AppPalette.dustyRose,
      AppPalette.dustyMauve,
      AppPalette.teaGreen,
      const Color(0xFF2FB3FF),
      const Color(0xFF6A7CFF),
      const Color(0xFFD943FF),
      const Color(0xFF00C86B),
      const Color(0xFFFF7A45),
      const Color(0xFFFFB347),
      Colors.black,
    ];

    final List<List<Color>> gradientSwatches = [
      [const Color(0xFFFF7A45), const Color(0xFFFFB347)],
      [AppPalette.dustyRose, AppPalette.dustyMauve],
      [const Color(0xFF2FB3FF), const Color(0xFF6A7CFF)],
      [const Color(0xFF00C86B), const Color(0xFF2FB3FF)],
      [const Color(0xFFD943FF), const Color(0xFF6A7CFF)],
      [Colors.white, AppPalette.dustyRose],
    ];

    final List<Color>? currentGradient = slide.textGradientOverride;
    Color currentColor = slide.textColorOverride ?? template.textColor;
    double opacity = (currentGradient?.first.opacity ?? currentColor.opacity)
        .clamp(0.05, 1.0);

    await showDialog(
      context: context,
      builder: (ctx) {
        List<Color>? previewGradient = currentGradient
            ?.map((c) => c.withOpacity(opacity))
            .toList();
        Color previewColor = currentColor.withOpacity(opacity);
        int selectedTab = currentGradient != null
            ? 1
            : 0; // 0=Normal,1=Gradient,2=Custom
        final TextEditingController customHex = TextEditingController(
          text:
              '#${(previewGradient == null ? previewColor : previewGradient.first).value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
        );

        Color _parseHex(String input, Color fallback) {
          final normalized = input.replaceAll('#', '').toUpperCase();
          if (normalized.length == 6 || normalized.length == 8) {
            final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
            final int? value = int.tryParse(hex, radix: 16);
            if (value != null) return Color(value);
          }
          return fallback;
        }

        return StatefulBuilder(
          builder: (context, setLocal) {
            Widget tabButton(String label, int tab) {
              final selected = selectedTab == tab;
              return Expanded(
                child: InkWell(
                  onTap: () => setLocal(() {
                    selectedTab = tab;
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? accentPink.withOpacity(0.18)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? accentPink : Colors.white24,
                      ),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: bgMedium,
              title: const Text(
                'Text color',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        tabButton('Normal', 0),
                        const SizedBox(width: 6),
                        tabButton('Gradient', 1),
                        const SizedBox(width: 6),
                        tabButton('Custom', 2),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Preview',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 42,
                            height: 22,
                            decoration: previewGradient != null
                                ? BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: previewGradient!,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white24),
                                  )
                                : BoxDecoration(
                                    color: previewColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white24),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (selectedTab == 0) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: normalSwatches
                            .map(
                              (c) => GestureDetector(
                                onTap: () {
                                  setLocal(() {
                                    previewGradient = null;
                                    previewColor = c.withOpacity(opacity);
                                  });
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: c,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          previewGradient == null &&
                                              previewColor.value ==
                                                  c.withOpacity(opacity).value
                                          ? accentPink
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ] else if (selectedTab == 1) ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: gradientSwatches
                            .map(
                              (g) => GestureDetector(
                                onTap: () {
                                  setLocal(() {
                                    previewGradient = g
                                        .map((c) => c.withOpacity(opacity))
                                        .toList();
                                  });
                                },
                                child: Container(
                                  width: 74,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: g),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          previewGradient != null &&
                                              previewGradient!.first.value ==
                                                  g.first
                                                      .withOpacity(opacity)
                                                      .value
                                          ? accentPink
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ] else ...[
                      TextField(
                        controller: customHex,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Hex color',
                          hintText: '#RRGGBB',
                        ),
                        onChanged: (v) {
                          final parsed = _parseHex(v, previewColor);
                          setLocal(() {
                            previewGradient = null;
                            previewColor = parsed.withOpacity(opacity);
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            final parsed = _parseHex(
                              customHex.text,
                              previewColor,
                            );
                            setLocal(() {
                              previewGradient = null;
                              previewColor = parsed.withOpacity(opacity);
                            });
                          },
                          child: const Text('Choose custom'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Opacity',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Slider(
                          min: 0.05,
                          max: 1.0,
                          divisions: 19,
                          activeColor: accentPink,
                          value: opacity,
                          onChanged: (v) {
                            setLocal(() {
                              opacity = v;
                              if (previewGradient != null) {
                                previewGradient = previewGradient!
                                    .map((c) => c.withOpacity(opacity))
                                    .toList();
                              } else {
                                previewColor = previewColor.withOpacity(
                                  opacity,
                                );
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (selectedTab == 1 && previewGradient != null) {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              textGradientOverride: previewGradient,
                              textColorOverride: null,
                            );
                      } else {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              textColorOverride: previewColor,
                              textGradientOverride: null,
                            );
                      }
                    });
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _itemTab(_SlideContent slide, _SlideTemplate template) {
    final selectedLayer = _currentSelectedLayer(slide);
    final opacity = (selectedLayer?.opacity ?? 1.0).clamp(0.0, 1.0);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Selected item'),
          const SizedBox(height: 6),
          if (selectedLayer == null)
            _frostedBox(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'No layer selected',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Click a layer on canvas or in the stack to edit its properties.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            _frostedBox(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              selectedLayer.role == _LayerRole.background
                              ? accentBlue.withOpacity(0.2)
                              : accentPink.withOpacity(0.2),
                          child: Icon(
                            _layerIcon(selectedLayer),
                            size: 16,
                            color: selectedLayer.role == _LayerRole.background
                                ? accentBlue
                                : accentPink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedLayer.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _layerKindLabel(selectedLayer),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete layer',
                          onPressed: () => _deleteLayer(selectedLayer.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Role',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ToggleButtons(
                      isSelected: [
                        selectedLayer.role == _LayerRole.background,
                        selectedLayer.role == _LayerRole.foreground,
                      ],
                      onPressed: (i) {
                        final role = i == 0
                            ? _LayerRole.background
                            : _LayerRole.foreground;
                        _setLayerRole(selectedLayer.id, role);
                      },
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white70,
                      selectedColor: Colors.white,
                      fillColor: accentPink.withOpacity(0.2),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('Background'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('Foreground'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Opacity ${opacity.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      value: opacity,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      activeColor: accentPink,
                      onChanged: (v) {
                        _updateLayerField(
                          selectedLayer.id,
                          (layer) => layer.copyWith(opacity: v),
                        );
                      },
                    ),
                    if (selectedLayer.kind == _LayerKind.media &&
                        selectedLayer.role == _LayerRole.foreground)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _setLayerRole(
                            selectedLayer.id,
                            _LayerRole.background,
                          ),
                          icon: const Icon(Icons.landscape, size: 16),
                          label: const Text('Use as background'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (selectedLayer?.kind == _LayerKind.textbox) ...[
            _sectionHeader('Text styling'),
            const SizedBox(height: 6),
            _frostedBox(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: slide.autoSize ?? false,
                          onChanged: (v) {
                            setState(() {
                              _slides[selectedSlideIndex] =
                                  _slides[selectedSlideIndex].copyWith(
                                    autoSize: v ?? false,
                                  );
                            });
                          },
                          activeColor: accentPink,
                        ),
                        const Text(
                          'Auto-size text to box',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _updateSlideBox(
                              _slides[selectedSlideIndex],
                              left: 0.1,
                              top: 0.18,
                              width: 0.8,
                              height: 0.64,
                            );
                          },
                          child: const Text(
                            'Reset box',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Font size: ${(slide.fontSizeOverride ?? template.fontSize).round()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      min: 18,
                      max: 72,
                      divisions: 54,
                      activeColor: accentPink,
                      value: (slide.fontSizeOverride ?? template.fontSize)
                          .clamp(18, 72)
                          .toDouble(),
                      onChanged: (v) {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                fontSizeOverride: v,
                              );
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Alignment',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ToggleButtons(
                      isSelected: [
                        (slide.alignOverride ?? template.alignment) ==
                            TextAlign.left,
                        (slide.alignOverride ?? template.alignment) ==
                            TextAlign.center,
                        (slide.alignOverride ?? template.alignment) ==
                            TextAlign.right,
                      ],
                      onPressed: (idx) {
                        final align = idx == 0
                            ? TextAlign.left
                            : idx == 1
                            ? TextAlign.center
                            : TextAlign.right;
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                alignOverride: align,
                              );
                        });
                      },
                      color: Colors.white70,
                      selectedColor: Colors.white,
                      fillColor: accentPink.withOpacity(0.2),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.format_align_left, size: 16),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.format_align_center, size: 16),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.format_align_right, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Style',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ToggleButtons(
                      isSelected: [
                        slide.isBold ?? true,
                        slide.isItalic ?? false,
                        slide.isUnderline ?? false,
                      ],
                      onPressed: (idx) {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                isBold: idx == 0
                                    ? !(slide.isBold ?? true)
                                    : (slide.isBold ?? true),
                                isItalic: idx == 1
                                    ? !(slide.isItalic ?? false)
                                    : (slide.isItalic ?? false),
                                isUnderline: idx == 2
                                    ? !(slide.isUnderline ?? false)
                                    : (slide.isUnderline ?? false),
                              );
                        });
                      },
                      color: Colors.white70,
                      selectedColor: Colors.white,
                      fillColor: accentPink.withOpacity(0.2),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.format_bold, size: 16),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.format_italic, size: 16),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.format_underline, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Line spacing: ${(slide.lineHeight ?? 1.3).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      min: 0.6,
                      max: 2.5,
                      divisions: 38,
                      activeColor: accentPink,
                      value: (slide.lineHeight ?? 1.3).clamp(0.6, 2.5),
                      onChanged: (v) {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                lineHeight: v,
                              );
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Letter spacing: ${(slide.letterSpacing ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      min: -1,
                      max: 5,
                      divisions: 60,
                      activeColor: accentPink,
                      value: (slide.letterSpacing ?? 0).clamp(-1, 5),
                      onChanged: (v) {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                letterSpacing: v,
                              );
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Transform',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<_TextTransform>(
                      value: slide.textTransform ?? _TextTransform.none,
                      isExpanded: true,
                      dropdownColor: bgMedium,
                      iconEnabledColor: Colors.white70,
                      style: const TextStyle(color: Colors.white),
                      underline: const SizedBox.shrink(),
                      items: _TextTransform.values
                          .map(
                            (t) => DropdownMenuItem<_TextTransform>(
                              value: t,
                              child: Text(
                                t.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                textTransform: value,
                              );
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Font family',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<String?>(
                      value: slide.fontFamilyOverride,
                      isExpanded: true,
                      dropdownColor: bgMedium,
                      iconEnabledColor: Colors.white70,
                      style: const TextStyle(color: Colors.white),
                      underline: const SizedBox.shrink(),
                      items: _fontFamilies
                          .map(
                            (f) => DropdownMenuItem<String?>(
                              value: f,
                              child: Text(
                                f ?? 'Use template',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                fontFamilyOverride: value,
                              );
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Text color',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in [
                          Colors.white,
                          AppPalette.dustyRose,
                          AppPalette.dustyMauve,
                          AppPalette.willowGreen,
                          Colors.white70,
                          Colors.black,
                        ])
                          _colorDot(
                            c,
                            selected:
                                (slide.textColorOverride ?? template.textColor)
                                    .value ==
                                c.value,
                            onTap: () {
                              setState(() {
                                _slides[selectedSlideIndex] =
                                    _slides[selectedSlideIndex].copyWith(
                                      textColorOverride: c,
                                    );
                              });
                            },
                          ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _slides[selectedSlideIndex] =
                                  _slides[selectedSlideIndex].copyWith(
                                    textColorOverride: null,
                                  );
                            });
                          },
                          child: const Text(
                            'Use template',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Shadow',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in [
                          Colors.black,
                          Colors.white,
                          AppPalette.dustyRose,
                          AppPalette.dustyMauve,
                          AppPalette.willowGreen,
                          Colors.white30,
                        ])
                          _colorDot(
                            c,
                            selected:
                                (slide.shadowColor ?? Colors.black).value ==
                                c.value,
                            onTap: () {
                              setState(() {
                                _slides[selectedSlideIndex] =
                                    _slides[selectedSlideIndex].copyWith(
                                      shadowColor: c,
                                    );
                              });
                            },
                          ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _slides[selectedSlideIndex] =
                                  _slides[selectedSlideIndex].copyWith(
                                    shadowColor: null,
                                    shadowBlur: 0,
                                    shadowOffsetX: 0,
                                    shadowOffsetY: 0,
                                  );
                            });
                          },
                          child: const Text(
                            'Clear shadow',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shadow blur: ${(slide.shadowBlur ?? 0).toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      min: 0,
                      max: 20,
                      divisions: 40,
                      activeColor: accentPink,
                      value: (slide.shadowBlur ?? 0).clamp(0, 20),
                      onChanged: (v) {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                shadowBlur: v,
                              );
                        });
                      },
                    ),
                    Text(
                      'Shadow offset X: ${(slide.shadowOffsetX ?? 0).toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      min: -10,
                      max: 10,
                      divisions: 40,
                      activeColor: accentPink,
                      value: (slide.shadowOffsetX ?? 0).clamp(-10, 10),
                      onChanged: (v) {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                shadowOffsetX: v,
                              );
                        });
                      },
                    ),
                    Text(
                      'Shadow offset Y: ${(slide.shadowOffsetY ?? 0).toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      min: -10,
                      max: 10,
                      divisions: 40,
                      activeColor: accentPink,
                      value: (slide.shadowOffsetY ?? 0).clamp(-10, 10),
                      onChanged: (v) {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                shadowOffsetY: v,
                              );
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Outline',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in [
                          Colors.black,
                          Colors.white,
                          AppPalette.dustyRose,
                          AppPalette.dustyMauve,
                          AppPalette.willowGreen,
                        ])
                          _colorDot(
                            c,
                            selected:
                                (slide.outlineColor ?? Colors.black).value ==
                                c.value,
                            onTap: () {
                              setState(() {
                                _slides[selectedSlideIndex] =
                                    _slides[selectedSlideIndex].copyWith(
                                      outlineColor: c,
                                    );
                              });
                            },
                          ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _slides[selectedSlideIndex] =
                                  _slides[selectedSlideIndex].copyWith(
                                    outlineColor: null,
                                    outlineWidth: 0,
                                  );
                            });
                          },
                          child: const Text(
                            'Clear outline',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Outline width: ${(slide.outlineWidth ?? 0).toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      min: 0,
                      max: 8,
                      divisions: 32,
                      activeColor: accentPink,
                      value: (slide.outlineWidth ?? 0).clamp(0, 8),
                      onChanged: (v) {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                outlineWidth: v,
                              );
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Textbox background',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in [
                          Colors.black54,
                          Colors.white10,
                          Colors.white24,
                          accentPink.withOpacity(0.16),
                          AppPalette.willowGreen.withOpacity(0.18),
                        ])
                          _colorDot(
                            c,
                            selected:
                                (slide.boxBackgroundColor ?? Colors.black26)
                                    .value ==
                                c.value,
                            onTap: () {
                              setState(() {
                                _slides[selectedSlideIndex] =
                                    _slides[selectedSlideIndex].copyWith(
                                      boxBackgroundColor: c,
                                    );
                              });
                            },
                          ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _slides[selectedSlideIndex] =
                                  _slides[selectedSlideIndex].copyWith(
                                    boxBackgroundColor: null,
                                  );
                            });
                          },
                          child: const Text(
                            'Clear background',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Textbox padding: ${(slide.boxPadding ?? 8).round()} px',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      min: 0,
                      max: 32,
                      divisions: 32,
                      activeColor: accentPink,
                      value: (slide.boxPadding ?? 8).clamp(0, 32),
                      onChanged: (v) {
                        setState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                boxPadding: v,
                              );
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Presets',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton(
                          onPressed: () => _applyTextPreset('heading'),
                          child: const Text('Heading'),
                        ),
                        OutlinedButton(
                          onPressed: () => _applyTextPreset('verse'),
                          child: const Text('Verse'),
                        ),
                        OutlinedButton(
                          onPressed: () => _applyTextPreset('note'),
                          child: const Text('Note'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (selectedLayer?.kind == _LayerKind.textbox)
            const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final overlayNote = slide.overlayNote ?? '';
              if (_overlayNoteController.text != overlayNote) {
                _overlayNoteController.text = overlayNote;
                _overlayNoteController.selection = TextSelection.collapsed(
                  offset: _overlayNoteController.text.length,
                );
              }
              return TextField(
                controller: _overlayNoteController,
                decoration: const InputDecoration(
                  labelText: 'Item note (overlay)',
                ),
                onChanged: (v) {
                  setState(() {
                    final trimmed = v.trim();
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(
                          overlayNote: trimmed.isEmpty ? null : trimmed,
                        );
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _itemsTab(
    _SlideContent slide,
    _SlideTemplate template, {
    bool showExtras = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve space for the tab content while allowing the whole tab to scroll if cramped.
        const double minViewHeight = 220;
        final double viewHeight = math.max(
          minViewHeight,
          constraints.maxHeight - 180,
        );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _itemButton(
                    'Textbox',
                    Icons.title,
                    () => _addUtilityLayer(_LayerKind.textbox, 'Textbox'),
                  ),
                  _itemButton('Media', Icons.image, _showMediaPickerSheet),
                  _itemButton(
                    'Website',
                    Icons.language,
                    () => _addUtilityLayer(_LayerKind.website, 'Website'),
                  ),
                  _itemButton(
                    'Timer',
                    Icons.timer,
                    () => _addUtilityLayer(_LayerKind.timer, 'Timer'),
                  ),
                  _itemButton(
                    'Clock',
                    Icons.access_time,
                    () => _addUtilityLayer(_LayerKind.clock, 'Clock'),
                  ),
                  _itemButton(
                    'Camera',
                    Icons.videocam,
                    _showCameraPicker,
                  ),
                  _itemButton(
                    'Screen',
                    Icons.desktop_windows,
                    _showScreenPicker,
                  ),
                  _itemButton(
                    'Progress',
                    Icons.percent,
                    () => _addUtilityLayer(_LayerKind.progress, 'Progress'),
                  ),
                  _itemButton(
                    'Events',
                    Icons.event,
                    () => _addUtilityLayer(_LayerKind.events, 'Events'),
                  ),
                  _itemButton(
                    'Weather',
                    Icons.cloud,
                    () => _addUtilityLayer(_LayerKind.weather, 'Weather'),
                  ),
                  _itemButton(
                    'Visualizer',
                    Icons.graphic_eq,
                    () => _addUtilityLayer(_LayerKind.visualizer, 'Visualizer'),
                  ),
                  _itemButton(
                    'Captions',
                    Icons.closed_caption,
                    () => _addUtilityLayer(_LayerKind.captions, 'Captions'),
                  ),
                  _itemButton(
                    'Icon',
                    Icons.star,
                    () => _addUtilityLayer(_LayerKind.icon, 'Icon'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (showExtras) _buildItemsDropdown(viewHeight, slide, template),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsDropdown(
    double viewHeight,
    _SlideContent slide,
    _SlideTemplate template,
  ) {
    final String label = _itemsSubTabIndex == 0 ? 'Slide' : 'Filters';

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: !_itemsExtrasExpanded
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: viewHeight,
                  child: _itemsSubTabIndex == 0
                      ? _slideTab(slide, template)
                      : _filtersTab(slide, template),
                ),
              ],
            ),
    );
  }

  Widget _slideTab(_SlideContent slide, _SlideTemplate template) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Background color',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
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
                AppPalette.dustyRose,
                template.background,
              ])
                _colorDot(
                  c,
                  selected:
                      (slide.backgroundColor ?? template.background).value ==
                      c.value,
                  onTap: () {
                    setState(() {
                      _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                          .copyWith(backgroundColor: c);
                    });
                  },
                ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(backgroundColor: null);
                  });
                },
                child: const Text(
                  'Use template',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
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
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                    .copyWith(templateId: v);
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
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                    .copyWith(overlayNote: v.trim().isEmpty ? null : v.trim());
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
          _sliderControl(
            'Hue rotate',
            slide.hueRotate ?? 0,
            -180,
            180,
            (v) => _setFilter(slide, hue: v),
          ),
          _sliderControl(
            'Invert',
            (slide.invert ?? 0),
            0,
            1,
            (v) => _setFilter(slide, invert: v),
          ),
          _sliderControl(
            'Blur',
            (slide.blur ?? 0),
            0,
            20,
            (v) => _setFilter(slide, blur: v),
          ),
          _sliderControl(
            'Brightness',
            (slide.brightness ?? 1),
            0,
            2,
            (v) => _setFilter(slide, brightness: v),
          ),
          _sliderControl(
            'Contrast',
            (slide.contrast ?? 1),
            0,
            2,
            (v) => _setFilter(slide, contrast: v),
          ),
          _sliderControl(
            'Saturate',
            (slide.saturate ?? 1),
            0,
            2,
            (v) => _setFilter(slide, saturate: v),
          ),
        ],
      ),
    );
  }

  Widget _sliderControl(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
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

  void _setFilter(
    _SlideContent slide, {
    double? hue,
    double? invert,
    double? blur,
    double? brightness,
    double? contrast,
    double? saturate,
  }) {
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

  // ignore: unused_element
  Widget _mediaAttachmentCard(_SlideContent slide) {
    if (slide.layers.isEmpty && !_hydratedLayerSlides.contains(slide.id)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _hydrateLegacyLayers(selectedSlideIndex),
      );
    }

    final bgLayer = _backgroundLayerFor(slide);
    final hasMedia =
        (bgLayer?.path?.isNotEmpty ?? false) ||
        (slide.mediaPath != null &&
            slide.mediaPath!.isNotEmpty &&
            slide.mediaType != null);
    final name = hasMedia
        ? _fileName(bgLayer?.path ?? slide.mediaPath!)
        : 'None';
    final _SlideMediaType? effectiveType =
        bgLayer?.mediaType ?? slide.mediaType;
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
                  Icon(
                    hasMedia ? Icons.check_circle : Icons.cloud_upload,
                    size: 18,
                    color: hasMedia ? accentPink : Colors.white70,
                  ),
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
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.white70),
                      ),
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
                      backgroundColor: AppPalette.carbonBlack.withOpacity(0.38),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      side: BorderSide(color: accentPink.withOpacity(0.6)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickMediaForSlide(_SlideMediaType.video),
                    icon: const Icon(Icons.videocam_outlined, size: 16),
                    label: const Text('Add video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.carbonBlack.withOpacity(0.38),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
          const Text(
            'Layers',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
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
                          child: const Icon(
                            Icons.drag_indicator,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: layer.role == _LayerRole.background
                              ? accentBlue.withOpacity(0.2)
                              : accentPink.withOpacity(0.2),
                          child: Icon(
                            _layerIcon(layer),
                            size: 16,
                            color: layer.role == _LayerRole.background
                                ? accentBlue
                                : accentPink,
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      layer.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${layer.role.name} • ${_layerKindLabel(layer)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Move up',
                          icon: const Icon(
                            Icons.arrow_upward,
                            color: Colors.white54,
                          ),
                          onPressed: index > 0
                              ? () => _nudgeLayer(index, -1)
                              : null,
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          icon: const Icon(
                            Icons.arrow_downward,
                            color: Colors.white54,
                          ),
                          onPressed: index < layers.length - 1
                              ? () => _nudgeLayer(index, 1)
                              : null,
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
                            DropdownMenuItem(
                              value: _LayerRole.background,
                              child: Text('Background'),
                            ),
                            DropdownMenuItem(
                              value: _LayerRole.foreground,
                              child: Text('Foreground'),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Delete layer',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white70,
                          ),
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
          const Text(
            'No layers yet — add media to start layering.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _itemButton(String label, IconData icon, VoidCallback onTap) {
    const Color innerBg = AppPalette.carbonBlack;
    final Gradient rim = LinearGradient(
      colors: [accentPink, accentPink.withOpacity(0.55)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return SizedBox(
      width: 120,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: rim,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: accentPink.withOpacity(0.25),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.2),
          child: ElevatedButton.icon(
            style:
                ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: innerBg,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ).copyWith(
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed))
                      return accentPink.withOpacity(0.22);
                    if (states.contains(WidgetState.hovered))
                      return accentPink.withOpacity(0.15);
                    return null;
                  }),
                ),
            onPressed: onTap,
            icon: Icon(icon, size: 18, color: accentPink),
            label: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addUtilityLayer(_LayerKind kind, String label) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    setState(() {
      final slide = _slides[selectedSlideIndex];
      final idx = slide.layers.length;
      // Stagger new layers so multiple adds don’t sit perfectly on top of each other.
      final double baseLeft = 0.15;
      final double baseTop = 0.15;
      final double baseWidth = 0.6;
      final double baseHeight = 0.6;
      final double offset = 0.04 * (idx % 4);
      final left = (baseLeft + offset).clamp(
        -_overflowAllowance,
        1 - baseWidth + _overflowAllowance,
      );
      final top = (baseTop + offset).clamp(
        -_overflowAllowance,
        1 - baseHeight + _overflowAllowance,
      );

      final layer = _SlideLayer(
        id: 'layer-${DateTime.now().microsecondsSinceEpoch}',
        label: label,
        kind: kind,
        role: _LayerRole.foreground,
        text: kind == _LayerKind.textbox ? 'Edit me' : null,
        left: left,
        top: top,
        width: baseWidth,
        height: baseHeight,
      );
      final updated = [...slide.layers, layer];
      _slides[selectedSlideIndex] = slide.copyWith(layers: updated);
    });
  }

  /// Show camera picker dialog with live thumbnails
  Future<void> _showCameraPicker() async {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length) return;

    // Get cameras from device service and local state
    final cameras = [..._connectedCameras];
    
    // If no cameras, show message
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cameras detected'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final selected = await showDialog<_LiveDevice>(
      context: context,
      builder: (context) => _CameraPickerDialog(
        cameras: cameras,
        bgColor: bgMedium,
        accentColor: accentPink,
      ),
    );

    if (selected != null) {
      _addCameraLayer(selected);
    }
  }

  /// Add a camera layer with specific camera ID
  void _addCameraLayer(_LiveDevice camera) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length) return;
    
    setState(() {
      final slide = _slides[selectedSlideIndex];
      final idx = slide.layers.length;
      final double baseLeft = 0.15;
      final double baseTop = 0.15;
      final double baseWidth = 0.6;
      final double baseHeight = 0.6;
      final double offset = 0.04 * (idx % 4);
      final left = (baseLeft + offset).clamp(
        -_overflowAllowance,
        1 - baseWidth + _overflowAllowance,
      );
      final top = (baseTop + offset).clamp(
        -_overflowAllowance,
        1 - baseHeight + _overflowAllowance,
      );

      final layer = _SlideLayer(
        id: 'layer-${DateTime.now().microsecondsSinceEpoch}',
        label: camera.name,
        kind: _LayerKind.camera,
        role: _LayerRole.foreground,
        path: camera.id, // Store camera ID in path field
        left: left,
        top: top,
        width: baseWidth,
        height: baseHeight,
      );
      final updated = [...slide.layers, layer];
      _slides[selectedSlideIndex] = slide.copyWith(layers: updated);
    });
  }

  /// Show screen picker dialog for display/window capture
  Future<void> _showScreenPicker() async {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length) return;

    // Get screens from device service and local state
    final screens = [..._connectedScreens];
    
    // If no screens, show message
    if (screens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No displays detected'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final selected = await showDialog<_ScreenSelection>(
      context: context,
      builder: (context) => _ScreenPickerDialog(
        screens: screens,
        bgColor: bgMedium,
        accentColor: accentPink,
      ),
    );

    if (selected != null) {
      _addScreenLayer(selected);
    }
  }

  /// Add a screen layer with specific screen/window ID
  void _addScreenLayer(_ScreenSelection selection) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length) return;
    
    setState(() {
      final slide = _slides[selectedSlideIndex];
      final idx = slide.layers.length;
      final double baseLeft = 0.10;
      final double baseTop = 0.10;
      final double baseWidth = 0.8;
      final double baseHeight = 0.8;
      final double offset = 0.03 * (idx % 4);
      final left = (baseLeft + offset).clamp(
        -_overflowAllowance,
        1 - baseWidth + _overflowAllowance,
      );
      final top = (baseTop + offset).clamp(
        -_overflowAllowance,
        1 - baseHeight + _overflowAllowance,
      );

      // For window captures, store hwnd in the path as "window-HWND"
      // For display captures, store displayIndex in the path as "display-INDEX"
      String pathValue = selection.id;
      if (selection.type == _ScreenCaptureType.window && selection.hwnd != null) {
        pathValue = 'hwnd:${selection.hwnd}';
      } else if (selection.type == _ScreenCaptureType.display && selection.displayIndex != null) {
        pathValue = 'display:${selection.displayIndex}';
      }

      final layer = _SlideLayer(
        id: 'layer-${DateTime.now().microsecondsSinceEpoch}',
        label: selection.name,
        kind: _LayerKind.screen,
        role: _LayerRole.foreground,
        path: pathValue, // Store hwnd or displayIndex for capture
        text: selection.type.name, // Store capture type (display/window/desktop)
        left: left,
        top: top,
        width: baseWidth,
        height: baseHeight,
      );
      final updated = [...slide.layers, layer];
      _slides[selectedSlideIndex] = slide.copyWith(layers: updated);
    });
  }

  Widget _applyFilters(Widget child, _SlideContent slide) {
    final matrix = _colorMatrix(slide);
    final blurSigma = (slide.blur ?? 0).clamp(0, 40).toDouble();
    Widget filtered = ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: child,
    );
    if (blurSigma > 0) {
      filtered = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: filtered,
      );
    }
    return filtered;
  }

  List<double> _colorMatrix(_SlideContent slide) {
    List<double> matrix = _identityMatrix();
    matrix = _matrixMultiply(
      matrix,
      _hueMatrix((slide.hueRotate ?? 0) * math.pi / 180),
    );
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
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  List<double> _invertMatrix() => [
    -1,
    0,
    0,
    0,
    255,
    0,
    -1,
    0,
    0,
    255,
    0,
    0,
    -1,
    0,
    255,
    0,
    0,
    0,
    1,
    0,
  ];

  List<double> _saturationMatrix(double s) {
    const rw = 0.2126, gw = 0.7152, bw = 0.0722;
    final inv = 1 - s;
    final r = inv * rw;
    final g = inv * gw;
    final b = inv * bw;
    return [
      r + s,
      g,
      b,
      0,
      0,
      r,
      g + s,
      b,
      0,
      0,
      r,
      g,
      b + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _hueMatrix(double radians) {
    final cosR = math.cos(radians);
    final sinR = math.sin(radians);
    const rw = 0.213, gw = 0.715, bw = 0.072;
    return [
      rw + cosR * (1 - rw) + sinR * (-rw),
      gw + cosR * (-gw) + sinR * (-gw),
      bw + cosR * (-bw) + sinR * (1 - bw),
      0,
      0,
      rw + cosR * (-rw) + sinR * 0.143,
      gw + cosR * (1 - gw) + sinR * 0.14,
      bw + cosR * (-bw) + sinR * (-0.283),
      0,
      0,
      rw + cosR * (-rw) + sinR * (-(1 - rw)),
      gw + cosR * (-gw) + sinR * gw,
      bw + cosR * (1 - bw) + sinR * bw,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _contrastMatrix(double c) {
    final t = 128 * (1 - c);
    return [c, 0, 0, 0, t, 0, c, 0, 0, t, 0, 0, c, 0, t, 0, 0, 0, 1, 0];
  }

  List<double> _brightnessMatrix(double b) {
    final offset = 255 * (b - 1);
    return [
      1,
      0,
      0,
      0,
      offset,
      0,
      1,
      0,
      0,
      offset,
      0,
      0,
      1,
      0,
      offset,
      0,
      0,
      0,
      1,
      0,
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

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  void _applyTextPreset(String preset) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    final slide = _slides[selectedSlideIndex];
    final template = _templateFor(slide.templateId);

    _SlideContent next = slide;
    switch (preset) {
      case 'heading':
        next = slide.copyWith(
          fontSizeOverride: (template.fontSize * 1.15).clamp(18, 80),
          isBold: true,
          isItalic: false,
          isUnderline: false,
          alignOverride: TextAlign.center,
          letterSpacing: 0.6,
          lineHeight: 1.1,
          shadowColor: Colors.black,
          shadowBlur: 8,
          shadowOffsetX: 1.2,
          shadowOffsetY: 2.2,
          outlineColor: Colors.black,
          outlineWidth: 1.5,
          textTransform: _TextTransform.uppercase,
          boxPadding: 10,
          boxBackgroundColor: slide.boxBackgroundColor,
        );
        break;
      case 'note':
        next = slide.copyWith(
          fontSizeOverride: (template.fontSize * 0.78).clamp(14, 64),
          isBold: false,
          isItalic: true,
          isUnderline: false,
          letterSpacing: 0.2,
          lineHeight: 1.4,
          shadowColor: null,
          shadowBlur: 0,
          outlineWidth: 0,
          boxPadding: 12,
          boxBackgroundColor: Colors.black54,
          textTransform: _TextTransform.none,
        );
        break;
      case 'verse':
      default:
        next = slide.copyWith(
          fontSizeOverride: template.fontSize,
          isBold: true,
          isItalic: false,
          isUnderline: false,
          letterSpacing: 0,
          lineHeight: 1.3,
          shadowColor: Colors.black,
          shadowBlur: 4,
          shadowOffsetX: 0,
          shadowOffsetY: 1.2,
          outlineWidth: 0,
          boxPadding: 10,
          boxBackgroundColor: slide.boxBackgroundColor,
          textTransform: _TextTransform.none,
        );
        break;
    }

    setState(() {
      _slides[selectedSlideIndex] = next;
    });
  }

  void _initStageLayouts() {
    if (_stageLayouts.isNotEmpty) return;
    _stageLayouts = const [
      _StageLayout(id: 'layout-lyrics', name: 'Lyrics only'),
      _StageLayout(id: 'layout-current-next', name: 'Current & Next'),
      _StageLayout(id: 'layout-clock', name: 'Clock + Timer'),
    ];
    _selectedStageLayoutId ??= _stageLayouts.first.id;
  }

  @override
  void initState() {
    super.initState();
    _syncSlideThumbnails();
    _initStageLayouts();
    if (_slides.isNotEmpty) {
      selectedSlides = {0};
      _syncSlideEditors();
    }
    _seedDefaultCategories();
    _drawerHeight = drawerExpanded ? _drawerDefaultHeight : _drawerMinHeight;
    _refreshScreensFromPlatform();
    _initializeDeviceService();
    _loadSettings();
    _inlineTextFocusNode.addListener(() {
      if (!_inlineTextFocusNode.hasFocus && _isInlineTextEditing) {
        setState(() {
          _isInlineTextEditing = false;
        });
      }
    });

    _layerInlineFocusNode.addListener(() {
      if (!_layerInlineFocusNode.hasFocus && _editingLayerId != null) {
        setState(() {
          _editingLayerId = null;
        });
      }
    });

    // Play videos on initial slide after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_slides.isNotEmpty) {
        _playVideosOnCurrentSlide();
      }
    });
  }

  @override
  void dispose() {
    _outputDebouncer.dispose();
    _outputThrottler.dispose();
    _slideEditorTabController?.removeListener(_onSlideEditorTabChanged);
    _slideEditorTabController = null;
    _youtubeQuery.dispose();
    _slideTitleController.dispose();
    _slideBodyController.dispose();
    _lyricsImportController.dispose();
    _folderRenameController.dispose();
    _projectRenameController.dispose();
    _previewTimer?.cancel();
    _cancelAutoAdvanceTimer();
    _slidesFocusNode.dispose();
    _slidesScrollController.dispose();
    _inlineTextFocusNode.dispose();
    _layerInlineFocusNode.dispose();
    _layerTextController.dispose();
    _overlayNoteController.dispose();
    // Dispose audio player
    _disposeAudioPlayer();
    _metronomeTimer?.cancel();
    // Dispose device service resources
    _deviceThumbnailTimer?.cancel();
    _deviceServiceSubscription?.cancel();
    for (final controller in _onlineSearchControllers.values) {
      controller.dispose();
    }
    for (final entry in _videoControllers.values) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  /// Initialize device service for cameras, screens, and NDI
  Future<void> _initializeDeviceService() async {
    try {
      await DeviceService.instance.initialize();
      
      // Listen for device updates
      _deviceServiceSubscription = DeviceService.instance.devicesStream.listen(
        (devices) {
          if (!mounted) return;
          setState(() {
            _connectedScreens.clear();
            _connectedCameras.clear();
            
            // Preserve user-added NDI sources (those with 'ndi_' prefix in id)
            final userAddedNdiSources = _ndiSources
                .where((s) => s.id.startsWith('ndi_'))
                .toList();
            _ndiSources.clear();
            
            for (final device in devices) {
              switch (device.type) {
                case DeviceType.screen:
                  _connectedScreens.add(_LiveDevice(
                    id: device.id,
                    name: device.name,
                    detail: device.detail,
                    thumbnail: device.thumbnail,
                    isActive: device.isActive,
                  ));
                  break;
                case DeviceType.camera:
                  _connectedCameras.add(_LiveDevice(
                    id: device.id,
                    name: device.name,
                    detail: device.detail,
                    thumbnail: device.thumbnail,
                    isActive: device.isActive,
                  ));
                  break;
                case DeviceType.ndi:
                  _ndiSources.add(_NdiSource(
                    id: device.id,
                    name: device.name,
                    url: device.ndiUrl ?? device.detail,
                    thumbnail: device.thumbnail,
                    isOnline: device.isActive,
                  ));
                  break;
              }
            }
            
            // Re-add user-added NDI sources
            _ndiSources.addAll(userAddedNdiSources);
          });
        },
      );
      
      // Start periodic thumbnail updates for live preview
      _deviceThumbnailTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _updateDeviceThumbnails(),
      );
    } catch (e) {
      debugPrint('Error initializing device service: $e');
    }
  }

  /// Update thumbnails for all connected devices
  Future<void> _updateDeviceThumbnails() async {
    if (!mounted) return;
    
    // NOTE: Screen thumbnail capture is DISABLED because screen_capturer
    // triggers the Windows Snipping Tool UI. Screens show info/icon only.
    // Camera thumbnails are handled by DeviceService.
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final envYoutubeKey = dotenv.isInitialized
        ? (dotenv.env['YOUTUBE_API_KEY'] ?? '')
        : '';
    final envVimeoToken = dotenv.isInitialized
        ? (dotenv.env['VIMEO_ACCESS_TOKEN'] ?? '')
        : '';
    final osYoutubeKey = Platform.environment['YOUTUBE_API_KEY'] ?? '';
    final osVimeoToken = Platform.environment['VIMEO_ACCESS_TOKEN'] ?? '';
    setState(() {
      videoFolder = prefs.getString('video_folder');
      songFolder = prefs.getString('song_folder');
      lyricsFolder = prefs.getString('lyrics_folder');
      saveFolder = prefs.getString('save_folder');
      final prefYoutubeKey = prefs.getString('youtube_api_key');
      final prefVimeoToken = prefs.getString('vimeo_access_token');
      youtubeApiKey = _firstNonEmpty([
        prefYoutubeKey,
        envYoutubeKey,
        osYoutubeKey,
      ]);
      vimeoAccessToken = _firstNonEmpty([
        prefVimeoToken,
        envVimeoToken,
        osVimeoToken,
      ]);
      savedYouTubeVideos = (prefs.getStringList('youtube_saved') ?? [])
          .map((e) => Map<String, String>.from(json.decode(e)))
          .toList();
      final savedStyles = prefs.getString('styles_json');
      if (savedStyles != null && savedStyles.isNotEmpty) {
        final list = json.decode(savedStyles) as List<dynamic>;
        _styles
          ..clear()
          ..addAll(
            list.map(
              (e) => _StylePreset.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
      }
      profiles = prefs.getStringList('profiles') ?? profiles;
      lowerThirdHeight =
          prefs.getDouble('lower_third_height') ?? lowerThirdHeight;
      lowerThirdGradient =
          prefs.getBool('lower_third_gradient') ?? lowerThirdGradient;
      stageNotesScale = prefs.getDouble('stage_notes_scale') ?? stageNotesScale;
      use24HourClock = prefs.getBool('use_24h_clock') ?? use24HourClock;
      disableLabels = prefs.getBool('disable_labels') ?? disableLabels;
      showProjectsOnStartup =
          prefs.getBool('show_projects_on_startup') ?? showProjectsOnStartup;
      autoLaunchOutput =
          prefs.getBool('auto_launch_output') ?? autoLaunchOutput;
      hideCursorInOutput =
          prefs.getBool('hide_cursor_output') ?? hideCursorInOutput;
      enableNdiOutput = prefs.getBool('enable_ndi_output') ?? enableNdiOutput;
      enableRemoteShow =
          prefs.getBool('enable_remote_show') ?? enableRemoteShow;
      enableStageShow = prefs.getBool('enable_stage_show') ?? enableStageShow;
      enableControlShow =
          prefs.getBool('enable_control_show') ?? enableControlShow;
      enableApiAccess = prefs.getBool('enable_api_access') ?? enableApiAccess;
      autoUpdates = prefs.getBool('auto_updates') ?? autoUpdates;
      alertOnUpdate = prefs.getBool('alert_on_update') ?? alertOnUpdate;
      alertOnBeta = prefs.getBool('alert_on_beta') ?? alertOnBeta;
      enableCloseConfirm =
          prefs.getBool('enable_close_confirm') ?? enableCloseConfirm;
      logSongUsage = prefs.getBool('log_song_usage') ?? logSongUsage;
      autoErrorReporting =
          prefs.getBool('auto_error_reporting') ?? autoErrorReporting;
      disableHardwareAcceleration =
          prefs.getBool('disable_hw_accel') ?? disableHardwareAcceleration;
      selectedThemeName = prefs.getString('theme_name') ?? selectedThemeName;
      final savedOutputs = prefs.getString('outputs_json');
      if (savedOutputs != null && savedOutputs.isNotEmpty) {
        final list = json.decode(savedOutputs) as List<dynamic>;
        _outputs = list
            .map((e) => OutputConfig.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (_outputs.isEmpty) {
        _outputs = [OutputConfig.defaultAudience()];
      }
      _ensureOutputPreviewVisibilityDefaults();
    });
    _applyThemePreset(selectedThemeName, persist: false);
    await _scanLibraries();
  }

  Future<void> _scanLibraries() async {
    if (videoFolder != null) {
      _scanFolder(videoFolder!, [
        '.mp4',
        '.mov',
        '.mkv',
      ], (list) => discoveredVideos = list);
    }
    if (songFolder != null) {
      _scanFolder(songFolder!, [
        '.mp3',
        '.wav',
        '.flac',
      ], (list) => discoveredSongs = list);
    }
    if (lyricsFolder != null) {
      _scanFolder(lyricsFolder!, [
        '.txt',
        '.srt',
        '.lrc',
      ], (list) => discoveredLyrics = list);
    }
  }

  void _scanFolder(
    String path,
    List<String> extensions,
    void Function(List<FileSystemEntity>) onUpdate,
  ) {
    final dir = Directory(path);
    if (dir.existsSync()) {
      final filtered = dir
          .listSync()
          .where(
            (f) => extensions.any((ext) => f.path.toLowerCase().endsWith(ext)),
          )
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
      if (key == 'save_folder') {
        await _showNoticeDialog(
          'Save folder set',
          'New saves will go to:\n$selectedDirectory',
          success: true,
        );
      }
    }
  }

  // ignore: unused_element
  Future<void> _uploadVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result == null) return;

    List<String> importedPaths = [];
    for (final file in result.files) {
      if (file.path == null) continue;
      final source = File(file.path!);
      if (videoFolder != null) {
        final destPath =
            videoFolder! +
            Platform.pathSeparator +
            source.uri.pathSegments.last;
        await source.copy(destPath);
      }
      importedPaths.add(file.path!);
    }

    _scanLibraries();
    _showSnack('Added ${importedPaths.length} video(s)');
  }

  Future<void> _sendCurrentSlideToOutputs({
    bool createIfMissing = false,
  }) async {
    if (_isSendingOutputs) return;
    _isSendingOutputs = true;
    if (_outputs.isEmpty ||
        _slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length) {
      _isSendingOutputs = false;
      return;
    }
    final shouldClearPreview =
        !(outputBackgroundActive || outputSlideActive || outputOverlayActive);
    if (!shouldClearPreview) {
      setState(() => outputPreviewCleared = false);
    }
    final slide = _slides[selectedSlideIndex];
    final template = _templateFor(slide.templateId);
    final payloadBase = _buildProjectionPayload(slide, template);

    final visibleOutputs = _outputs.where((o) => o.visible).toList();
    final screenOutputs = _outputs
        .where((o) => o.destination == _OutputDestination.screen)
        .toList();
    final visibleScreenOutputs = screenOutputs.where((o) => o.visible).toList();
    List<OutputConfig> outputsToSend;
    if (_armedOutputs.isNotEmpty) {
      outputsToSend = _outputs
          .where((o) => _armedOutputs.contains(o.id))
          .toList();
    } else {
      // Prefer a visible screen output; otherwise fall back to any screen output, then to other outputs.
      if (visibleScreenOutputs.isNotEmpty) {
        outputsToSend = [visibleScreenOutputs.first];
      } else if (screenOutputs.isNotEmpty) {
        outputsToSend = [screenOutputs.first];
      } else if (visibleOutputs.isNotEmpty) {
        outputsToSend = [visibleOutputs.first];
      } else if (_outputs.isNotEmpty) {
        outputsToSend = [_outputs.first];
      } else {
        outputsToSend = [];
      }
    }
    if (outputsToSend.isEmpty) {
      _isSendingOutputs = false;
      _showSnack('No outputs configured or visible');
      return;
    }

    try {
      for (final output in outputsToSend) {
        final locked = (_outputRuntime[output.id]?.locked ?? outputsLocked);
        final slideLayerActive =
            outputSlideActive || slide.body.trim().isNotEmpty;
        final bool isScreen = output.destination == _OutputDestination.screen;
        final bool showWindow = isScreen && (output.visible || createIfMissing);
        final bool isHeadless = !showWindow;
        final payload = {
          ...payloadBase,
          'output': {
            ...output.toJson(),
            'lowerThirdHeight': lowerThirdHeight,
            'lowerThirdGradient': lowerThirdGradient,
            'stageNotesScale': stageNotesScale,
            'locked': locked,
          },
          'state': {
            'layers': {
              'background': outputBackgroundActive,
              'foregroundMedia': outputForegroundMediaActive,
              'slide': slideLayerActive,
              'overlay': outputOverlayActive,
              'audio': outputAudioActive,
              'timer': outputTimerActive,
            },
            'locked': locked,
            'transition': outputTransition,
            'isPlaying': isPlaying,
          },
        };
        if (isHeadless) {
          final runtime = _outputRuntime[output.id] ?? _OutputRuntimeState();
          runtime.active = true;
          runtime.locked = locked;
          runtime.disconnected = false;
          runtime.ndi =
              output.destination == _OutputDestination.ndi || enableNdiOutput;
          runtime.headless = true;
          _outputRuntime[output.id] = runtime;
          _headlessOutputPayloads[output.id] = payload;
          continue;
        }
        final delivered = await _ensureOutputWindow(
          output,
          payload,
          createIfMissing: createIfMissing,
        );
        if (delivered) {
          final runtime =
              _outputRuntime[output.id] ??
              _OutputRuntimeState(ndi: enableNdiOutput);
          runtime.active = true;
          runtime.locked = locked;
          runtime.headless = false;
          runtime.disconnected = false;
          _outputRuntime[output.id] = runtime;
        } else {
          final runtime = _outputRuntime[output.id] ?? _OutputRuntimeState();
          runtime.disconnected = true;
          runtime.active = false;
          runtime.headless = false;
          _outputRuntime[output.id] = runtime;
        }
      }
    } finally {
      _isSendingOutputs = false;
    }
  }

  Future<void> _togglePresent() async {
    // If output windows are open, single click does nothing (use double-click to close)
    // If no output windows, single click opens them
    if (_outputWindowIds.isNotEmpty) {
      // Windows already open - show hint about double-click
      _showSnack('Double-click to close outputs');
      return;
    }

    // Open the output windows
    setState(() {
      _awaitingPresentStopConfirm = false;
      _presentStopRequestedAt = null;
    });
    await _armPresentation();
  }

  Future<void> _armPresentation() async {
    debugPrint('out: arming presentation, sending current slide to outputs');
    // Reset layer toggles to default on state when opening outputs
    setState(() {
      outputBackgroundActive = true;
      outputForegroundMediaActive = true;
      outputSlideActive = true;
      outputOverlayActive = true;
      outputAudioActive = true;
      outputTimerActive = false;
      outputPreviewCleared = false;
    });
    await _sendCurrentSlideToOutputs(createIfMissing: true);
    setState(() {
      _isPresenting = true;
    });
  }

  Future<void> _disarmPresentation() async {
    debugPrint('out: disarming presentation, closing outputs');
    await _closeAllOutputWindows();
    setState(() {
      _isPresenting = false;
      _awaitingPresentStopConfirm = false;
      _presentStopRequestedAt = null;
    });
    _showSnack('Outputs stopped');
  }

  Future<void> _closeAllOutputWindows() async {
  debugPrint('out: closing all output windows count=${_outputWindowIds.length}');
  
  // We convert to list to avoid "Concurrent Modification" errors 
  // if the map is changed during the loop
  final entries = _outputWindowIds.entries.toList();

  for (final entry in entries) {
    final int id = entry.value; // Access the ID from the map value
    try {
      debugPrint('out: closing windowId=$id outputId=${entry.key}');
      
      // Use the ID variable we just defined
      await WindowController.fromWindowId(id).close();
      
      debugPrint('out: successfully closed window $id');
    } catch (e) {
      debugPrint('out: exception closing window $id: $e');
    }
  }
  
  setState(() {
    _outputWindowIds.clear();
  });
  
  await Future.delayed(const Duration(milliseconds: 100));
    for (final id in _outputRuntime.keys) {
      final runtime = _outputRuntime[id] ?? _OutputRuntimeState();
      runtime.active = false;
      runtime.disconnected = false;
      _outputRuntime[id] = runtime;
    }
    _headlessOutputPayloads.clear();
  }

  Future<Rect?> _resolveOutputFrame(OutputConfig output) async {
    try {
      final displays = await ScreenRetriever.instance.getAllDisplays();
      if (displays.isEmpty) return null;

      Display? target;
      if (output.targetScreenId != null) {
        for (final display in displays) {
          final matchesId =
              output.targetScreenId == 'display-${display.id}' ||
              output.targetScreenId == display.id.toString();
          if (matchesId) {
            target = display;
            break;
          }
        }
      }
      target ??= displays.first;

      final pos = target.visiblePosition ?? Offset.zero;
      final size = target.visibleSize ?? target.size ?? const Size(0, 0);
      final frame = Rect.fromLTWH(
        pos.dx,
        pos.dy,
        size.width.toDouble(),
        size.height.toDouble(),
      );
      final double desiredWidth = _safeClamp(
        (output.width ?? frame.width.toInt()).toDouble(),
        320,
        frame.width,
      );
      final double desiredHeight = _safeClamp(
        (output.height ?? frame.height.toInt()).toDouble(),
        240,
        frame.height,
      );
      final double left = frame.left + (frame.width - desiredWidth) / 2;
      final double top = frame.top + (frame.height - desiredHeight) / 2;
      return Rect.fromLTWH(left, top, desiredWidth, desiredHeight);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureOutputWindow(
    OutputConfig output,
    Map<String, dynamic> payload, {
    bool createIfMissing = false,
  }) async {
    debugPrint(
      'out: ensure window output=${output.id} createIfMissing=$createIfMissing',
    );
    final Rect? targetFrame = await _resolveOutputFrame(output);
    final String payloadJson = json.encode(payload);
    try {
      final windowId = _outputWindowIds[output.id];
      if (windowId == null) {
        if (!createIfMissing || _pendingOutputCreates.contains(output.id))
          return false;
        _pendingOutputCreates.add(output.id);
        try {
          debugPrint('out: creating window for output=${output.id}');
          // Create window with thin payload to avoid crashing the secondary engine during spawn.
          final window = await _safeCreateWindow('{}');
          if (window == null) {
            debugPrint('out: create window skipped due to plugin error');
            return false;
          }
          window.setTitle(output.name);
          await window.setFrame(
            targetFrame ?? const Rect.fromLTWH(0, 0, 1920, 1080),
          );
          await window.show();
          // Push full payload after the window exists to reduce native bridge pressure.
          // Give the secondary engine more time to initialize before sending content.
          await Future.delayed(const Duration(milliseconds: 500));
          debugPrint(
            'out: sending initial content to windowId=${window.windowId}',
          );
          await DesktopMultiWindow.invokeMethod(
            window.windowId,
            'updateContent',
            payloadJson,
          );
          _outputWindowIds[output.id] = window.windowId;
          debugPrint(
            'out: created windowId=${window.windowId} for output=${output.id}',
          );
          return true;
        } finally {
          _pendingOutputCreates.remove(output.id);
        }
      } else {
        try {
          debugPrint(
            'out: updating windowId=$windowId for output=${output.id}',
          );
          await DesktopMultiWindow.invokeMethod(
            windowId,
            'updateContent',
            payloadJson,
          );
          return true;
        } on PlatformException {
          debugPrint('out: update failed for windowId=$windowId, recreating');
          // Window was likely closed; recreate immediately so rapid re-open works.
          _outputWindowIds.remove(output.id);
          if (!createIfMissing || _pendingOutputCreates.contains(output.id))
            return false;
          _pendingOutputCreates.add(output.id);
          try {
            debugPrint('out: recreating window for output=${output.id}');
            final window = await _safeCreateWindow('{}');
            if (window == null) {
              debugPrint('out: recreate window skipped due to plugin error');
              return false;
            }
            window.setTitle(output.name);
            await window.setFrame(
              targetFrame ?? const Rect.fromLTWH(0, 0, 1920, 1080),
            );
            await window.show();
            // Give the secondary engine more time to initialize before sending content.
            await Future.delayed(const Duration(milliseconds: 500));
            debugPrint(
              'out: sending initial content to recreated windowId=${window.windowId}',
            );
            await DesktopMultiWindow.invokeMethod(
              window.windowId,
              'updateContent',
              payloadJson,
            );
            _outputWindowIds[output.id] = window.windowId;
            debugPrint(
              'out: recreated windowId=${window.windowId} for output=${output.id}',
            );
            return true;
          } finally {
            _pendingOutputCreates.remove(output.id);
          }
        }
      }
    } catch (e) {
      debugPrint('out: ensure window error=$e');
      _showSnack('Output error: $e');
    }
    return false;
  }

  Future<WindowController?> _safeCreateWindow(String serialized) async {
    try {
      return await DesktopMultiWindow.createWindow(serialized);
    } catch (e) {
      // Plugin occasionally throws when main window already exists or other platform errors; swallow to keep app alive.
      debugPrint('out: createWindow failed; skipping output create. error=$e');
      return null;
    }
  }

  Map<String, dynamic> _buildProjectionPayload(
    _SlideContent slide,
    _SlideTemplate template,
  ) {
    final align = slide.alignOverride ?? template.alignment;
    final bg = slide.backgroundColor ?? template.background;
    final mediaLayer = _effectiveMediaLayer(slide);
    final mediaPath = mediaLayer?.path ?? slide.mediaPath;
    final mediaTypeName = mediaLayer?.mediaType?.name ?? slide.mediaType?.name;
    final mediaOpacity = (mediaLayer?.opacity ?? 1.0).clamp(0.0, 1.0);
    return {
      'slide': {
        ...slide.toJson(),
        'templateTextColor': template.textColor.value,
        'templateBackground': bg.value,
        'templateFontSize': template.fontSize,
        'templateAlign': align.name,
        'mediaPath': mediaPath,
        'mediaType': mediaTypeName,
        'mediaOpacity': mediaOpacity,
      },
      'content': slide.body,
      'alignment': align.name,
    };
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showNoticeDialog(
    String title,
    String message, {
    bool success = false,
    bool offerSettings = false,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppPalette.carbonBlack,
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success ? Colors.greenAccent : Colors.amber,
              ),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            if (offerSettings)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openSettingsPage();
                },
                child: const Text('Open Settings'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveYoutubeApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = key.trim();
    await prefs.setString('youtube_api_key', value);
    setState(() => youtubeApiKey = value.isEmpty ? null : value);
    _showSnack('YouTube API key saved');
  }

  Future<void> _saveVimeoAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final value = token.trim();
    await prefs.setString('vimeo_access_token', value);
    setState(() => vimeoAccessToken = value.isEmpty ? null : value);
    _showSnack('Vimeo token saved');
  }

  Future<void> _setBoolPref(
    String key,
    bool value,
    void Function(bool) apply,
  ) async {
    setState(() => apply(value));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _setStringPref(
    String key,
    String value,
    void Function(String) apply,
  ) async {
    setState(() => apply(value));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _setDoublePref(
    String key,
    double value,
    void Function(double) apply,
  ) async {
    setState(() => apply(value));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _saveOutputs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _outputs.map((o) => o.toJson()).toList();
    await prefs.setString('outputs_json', json.encode(list));
  }

  Future<void> _saveStyles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'styles_json',
      json.encode(_styles.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('profiles', profiles);
  }

  Map<String, dynamic> _buildProgramStateSnapshot() {
    return {
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'shows': shows
          .map((s) => {'name': s.name, 'category': s.category})
          .toList(),
      'folders': folders,
      'showCategories': showCategories,
      'playlists': playlists,
      'projects': projects,
      'slides': _slides.map((s) => s.toJson()).toList(),
      'styles': _styles.map((s) => s.toJson()).toList(),
      'outputs': _outputs.map((o) => o.toJson()).toList(),
      'profiles': profiles,
      'settings': {
        'selectedTheme': selectedThemeName,
        'use24HourClock': use24HourClock,
        'lowerThirdHeight': lowerThirdHeight,
        'lowerThirdGradient': lowerThirdGradient,
        'stageNotesScale': stageNotesScale,
        'selectedTopTab': selectedTopTab,
      },
    };
  }

  String _timestampStamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  static const String _stateFileExtension = 'psshow';

  Future<File?> _writeStateFile(String directory, {String? fileName}) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final name =
        fileName ?? 'aurashow-state-${_timestampStamp()}.$_stateFileExtension';
    final path = directory + Platform.pathSeparator + name;
    final file = File(path);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(_buildProgramStateSnapshot()));
    return file;
  }

  Future<String?> _promptSaveFileName() async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppPalette.carbonBlack,
          title: const Text('Save As'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'File name',
              hintText: 'Leave blank for automatic name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _coerceFileName(String? raw) {
    final fallback = 'aurashow-state-${_timestampStamp()}.$_stateFileExtension';
    if (raw == null || raw.isEmpty) return fallback;
    var cleaned = raw.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[\\/:*?\"<>|]'), '_');
    // Strip any user-entered extension to enforce .psshow.
    if (cleaned.contains('.')) {
      cleaned = cleaned.split('.').first;
    }
    if (cleaned.isEmpty) return fallback;
    return '$cleaned.$_stateFileExtension';
  }

  Future<void> _saveProgramStateToFile() async {
    final targetDir = saveFolder;
    if (targetDir == null || targetDir.isEmpty) {
      await _showNoticeDialog(
        'Save failed',
        'Set a Save Folder first in Settings > Saves. After that, clicking Save will write directly to that folder.',
        offerSettings: true,
      );
      return;
    }
    final desiredName = await _promptSaveFileName();
    if (desiredName == null) {
      return;
    }
    final finalName = _coerceFileName(desiredName);
    try {
      final file = await _writeStateFile(targetDir, fileName: finalName);
      if (file != null) {
        await _showNoticeDialog(
          'Save successful',
          'Saved to ${file.path}',
          success: true,
        );
      } else {
        await _showNoticeDialog(
          'Save failed',
          'No file was written. Check folder permissions.',
          success: false,
        );
      }
    } catch (e) {
      await _showNoticeDialog(
        'Save failed',
        'Could not save: $e',
        success: false,
      );
    }
  }

  Future<void> _exportProgramState() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) {
      _showSnack('Export canceled');
      return;
    }
    final file = await _writeStateFile(dir);
    if (file != null) {
      _showSnack('Exported to ${file.path}');
    }
  }

  Future<void> _importProgramStateFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [_stateFileExtension, 'json'],
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      _showSnack('Import canceled');
      return;
    }

    final path = result.files.first.path!;
    final file = File(path);
    if (!file.existsSync()) {
      _showSnack('File not found');
      return;
    }

    try {
      final content = await file.readAsString();
      final decoded = json.decode(content);
      if (decoded is! Map<String, dynamic>) {
        _showSnack('Invalid save file');
        return;
      }
      _applyImportedState(decoded);
      _showSnack('Imported state applied');
    } catch (e) {
      _showSnack('Failed to import: $e');
    }
  }

  void _applyImportedState(Map<String, dynamic> data) {
    setState(() {
      shows =
          (data['shows'] as List?)?.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return ShowItem(
              name: m['name'] ?? 'Untitled',
              category: m['category'] as String?,
            );
          }).toList() ??
          shows;
      folders =
          (data['folders'] as List?)?.map((e) => e.toString()).toList() ??
          folders;
      showCategories =
          (data['showCategories'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          showCategories;
      playlists =
          (data['playlists'] as List?)?.map((e) => e.toString()).toList() ??
          playlists;
      projects =
          (data['projects'] as List?)?.map((e) => e.toString()).toList() ??
          projects;
      _slides =
          (data['slides'] as List?)
              ?.map(
                (e) =>
                    _SlideContent.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          _slides;
      _slideThumbnails = List<String?>.filled(
        _slides.length,
        null,
        growable: true,
      );
      _styles =
          (data['styles'] as List?)
              ?.map(
                (e) =>
                    _StylePreset.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          _styles;
      _outputs =
          (data['outputs'] as List?)
              ?.map(
                (e) =>
                    OutputConfig.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          _outputs;
      profiles =
          (data['profiles'] as List?)?.map((e) => e.toString()).toList() ??
          profiles;

      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        selectedThemeName =
            settings['selectedTheme'] as String? ?? selectedThemeName;
        use24HourClock = settings['use24HourClock'] as bool? ?? use24HourClock;
        lowerThirdHeight =
            (settings['lowerThirdHeight'] as num?)?.toDouble() ??
            lowerThirdHeight;
        lowerThirdGradient =
            settings['lowerThirdGradient'] as bool? ?? lowerThirdGradient;
        stageNotesScale =
            (settings['stageNotesScale'] as num?)?.toDouble() ??
            stageNotesScale;
        selectedTopTab = settings['selectedTopTab'] as int? ?? selectedTopTab;
      }

      selectedSlideIndex = _slides.isEmpty ? 0 : 0;
      selectedSlides = _slides.isEmpty ? <int>{} : {0};
    });

    _syncSlideThumbnails();
    _syncSlideEditors();
    _clampSelectedShow();
    _applyThemePreset(selectedThemeName, persist: false);
  }

  void _quitApp() {
    if (kIsWeb) return;
    exit(0);
  }

  bool _hasSelection() =>
      selectedSlides.isNotEmpty ||
      selectedSlideIndex >= 0 && selectedSlideIndex < _slides.length;

  void _undoAction() => _showSnack('Undo not implemented yet');
  void _redoAction() => _showSnack('Redo not implemented yet');
  void _historyAction() => _showSnack('History not implemented yet');

  void _cutAction() {
    if (!_hasSelection()) return;
    _copyAction();
    _deleteAction();
    _showSnack('Cut selection');
  }

  List<_SlideContent> _clipboardSlides = [];

  void _copyAction() {
    if (!_hasSelection()) return;
    final indices = selectedSlides.isNotEmpty
        ? selectedSlides.toList()
        : [selectedSlideIndex];
    _clipboardSlides = [
      for (final i in indices.where((i) => i >= 0 && i < _slides.length))
        _slides[i].copyWith(),
    ];
    _showSnack('Copied ${_clipboardSlides.length} slide(s)');
  }

  void _pasteAction() {
    if (_clipboardSlides.isEmpty) {
      _showSnack('Nothing to paste');
      return;
    }
    setState(() {
      final insertAt = (_slides.isEmpty
          ? 0
          : math.min(selectedSlideIndex + 1, _slides.length));
      final clones = _clipboardSlides
          .map(
            (s) => s.copyWith(
              id: 's-${DateTime.now().microsecondsSinceEpoch}-${_slides.length}',
            ),
          )
          .toList();
      _slides = [
        ..._slides.sublist(0, insertAt),
        ...clones,
        ..._slides.sublist(insertAt),
      ];
      selectedSlideIndex = insertAt;
      selectedSlides = {insertAt};
    });
    _syncSlideThumbnails();
    _syncSlideEditors();
    _showSnack('Pasted ${_clipboardSlides.length} slide(s)');
  }

  void _deleteAction() {
    if (!_hasSelection()) return;
    if (selectedSlides.isNotEmpty) {
      _deleteSlides(selectedSlides);
    } else if (selectedSlideIndex >= 0 && selectedSlideIndex < _slides.length) {
      _deleteSlides({selectedSlideIndex});
    }
    _showSnack('Deleted selection');
  }

  void _selectAllAction() {
    if (_slides.isEmpty) return;
    setState(
      () => selectedSlides = {for (int i = 0; i < _slides.length; i++) i},
    );
    _showSnack('Selected all slides');
  }

  void _addOutput() {
    setState(() {
      _outputs = [
        ..._outputs,
        OutputConfig.defaultAudience().copyWith(
          id: 'output-${DateTime.now().microsecondsSinceEpoch}',
          name: 'Output ${_outputs.length + 1}',
        ),
      ];
      _ensureOutputPreviewVisibilityDefaults();
    });
    _saveOutputs();
  }

  void _updateOutput(OutputConfig updated) {
    setState(() {
      _outputs = _outputs.map((o) => o.id == updated.id ? updated : o).toList();
    });
    _saveOutputs();
  }

  void _ensureOutputPreviewVisibilityDefaults() {
    for (final output in _outputs) {
      _outputPreviewVisible.putIfAbsent(output.id, () => true);
    }
    final existingIds = _outputs.map((o) => o.id).toSet();
    _outputPreviewVisible.removeWhere((key, _) => !existingIds.contains(key));
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

  Future<List<_MediaEntry>> _searchYouTubeOnline(
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

    return items.map<_MediaEntry>((item) {
      final id = item['id']?['videoId'] ?? '';
      final snippet = item['snippet'] ?? {};
      final title = snippet['title'] ?? 'Untitled';
      final channel = snippet['channelTitle'] ?? 'YouTube';
      final thumb =
          snippet['thumbnails']?['medium']?['url'] ??
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
    return data.map<_MediaEntry>((item) {
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
        _LiveDevice(
          id: 'screen-1',
          name: 'Main Display',
          detail: '1920x1080 @60Hz',
        ),
        _LiveDevice(
          id: 'screen-2',
          name: 'Projector',
          detail: '1280x720 @60Hz',
        ),
      ]);
    }
    if (_connectedCameras.isEmpty) {
      _connectedCameras.add(
        _LiveDevice(id: 'cam-1', name: 'USB Camera', detail: 'Front stage'),
      );
    }
  }

  Future<void> _refreshScreensFromPlatform() async {
    try {
      final displays = await ScreenRetriever.instance.getAllDisplays();
      if (displays.isEmpty) {
        _seedDemoDevices();
        return;
      }

      if (!mounted) return;
      setState(() {
        _connectedScreens
          ..clear()
          ..addAll(
            displays.map((d) {
              final pos = d.visiblePosition ?? Offset.zero;
              final size = d.visibleSize ?? d.size ?? const Size(0, 0);
              final name = d.name ?? 'Display ${d.id}';
              return _LiveDevice(
                id: 'display-${d.id}',
                name: name,
                detail:
                    '${size.width.toInt()}x${size.height.toInt()} @(${pos.dx.toInt()},${pos.dy.toInt()})',
              );
            }),
          );
      });
    } catch (_) {
      _seedDemoDevices();
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

  Future<void> _addYouTubeVideo(String id, String title) async {
    if (savedYouTubeVideos.any((v) => v['id'] == id)) {
      _showSnack('Video already saved');
      return;
    }
    final newList = [
      ...savedYouTubeVideos,
      {'id': id, 'title': title},
    ];
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
    final bool isEditTab = selectedTopTab == 1;
    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _leftPaneWidth,
          child: () {
            if (selectedTopTab == 1) return _buildEditLeftPane();
            if (selectedTopTab == 2) return _buildStageLayoutListPanel();
            return _buildShowListPanel();
          }(),
        ),
        _dragHandle(
          onDrag: (dx) => setState(() {
            _leftPaneWidth = _safeClamp(
              _leftPaneWidth + dx,
              _minPaneWidth,
              520,
            );
          }),
        ),
        Expanded(child: _buildCenterContent()),
        _dragHandle(
          onDrag: (dx) => setState(() {
            _rightPaneWidth = _safeClamp(_rightPaneWidth - dx, 240, 520);
          }),
        ),
        SizedBox(width: _rightPaneWidth, child: _buildRightPanel()),
      ],
    );

    return Scaffold(
      backgroundColor: bgDark,
      appBar: null,
      body: Column(
        children: [
          _buildTopNavBar(),
          Expanded(
            child: isEditTab
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: rowContent,
                  )
                : rowContent,
          ),
          _buildBottomDrawer(),
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
      _buildAudioTab(),
      _buildScriptureTab(),
      _buildLyricsTab(),
    ];

    final double collapsedHeight = _safeClamp(
      _drawerTabHeight + 4,
      _drawerMinHeight,
      double.infinity,
    );
    // Only render the heavy tab content when we have enough height to avoid overflow.
    final bool showContent =
        drawerExpanded && _drawerHeight > (_drawerMinHeight + 80);
    final targetHeight =
        (drawerExpanded ? _drawerHeight : collapsedHeight) + bottomInset;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: targetHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        border: const Border(top: BorderSide(color: Colors.white10)),
        boxShadow: drawerExpanded
            ? [
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, -4),
                ),
              ]
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
                  onVerticalDragStart: (_) =>
                      setState(() => drawerExpanded = true),
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
                        _drawerHeight = drawerExpanded
                            ? _drawerDefaultHeight
                            : _drawerMinHeight;
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
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            isScrollable: true,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 34,
                            ),
                            indicatorPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(
          '$label coming soon',
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Bible books data - use ScriptureService for consistent data
  static List<Map<String, dynamic>> get _bibleBooks => ScriptureService.books;

  // Bible API sources configuration
  static const List<Map<String, dynamic>> _bibleApiSources = [
    {
      'id': 'bolls',
      'name': 'Bolls.life',
      'baseUrl': 'https://bolls.life',
      'free': true,
      'description': 'Free API with 50+ translations including KJV, NKJV, ESV, NIV, NLT, etc.',
    },
    {
      'id': 'bible-api',
      'name': 'Bible-API.com',
      'baseUrl': 'https://bible-api.com',
      'free': true,
      'description': 'Simple free API with KJV, WEB, ASV and other public domain translations.',
    },
  ];

  // Translations available from each API
  static const Map<String, List<Map<String, String>>> _apiTranslations = {
    'bolls': [
      {'id': 'KJV', 'name': 'King James Version'},
      {'id': 'NKJV', 'name': 'New King James Version'},
      {'id': 'ESV', 'name': 'English Standard Version'},
      {'id': 'NIV', 'name': 'New International Version'},
      {'id': 'NLT', 'name': 'New Living Translation'},
      {'id': 'NASB', 'name': 'New American Standard Bible'},
      {'id': 'AMP', 'name': 'Amplified Bible'},
      {'id': 'MSG', 'name': 'The Message'},
      {'id': 'YLT', 'name': "Young's Literal Translation"},
      {'id': 'WEB', 'name': 'World English Bible'},
      {'id': 'ASV', 'name': 'American Standard Version'},
      {'id': 'SYNOD', 'name': 'Russian Synodal'},
      {'id': 'LXX', 'name': 'Septuagint (Greek)'},
      {'id': 'TR', 'name': 'Textus Receptus (Greek)'},
      {'id': 'CUV', 'name': 'Chinese Union Version'},
      {'id': 'RVR', 'name': 'Reina Valera (Spanish)'},
    ],
    'bible-api': [
      {'id': 'kjv', 'name': 'King James Version'},
      {'id': 'web', 'name': 'World English Bible'},
      {'id': 'asv', 'name': 'American Standard Version'},
      {'id': 'bbe', 'name': 'Bible in Basic English'},
      {'id': 'darby', 'name': 'Darby Bible'},
      {'id': 'ylt', 'name': "Young's Literal Translation"},
      {'id': 'oeb-us', 'name': 'Open English Bible (US)'},
      {'id': 'oeb-cw', 'name': 'Open English Bible (UK)'},
      {'id': 'webbe', 'name': 'World English Bible (British)'},
      {'id': 'cuv', 'name': 'Chinese Union Version'},
      {'id': 'cherokee', 'name': 'Cherokee New Testament'},
      {'id': 'almeida', 'name': 'João Ferreira de Almeida (Portuguese)'},
    ],
  };

  // Book ID mapping for Bolls API (1-66)
  static const Map<String, int> _bookIdMap = {
    'Genesis': 1, 'Exodus': 2, 'Leviticus': 3, 'Numbers': 4, 'Deuteronomy': 5,
    'Joshua': 6, 'Judges': 7, 'Ruth': 8, '1 Samuel': 9, '2 Samuel': 10,
    '1 Kings': 11, '2 Kings': 12, '1 Chronicles': 13, '2 Chronicles': 14,
    'Ezra': 15, 'Nehemiah': 16, 'Esther': 17, 'Job': 18, 'Psalms': 19,
    'Proverbs': 20, 'Ecclesiastes': 21, 'Song of Solomon': 22, 'Isaiah': 23,
    'Jeremiah': 24, 'Lamentations': 25, 'Ezekiel': 26, 'Daniel': 27,
    'Hosea': 28, 'Joel': 29, 'Amos': 30, 'Obadiah': 31, 'Jonah': 32,
    'Micah': 33, 'Nahum': 34, 'Habakkuk': 35, 'Zephaniah': 36, 'Haggai': 37,
    'Zechariah': 38, 'Malachi': 39, 'Matthew': 40, 'Mark': 41, 'Luke': 42,
    'John': 43, 'Acts': 44, 'Romans': 45, '1 Corinthians': 46, '2 Corinthians': 47,
    'Galatians': 48, 'Ephesians': 49, 'Philippians': 50, 'Colossians': 51,
    '1 Thessalonians': 52, '2 Thessalonians': 53, '1 Timothy': 54, '2 Timothy': 55,
    'Titus': 56, 'Philemon': 57, 'Hebrews': 58, 'James': 59, '1 Peter': 60,
    '2 Peter': 61, '1 John': 62, '2 John': 63, '3 John': 64, 'Jude': 65,
    'Revelation': 66,
  };

  List<Map<String, String>> get _currentApiTranslations {
    // Check custom APIs first, then built-in
    if (_customApiTranslations.containsKey(_selectedBibleApi)) {
      return _customApiTranslations[_selectedBibleApi]!;
    }
    return _apiTranslations[_selectedBibleApi] ?? [];
  }

  List<Map<String, dynamic>> get _allBibleApiSources {
    return [..._bibleApiSources, ..._customBibleApiSources];
  }

  /// Build the Audio tab with FreeShow-style features
  Widget _buildAudioTab() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with mode tabs
          Row(
            children: [
              Icon(Icons.music_note, size: 16, color: accentBlue),
              const SizedBox(width: 6),
              const Text('Audio', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              // Mode toggle buttons
              _audioModeButton('Files', 'files', Icons.folder_open),
              _audioModeButton('Playlists', 'playlists', Icons.queue_music),
              _audioModeButton('Effects', 'effects', Icons.campaign),
              _audioModeButton('Metronome', 'metronome', Icons.timer),
            ],
          ),
          const SizedBox(height: 8),
          
          // Now Playing bar (if audio is playing)
          if (_currentlyPlayingAudioPath != null) _buildNowPlayingBar(),
          
          // Content based on mode
          Expanded(
            child: _audioTabMode == 'files'
                ? _buildAudioFilesView()
                : _audioTabMode == 'playlists'
                    ? _buildAudioPlaylistsView()
                    : _audioTabMode == 'effects'
                        ? _buildSoundEffectsView()
                        : _buildMetronomeView(),
          ),
        ],
      ),
    );
  }

  Widget _audioModeButton(String label, String mode, IconData icon) {
    final isActive = _audioTabMode == mode;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: () => setState(() => _audioTabMode = mode),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? accentBlue.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? accentBlue : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: isActive ? accentBlue : Colors.white54),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? accentBlue : Colors.white54,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Now Playing bar with playback controls
  Widget _buildNowPlayingBar() {
    final fileName = _currentlyPlayingAudioPath?.split(Platform.pathSeparator).last ?? 'Unknown';
    final progress = _audioDuration > 0 ? _audioPosition / _audioDuration : 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: accentPink.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentPink.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play/Pause
              IconButton(
                icon: Icon(
                  _isAudioPlaying && !_isAudioPaused ? Icons.pause : Icons.play_arrow,
                  size: 20,
                ),
                onPressed: _toggleAudioPlayback,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: accentPink,
              ),
              const SizedBox(width: 8),
              // Stop
              IconButton(
                icon: const Icon(Icons.stop, size: 18),
                onPressed: _stopAudio,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.white54,
              ),
              const SizedBox(width: 12),
              // Track info and seekable progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Seekable progress bar
                    SizedBox(
                      height: 16,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          activeTrackColor: accentPink,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: accentPink,
                          overlayColor: accentPink.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (v) {
                            if (_audioDuration > 0) {
                              _seekAudio(v * _audioDuration);
                            }
                          },
                          min: 0,
                          max: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Time
              Text(
                '${_formatAudioTime(_audioPosition.toInt())} / ${_formatAudioTime(_audioDuration.toInt())}',
                style: const TextStyle(fontSize: 9, color: Colors.white54),
              ),
              const SizedBox(width: 8),
              // Volume icon (click to mute)
              IconButton(
                icon: Icon(
                  _audioVolume > 0 ? Icons.volume_up : Icons.volume_off,
                  size: 14,
                ),
                onPressed: () => _setAudioVolume(_audioVolume > 0 ? 0 : 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.white54,
                tooltip: 'Mute/Unmute',
              ),
              SizedBox(
                width: 60,
                child: Slider(
                  value: _audioVolume,
                  onChanged: _setAudioVolume,
                  min: 0,
                  max: 1,
                  activeColor: accentPink,
                  inactiveColor: Colors.white24,
                ),
              ),
              // Loop toggle
              IconButton(
                icon: Icon(
                  Icons.repeat,
                  size: 16,
                  color: _audioLoop ? accentPink : Colors.white38,
                ),
                onPressed: () {
                  setState(() => _audioLoop = !_audioLoop);
                  _audioPlayer?.setLoopMode(_audioLoop ? ja.LoopMode.one : ja.LoopMode.off);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Loop',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAudioTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Initialize audio player with listeners
  void _initAudioPlayer() {
    _audioPlayer = ja.AudioPlayer();
    
    // Listen to position updates
    _audioPositionSubscription = _audioPlayer!.positionStream.listen((position) {
      if (mounted) {
        setState(() => _audioPosition = position.inSeconds.toDouble());
      }
    });
    
    // Listen to duration updates
    _audioDurationSubscription = _audioPlayer!.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() => _audioDuration = duration.inSeconds.toDouble());
      }
    });
    
    // Listen to player state changes
    _audioPlayerStateSubscription = _audioPlayer!.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = state.playing;
          _isAudioPaused = !state.playing && state.processingState != ja.ProcessingState.completed;
          
          // Handle track completion
          if (state.processingState == ja.ProcessingState.completed) {
            if (_audioLoop) {
              _audioPlayer?.seek(Duration.zero);
              _audioPlayer?.play();
            } else {
              _audioPosition = 0;
              _isAudioPlaying = false;
            }
          }
        });
      }
    });
  }

  /// Dispose audio player resources
  void _disposeAudioPlayer() {
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _audioPlayerStateSubscription?.cancel();
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  void _toggleAudioPlayback() {
    if (_audioPlayer == null) return;
    
    if (_audioPlayer!.playing) {
      _audioPlayer!.pause();
    } else {
      _audioPlayer!.play();
    }
  }

  void _stopAudio() {
    _audioPlayer?.stop();
    setState(() {
      _currentlyPlayingAudioPath = null;
      _isAudioPlaying = false;
      _isAudioPaused = false;
      _audioPosition = 0;
      _audioDuration = 0;
    });
  }

  void _seekAudio(double seconds) {
    _audioPlayer?.seek(Duration(seconds: seconds.toInt()));
  }

  void _setAudioVolume(double volume) {
    setState(() => _audioVolume = volume);
    _audioPlayer?.setVolume(volume);
  }

  /// Get combined list of audio files (songs + optionally video files)
  List<FileSystemEntity> get _audioFiles {
    if (_showVideoFilesInAudio) {
      // Combine audio files and video files (videos have audio tracks)
      return [...discoveredSongs, ...discoveredVideos];
    }
    return discoveredSongs;
  }

  /// Check if a file is a video (vs pure audio)
  bool _isVideoFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.mkv') || ext.endsWith('.avi') || 
           ext.endsWith('.mov') || ext.endsWith('.webm') || ext.endsWith('.wmv');
  }

  /// Audio files browser view
  Widget _buildAudioFilesView() {
    final files = _audioFiles;
    
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 40, color: Colors.white24),
            const SizedBox(height: 8),
            const Text(
              'No audio files found',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _selectAudioFolder,
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Select Folder', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folder info and toggle
        Row(
          children: [
            Expanded(
              child: Text(
                songFolder ?? videoFolder ?? 'No folder selected',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Toggle to include videos
            Tooltip(
              message: 'Include video files (play audio from videos)',
              child: InkWell(
                onTap: () => setState(() => _showVideoFilesInAudio = !_showVideoFilesInAudio),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _showVideoFilesInAudio ? accentBlue.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _showVideoFilesInAudio ? accentBlue : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam,
                        size: 12,
                        color: _showVideoFilesInAudio ? accentBlue : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Videos',
                        style: TextStyle(
                          fontSize: 9,
                          color: _showVideoFilesInAudio ? accentBlue : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.folder_open, size: 14),
              onPressed: _selectAudioFolder,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Change folder',
            ),
          ],
        ),
        const SizedBox(height: 4),
        // File count
        Text(
          '${files.length} file${files.length == 1 ? '' : 's'}${_showVideoFilesInAudio ? ' (incl. videos)' : ''}',
          style: const TextStyle(fontSize: 9, color: Colors.white24),
        ),
        const SizedBox(height: 4),
        // Audio files list
        Expanded(
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, i) {
              final file = files[i];
              final name = file.path.split(Platform.pathSeparator).last;
              final isPlaying = _currentlyPlayingAudioPath == file.path;
              final isVideo = _isVideoFile(file.path);
              
              return InkWell(
                onTap: () => _playAudioFile(file.path),
                onDoubleTap: () => _addAudioToSlide(file.path),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isPlaying ? accentPink.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      // Icon based on type and state
                      Icon(
                        isPlaying 
                            ? Icons.play_arrow 
                            : (isVideo ? Icons.videocam : Icons.music_note),
                        size: 14,
                        color: isPlaying 
                            ? accentPink 
                            : (isVideo ? accentBlue : Colors.white38),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            color: isPlaying ? Colors.white : Colors.white70,
                            fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Video badge
                      if (isVideo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: accentBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'VIDEO',
                            style: TextStyle(fontSize: 8, color: Colors.white54),
                          ),
                        ),
                      // Quick actions
                      IconButton(
                        icon: const Icon(Icons.add, size: 14),
                        onPressed: () => _addAudioToSlide(file.path),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Add to slide',
                        color: Colors.white38,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _selectAudioFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        songFolder = result;
      });
      _scanFolder(result, ['.mp3', '.wav', '.flac', '.ogg', '.m4a'], (list) => setState(() => discoveredSongs = list));
    }
  }

  Future<void> _playAudioFile(String path) async {
    // Initialize player if needed
    if (_audioPlayer == null) {
      _initAudioPlayer();
    }
    
    try {
      // Stop current playback if different file
      if (_currentlyPlayingAudioPath != path) {
        await _audioPlayer!.stop();
      }
      
      // Set the audio source
      await _audioPlayer!.setFilePath(path);
      
      // Set volume and loop mode
      await _audioPlayer!.setVolume(_audioVolume);
      await _audioPlayer!.setLoopMode(_audioLoop ? ja.LoopMode.one : ja.LoopMode.off);
      
      setState(() {
        _currentlyPlayingAudioPath = path;
        _isAudioPlaying = true;
        _isAudioPaused = false;
        _audioPosition = 0;
      });
      
      // Start playback
      await _audioPlayer!.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing audio: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addAudioToSlide(String path) {
    // TODO: Add audio to current slide
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added audio: ${path.split(Platform.pathSeparator).last}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Playlists management view
  Widget _buildAudioPlaylistsView() {
    if (_audioPlaylists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music, size: 40, color: Colors.white24),
            const SizedBox(height: 8),
            const Text(
              'No playlists created',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _createNewPlaylist,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create Playlist', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Create playlist button
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _createNewPlaylist,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('New Playlist', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Playlists list
        Expanded(
          child: ListView.builder(
            itemCount: _audioPlaylists.length,
            itemBuilder: (context, i) {
              final playlist = _audioPlaylists[i];
              final isSelected = _selectedPlaylistId == playlist['id'];
              final songCount = (playlist['songs'] as List?)?.length ?? 0;
              
              return InkWell(
                onTap: () => setState(() => _selectedPlaylistId = playlist['id'] as String?),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? accentBlue.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? accentBlue : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.queue_music,
                        size: 16,
                        color: isSelected ? accentBlue : Colors.white38,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist['name'] as String? ?? 'Unnamed',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            Text(
                              '$songCount songs',
                              style: const TextStyle(fontSize: 10, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      // Play button
                      IconButton(
                        icon: const Icon(Icons.play_circle, size: 20),
                        onPressed: () => _playPlaylist(playlist),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: accentBlue,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _createNewPlaylist() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _audioPlaylists.add({
        'id': id,
        'name': 'Playlist ${_audioPlaylists.length + 1}',
        'songs': <String>[],
      });
      _selectedPlaylistId = id;
    });
  }

  void _playPlaylist(Map<String, dynamic> playlist) {
    final songs = playlist['songs'] as List?;
    if (songs != null && songs.isNotEmpty) {
      _playAudioFile(songs.first as String);
    }
  }

  /// Sound effects quick-trigger view
  Widget _buildSoundEffectsView() {
    // Predefined sound effect categories
    final effects = [
      {'name': 'Applause', 'icon': Icons.thumb_up},
      {'name': 'Bell', 'icon': Icons.notifications},
      {'name': 'Buzzer', 'icon': Icons.error},
      {'name': 'Countdown', 'icon': Icons.timer},
      {'name': 'Ding', 'icon': Icons.check_circle},
      {'name': 'Drum Roll', 'icon': Icons.music_note},
      {'name': 'Horn', 'icon': Icons.volume_up},
      {'name': 'Whoosh', 'icon': Icons.air},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Click to play sound effects',
          style: TextStyle(fontSize: 10, color: Colors.white38),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemCount: effects.length,
            itemBuilder: (context, i) {
              final effect = effects[i];
              return InkWell(
                onTap: () => _playSoundEffect(effect['name'] as String),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        effect['icon'] as IconData,
                        size: 24,
                        color: accentBlue,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        effect['name'] as String,
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _playSoundEffect(String name) {
    // TODO: Play actual sound effect
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing: $name'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  /// Metronome view with BPM control
  Widget _buildMetronomeView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // BPM display
        Text(
          '$_metronomeBpm',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: _metronomeRunning ? accentPink : Colors.white,
          ),
        ),
        const Text(
          'BPM',
          style: TextStyle(fontSize: 14, color: Colors.white54),
        ),
        const SizedBox(height: 16),
        // BPM slider
        Row(
          children: [
            const Text('40', style: TextStyle(fontSize: 10, color: Colors.white38)),
            Expanded(
              child: Slider(
                value: _metronomeBpm.toDouble(),
                onChanged: (v) => setState(() => _metronomeBpm = v.round()),
                min: 40,
                max: 240,
                divisions: 200,
                activeColor: accentPink,
                inactiveColor: Colors.white24,
              ),
            ),
            const Text('240', style: TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
        const SizedBox(height: 8),
        // Quick BPM buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [60, 80, 100, 120, 140].map((bpm) {
            final isSelected = _metronomeBpm == bpm;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => setState(() => _metronomeBpm = bpm),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? accentPink.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? accentPink : Colors.white24,
                    ),
                  ),
                  child: Text(
                    '$bpm',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? accentPink : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Time signature
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Beats per measure: ', style: TextStyle(fontSize: 11, color: Colors.white54)),
            DropdownButton<int>(
              value: _metronomeBeatsPerMeasure,
              dropdownColor: AppPalette.carbonBlack,
              style: const TextStyle(fontSize: 12, color: Colors.white),
              underline: Container(height: 1, color: Colors.white24),
              items: [2, 3, 4, 5, 6, 7, 8].map((b) {
                return DropdownMenuItem(value: b, child: Text('$b'));
              }).toList(),
              onChanged: (v) => setState(() => _metronomeBeatsPerMeasure = v ?? 4),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Beat indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_metronomeBeatsPerMeasure, (i) {
            final isCurrentBeat = _metronomeRunning && _metronomeCurrentBeat == i;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isCurrentBeat
                      ? (i == 0 ? accentPink : accentBlue)
                      : Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == 0 ? accentPink : accentBlue,
                    width: 2,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        // Start/Stop button
        ElevatedButton.icon(
          onPressed: _toggleMetronome,
          icon: Icon(_metronomeRunning ? Icons.stop : Icons.play_arrow),
          label: Text(_metronomeRunning ? 'Stop' : 'Start'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _metronomeRunning ? Colors.red : accentPink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
        ),
      ],
    );
  }

  Timer? _metronomeTimer;

  void _toggleMetronome() {
    if (_metronomeRunning) {
      _metronomeTimer?.cancel();
      setState(() {
        _metronomeRunning = false;
        _metronomeCurrentBeat = 0;
      });
    } else {
      setState(() {
        _metronomeRunning = true;
        _metronomeCurrentBeat = 0;
      });
      final interval = Duration(milliseconds: (60000 / _metronomeBpm).round());
      _metronomeTimer = Timer.periodic(interval, (timer) {
        if (!_metronomeRunning) {
          timer.cancel();
          return;
        }
        setState(() {
          _metronomeCurrentBeat = (_metronomeCurrentBeat + 1) % _metronomeBeatsPerMeasure;
        });
        // TODO: Play click sound
      });
    }
  }

  Widget _buildScriptureTab() {
    final bookData = _selectedBook != null
        ? _bibleBooks.firstWhere(
            (b) => b['name'] == _selectedBook,
            orElse: () => {'chapters': 0},
          )
        : null;
    final chapterCount = (bookData?['chapters'] as int?) ?? 0;
    final translations = _currentApiTranslations;

    return GestureDetector(
      onTap: () {
        // Dismiss search results when tapping outside
        if (_showScriptureSearchResults) {
          setState(() => _showScriptureSearchResults = false);
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.carbonBlack,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: API Source, Version & Book selection
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // API Source selector
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_outlined,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Source',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      const Spacer(),
                      // Add custom API button
                      InkWell(
                      onTap: _showAddApiDialog,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.add_circle_outline,
                          size: 14,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedBibleApi,
                        dropdownColor: AppPalette.carbonBlack,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        items: _allBibleApiSources
                            .map((api) => DropdownMenuItem(
                                  value: api['id'] as String,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(api['name'] as String),
                                      if (api['custom'] == true) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.star, size: 10, color: Colors.amber),
                                      ],
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedBibleApi = v;
                              // Reset to first available translation
                              final trans = _currentApiTranslations;
                              if (trans.isNotEmpty) {
                                _selectedBibleVersion = trans[0]['id']!;
                              }
                              _loadedVerses = [];
                            });
                          }
                        },
                      ),
                    ),
                    // Delete custom source button
                    if (_customBibleApiSources.any((api) => api['id'] == _selectedBibleApi))
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: AppPalette.carbonBlack,
                              title: const Text('Remove Custom Source?', style: TextStyle(color: Colors.white)),
                              content: Text(
                                'Remove "${_allBibleApiSources.firstWhere((api) => api['id'] == _selectedBibleApi)['name']}"?',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _customBibleApiSources.removeWhere((api) => api['id'] == _selectedBibleApi);
                                      _customApiTranslations.remove(_selectedBibleApi);
                                      _selectedBibleApi = 'bolls';
                                      _selectedBibleVersion = 'KJV';
                                      _loadedVerses = [];
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Remove', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Version dropdown
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book,
                      size: 16,
                      color: AppPalette.dustyMauve,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Version',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 90),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButton<String>(
                        value: translations.any((t) => t['id'] == _selectedBibleVersion)
                            ? _selectedBibleVersion
                            : (translations.isNotEmpty ? translations[0]['id'] : 'KJV'),
                        dropdownColor: AppPalette.carbonBlack,
                        underline: const SizedBox.shrink(),
                        isExpanded: true,
                        isDense: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        items: translations
                            .map((t) => DropdownMenuItem(
                                  value: t['id'],
                                  child: Text(t['id']!, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedBibleVersion = v;
                              _loadedVerses = [];
                            });
                            if (_selectedBook != null && _selectedChapter != null) {
                              _loadChapterVerses();
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Testament filter dropdown
                Row(
                  children: [
                    const Text(
                      'Books',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _testamentFilter,
                        dropdownColor: AppPalette.carbonBlack,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'OT', child: Text('Old')),
                          DropdownMenuItem(value: 'NT', child: Text('New')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _testamentFilter = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        if (_testamentFilter == 'all' || _testamentFilter == 'OT') ...[
                          _scriptureTestamentHeader('Old Testament'),
                          ..._bibleBooks
                              .where((b) => b['testament'] == 'OT')
                              .map((b) => _scriptureBookTile(b)),
                        ],
                        if (_testamentFilter == 'all') const SizedBox(height: 8),
                        if (_testamentFilter == 'all' || _testamentFilter == 'NT') ...[
                          _scriptureTestamentHeader('New Testament'),
                          ..._bibleBooks
                              .where((b) => b['testament'] == 'NT')
                              .map((b) => _scriptureBookTile(b)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Middle column: Chapter & Verse selection
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chapter',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _selectedBook == null
                        ? const Center(
                            child: Text(
                              'Select a book',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(6),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              childAspectRatio: 1,
                            ),
                            itemCount: chapterCount,
                            itemBuilder: (context, i) {
                              final chapter = i + 1;
                              final isSelected = _selectedChapter == chapter;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedChapter = chapter;
                                    _selectedVerseStart = null;
                                    _selectedVerseEnd = null;
                                  });
                                  _loadChapterVerses();
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accentPink.withOpacity(0.4)
                                        : Colors.white12,
                                    borderRadius: BorderRadius.circular(6),
                                    border: isSelected
                                        ? Border.all(color: accentPink, width: 2)
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$chapter',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Right column: Verses display and actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar with results overlay (FreeShow-style)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: TextField(
                              controller: _scriptureSearchController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Type "ma" → Matthew, "ma 5" → chapter, "ma 5:3" → verse',
                                hintStyle: const TextStyle(fontSize: 10),
                                prefixIcon: const Icon(Icons.search, size: 16),
                                suffixIcon: _scriptureSearchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close, size: 14),
                                          onPressed: () {
                                            setState(() {
                                              _scriptureSearchController.clear();
                                              _scriptureSearchResults = [];
                                              _showScriptureSearchResults = false;
                                            });
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.black26,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {});
                                  _scriptureSearchDebouncer.call(() {
                                    _performScriptureSearch(value);
                                  });
                                },
                                onSubmitted: (_) => _selectFirstSearchResult(),
                              ),
                            ),
                          ),
                        if (_scriptureSearching)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    // Search results dropdown (only for text search in verses)
                    if (_showScriptureSearchResults && _scriptureSearchResults.isNotEmpty)
                      Positioned(
                        top: 36,
                        left: 0,
                        right: 0,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(6),
                          color: AppPalette.carbonBlack,
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    'Found ${_scriptureSearchResults.length} verse${_scriptureSearchResults.length == 1 ? '' : 's'} containing "${_scriptureSearchController.text.trim()}"',
                                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                                  ),
                                ),
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: math.min(_scriptureSearchResults.length, 10),
                                    itemBuilder: (context, index) {
                                      final result = _scriptureSearchResults[index];
                                      final reference = result['reference'] as String;
                                      final verseText = result['text'] as String? ?? '';
                                      final highlightTerm = _scriptureSearchController.text.trim().toLowerCase();
                                      
                                      return InkWell(
                                        onTap: () => _selectScriptureSearchResult(result),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: index == 0 ? Colors.white.withOpacity(0.05) : null,
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                reference,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              if (verseText.isNotEmpty)
                                                Text(
                                                  verseText.length > 80
                                                      ? '${verseText.substring(0, 80)}...'
                                                      : verseText,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white.withOpacity(0.6),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
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
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Verse reference display
                if (_selectedBook != null && _selectedChapter != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentPink.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_selectedBook $_selectedChapter${_selectedVerseStart != null ? ':$_selectedVerseStart' : ''}${_selectedVerseEnd != null && _selectedVerseEnd != _selectedVerseStart ? '-$_selectedVerseEnd' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($_selectedBibleVersion)',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.cloud_done,
                          size: 12,
                          color: Colors.green.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                // Verses list
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _loadingVerses
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(height: 8),
                                Text(
                                  'Fetching verses...',
                                  style: TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        : _loadedVerses.isEmpty
                            ? Center(
                                child: Text(
                                  _selectedChapter == null
                                      ? 'Select a chapter to view verses'
                                      : 'No verses loaded',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _versesScrollController,
                                padding: const EdgeInsets.all(8),
                                itemCount: _loadedVerses.length,
                                itemBuilder: (context, i) {
                                  final verse = _loadedVerses[i];
                                  final verseNum = verse['verse'] as int;
                                  final text = verse['text'] as String;
                                  final isSelected = _isVerseInRange(verseNum);
                                  return InkWell(
                                    onTap: () => _toggleVerseSelection(verseNum),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 6,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accentPink.withOpacity(0.2)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 28,
                                            child: Text(
                                              '$verseNum',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? accentPink
                                                    : Colors.white54,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              text,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.5,
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
                ),
                const SizedBox(height: 8),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 26,
                        child: ElevatedButton.icon(
                          onPressed: _selectedVerseStart != null
                              ? _addScriptureToSlide
                              : null,
                          icon: const Icon(Icons.add, size: 12),
                          label: const Text(
                            'Add',
                            style: TextStyle(fontSize: 10),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentPink,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white10,
                            disabledForegroundColor: Colors.white38,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 26,
                        child: ElevatedButton.icon(
                          onPressed: _selectedVerseStart != null
                              ? _createScriptureSlides
                              : null,
                          icon: const Icon(Icons.auto_awesome, size: 12),
                          label: const Text(
                            'Slides',
                            style: TextStyle(fontSize: 10),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white10,
                            disabledForegroundColor: Colors.white38,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 26,
                      child: ElevatedButton.icon(
                        onPressed: _sendScriptureToOutput,
                        icon: const Icon(Icons.cast, size: 12),
                        label: const Text(
                          'Show',
                          style: TextStyle(fontSize: 10),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.withOpacity(0.5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
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
  }

  Widget _buildLyricsTab() {
    return Column(
      children: [
        // Search bar
        TextField(
          controller: _lyricsSearchController,
          decoration: InputDecoration(
            hintText: 'Search for lyrics...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _searchLyrics,
            ),
          ),
        ),
        // Results
        if (_lyricsSearching)
          const CircularProgressIndicator()
        else if (_rawLyricsResult != null)
          Expanded(
            child: SingleChildScrollView(
              child: Text(_processedLyrics ?? _rawLyricsResult!),
            ),
          )
        else
          const Text('Search for lyrics to get started.'),
      ],
    );
  }

  Future<void> _searchLyrics() async {
    final query = _lyricsSearchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _lyricsSearching = true;
      _rawLyricsResult = null;
      _processedLyrics = null;
    });

    try {
      // Use the implemented service/method to get lyrics
      final rawLyrics = await _searchLyricsOnWeb(query);
      final processedLyrics = _processLyrics(rawLyrics);

      setState(() {
        _rawLyricsResult = rawLyrics;
        _processedLyrics = processedLyrics;
        _lyricsSearching = false;
      });
    } catch (e) {
      setState(() {
        _rawLyricsResult = 'Failed to load lyrics: $e';
        _processedLyrics = null;
        _lyricsSearching = false;
      });
    }
  }

  Future<String> _searchLyricsOnWeb(String query) async {
    // Placeholder for actual web search implementation.
    await Future.delayed(const Duration(seconds: 1)); 
    return "Lyrics for '$query' would appear here.\n\n(Web search implementation requires an API key or backend service)";
  }

  String _processLyrics(String rawLyrics) {
    // Simple formatting: add a new line after each sentence.
    return rawLyrics.replaceAllMapped(RegExp(r'(\.|\?|!)\s*'), (match) => '${match.group(0)}\n');
  }

  Widget _scriptureTestamentHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white60,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _scriptureBookTile(Map<String, dynamic> book) {
    final name = book['name'] as String;
    final isSelected = _selectedBook == name;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedBook = name;
          _selectedChapter = null;
          _selectedVerseStart = null;
          _selectedVerseEnd = null;
          _loadedVerses = [];
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentPink.withOpacity(0.2) : Colors.transparent,
          border: isSelected
              ? Border(left: BorderSide(color: accentPink, width: 2))
              : null,
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white,
          ),
        ),
      ),
    );
  }

  bool _isVerseInRange(int verse) {
    if (_selectedVerseStart == null) return false;
    if (_selectedVerseEnd == null) return verse == _selectedVerseStart;
    final start = math.min(_selectedVerseStart!, _selectedVerseEnd!);
    final end = math.max(_selectedVerseStart!, _selectedVerseEnd!);
    return verse >= start && verse <= end;
  }

  void _toggleVerseSelection(int verse) {
    setState(() {
      if (_selectedVerseStart == null) {
        _selectedVerseStart = verse;
        _selectedVerseEnd = null;
      } else if (_selectedVerseEnd == null) {
        if (verse == _selectedVerseStart) {
          _selectedVerseStart = null;
        } else {
          _selectedVerseEnd = verse;
        }
      } else {
        // Reset and start new selection
        _selectedVerseStart = verse;
        _selectedVerseEnd = null;
      }
    });
  }

  Future<void> _loadChapterVerses() async {
    if (_selectedBook == null || _selectedChapter == null) return;

    setState(() => _loadingVerses = true);

    try {
      final verses = <Map<String, dynamic>>[];

      if (_selectedBibleApi == 'bolls') {
        // Bolls.life API: https://bolls.life/get-text/TRANSLATION/BOOK_ID/CHAPTER/
        final bookId = _bookIdMap[_selectedBook] ?? 1;
        final url = Uri.parse(
          'https://bolls.life/get-text/$_selectedBibleVersion/$bookId/$_selectedChapter/',
        );
        
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          for (final verse in data) {
            verses.add({
              'verse': verse['verse'] ?? 0,
              'text': _cleanVerseText(verse['text'] ?? ''),
            });
          }
        } else {
          throw Exception('Failed to load verses: ${response.statusCode}');
        }
      } else if (_selectedBibleApi == 'bible-api') {
        // bible-api.com: https://bible-api.com/BOOK+CHAPTER?translation=xxx
        final bookName = _selectedBook!.replaceAll(' ', '%20');
        final url = Uri.parse(
          'https://bible-api.com/$bookName+$_selectedChapter?translation=$_selectedBibleVersion',
        );
        
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final List<dynamic> verseList = data['verses'] ?? [];
          for (final verse in verseList) {
            verses.add({
              'verse': verse['verse'] ?? 0,
              'text': _cleanVerseText(verse['text'] ?? ''),
            });
          }
        } else {
          throw Exception('Failed to load verses: ${response.statusCode}');
        }
      } else {
        // Custom API - check if we have a valid configuration
        final apiConfig = _bibleApiSources.firstWhere(
          (api) => api['id'] == _selectedBibleApi,
          orElse: () => <String, dynamic>{},
        );
        
        if (apiConfig.isNotEmpty && apiConfig['urlTemplate'] != null) {
          final urlTemplate = apiConfig['urlTemplate'] as String;
          final bookId = _bookIdMap[_selectedBook] ?? 1;
          final bookName = _selectedBook!.replaceAll(' ', '%20');
          
          final url = urlTemplate
              .replaceAll('{translation}', _selectedBibleVersion)
              .replaceAll('{book}', bookName)
              .replaceAll('{bookId}', bookId.toString())
              .replaceAll('{chapter}', _selectedChapter.toString());
          
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final dynamic data = json.decode(response.body);
            // Try to parse as array (bolls-style) or object with verses array (bible-api style)
            if (data is List) {
              for (final verse in data) {
                verses.add({
                  'verse': verse['verse'] ?? verse['v'] ?? 0,
                  'text': _cleanVerseText(verse['text'] ?? verse['t'] ?? ''),
                });
              }
            } else if (data is Map && data['verses'] != null) {
              for (final verse in data['verses']) {
                verses.add({
                  'verse': verse['verse'] ?? verse['v'] ?? 0,
                  'text': _cleanVerseText(verse['text'] ?? verse['t'] ?? ''),
                });
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _loadedVerses = verses;
          _loadingVerses = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading verses: $e');
      if (mounted) {
        setState(() {
          _loadedVerses = [];
          _loadingVerses = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load verses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Clean verse text by removing HTML tags, Strong's numbers, and extra whitespace
  String _cleanVerseText(String text) {
    // Remove HTML tags
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // Remove Strong's Concordance numbers (digits attached to or between words)
    // Pattern: numbers that appear after letters or standalone numbers between words
    cleaned = cleaned.replaceAll(RegExp(r'(?<=[a-zA-Z])\d+'), ''); // Numbers after letters
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+\s+'), ' '); // Standalone numbers between words
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+$'), ''); // Numbers at end
    cleaned = cleaned.replaceAll(RegExp(r'^\d+\s+'), ''); // Numbers at start
    // Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Show dialog to add a custom Bible API source
  void _showAddApiDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final translationsController = TextEditingController();
    String selectedFormat = 'bolls'; // 'bolls' or 'bible-api'

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppPalette.carbonBlack,
          title: const Row(
            children: [
              Icon(Icons.add_circle, color: AppPalette.dustyMauve),
              SizedBox(width: 10),
              Text('Add Bible API Source', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a custom Bible API source to fetch scriptures from.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'API Name',
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: 'e.g., My Bible Server',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'URL Template',
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: 'https://api.example.com/{translation}/{bookId}/{chapter}',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'URL Placeholders:',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '{translation} - Translation code (e.g., KJV)\n'
                        '{book} - Book name (e.g., Genesis)\n'
                        '{bookId} - Book number 1-66\n'
                        '{chapter} - Chapter number',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Response Format',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Array', style: TextStyle(fontSize: 11)),
                      selected: selectedFormat == 'bolls',
                      selectedColor: AppPalette.dustyMauve,
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: selectedFormat == 'bolls' ? Colors.white : Colors.white54,
                      ),
                      onSelected: (_) => setDialogState(() => selectedFormat = 'bolls'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Object', style: TextStyle(fontSize: 11)),
                      selected: selectedFormat == 'bible-api',
                      selectedColor: AppPalette.dustyMauve,
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: selectedFormat == 'bible-api' ? Colors.white : Colors.white54,
                      ),
                      onSelected: (_) => setDialogState(() => selectedFormat = 'bible-api'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  selectedFormat == 'bolls'
                      ? 'Expects: [{verse: 1, text: "..."}, ...]'
                      : 'Expects: {verses: [{verse: 1, text: "..."}, ...]}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: translationsController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Translations (comma-separated)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: 'KJV, NIV, ESV, NLT',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.dustyMauve,
              ),
              onPressed: () {
                if (nameController.text.trim().isEmpty || urlController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in API name and URL template'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Generate unique ID
                final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                
                // Parse translations
                final transList = translationsController.text
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();

                setState(() {
                  // Add the custom API source
                  _customBibleApiSources.add({
                    'id': id,
                    'name': nameController.text.trim(),
                    'urlTemplate': urlController.text.trim(),
                    'format': selectedFormat,
                    'free': true,
                    'custom': true,
                    'description': 'Custom API source',
                  });

                  // Add translations for this API
                  _customApiTranslations[id] = transList.isEmpty
                      ? [{'id': 'default', 'name': 'Default'}]
                      : transList.map((t) => {'id': t, 'name': t}).toList();

                  // Switch to the new API
                  _selectedBibleApi = id;
                  _selectedBibleVersion = _customApiTranslations[id]![0]['id']!;
                  _loadedVerses = [];
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added "${nameController.text.trim()}" as Bible source'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Add Source', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  int _getVerseCount(String book, int chapter) {
    // Simplified verse counts - in production, use actual data
    // This returns approximate verse counts for demo purposes
    final Map<String, List<int>> verseCounts = {
      'Genesis': [
        31,
        25,
        24,
        26,
        32,
        22,
        24,
        22,
        29,
        32,
        32,
        20,
        18,
        24,
        21,
        16,
        27,
        33,
        38,
        18,
        34,
        24,
        20,
        67,
        34,
        35,
        46,
        22,
        35,
        43,
        55,
        32,
        20,
        31,
        29,
        43,
        36,
        30,
        23,
        23,
        57,
        38,
        34,
        34,
        28,
        34,
        31,
        22,
        33,
        26,
      ],
      'Psalms': List.generate(150, (i) => 20), // Simplified
      'John': [
        51,
        25,
        36,
        54,
        47,
        71,
        53,
        59,
        41,
        42,
        57,
        50,
        38,
        31,
        27,
        33,
        26,
        40,
        42,
        31,
        25,
      ],
    };
    final counts = verseCounts[book];
    if (counts != null && chapter <= counts.length) {
      return counts[chapter - 1];
    }
    return 30; // Default verse count
  }

  /// FreeShow-style scripture search using ScriptureService parser
  /// Provides inline autocomplete and automatic jump-to-verse
  Future<void> _performScriptureSearch(String query) async {
    // Prevent recursive calls during autocomplete
    if (_isAutoCompleting) return;
    
    final trimmedQuery = query.trim();
    
    if (trimmedQuery.isEmpty) {
      setState(() {
        _scriptureSearchResults = [];
        _showScriptureSearchResults = false;
        _scriptureSearching = false;
      });
      return;
    }

    setState(() => _scriptureSearching = true);

    try {
      // Use ScriptureService to parse the input
      final result = ScriptureService.parse(trimmedQuery);
      
      switch (result.type) {
        case ParseResultType.empty:
        case ParseResultType.noMatch:
          // No valid reference found - check for text search
          if (trimmedQuery.length >= 3 && !trimmedQuery.contains(RegExp(r'\d'))) {
            _performTextSearch(trimmedQuery);
          } else {
            setState(() {
              _scriptureSearchResults = [];
              _showScriptureSearchResults = false;
              _scriptureSearching = false;
            });
          }
          break;
          
        case ParseResultType.bookMatch:
          // Partial book name typed - autocomplete to full book name
          if (result.book != null && result.needsAutocomplete && 
              (result.inputBookText?.length ?? 0) >= 3) {
            final fullName = result.bookName!;
            final autocompleteText = '$fullName ';
            
            _isAutoCompleting = true;
            _scriptureSearchController.value = TextEditingValue(
              text: autocompleteText,
              selection: TextSelection.collapsed(offset: autocompleteText.length),
            );
            _isAutoCompleting = false;
            
            // Select the book in the UI
            setState(() {
              _selectedBook = fullName;
              _selectedChapter = null;
              _selectedVerseStart = null;
              _selectedVerseEnd = null;
              _loadedVerses = [];
              _scriptureSearchResults = [];
              _showScriptureSearchResults = false;
              _scriptureSearching = false;
            });
          } else {
            setState(() {
              _scriptureSearchResults = [];
              _showScriptureSearchResults = false;
              _scriptureSearching = false;
            });
          }
          break;
          
        case ParseResultType.chapterReference:
          // Book + chapter typed (e.g., "Matthew 5") - load the chapter
          if (result.book != null && result.chapter != null) {
            final fullName = result.bookName!;
            final chapter = result.chapter!;
            
            // Autocomplete book name if needed
            if (result.needsAutocomplete) {
              final newText = '$fullName $chapter';
              _isAutoCompleting = true;
              _scriptureSearchController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              );
              _isAutoCompleting = false;
            }
            
            // Navigate to chapter
            final needsLoad = _selectedBook != fullName || _selectedChapter != chapter;
            setState(() {
              _selectedBook = fullName;
              _selectedChapter = chapter;
              _selectedVerseStart = null;
              _selectedVerseEnd = null;
              _scriptureSearchResults = [];
              _showScriptureSearchResults = false;
              _scriptureSearching = false;
            });
            
            if (needsLoad) {
              await _loadChapterVerses();
            }
          }
          break;
          
        case ParseResultType.chapterReady:
          // Book + chapter + colon typed (e.g., "Matthew 5:") - ready for verse
          if (result.book != null && result.chapter != null) {
            final fullName = result.bookName!;
            final chapter = result.chapter!;
            
            // Ensure chapter is loaded
            final needsLoad = _selectedBook != fullName || _selectedChapter != chapter;
            setState(() {
              _selectedBook = fullName;
              _selectedChapter = chapter;
              _selectedVerseStart = null;
              _selectedVerseEnd = null;
              _scriptureSearchResults = [];
              _showScriptureSearchResults = false;
              _scriptureSearching = false;
            });
            
            if (needsLoad) {
              await _loadChapterVerses();
            }
          }
          break;
          
        case ParseResultType.verseReference:
          // Full reference typed (e.g., "Matthew 5:3" or "Matthew 5:3-7")
          if (result.book != null && result.chapter != null && result.verseStart != null) {
            final fullName = result.bookName!;
            final chapter = result.chapter!;
            final verseStart = result.verseStart!;
            final verseEnd = result.verseEnd;
            
            // Autocomplete to full reference
            final autocompleteText = result.autocompleteText;
            if (autocompleteText != null && _scriptureSearchController.text != autocompleteText) {
              _isAutoCompleting = true;
              _scriptureSearchController.value = TextEditingValue(
                text: autocompleteText,
                selection: TextSelection.collapsed(offset: autocompleteText.length),
              );
              _isAutoCompleting = false;
            }
            
            // Navigate to the verse
            final needsLoad = _selectedBook != fullName || _selectedChapter != chapter;
            setState(() {
              _selectedBook = fullName;
              _selectedChapter = chapter;
              _selectedVerseStart = verseStart;
              _selectedVerseEnd = verseEnd;
              _scriptureSearchResults = [];
              _showScriptureSearchResults = false;
              _scriptureSearching = false;
            });
            
            if (needsLoad) {
              await _loadChapterVerses();
            }
            
            // Scroll to the selected verse after a short delay
            _scrollToVerse(verseStart);
          }
          break;
      }
    } catch (e) {
      debugPrint('Scripture search error: $e');
      if (mounted) {
        setState(() {
          _scriptureSearchResults = [];
          _showScriptureSearchResults = false;
          _scriptureSearching = false;
        });
      }
    }
  }

  /// Perform text search within loaded verses
  void _performTextSearch(String query) {
    final queryLower = query.toLowerCase();
    final results = <Map<String, dynamic>>[];
    
    for (final verse in _loadedVerses) {
      final verseText = (verse['text'] as String?) ?? '';
      if (verseText.toLowerCase().contains(queryLower)) {
        final verseNum = verse['verse'] as int;
        results.add({
          'type': 'text',
          'reference': '${_selectedBook ?? 'Unknown'} ${_selectedChapter ?? 0}:$verseNum',
          'book': _selectedBook,
          'chapter': _selectedChapter,
          'verseStart': verseNum,
          'verseEnd': null,
          'text': verseText,
        });
      }
    }
    
    setState(() {
      _scriptureSearchResults = results;
      _showScriptureSearchResults = results.isNotEmpty;
      _scriptureSearching = false;
    });
  }

  /// Scroll the verses list to a specific verse number
  void _scrollToVerse(int verseNumber) {
    // Wait for the UI to update, then scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_versesScrollController.hasClients) return;
      
      // Find the verse index in loaded verses
      final verseIndex = _loadedVerses.indexWhere((v) => v['verse'] == verseNumber);
      if (verseIndex == -1) return;
      
      // Estimate scroll position (each verse item is approximately 40-60 pixels)
      const itemHeight = 50.0;
      final targetOffset = verseIndex * itemHeight;
      
      // Clamp to valid scroll range
      final maxScroll = _versesScrollController.position.maxScrollExtent;
      final scrollTo = targetOffset.clamp(0.0, maxScroll);
      
      // Animate to the verse
      _versesScrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Auto-navigate to a scripture reference (called during typing)
  Future<void> _autoNavigateToReference(
    String bookName,
    int chapter,
    int verseStart,
    int? verseEnd,
  ) async {
    // Only auto-navigate if the book or chapter changed
    final needsLoad = _selectedBook != bookName || _selectedChapter != chapter;
    
    setState(() {
      _selectedBook = bookName;
      _selectedChapter = chapter;
      _selectedVerseStart = verseStart;
      _selectedVerseEnd = verseEnd;
    });
    
    if (needsLoad) {
      await _loadChapterVerses();
    }
    
    // Scroll to the selected verse
    _scrollToVerse(verseStart);
  }

  /// Find a book by name or abbreviation (uses ScriptureService)
  Map<String, dynamic> _findBookByName(String query) {
    final result = ScriptureService.findBestMatch(query);
    return result ?? <String, dynamic>{};
  }

  /// Search Bible text using Bolls.life API
  Future<void> _searchBibleTextApi(String query, List<Map<String, dynamic>> results) async {
    // Note: Bolls.life has a search endpoint, but it's limited
    // For now, we'll search in the current book if loaded
    // A full implementation would use their search API or cache more verses
  }

  /// Search within a specific book using API
  Future<void> _searchBibleTextInBookApi(
    String query,
    Map<String, dynamic> book,
    List<Map<String, dynamic>> results,
  ) async {
    // For comprehensive text search, we'd need to either:
    // 1. Use an API that supports full-text search
    // 2. Cache verses locally for search
    // For now, add a placeholder result that navigates to the book
    results.add({
      'type': 'book_search',
      'reference': '${book['name']} (search for "$query")',
      'book': book['name'],
      'chapter': 1,
      'verseStart': null,
      'verseEnd': null,
      'text': 'Tap to open ${book['name']} and search',
      'searchTerm': query,
    });
  }

  /// Select a search result and navigate to it (for text search results only)
  void _selectScriptureSearchResult(Map<String, dynamic> result) {
    final book = result['book'] as String?;
    final chapter = result['chapter'] as int?;
    final verseStart = result['verseStart'] as int?;
    final verseEnd = result['verseEnd'] as int?;

    // Navigate to the selected result
    setState(() {
      _showScriptureSearchResults = false;
      _scriptureSearchController.clear();
      if (book != null) {
        _selectedBook = book;
      }
      if (chapter != null) {
        _selectedChapter = chapter;
      }
      _selectedVerseStart = verseStart;
      _selectedVerseEnd = verseEnd;
    });

    if (book != null && chapter != null) {
      _loadChapterVerses();
    }
  }

  /// Select the first search result (called on Enter key)
  void _selectFirstSearchResult() {
    if (_scriptureSearchResults.isNotEmpty) {
      setState(() => _showScriptureSearchResults = false);
      _selectScriptureSearchResult(_scriptureSearchResults.first);
    }
  }

  void _addScriptureToSlide() {
    if (_selectedBook == null ||
        _selectedChapter == null ||
        _selectedVerseStart == null) {
      return;
    }

    final start = _selectedVerseEnd != null
        ? math.min(_selectedVerseStart!, _selectedVerseEnd!)
        : _selectedVerseStart!;
    final end = _selectedVerseEnd != null
        ? math.max(_selectedVerseStart!, _selectedVerseEnd!)
        : _selectedVerseStart!;

    final selectedVerses = _loadedVerses
        .where(
          (v) => (v['verse'] as int) >= start && (v['verse'] as int) <= end,
        )
        .toList();

    if (selectedVerses.isEmpty) return;

    final verseTexts = selectedVerses
        .map((v) => '${v['verse']} ${v['text']}')
        .join(' ');
    final reference =
        '$_selectedBook $_selectedChapter:$start${end != start ? '-$end' : ''} ($_selectedBibleVersion)';

    // Add to current slide or create new one
    if (_slides.isEmpty) {
      _addSlide();
    }

    setState(() {
      final slide = _slides[selectedSlideIndex];
      final newBody = slide.body.isEmpty
          ? '$verseTexts\n\n— $reference'
          : '${slide.body}\n\n$verseTexts\n\n— $reference';
      _slides[selectedSlideIndex] = slide.copyWith(body: newBody);
    });
    _syncSlideEditors();
    _showSnack('Added $reference to slide');
  }

  void _createScriptureSlides() {
    if (_selectedBook == null ||
        _selectedChapter == null ||
        _selectedVerseStart == null) {
      return;
    }

    final start = _selectedVerseEnd != null
        ? math.min(_selectedVerseStart!, _selectedVerseEnd!)
        : _selectedVerseStart!;
    final end = _selectedVerseEnd != null
        ? math.max(_selectedVerseStart!, _selectedVerseEnd!)
        : _selectedVerseStart!;

    final selectedVerses = _loadedVerses
        .where(
          (v) => (v['verse'] as int) >= start && (v['verse'] as int) <= end,
        )
        .toList();

    if (selectedVerses.isEmpty) return;

    // Create one slide per verse
    for (final verse in selectedVerses) {
      final verseNum = verse['verse'] as int;
      final text = verse['text'] as String;
      final reference =
          '$_selectedBook $_selectedChapter:$verseNum ($_selectedBibleVersion)';

      final newSlide = _SlideContent(
        id: 'slide-${DateTime.now().millisecondsSinceEpoch}-$verseNum',
        templateId: 'default',
        title: reference,
        body: '$verseNum $text',
        overlayNote: reference,
      );
      _slides.add(newSlide);
    }

    setState(() {
      selectedSlideIndex = _slides.length - 1;
    });
    _syncSlideEditors();
    _showSnack('Created ${selectedVerses.length} scripture slides');
  }

  void _sendScriptureToOutput() {
    if (_selectedBook == null ||
        _selectedChapter == null ||
        _selectedVerseStart == null) {
      _showSnack('Select verses to display');
      return;
    }

    final start = _selectedVerseEnd != null
        ? math.min(_selectedVerseStart!, _selectedVerseEnd!)
        : _selectedVerseStart!;
    final end = _selectedVerseEnd != null
        ? math.max(_selectedVerseStart!, _selectedVerseEnd!)
        : _selectedVerseStart!;

    final selectedVerses = _loadedVerses
        .where(
          (v) => (v['verse'] as int) >= start && (v['verse'] as int) <= end,
        )
        .toList();

    if (selectedVerses.isEmpty) return;

    final verseTexts = selectedVerses
        .map((v) => '${v['verse']} ${v['text']}')
        .join(' ');
    final reference =
        '$_selectedBook $_selectedChapter:$start${end != start ? '-$end' : ''} ($_selectedBibleVersion)';

    // Create a temporary slide and send to output
    final scriptureSlide = _SlideContent(
      id: 'scripture-temp-${DateTime.now().millisecondsSinceEpoch}',
      templateId: 'default',
      title: reference,
      body: verseTexts,
      overlayNote: reference,
    );

    // Send to outputs directly
    _sendSlideToOutputs(scriptureSlide);
    _showSnack('Displaying $reference');
  }

  void _sendSlideToOutputs(_SlideContent slide) {
    final template = _templateFor(slide.templateId);
    final payloadBase = _buildProjectionPayload(slide, template);

    for (final output in _outputs) {
      final windowId = _outputWindowIds[output.id];
      if (windowId == null) continue;

      final locked = (_outputRuntime[output.id]?.locked ?? outputsLocked);
      final slideLayerActive =
          outputSlideActive || slide.body.trim().isNotEmpty;

      final payload = {
        ...payloadBase,
        'output': {
          ...output.toJson(),
          'lowerThirdHeight': lowerThirdHeight,
          'lowerThirdGradient': lowerThirdGradient,
          'stageNotesScale': stageNotesScale,
        },
        'state': {
          'layers': {
            'background': outputBackgroundActive,
            'foregroundMedia': outputForegroundMediaActive,
            'slide': slideLayerActive,
            'overlay': outputOverlayActive,
            'audio': outputAudioActive,
            'timer': outputTimerActive,
          },
          'locked': locked,
          'transition': outputTransition,
          'isPlaying': isPlaying,
        },
      };

      DesktopMultiWindow.invokeMethod(
        windowId,
        'updateSlide',
        jsonEncode(payload),
      );
    }
  }

  Widget _buildMediaDrawerTab() {
    final entries = _filteredMediaEntries();
    final counts = {
      MediaFilter.all: _countFor(MediaFilter.all),
      MediaFilter.online: _countFor(MediaFilter.online),
      MediaFilter.screens: _countFor(MediaFilter.screens),
      MediaFilter.cameras: _countFor(MediaFilter.cameras),
      MediaFilter.ndi: _countFor(MediaFilter.ndi),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double minSourcesHeight = 190;
                const double minFoldersHeight = 140;
                const double gap = 10;

                final double available = constraints.maxHeight;
                final bool tooTight =
                    available < (minSourcesHeight + minFoldersHeight + gap);

                final double sourcesHeight = minSourcesHeight;
                final double foldersHeight = tooTight
                    ? minFoldersHeight
                    : math.max(
                        minFoldersHeight,
                        available - sourcesHeight - gap,
                      );

                final column = Column(
                  children: [
                    SizedBox(
                      height: sourcesHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppPalette.carbonBlack,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sources',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _mediaFilterTile(
                                MediaFilter.all,
                                counts[MediaFilter.all] ?? 0,
                                Icons.apps,
                              ),
                              _mediaFilterTile(
                                MediaFilter.online,
                                counts[MediaFilter.online] ?? 0,
                                Icons.wifi_tethering,
                              ),
                              _mediaFilterTile(
                                MediaFilter.screens,
                                counts[MediaFilter.screens] ?? 0,
                                Icons.monitor_heart,
                              ),
                              _mediaFilterTile(
                                MediaFilter.cameras,
                                counts[MediaFilter.cameras] ?? 0,
                                Icons.videocam,
                              ),
                              _mediaFilterTile(
                                MediaFilter.ndi,
                                counts[MediaFilter.ndi] ?? 0,
                                Icons.cast_connected,
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _promptAddNdiSource,
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text(
                                  'Add NDI® Source',
                                  style: TextStyle(fontSize: 12),
                                ),
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
                    ),
                    const SizedBox(height: gap),
                    SizedBox(
                      height: foldersHeight,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppPalette.carbonBlack,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Folders',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: playlists.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No folders',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: playlists.length,
                                      itemBuilder: (context, i) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.folder,
                                                size: 16,
                                                color: Colors.white70,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  playlists[i],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                              label: const Text(
                                'Add folder',
                                style: TextStyle(fontSize: 12),
                              ),
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
                );

                if (tooTight) {
                  return SingleChildScrollView(child: column);
                }
                return column;
              },
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
                      if (_mediaFilter == MediaFilter.online &&
                          _onlineSourceFilter != OnlineSource.all)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: _onlineSearchBar(),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(
                          top:
                              _mediaFilter == MediaFilter.online &&
                                  _onlineSourceFilter != OnlineSource.all
                              ? 64
                              : 0,
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
          thumbnailBytes: screen.thumbnail,
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
          thumbnailBytes: cam.thumbnail,
        ),
      );
    }

    for (final ndi in _ndiSources) {
      items.add(
        _MediaEntry(
          id: 'ndi-${ndi.id}',
          title: ndi.name,
          subtitle: ndi.url,
          category: MediaFilter.ndi,
          icon: Icons.cast_connected,
          tint: Colors.greenAccent,
          isLive: ndi.isOnline,
          badge: 'NDI',
          thumbnailBytes: ndi.thumbnail,
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
    if (_mediaFilter == MediaFilter.online &&
        _onlineSourceFilter != OnlineSource.all) {
      return filtered
          .where((e) => e.onlineSource == _onlineSourceFilter)
          .toList();
    }
    return filtered;
  }

  int _countFor(MediaFilter filter) {
    final items = _mediaEntries();
    if (filter == MediaFilter.all) return items.length;
    return items.where((e) => e.category == filter).length;
  }

  int _countForOnlineSource(OnlineSource source) {
    final items = _mediaEntries().where(
      (e) => e.category == MediaFilter.online,
    );
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
    final activeSource = _onlineSourceFilter == OnlineSource.all
        ? OnlineSource.youtube
        : _onlineSourceFilter;
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
          color: AppPalette.carbonBlack,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
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
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
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
      case MediaFilter.ndi:
        return 'NDI®';
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
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.white70,
            ),
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
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _onlineSubfilterTabs() {
    final labels = [
      {
        'label': 'All',
        'source': OnlineSource.all,
        'icon': Icons.wifi_tethering,
      },
      {
        'label': 'Vimeo',
        'source': OnlineSource.vimeo,
        'icon': Icons.video_library,
      },
      {
        'label': 'YouTube',
        'source': OnlineSource.youtube,
        'icon': Icons.smart_display,
      },
      {
        'label': 'YT Music',
        'source': OnlineSource.youtubeMusic,
        'icon': Icons.music_note,
      },
    ];

    final currentIndex = labels.indexWhere(
      (m) => m['source'] == _onlineSourceFilter,
    );
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
              labelPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 0,
              ),
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
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
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
          color: AppPalette.carbonBlack,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text(
            'No media found',
            style: TextStyle(color: Colors.white70),
          ),
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
    Widget buildCardContent({double? opacity}) {
      final hovered = _hoveredMediaId == entry.id;
      final previewing = _previewingMediaId == entry.id;
      final overlay = hovered || previewing;

      final content = AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppPalette.carbonBlack,
          border: Border.all(
            color: overlay ? accentPink.withOpacity(0.5) : Colors.white12,
          ),
          boxShadow: overlay
              ? [
                  const BoxShadow(
                    color: Colors.black45,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: _mediaPreviewSurface(entry, overlay, previewing),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  _mediaBadge(
                    _mediaFilterLabel(entry.category),
                    Colors.white10,
                  ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(entry.icon, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.subtitle ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      if (opacity != null) {
        return Opacity(
          opacity: opacity,
          child: IgnorePointer(child: content),
        );
      }
      return content;
    }

    return MouseRegion(
      onEnter: (_) {
        _previewTimer?.cancel();
        setState(() {
          _hoveredMediaId = entry.id;
        });
        _previewTimer = Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          setState(() {
            _previewingMediaId = entry.id;
          });
        });
      },
      onExit: (_) {
        _previewTimer?.cancel();
        setState(() {
          _hoveredMediaId = null;
          _previewingMediaId = null;
        });
      },
      child: Draggable<_MediaEntry>(
        data: entry,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        maxSimultaneousDrags: 1,
        onDragStarted: () {
          _previewTimer?.cancel();
          setState(() {
            _previewingMediaId = null;
          });
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
      ),
    );
  }

  Widget _mediaPreviewSurface(
    _MediaEntry entry,
    bool overlay,
    bool previewing,
  ) {
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
                colors: [
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.35),
                ],
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
                  Icon(
                    entry.isLive ? Icons.play_circle : Icons.preview,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.isLive ? 'Live preview' : 'Hover preview',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbnailOrFallback(_MediaEntry entry) {
    // Check for live thumbnail bytes first (screens, cameras, NDI)
    if (entry.thumbnailBytes != null && entry.thumbnailBytes!.isNotEmpty) {
      return Image.memory(
        entry.thumbnailBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true, // Prevents flickering during updates
        errorBuilder: (_, __, ___) => _fallbackPreview(entry),
      );
    }
    // Then check for URL-based thumbnail
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
    // For live sources, show the live thumbnail (already updating)
    if (entry.isLive && entry.thumbnailBytes != null) {
      return _thumbnailOrFallback(entry);
    }
    
    final isYoutube =
        entry.onlineSource == OnlineSource.youtube ||
        entry.onlineSource == OnlineSource.youtubeMusic;
    final supportsInlineWebView =
        kIsWeb ||
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
    // Show a pulsing live indicator for live sources without thumbnail
    if (entry.isLive) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [entry.tint.withOpacity(0.22), entry.tint.withOpacity(0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                entry.icon,
                size: 32,
                color: entry.tint.withOpacity(0.6),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
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
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
    );
  }

  Widget _pillToggle(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accentPink.withOpacity(0.25) : Colors.white12,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? accentPink : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _accordionSection({
    required IconData icon,
    required String label,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: ExpansionTile(
          leading: Icon(icon, color: Colors.white70, size: 14),
          title: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          childrenPadding: const EdgeInsets.fromLTRB(10, 1, 10, 6),
          tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          children: children,
        ),
      ),
    );
  }

  Widget _dragHandle({
    required void Function(double delta) onDrag,
    double height = double.infinity,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: Container(
          width: 10,
          height: height,
          alignment: Alignment.center,
          child: Container(
            width: 2,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavBar() {
    final ShowItem? selectedShow =
        (selectedShowIndex != null &&
            selectedShowIndex! >= 0 &&
            selectedShowIndex! < shows.length)
        ? shows[selectedShowIndex!]
        : null;

    final fileMenu = [
      _MiniNavAction(
        label: 'Save',
        icon: Icons.save_outlined,
        shortcut: 'Ctrl+S',
        onSelected: _saveProgramStateToFile,
      ),
      _MiniNavAction(
        label: 'Import',
        icon: Icons.download_outlined,
        shortcut: 'Ctrl+I',
        onSelected: _importProgramStateFromFile,
      ),
      _MiniNavAction(
        label: 'Export',
        icon: Icons.upload_outlined,
        shortcut: 'Ctrl+E',
        onSelected: _exportProgramState,
      ),
      _MiniNavAction(
        label: 'Quit',
        icon: Icons.close,
        shortcut: 'Ctrl+Q',
        onSelected: _quitApp,
      ),
    ];

    final editMenu = [
      _MiniNavAction(
        label: 'Undo',
        icon: Icons.undo,
        shortcut: 'Ctrl+Z',
        onSelected: _undoAction,
      ),
      _MiniNavAction(
        label: 'Redo',
        icon: Icons.redo,
        shortcut: 'Ctrl+Y',
        onSelected: _redoAction,
      ),
      _MiniNavAction(
        label: 'History',
        icon: Icons.history,
        shortcut: 'Ctrl+H',
        onSelected: _historyAction,
      ),
      _MiniNavAction(
        label: 'Cut',
        icon: Icons.cut,
        shortcut: 'Ctrl+X',
        onSelected: _cutAction,
        enabled: _hasSelection(),
      ),
      _MiniNavAction(
        label: 'Copy',
        icon: Icons.copy,
        shortcut: 'Ctrl+C',
        onSelected: _copyAction,
        enabled: _hasSelection(),
      ),
      _MiniNavAction(
        label: 'Paste',
        icon: Icons.paste,
        shortcut: 'Ctrl+V',
        onSelected: _pasteAction,
      ),
      _MiniNavAction(
        label: 'Delete',
        icon: Icons.delete_outline,
        shortcut: 'Del',
        onSelected: _deleteAction,
        enabled: _hasSelection(),
      ),
      _MiniNavAction(
        label: 'Select all',
        icon: Icons.select_all,
        shortcut: 'Ctrl+A',
        onSelected: _selectAllAction,
        enabled: _slides.isNotEmpty,
      ),
    ];

    final viewMenu = [
      _MiniNavAction(
        label: 'Show tab',
        icon: Icons.tv,
        onSelected: () => setState(() => selectedTopTab = 0),
      ),
      _MiniNavAction(
        label: 'Edit tab',
        icon: Icons.edit,
        onSelected: () => setState(() => selectedTopTab = 1),
      ),
      _MiniNavAction(
        label: 'Stage tab',
        icon: Icons.personal_video,
        onSelected: () => setState(() => selectedTopTab = 2),
      ),
      _MiniNavAction(
        label: drawerExpanded ? 'Hide drawer' : 'Show drawer',
        icon: Icons.view_day_outlined,
        onSelected: () => setState(() {
          drawerExpanded = !drawerExpanded;
          _drawerHeight = drawerExpanded
              ? _drawerDefaultHeight
              : _drawerMinHeight;
        }),
      ),
    ];

    final helpMenu = [
      _MiniNavAction(
        label: 'About',
        icon: Icons.info_outline,
        onSelected: _showAboutSheet,
      ),
    ];

    // Tab dimensions for animation
    const double tabWidth = 72.0;
    const double tabHeight = 26.0;

    final tabSwitcher = Container(
      height: 34,
      decoration: BoxDecoration(
        // Glass container background
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Stack(
        children: [
          // Animated sliding glass pill indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 4 + (selectedTopTab * tabWidth),
            top: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: tabWidth,
              height: tabHeight,
              decoration: BoxDecoration(
                // Liquid glass gradient
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.28),
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 0.5,
                ),
                boxShadow: [
                  // Outer glow
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                  // Drop shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    spreadRadius: -2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Tab buttons row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _topTab(
                icon: Icons.tv,
                label: 'Show',
                selected: selectedTopTab == 0,
                onTap: () => setState(() => selectedTopTab = 0),
                width: tabWidth,
                height: tabHeight,
              ),
              _topTab(
                icon: Icons.edit,
                label: 'Edit',
                selected: selectedTopTab == 1,
                onTap: () => setState(() => selectedTopTab = 1),
                width: tabWidth,
                height: tabHeight,
              ),
              _topTab(
                icon: Icons.personal_video,
                label: 'Stage',
                selected: selectedTopTab == 2,
                onTap: () => setState(() => selectedTopTab = 2),
                width: tabWidth,
                height: tabHeight,
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      height: 52,
      color: AppPalette.carbonBlack,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FreeShow',
                  style: TextStyle(
                    color: AppPalette.dustyMauve,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 24),
                _miniNavItem('File', fileMenu, _fileNavKey),
                _miniNavItem('Edit', editMenu, _editNavKey),
                _miniNavItem('View', viewMenu, _viewNavKey),
                _miniNavItem('Help', helpMenu, _helpNavKey),
              ],
            ),
          ),
          Center(child: tabSwitcher),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _openSettingsPage,
                  icon: const Icon(
                    Icons.extension,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
                IconButton(
                  onPressed: _openSettingsPage,
                  icon: const Icon(
                    Icons.settings,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
                Tooltip(
                  message: _outputWindowIds.isNotEmpty
                      ? 'Outputs live (double-click to stop)'
                      : 'Show Output',
                  child: InkWell(
                    onTap: _outputWindowIds.isEmpty
                        ? () {
                            debugPrint('out: opening output windows');
                            _togglePresent();
                          }
                        : null,
                    onDoubleTap: _outputWindowIds.isNotEmpty
                        ? () async {
                            debugPrint(
                              'out: double-tap detected, closing outputs',
                            );
                            await _disarmPresentation();
                            if (mounted) setState(() {});
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.present_to_all,
                        size: 24,
                        color: _outputWindowIds.isNotEmpty
                            ? Colors.redAccent
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowListPanel() {
    return Container(
      color: AppPalette.carbonBlack,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _frostedBox(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Center(
                      child: Text(
                        'Projects',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _projectsList()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _newProjectControl(),
        ],
      ),
    );
  }

  Widget _projectsList() {
    final grouped = _groupFoldersWithShows();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final entry in grouped.entries)
          _projectCategoryTile(entry.key, entry.value),
      ],
    );
  }

  Map<String?, List<ShowItem>> _groupFoldersWithShows() {
    final Map<String?, List<ShowItem>> grouped = {};

    // Start with explicit folders so they render even when empty.
    for (final folder in folders) {
      final key = folder.trim();
      grouped[key.isEmpty ? null : key] = [];
    }

    // Include named categories even if not in folders list.
    for (final cat in showCategories) {
      final key = cat.trim();
      grouped.putIfAbsent(key.isEmpty ? null : key, () => []);
    }

    // Collect shows by category/folder.
    for (final show in shows) {
      final key = (show.category?.trim().isEmpty ?? true)
          ? null
          : show.category!.trim();
      grouped.putIfAbsent(key, () => []).add(show);
    }

    // Ensure unlabeled bucket exists so "Nothing here" can show.
    grouped.putIfAbsent(null, () => []);

    // Order: explicit folders, remaining named categories, unlabeled last.
    final Map<String?, List<ShowItem>> ordered = {};
    for (final folder in folders) {
      final key = folder.trim().isEmpty ? null : folder.trim();
      if (grouped.containsKey(key)) ordered[key] = grouped.remove(key)!;
    }

    final namedRemainder = grouped.entries.where((e) => e.key != null).toList();
    for (final entry in namedRemainder) {
      ordered[entry.key] = grouped.remove(entry.key)!;
    }

    if (grouped.containsKey(null)) {
      ordered[null] = grouped.remove(null)!;
    }

    return ordered;
  }

  Widget _projectCategoryTile(String? category, List<ShowItem> items) {
    final title = (category == null || category.isEmpty)
        ? 'Unlabeled'
        : category;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.dustyMauve),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: (d) => _showFolderMenu(
              context: context,
              category: category,
              position: d.globalPosition,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.carbonBlack,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(color: AppPalette.dustyMauve),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    category == null ? Icons.folder_open : Icons.folder,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _renamingFolder == category
                        ? TextField(
                            controller: _folderRenameController,
                            autofocus: true,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 2),
                            ),
                            onSubmitted: (v) =>
                                _commitFolderRename(category ?? '', v),
                            onEditingComplete: () => _commitFolderRename(
                              category ?? '',
                              _folderRenameController.text,
                            ),
                            onTapOutside: (_) => _cancelInlineFolderRename(),
                          )
                        : Text(
                            title.isEmpty ? 'Unnamed' : title,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.dustyRose,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Column(
                children: [
                  const Text(
                    'Nothing here',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  _inlineNewProjectButton(targetFolder: category),
                ],
              ),
            )
          else ...[
            ...items.map(_projectItemRow),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: _inlineNewProjectButton(targetFolder: category),
            ),
          ],
        ],
      ),
    );
  }

  Widget _projectItemRow(ShowItem item) {
    final globalIndex = shows.indexOf(item);
    final selected = selectedShowIndex == globalIndex;
    final isRenaming = _renamingProjectIndex == globalIndex;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? accentPink : AppPalette.carbonBlack,
        border: Border(top: BorderSide(color: AppPalette.dustyMauve)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description,
            size: 16,
            color: selected ? Colors.white : accentPink,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isRenaming
                ? TextField(
                    controller: _projectRenameController,
                    autofocus: true,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withOpacity(0.88),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 2),
                    ),
                    onSubmitted: (v) => _commitProjectRename(globalIndex, v),
                    onEditingComplete: () => _commitProjectRename(
                      globalIndex,
                      _projectRenameController.text,
                    ),
                    onTapOutside: (_) => _cancelInlineProjectRename(),
                  )
                : Text(
                    item.name,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );

    if (isRenaming) return content;

    return InkWell(
      onTap: () => setState(() => selectedShowIndex = globalIndex),
      onSecondaryTapDown: (d) =>
          _showProjectMenu(item: item, position: d.globalPosition),
      child: content,
    );
  }

  Widget _projectEmptyState({String message = 'No items yet'}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.dustyMauve),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _newProjectControl() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.dustyMauve),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pillButton(
            icon: Icons.folder_open,
            label: null,
            onTap: _createNewFolderFromShortcut,
            tooltip: 'New folder',
            isFirst: true,
          ),
          Container(width: 1, height: 30, color: Colors.white12),
          _pillButton(
            icon: Icons.add,
            label: 'New project',
            onTap: () => _createQuickProject(category: null),
            tooltip: 'New project',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
    String? tooltip,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 12 : 14,
        vertical: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentPink, size: 16),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        key: label == null ? _newProjectButtonKey : null,
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(isFirst ? 18 : 0),
          right: Radius.circular(isLast ? 18 : 0),
        ),
        child: content,
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _inlineNewProjectButton({String? targetFolder}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _createQuickProject(category: targetFolder),
        icon: Icon(Icons.add, size: 16, color: accentPink),
        label: const Text('New project'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: AppPalette.dustyMauve),
          backgroundColor: AppPalette.carbonBlack,
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Future<void> _showFolderMenu({
    required BuildContext context,
    required Offset position,
    String? category,
  }) async {
    final overlay = Overlay.of(context);
    final box = overlay.context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final items = <PopupMenuEntry<String>>[];
    if (category != null) {
      items.addAll(const [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
      ]);
      items.addAll(const [
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 8),
              Text('Duplicate'),
            ],
          ),
        ),
      ]);
      items.addAll(const [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
      ]);
      items.add(const PopupMenuDivider());
    }

    items.addAll(const [
      PopupMenuItem(
        value: 'newProject',
        child: Row(
          children: [
            Icon(Icons.add, size: 16),
            SizedBox(width: 8),
            Text('New project'),
          ],
        ),
      ),
    ]);
    items.addAll(const [
      PopupMenuItem(
        value: 'newFolder',
        child: Row(
          children: [
            Icon(Icons.create_new_folder_outlined, size: 16),
            SizedBox(width: 8),
            Text('New folder'),
          ],
        ),
      ),
    ]);

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & box.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: items,
    );

    switch (selection) {
      case 'rename':
        if (category != null) _beginInlineFolderRename(category);
        break;
      case 'duplicate':
        if (category != null) _duplicateFolder(category);
        break;
      case 'delete':
        if (category != null) _deleteFolder(category);
        break;
      case 'newProject':
        _createQuickProject(category: category);
        break;
      case 'newFolder':
        _createNewFolderFromShortcut();
        break;
      default:
        break;
    }
  }

  Future<void> _showProjectMenu({
    required ShowItem item,
    required Offset position,
  }) async {
    final overlay = Overlay.of(context);
    final box = overlay.context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & box.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: const [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 8),
              Text('Duplicate'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'newProject',
          child: Row(
            children: [
              Icon(Icons.add, size: 16),
              SizedBox(width: 8),
              Text('New project'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'newFolder',
          child: Row(
            children: [
              Icon(Icons.create_new_folder_outlined, size: 16),
              SizedBox(width: 8),
              Text('New folder'),
            ],
          ),
        ),
      ],
    );

    switch (selection) {
      case 'rename':
        _beginInlineProjectRename(item);
        break;
      case 'duplicate':
        _duplicateProject(item);
        break;
      case 'delete':
        _deleteProject(item);
        break;
      case 'newProject':
        _createQuickProject(category: item.category);
        break;
      case 'newFolder':
        _createNewFolderFromShortcut();
        break;
      default:
        break;
    }
  }

  void _createNewFolderFromShortcut() {
    _createFolder(name: 'Unnamed');
  }

  void _createFolder({required String name}) {
    final trimmed = name.trim();
    final unique = _uniqueFolderName(trimmed.isEmpty ? 'Unnamed' : trimmed);
    setState(() {
      folders = [...folders, unique];
      if (!showCategories.contains(unique)) {
        showCategories = [...showCategories, unique];
      }
    });
  }

  String _uniqueFolderName(String base) {
    if (!folders.contains(base)) return base;
    int i = 2;
    while (folders.contains('$base $i')) {
      i++;
    }
    return '$base $i';
  }

  void _createQuickProject({String? category}) {
    final cat = category?.trim().isEmpty ?? true ? null : category!.trim();
    final name = _uniqueProjectName(_defaultProjectName(), cat);
    setState(() {
      if (cat != null && !showCategories.contains(cat)) {
        showCategories = [...showCategories, cat];
      }
      if (cat != null && !folders.contains(cat)) {
        folders = [...folders, cat];
      }
      shows = [...shows, ShowItem(name: name, category: cat)];
      selectedShowIndex = shows.length - 1;
    });
    _clampSelectedShow();
  }

  String _uniqueProjectName(String base, String? category) {
    final folder = category?.trim().isEmpty ?? true ? null : category!.trim();
    final existing = shows
        .where(
          (s) =>
              (s.category?.trim().isEmpty ?? true
                  ? null
                  : s.category!.trim()) ==
              folder,
        )
        .map((s) => s.name)
        .toSet();
    if (!existing.contains(base)) return base;
    int i = 2;
    while (existing.contains('$base ($i)')) {
      i++;
    }
    return '$base ($i)';
  }

  String _defaultProjectName() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final yy = (now.year % 100).toString().padLeft(2, '0');
    return '$mm/$dd/$yy';
  }

  void _beginInlineFolderRename(String oldName) {
    _folderRenameController
      ..text = oldName
      ..selection = TextSelection(baseOffset: 0, extentOffset: oldName.length);
    setState(() {
      _renamingFolder = oldName;
    });
  }

  void _beginInlineProjectRename(ShowItem item) {
    final idx = shows.indexOf(item);
    if (idx < 0) return;
    _projectRenameController
      ..text = item.name
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: item.name.length,
      );
    setState(() {
      _renamingProjectIndex = idx;
    });
  }

  void _cancelInlineFolderRename() {
    setState(() => _renamingFolder = null);
  }

  void _cancelInlineProjectRename() {
    setState(() => _renamingProjectIndex = null);
  }

  void _commitFolderRename(String oldName, String newNameRaw) {
    final trimmed = newNameRaw.trim();
    if (trimmed.isEmpty || trimmed == oldName) {
      _cancelInlineFolderRename();
      return;
    }
    final newName = _uniqueFolderName(trimmed);
    setState(() {
      folders = folders.map((f) => f == oldName ? newName : f).toList();
      shows = [
        for (final s in shows)
          s.category == oldName ? ShowItem(name: s.name, category: newName) : s,
      ];
      showCategories = showCategories
          .map((c) => c == oldName ? newName : c)
          .toList();
      _renamingFolder = null;
    });
    _clampSelectedShow();
  }

  void _commitProjectRename(int index, String newNameRaw) {
    if (index < 0 || index >= shows.length) {
      _cancelInlineProjectRename();
      return;
    }
    final trimmed = newNameRaw.trim();
    final current = shows[index];
    if (trimmed.isEmpty || trimmed == current.name) {
      _cancelInlineProjectRename();
      return;
    }
    final newName = _uniqueProjectName(trimmed, current.category);
    setState(() {
      shows = [
        for (var i = 0; i < shows.length; i++)
          if (i == index)
            ShowItem(name: newName, category: current.category)
          else
            shows[i],
      ];
      _renamingProjectIndex = null;
    });
  }

  Future<void> _promptRenameFolder(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgMedium,
          title: const Text('Rename folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Folder name'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final newNameRaw = result?.trim();
    if (newNameRaw == null || newNameRaw.isEmpty || newNameRaw == oldName)
      return;
    final newName = _uniqueFolderName(newNameRaw);

    setState(() {
      folders = folders.map((f) => f == oldName ? newName : f).toList();
      shows = [
        for (final s in shows)
          s.category == oldName ? ShowItem(name: s.name, category: newName) : s,
      ];
      showCategories = showCategories
          .map((c) => c == oldName ? newName : c)
          .toList();
    });
    _clampSelectedShow();
  }

  Future<void> _promptRenameProject(ShowItem item) async {
    final controller = TextEditingController(text: item.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgMedium,
          title: const Text('Rename project'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Project name'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final newNameRaw = result?.trim();
    if (newNameRaw == null || newNameRaw.isEmpty || newNameRaw == item.name)
      return;
    final newName = _uniqueProjectName(newNameRaw, item.category);

    setState(() {
      final idx = shows.indexOf(item);
      if (idx >= 0) {
        shows = [
          for (int i = 0; i < shows.length; i++)
            if (i == idx)
              ShowItem(name: newName, category: shows[i].category)
            else
              shows[i],
        ];
        selectedShowIndex = idx;
      }
    });
  }

  void _duplicateProject(ShowItem item) {
    final name = _uniqueProjectName('${item.name} Copy', item.category);
    final insertIndex = shows.indexOf(item) + 1;
    setState(() {
      shows = [
        ...shows.sublist(0, insertIndex),
        ShowItem(name: name, category: item.category),
        ...shows.sublist(insertIndex),
      ];
      selectedShowIndex = insertIndex;
    });
    _clampSelectedShow();
  }

  Future<void> _confirmDeleteProject(ShowItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgMedium,
        title: const Text('Delete project?'),
        content: Text('Delete "${item.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteProject(item);
    }
  }

  void _deleteProject(ShowItem item) {
    final idx = shows.indexOf(item);
    if (idx < 0) return;
    setState(() {
      shows = [
        for (int i = 0; i < shows.length; i++)
          if (i != idx) shows[i],
      ];
      if (selectedShowIndex != null) {
        if (selectedShowIndex == idx) {
          selectedShowIndex = null;
        } else if (selectedShowIndex != null && selectedShowIndex! > idx) {
          selectedShowIndex = selectedShowIndex! - 1;
        }
      }
    });
    _clampSelectedShow();
  }

  void _duplicateFolder(String oldName) {
    final newName = _uniqueFolderName('$oldName Copy');
    final items = shows.where((s) => s.category == oldName).toList();
    setState(() {
      folders = [...folders, newName];
      if (!showCategories.contains(newName)) {
        showCategories = [...showCategories, newName];
      }
      shows = [
        ...shows,
        for (final s in items)
          ShowItem(name: '${s.name} Copy', category: newName),
      ];
      selectedShowIndex = shows.isEmpty ? null : shows.length - 1;
    });
    _clampSelectedShow();
  }

  void _deleteFolder(String oldName) {
    setState(() {
      folders = folders.where((f) => f != oldName).toList();
      showCategories = showCategories.where((c) => c != oldName).toList();
      shows = [
        for (final s in shows)
          s.category == oldName ? ShowItem(name: s.name, category: null) : s,
      ];
    });
    _clampSelectedShow();
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

  void _addStageLayout() {
    final nextIndex = _stageLayouts.length + 1;
    final id = 'layout-${DateTime.now().millisecondsSinceEpoch}';
    final layout = _StageLayout(id: id, name: 'New Layout $nextIndex');
    setState(() {
      _stageLayouts = [..._stageLayouts, layout];
      _selectedStageLayoutId = id;
    });
  }

  void _reorderStageLayouts(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final layouts = List<_StageLayout>.from(_stageLayouts);
      final item = layouts.removeAt(oldIndex);
      layouts.insert(newIndex, item);
      _stageLayouts = layouts;
    });
    _ensureStageLayoutSelection();
  }

  void _selectStageLayout(String id) {
    if (!_stageLayouts.any((l) => l.id == id)) return;
    setState(() => _selectedStageLayoutId = id);
  }

  void _ensureStageLayoutSelection() {
    if (_stageLayouts.isEmpty) {
      _selectedStageLayoutId = null;
      return;
    }
    if (_selectedStageLayoutId == null ||
        !_stageLayouts.any((l) => l.id == _selectedStageLayoutId)) {
      _selectedStageLayoutId = _stageLayouts.first.id;
    }
  }

  Widget _buildStageLayoutListPanel() {
    final hasLayouts = _stageLayouts.isNotEmpty;
    final selectedId = _selectedStageLayoutId;

    return SizedBox(
      width: _leftPaneWidth,
      child: _frostedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _sectionHeader('Layout List'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 18, color: Colors.white70),
                  tooltip: 'Add layout',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  onPressed: _addStageLayout,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: hasLayouts
                  ? ReorderableListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _stageLayouts.length,
                      onReorder: _reorderStageLayouts,
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        elevation: 6,
                        borderRadius: BorderRadius.circular(10),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      itemBuilder: (context, i) {
                        final layout = _stageLayouts[i];
                        final selected = layout.id == selectedId;
                        return Padding(
                          key: ValueKey(layout.id),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _selectStageLayout(layout.id),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? accentPink.withOpacity(0.08)
                                    : Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected ? accentPink : Colors.white12,
                                  width: selected ? 1.5 : 0.9,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.layers,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      layout.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.drag_indicator,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text(
                        'No layouts yet',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageViewPanel() {
    final selectedLayout = _stageLayouts.firstWhere(
      (l) => l.id == _selectedStageLayoutId,
      orElse: () => _stageLayouts.isNotEmpty
          ? _stageLayouts.first
          : const _StageLayout(id: '', name: ''),
    );
    final hasSelectedLayout =
        _stageLayouts.isNotEmpty && _selectedStageLayoutId != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _frostedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _sectionHeader('Layout Editor'),
                const Spacer(),
                Text(
                  hasSelectedLayout
                      ? selectedLayout.name
                      : 'No layout selected',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _slides.isEmpty
                        ? _emptyStageBox('No current slide')
                        : _renderSlidePreview(
                            _slides[_safeIntClamp(
                              selectedSlideIndex,
                              0,
                              _slides.length - 1,
                            )],
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _slides.length < 2
                        ? _emptyStageBox('No next slide')
                        : _renderSlidePreview(
                            _slides[(_safeIntClamp(
                              selectedSlideIndex + 1,
                              0,
                              _slides.length - 1,
                            ))],
                            compact: true,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unnamed', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...meta.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    e.value.isEmpty ? '—' : e.value,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
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
    return Row(children: [Expanded(child: _buildSingleSlideEditSurface())]);
  }

  Widget _buildEditLeftPane() {
    final hasSlides = _slides.isNotEmpty;
    final safeIndex = _safeIntClamp(
      selectedSlideIndex,
      0,
      hasSlides ? _slides.length - 1 : 0,
    );
    return _frostedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader('Slide List'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 18, color: Colors.white70),
                tooltip: 'Add slide',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                onPressed: _addSlide,
              ),
              const SizedBox(width: 6),
              if (hasSlides)
                Text(
                  'Slide ${safeIndex + 1}/${_slides.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasSlides)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _renderSlidePreview(_slides[safeIndex], compact: true),
            )
          else
            _emptyStageBox('No slide'),
          if (hasSlides) ...[
            const SizedBox(height: 12),
            const Text(
              'Drag to reorder or click to load',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: hasSlides
                ? ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.zero,
                    itemCount: _slides.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      _moveSlide(oldIndex, newIndex);
                    },
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      elevation: 6,
                      borderRadius: BorderRadius.circular(10),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    itemBuilder: (context, i) {
                      final slide = _slides[i];
                      final selected = i == safeIndex;
                      return Padding(
                        key: ValueKey(slide.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ReorderableDelayedDragStartListener(
                          index: i,
                          child: InkWell(
                            onTap: () => _selectSlide(i),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final double cardPadding = 4;
                                  final double available =
                                      constraints.maxWidth.isFinite
                                      ? constraints.maxWidth - (cardPadding * 2)
                                      : 180;
                                  final double innerWidth =
                                      constraints.maxWidth.isFinite
                                      ? (available <= 0
                                            ? constraints.maxWidth
                                            : math.min(
                                                math.max(180, available),
                                                constraints.maxWidth,
                                              ))
                                      : 180;
                                  return Container(
                                    width: constraints.maxWidth,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? accentPink.withOpacity(0.08)
                                          : Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: selected
                                            ? accentPink
                                            : Colors.white12,
                                        width: selected ? 1.6 : 0.9,
                                      ),
                                    ),
                                    padding: EdgeInsets.all(cardPadding),
                                    child: Stack(
                                      children: [
                                        SizedBox(
                                          width: innerWidth,
                                          child: AspectRatio(
                                            aspectRatio: 16 / 9,
                                            child: _renderSlidePreview(
                                              slide,
                                              compact: true,
                                            ),
                                          ),
                                        ),
                                        if (selected)
                                          Positioned(
                                            left: 6,
                                            top: 6,
                                            child: _mediaBadge(
                                              'ACTIVE',
                                              accentPink.withOpacity(0.22),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text(
                      'No slides yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSlideEditSurface() {
    final hasSlide =
        _slides.isNotEmpty &&
        selectedSlideIndex >= 0 &&
        selectedSlideIndex < _slides.length;
    final slide = hasSlide ? _slides[selectedSlideIndex] : null;
    return _frostedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader('Canvas'),
              const Spacer(),
              Text(
                hasSlide
                    ? 'Slide ${selectedSlideIndex + 1}/${_slides.length}'
                    : 'No slide',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
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
    final align = slide.alignOverride ?? template.alignment;
    final verticalAlign = slide.verticalAlign ?? _VerticalAlign.middle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = _resolvedBoxRect(slide);
        final boxLeft = box.left * constraints.maxWidth;
        final boxTop = box.top * constraints.maxHeight;
        final boxWidth = box.width * constraints.maxWidth;
        final boxHeight = box.height * constraints.maxHeight;
        final hasTextboxLayer = slide.layers.any(
          (l) => l.kind == _LayerKind.textbox,
        );
        final fgLayers = _foregroundLayers(slide);

        // ignore: unused_element
        Offset toStagePos(Offset global) {
          final renderBox =
              _stageKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox == null) return Offset.zero;
          final local = renderBox.globalToLocal(global);
          final scaleX = constraints.maxWidth / renderBox.size.width;
          final scaleY = constraints.maxHeight / renderBox.size.height;
          return Offset(local.dx * scaleX, local.dy * scaleY);
        }

        Offset scaleDelta(Offset rawDelta) {
          final renderBox =
              _stageKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox == null) return rawDelta;
          final scaleX = constraints.maxWidth / renderBox.size.width;
          final scaleY = constraints.maxHeight / renderBox.size.height;
          return Offset(rawDelta.dx * scaleX, rawDelta.dy * scaleY);
        }

        final bool showDefaultTextbox =
            !hasTextboxLayer && (slide.body.trim().isNotEmpty);

        return MouseRegion(
          cursor: SystemMouseCursors.basic,
          child: Stack(
            key: _stageKey,
            children: [
              Positioned.fill(
                child: _applyFilters(
                  _buildSlideBackground(slide, template, autoPlayVideo: false),
                  slide,
                ),
              ),
              for (final layer in fgLayers)
                () {
                  final rect = _resolvedLayerRect(layer);
                  final layerLeft = rect.left * constraints.maxWidth;
                  final layerTop = rect.top * constraints.maxHeight;
                  final layerWidth = rect.width * constraints.maxWidth;
                  final layerHeight = rect.height * constraints.maxHeight;
                  final selected = _selectedLayerId == layer.id;
                  final editingLayer = _editingLayerId == layer.id;
                  final layerText = (layer.text ?? '').trim();
                  final textColor =
                      slide.textColorOverride ?? template.textColor;
                  return Positioned(
                    left: layerLeft,
                    top: layerTop,
                    width: layerWidth,
                    height: layerHeight,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onSecondaryTapDown: (details) => _showLayerContextMenu(
                          context,
                          layer,
                          details.globalPosition,
                        ),
                        onTapDown: (_) {
                          setState(() {
                            _selectedLayerId = layer.id;
                            if (_editingLayerId != null &&
                                _editingLayerId != layer.id) {
                              _editingLayerId = null;
                              _layerTextController.clear();
                            }
                          });
                        },
                        onPanStart: (details) {
                          if (_isLayerResizing || editingLayer) return;
                          _layerDragStartPointer = Offset.zero;
                          _layerDragStartRect = rect;
                          _layerDragAccum = Offset.zero;
                        },
                        onPanUpdate: (details) {
                          if (_isLayerResizing || editingLayer) return;
                          if (_layerDragStartRect == null ||
                              _layerDragStartPointer == null)
                            return;
                          _layerDragAccum += scaleDelta(details.delta);
                          final dx = _layerDragAccum.dx;
                          final dy = _layerDragAccum.dy;
                          final totalW = constraints.maxWidth;
                          final totalH = constraints.maxHeight;
                          final newLeft =
                              (_layerDragStartRect!.left * totalW + dx) /
                              totalW;
                          final newTop =
                              (_layerDragStartRect!.top * totalH + dy) / totalH;
                          final moved = Rect.fromLTWH(
                            newLeft,
                            newTop,
                            _layerDragStartRect!.width,
                            _layerDragStartRect!.height,
                          );
                          final snapped = _snapRect(moved, totalW, totalH);
                          _setLayerRect(layer, snapped);
                        },
                        onPanEnd: (_) {
                          if (_isLayerResizing || editingLayer) return;
                          _layerDragStartPointer = null;
                          _layerDragStartRect = null;
                          _layerDragAccum = Offset.zero;
                        },
                        onDoubleTap: layer.kind == _LayerKind.textbox
                            ? () {
                                setState(() {
                                  _selectedLayerId = layer.id;
                                  _editingLayerId = layer.id;
                                  _isInlineTextEditing = false;
                                  _layerTextController.text = layer.text ?? '';
                                });
                                Future.microtask(
                                  () => _layerInlineFocusNode.requestFocus(),
                                );
                              }
                            : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: layer.kind == _LayerKind.textbox
                                    ? Container(
                                        padding: const EdgeInsets.all(8),
                                        color: Colors.black.withOpacity(0.04),
                                        alignment: Alignment.center,
                                        child: editingLayer
                                            ? TextField(
                                                controller:
                                                    _layerTextController,
                                                focusNode:
                                                    _layerInlineFocusNode,
                                                autofocus: true,
                                                expands: true,
                                                maxLines: null,
                                                textAlign: TextAlign.center,
                                                decoration:
                                                    const InputDecoration(
                                                      border: InputBorder.none,
                                                      isDense: true,
                                                      hintText: 'Edit text',
                                                    ),
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: math
                                                      .min(
                                                        layerHeight * 0.32,
                                                        80,
                                                      )
                                                      .clamp(14, 96)
                                                      .toDouble(),
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.1,
                                                ),
                                                onChanged: (v) =>
                                                    _updateLayerField(
                                                      layer.id,
                                                      (l) =>
                                                          l.copyWith(text: v),
                                                    ),
                                                onEditingComplete: () =>
                                                    setState(
                                                      () => _editingLayerId =
                                                          null,
                                                    ),
                                                onSubmitted: (_) => setState(
                                                  () => _editingLayerId = null,
                                                ),
                                                onTapOutside: (_) => setState(
                                                  () => _editingLayerId = null,
                                                ),
                                              )
                                            : Text(
                                                layerText.isEmpty
                                                    ? 'Double-tap to edit'
                                                    : layerText,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: math
                                                      .min(
                                                        layerHeight * 0.32,
                                                        80,
                                                      )
                                                      .clamp(14, 96)
                                                      .toDouble(),
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.1,
                                                  shadows: const [
                                                    Shadow(
                                                      color: Colors.black45,
                                                      blurRadius: 6,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                maxLines: null,
                                                overflow: TextOverflow.visible,
                                              ),
                                      )
                                    : _buildLayerWidget(
                                        layer,
                                        fit: BoxFit.cover,
                                        autoPlayVideo: false,
                                      ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selected
                                          ? accentPink.withOpacity(0.9)
                                          : Colors.white30,
                                      width: selected ? 2 : 0.6,
                                    ),
                                    color: selected
                                        ? accentPink.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.04),
                                  ),
                                ),
                              ),
                            ),
                            if (!editingLayer)
                              ..._buildResizeHandles(
                                rect: Rect.fromLTWH(
                                  0,
                                  0,
                                  layerWidth,
                                  layerHeight,
                                ),
                                scaleDelta: scaleDelta,
                                onResize: (pos, delta) {
                                  if (_layerDragStartRect == null) return;
                                  _layerResizeAccum += delta;
                                  final startRect = _layerDragStartRect!;
                                  final resized = _resizeRectFromHandle(
                                    startRect,
                                    _layerResizeAccum,
                                    pos,
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                    aspectRatio: null,
                                  );
                                  _setLayerRect(layer, resized);
                                },
                                onStart: (pos) {
                                  setState(() {
                                    _isLayerResizing = true;
                                    _layerDragStartRect = rect;
                                    _layerResizeAccum = Offset.zero;
                                  });
                                },
                                onEnd: () {
                                  final current = _resolvedLayerRect(layer);
                                  final snapped = _snapRect(
                                    current,
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  );
                                  _setLayerRect(layer, snapped);
                                  setState(() {
                                    _layerDragStartRect = null;
                                    _isLayerResizing = false;
                                    _layerResizeAccum = Offset.zero;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }(),

              if (showDefaultTextbox)
                Positioned(
                  left: boxLeft,
                  top: boxTop,
                  width: boxWidth,
                  height: boxHeight,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onPanStart: _isBoxResizing || _isInlineTextEditing
                          ? null
                          : (details) {
                              _boxDragStartPointer = Offset.zero;
                              _boxDragStartRect = box;
                              _boxDragAccum = Offset.zero;
                            },
                      onPanUpdate: _isBoxResizing || _isInlineTextEditing
                          ? null
                          : (details) {
                              if (_boxDragStartRect == null ||
                                  _boxDragStartPointer == null)
                                return;
                              _boxDragAccum += scaleDelta(details.delta);
                              final dx = _boxDragAccum.dx;
                              final dy = _boxDragAccum.dy;
                              final totalW = constraints.maxWidth;
                              final totalH = constraints.maxHeight;
                              final newLeft =
                                  (_boxDragStartRect!.left * totalW + dx) /
                                  totalW;
                              final newTop =
                                  (_boxDragStartRect!.top * totalH + dy) /
                                  totalH;
                              final next = Rect.fromLTWH(
                                newLeft,
                                newTop,
                                _boxDragStartRect!.width,
                                _boxDragStartRect!.height,
                              );
                              _setTextboxRect(_snapRect(next, totalW, totalH));
                            },
                      onPanEnd: _isBoxResizing || _isInlineTextEditing
                          ? null
                          : (_) {
                              _boxDragStartPointer = null;
                              _boxDragStartRect = null;
                              _boxDragAccum = Offset.zero;
                            },
                      onDoubleTap: () {
                        setState(() {
                          _isInlineTextEditing = true;
                          _editingLayerId = null;
                          _slideBodyController.text =
                              _slides[selectedSlideIndex].body;
                        });
                        Future.microtask(
                          () => _inlineTextFocusNode.requestFocus(),
                        );
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    (slide.boxBackgroundColor ??
                                    Colors.black26),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accentPink.withOpacity(0.8),
                                  width: 1.5,
                                ),
                              ),
                              padding: EdgeInsets.all(
                                ((slide.boxPadding ?? 8).clamp(
                                  0,
                                  48,
                                )).toDouble(),
                              ),
                              alignment: _textAlignToAlignment(
                                align,
                                verticalAlign,
                              ),
                              child: Builder(
                                builder: (context) {
                                  final fontWeight = (slide.isBold ?? true)
                                      ? FontWeight.w700
                                      : FontWeight.w400;
                                  final fontStyle = (slide.isItalic ?? false)
                                      ? FontStyle.italic
                                      : FontStyle.normal;
                                  final decoration =
                                      (slide.isUnderline ?? false)
                                      ? TextDecoration.underline
                                      : TextDecoration.none;
                                  final height = (slide.lineHeight ?? 1.3)
                                      .clamp(0.6, 3.0);
                                  final letterSpacing =
                                      (slide.letterSpacing ?? 0).clamp(
                                        -2.0,
                                        10.0,
                                      );
                                  final wordSpacing = (slide.wordSpacing ?? 0)
                                      .clamp(-4.0, 16.0);
                                  final textShadows = _textShadows(slide);
                                  final gradientColors =
                                      slide.textGradientOverride;
                                  Paint? gradientPaint;
                                  if (gradientColors != null &&
                                      gradientColors.isNotEmpty) {
                                    gradientPaint = Paint()
                                      ..shader =
                                          LinearGradient(
                                            colors: gradientColors,
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ).createShader(
                                            Rect.fromLTWH(
                                              0,
                                              0,
                                              boxWidth,
                                              boxHeight,
                                            ),
                                          );
                                  }
                                  final textColor =
                                      slide.textColorOverride ??
                                      template.textColor;
                                  final baseStyle = TextStyle(
                                    color: gradientPaint == null
                                        ? textColor
                                        : null,
                                    foreground: gradientPaint,
                                    fontSize: _autoSizedFont(
                                      slide,
                                      slide.fontSizeOverride ??
                                          template.fontSize,
                                      box,
                                    ),
                                    fontWeight: fontWeight,
                                    fontStyle: fontStyle,
                                    height: height,
                                    fontFamily: slide.fontFamilyOverride,
                                    letterSpacing: letterSpacing,
                                    wordSpacing: wordSpacing,
                                    decoration: decoration,
                                    decorationColor: textColor,
                                    shadows: textShadows,
                                  );

                                  if (_isInlineTextEditing) {
                                    return TextField(
                                      controller: _slideBodyController,
                                      focusNode: _inlineTextFocusNode,
                                      autofocus: true,
                                      maxLines: slide.singleLine == true
                                          ? 1
                                          : null,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        hintText: 'Edit text',
                                      ),
                                      style: baseStyle,
                                      onChanged: (v) {
                                        setState(() {
                                          _slides[selectedSlideIndex] =
                                              _slides[selectedSlideIndex]
                                                  .copyWith(body: v);
                                        });
                                      },
                                      onEditingComplete: () {
                                        setState(() {
                                          _isInlineTextEditing = false;
                                        });
                                      },
                                    );
                                  }

                                  final renderedBody = _applyTransform(
                                    slide.body,
                                    slide.textTransform ?? _TextTransform.none,
                                  );
                                  return Text(
                                    renderedBody,
                                    textAlign: align,
                                    style: baseStyle,
                                    maxLines: slide.singleLine == true ? 1 : 12,
                                    overflow: slide.singleLine == true
                                        ? TextOverflow.fade
                                        : TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ),
                          ),
                          ..._buildResizeHandles(
                            rect: Rect.fromLTWH(0, 0, boxWidth, boxHeight),
                            scaleDelta: scaleDelta,
                            onResize: (pos, delta) {
                              if (_boxDragStartRect == null) return;
                              _boxResizeAccum += delta;
                              final startRect = _boxDragStartRect!;
                              final resized = _resizeRectFromHandle(
                                startRect,
                                _boxResizeAccum,
                                pos,
                                constraints.maxWidth,
                                constraints.maxHeight,
                                aspectRatio: null,
                              );
                              _setTextboxRect(resized);
                            },
                            onStart: (pos) {
                              setState(() {
                                _isBoxResizing = true;
                                _boxDragStartRect = box;
                                _boxResizeAccum = Offset.zero;
                              });
                            },
                            onEnd: () {
                              final current = _resolvedBoxRect(slide);
                              final snapped = _snapRect(
                                current,
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              _setTextboxRect(snapped);
                              setState(() {
                                _boxDragStartRect = null;
                                _isBoxResizing = false;
                                _boxResizeAccum = Offset.zero;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _updateSlideBox(
    _SlideContent slide, {
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    final rect = _resolvedBoxRect(slide);
    final next = Rect.fromLTWH(
      left ?? rect.left,
      top ?? rect.top,
      width ?? rect.width,
      height ?? rect.height,
    );
    _setTextboxRect(next);
  }

  void _setTextboxRect(Rect rect) {
    final clamped = _clampRectWithOverflow(rect);
    setState(() {
      _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(
        boxLeft: clamped.left,
        boxTop: clamped.top,
        boxWidth: clamped.width,
        boxHeight: clamped.height,
      );
    });
  }

  // ignore: unused_element
  void _updateLayerBox(
    _SlideLayer layer, {
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    final rect = _resolvedLayerRect(layer);
    final next = Rect.fromLTWH(
      left ?? rect.left,
      top ?? rect.top,
      width ?? rect.width,
      height ?? rect.height,
    );
    _setLayerRect(layer, next);
  }

  void _setLayerRect(_SlideLayer layer, Rect rect) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    final clamped = _clampRectWithOverflow(rect);
    final layers = [..._slides[selectedSlideIndex].layers];
    final idx = layers.indexWhere((l) => l.id == layer.id);
    if (idx == -1) return;
    layers[idx] = layers[idx].copyWith(
      left: clamped.left,
      top: clamped.top,
      width: clamped.width,
      height: clamped.height,
    );
    _applyLayerUpdate(layers, triggerSetState: true);
  }

  List<Widget> _buildResizeHandles({
    required Rect rect,
    required Offset Function(Offset rawDelta) scaleDelta,
    required void Function(_HandlePosition pos, Offset deltaPx) onResize,
    required void Function(_HandlePosition pos) onStart,
    required VoidCallback onEnd,
  }) {
    Offset centerFor(_HandlePosition pos) {
      final left = rect.left;
      final top = rect.top;
      final right = rect.left + rect.width;
      final bottom = rect.top + rect.height;
      final midX = rect.left + rect.width / 2;
      final midY = rect.top + rect.height / 2;

      switch (pos) {
        case _HandlePosition.topLeft:
          return Offset(left, top);
        case _HandlePosition.midTop:
          return Offset(midX, top);
        case _HandlePosition.topRight:
          return Offset(right, top);
        case _HandlePosition.midLeft:
          return Offset(left, midY);
        case _HandlePosition.midRight:
          return Offset(right, midY);
        case _HandlePosition.bottomLeft:
          return Offset(left, bottom);
        case _HandlePosition.midBottom:
          return Offset(midX, bottom);
        case _HandlePosition.bottomRight:
          return Offset(right, bottom);
      }
    }

    Widget handleFor(_HandlePosition pos) {
      Offset accumulated = Offset.zero;
      final center = centerFor(pos);
      // Keep the hitbox aligned with the visual dot; slight outward nudge.
      const double visualPad = 3;
      final Offset visualOffset = () {
        switch (pos) {
          case _HandlePosition.topLeft:
            return const Offset(-visualPad, -visualPad);
          case _HandlePosition.midTop:
            return const Offset(0, -visualPad);
          case _HandlePosition.topRight:
            return const Offset(visualPad, -visualPad);
          case _HandlePosition.midLeft:
            return const Offset(-visualPad, 0);
          case _HandlePosition.midRight:
            return const Offset(visualPad, 0);
          case _HandlePosition.bottomLeft:
            return const Offset(-visualPad, visualPad);
          case _HandlePosition.midBottom:
            return const Offset(0, visualPad);
          case _HandlePosition.bottomRight:
            return const Offset(visualPad, visualPad);
        }
      }();

      return Positioned(
        left: center.dx - _resizeHandleSize / 2 + visualOffset.dx,
        top: center.dy - _resizeHandleSize / 2 + visualOffset.dy,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (_) {
            accumulated = Offset.zero;
            onStart(pos);
          },
          onPanUpdate: (details) {
            accumulated += scaleDelta(details.delta) * _resizeDampening;
            onResize(pos, accumulated);
          },
          onPanEnd: (_) {
            accumulated = Offset.zero;
            onEnd();
          },
          onPanCancel: () {
            accumulated = Offset.zero;
            onEnd();
          },
          child: MouseRegion(
            cursor: _cursorForHandle(pos),
            child: Container(
              width: _resizeHandleSize,
              height: _resizeHandleSize,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Container(
                width: _resizeHandleSize * 0.6,
                height: _resizeHandleSize * 0.6,
                decoration: BoxDecoration(
                  color: accentPink,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 6),
                  ],
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _HandlePosition.values.map(handleFor).toList();
  }

  SystemMouseCursor _cursorForHandle(_HandlePosition pos) {
    switch (pos) {
      case _HandlePosition.topLeft:
      case _HandlePosition.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case _HandlePosition.topRight:
      case _HandlePosition.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      case _HandlePosition.midLeft:
      case _HandlePosition.midRight:
        return SystemMouseCursors.resizeLeftRight;
      case _HandlePosition.midTop:
      case _HandlePosition.midBottom:
        return SystemMouseCursors.resizeUpDown;
    }
  }

  void _attachSlideEditorController(TabController controller) {
    if (_slideEditorTabController == controller) return;
    _slideEditorTabController?.removeListener(_onSlideEditorTabChanged);
    _slideEditorTabController = controller;
    _slideEditorTabController?.addListener(_onSlideEditorTabChanged);
  }

  void _onSlideEditorTabChanged() {
    final controller = _slideEditorTabController;
    if (controller == null) return;
    if (!controller.indexIsChanging &&
        controller.index != _slideEditorTabIndex) {
      setState(() {
        _slideEditorTabIndex = controller.index;
      });
    }
  }

  Widget _buildSlideEditorPanel() {
    final hasSlide =
        _slides.isNotEmpty &&
        selectedSlideIndex >= 0 &&
        selectedSlideIndex < _slides.length;
    if (!hasSlide) {
      return _frostedBox(
        child: const Text(
          'No slide selected',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final _SlideContent slide = _slides[selectedSlideIndex];
    final _SlideTemplate template = _templateFor(slide.templateId);

    return _frostedBox(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Inline slide/filters when there's adequate room, or when explicitly expanded via the dropdown.
          // Always include Slide / Filters tabs; allow scroll instead of collapsing.
          final bool widthAllowsInline = constraints.maxWidth >= 420;
          final bool injectExtras = true;
          final tabSpecs = <Map<String, dynamic>>[
            {
              'id': 'textbox',
              'label': 'Textbox',
              'builder': () => _textboxTab(slide, template),
            },
            {
              'id': 'item',
              'label': 'Item',
              'builder': () => _itemTab(slide, template),
            },
            {
              'id': 'items',
              'label': 'Items',
              'builder': () => _itemsTab(
                slide,
                template,
                showExtras: !injectExtras && _itemsExtrasExpanded,
              ),
            },
          ];

          tabSpecs.addAll([
            {
              'id': 'slide',
              'label': 'Slide',
              'builder': () => _slideTab(slide, template),
            },
            {
              'id': 'filters',
              'label': 'Filters',
              'builder': () => _filtersTab(slide, template),
            },
          ]);

          final int itemsTabIndex = tabSpecs.indexWhere(
            (t) => t['id'] == 'items',
          );
          final int slideTabIndex = tabSpecs.indexWhere(
            (t) => t['id'] == 'slide',
          );
          final int filtersTabIndex = tabSpecs.indexWhere(
            (t) => t['id'] == 'filters',
          );
          final int textboxTabIndex = tabSpecs.indexWhere(
            (t) => t['id'] == 'textbox',
          );

          int desiredIndex = _slideEditorTabIndex;
          // With slide/filters always present, keep the desired index as-is.

          desiredIndex = desiredIndex.clamp(0, tabSpecs.length - 1).toInt();

          if (_slideEditorTabIndex != desiredIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _slideEditorTabIndex = desiredIndex);
            });
          }

          if (_itemsExtrasExpanded && injectExtras && widthAllowsInline) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _itemsExtrasExpanded = false);
            });
          }

          return DefaultTabController(
            length: tabSpecs.length,
            initialIndex: desiredIndex,
            child: Builder(
              builder: (context) {
                final controller = DefaultTabController.of(context);
                if (controller != null) {
                  _attachSlideEditorController(controller);
                }

                final int activeIndex = controller?.index ?? desiredIndex;
                final activeBuilder =
                    tabSpecs[activeIndex]['builder'] as Widget Function();

                return Tooltip(
                  message: 'Slide Editor',
                  waitDuration: const Duration(milliseconds: 250),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final int tabCount = tabSpecs.length;
                                const double minComfortable = 88.0;
                                final bool canFill =
                                    constraints.maxWidth >=
                                    (tabCount * minComfortable);

                                final tabBar = TabBar(
                                  isScrollable: !canFill,
                                  tabAlignment: canFill
                                      ? TabAlignment.fill
                                      : TabAlignment.start,
                                  indicatorColor: accentPink,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: Colors.white70,
                                  padding: EdgeInsets.zero,
                                  labelPadding: canFill
                                      ? EdgeInsets.zero
                                      : const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                  indicatorPadding: EdgeInsets.zero,
                                  onTap: (idx) => setState(() {
                                    _slideEditorTabIndex = idx;
                                  }),
                                  tabs: [
                                    for (final t in tabSpecs)
                                      Tab(text: t['label'] as String),
                                  ],
                                );

                                if (canFill) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: tabBar,
                                  );
                                }

                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    padding: EdgeInsets.zero,
                                    child: tabBar,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (!injectExtras &&
                              itemsTabIndex != -1 &&
                              _slideEditorTabIndex == itemsTabIndex)
                            PopupMenuButton<int>(
                              tooltip: 'Slide / Filters',
                              onSelected: (idx) => setState(() {
                                _itemsExtrasExpanded = true;
                                _itemsSubTabIndex = idx;
                              }),
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 0, child: Text('Slide')),
                                PopupMenuItem(value: 1, child: Text('Filters')),
                              ],
                              icon: const Icon(
                                Icons.expand_more,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: KeyedSubtree(
                          key: ValueKey(tabSpecs[activeIndex]['id']),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: activeBuilder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _importLyrics(String raw, {int? linesPerSlide}) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final blocks = text
        .split(RegExp(r'\n\s*\n'))
        .where((b) => b.trim().isNotEmpty)
        .toList();
    final List<_SlideContent> newSlides = [];

    for (final block in blocks) {
      final lines = block
          .trim()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
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
      return const Center(
        child: Text('No shows yet', style: TextStyle(color: Colors.white54)),
      );
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
      final stackBox =
          _slidesStackKey.currentContext?.findRenderObject() as RenderBox?;
      if (stackBox == null) return;
      final topLeftLocal = stackBox.globalToLocal(topLeftGlobal);
      _slideRects[index] = Rect.fromLTWH(
        topLeftLocal.dx,
        topLeftLocal.dy,
        size.width,
        size.height,
      );
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
      _ensureSelectedLayerValid(forcePickFirst: true);
      _isInlineTextEditing = false;
      _editingLayerId = null;
      _layerTextController.clear();
    });
    _syncSlideEditors();
    _sendCurrentSlideToOutputs();
    // Auto-play videos on the newly selected slide
    _playVideosOnCurrentSlide();
  }

  /// Play all videos on the current slide
  void _playVideosOnCurrentSlide() async {
    final videoPaths = _getCurrentSlideVideoPaths();
    for (final path in videoPaths) {
      final entry = _ensureVideoController(path, autoPlay: true);
      // Ensure video is initialized before playing
      await entry.initialize;
      if (mounted && !entry.controller.value.isPlaying) {
        entry.controller.setLooping(true);
        entry.controller.play();
      }
    }
  }

  void _syncSlideEditors() {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
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
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= _slides.length ||
        to > _slides.length)
      return;
    _syncSlideThumbnails();
    setState(() {
      // Work on mutable copies in case the current lists are wrapped/unmodifiable.
      final slides = List<_SlideContent>.from(_slides);
      final thumbs = List<String?>.from(_slideThumbnails);

      final item = slides.removeAt(from);
      slides.insert(to, item);

      final thumb = thumbs.removeAt(from);
      thumbs.insert(to, thumb);

      _slides = slides;
      _slideThumbnails = thumbs;

      selectedSlideIndex = _mapIndexOnMove(selectedSlideIndex, from, to);
      selectedSlides = selectedSlides
          .map((i) => _mapIndexOnMove(i, from, to))
          .toSet();
    });
    _syncSlideEditors();
    // Avoid auto-broadcast during drag/reorder to prevent duplicate output windows.
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
    // Default new media to foreground so it can be dragged/resized unless user explicitly switches to background.
    return _LayerRole.foreground;
  }

  _SlideLayer? _backgroundLayerFor(_SlideContent slide) {
    for (final layer in slide.layers.reversed) {
      if (layer.role == _LayerRole.background &&
          layer.kind == _LayerKind.media &&
          layer.mediaType != null)
        return layer;
    }
    return null;
  }

  _SlideLayer? _effectiveMediaLayer(_SlideContent slide) {
    // Only use explicit background media; foreground media should render as layers (not yet wired in output window).
    final bg = _backgroundLayerFor(slide);
    if (bg != null && (bg.path?.isNotEmpty ?? false)) return bg;
    return null;
  }

  List<_SlideLayer> _foregroundLayers(_SlideContent slide) {
    return slide.layers.where((l) => l.role == _LayerRole.foreground).toList();
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
      case _LayerKind.screen:
        return 'Screen';
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
        return layer.mediaType == _SlideMediaType.video
            ? Icons.videocam_outlined
            : Icons.image_outlined;
      case _LayerKind.textbox:
        return Icons.title;
      case _LayerKind.camera:
        return Icons.videocam;
      case _LayerKind.screen:
        return Icons.desktop_windows;
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
    if (bg != null &&
        bg.mediaType == _SlideMediaType.image &&
        bg.path != null) {
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
    if (slide.mediaPath != null &&
        slide.mediaPath!.isNotEmpty &&
        slide.mediaType != null) {
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
        if (slideIndex == selectedSlideIndex) {
          _selectedLayerId = layer.id;
        }
        _applyLayerUpdate(
          _slides[slideIndex].layers,
          slideIndex: slideIndex,
          triggerSetState: false,
        );
      });
      return;
    }

    // No legacy media: seed a default textbox layer so the stack is populated.
    final defaultTextbox = _SlideLayer(
      id: 'layer-${DateTime.now().millisecondsSinceEpoch}',
      label: 'Textbox',
      kind: _LayerKind.textbox,
      role: _LayerRole.foreground,
      text: slide.body,
    );
    setState(() {
      _slides[slideIndex] = slide.copyWith(layers: [defaultTextbox]);
      _hydratedLayerSlides.add(slide.id);
      if (slideIndex == selectedSlideIndex) {
        _selectedLayerId = defaultTextbox.id;
      }
      _applyLayerUpdate(
        _slides[slideIndex].layers,
        slideIndex: slideIndex,
        triggerSetState: false,
      );
    });
  }

  void _reorderLayers(int oldIndex, int newIndex) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    setState(() {
      final layers = [..._slides[selectedSlideIndex].layers];
      if (newIndex > oldIndex) newIndex -= 1;
      final layer = layers.removeAt(oldIndex);
      layers.insert(newIndex, layer);
      _applyLayerUpdate(layers, triggerSetState: false);
    });
  }

  void _toggleArmOutput(String outputId) {
    setState(() {
      // If nothing is armed yet, start with all outputs armed so toggling removes one.
      if (_armedOutputs.isEmpty) {
        _armedOutputs.addAll(_outputs.map((o) => o.id));
      }

      if (_armedOutputs.contains(outputId)) {
        _armedOutputs.remove(outputId);
      } else {
        _armedOutputs.add(outputId);
      }

      // If all outputs are re-armed, collapse back to empty to signify "all".
      final allIds = _outputs.map((o) => o.id).toSet();
      if (_armedOutputs.length == allIds.length &&
          _armedOutputs.containsAll(allIds)) {
        _armedOutputs.clear();
      }
    });
  }

  void _setLayerRole(String layerId, _LayerRole role) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    final layers = _slides[selectedSlideIndex].layers.map((layer) {
      if (layer.id == layerId) {
        return layer.copyWith(role: role);
      }
      return layer;
    }).toList();
    setState(() {
      _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(
        layers: layers,
      );
      _selectedLayerId = layerId;
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
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
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

      if (_selectedLayerId == layerId) {
        _selectedLayerId = layers.isNotEmpty ? layers.first.id : null;
      }

      if (_editingLayerId == layerId) {
        _editingLayerId = null;
        _layerTextController.clear();
      }

      // If the user intentionally removes the final layer, mark this slide as hydrated
      // so we don't auto-inject a default textbox again.
      if (layers.isEmpty) {
        _hydratedLayerSlides.add(slide.id);
      }

      // If the removed layer was a background media, drop the slide media mapping immediately.
      final wasBackgroundMedia =
          removedLayer?.kind == _LayerKind.media &&
          removedLayer?.role == _LayerRole.background;
      final hasMedia = layers.any((l) => l.kind == _LayerKind.media);
      if (wasBackgroundMedia || !hasMedia) {
        _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(
          mediaPath: null,
          mediaType: null,
        );
        _slideThumbnails[selectedSlideIndex] = null;
        _updateSlideThumbnailFromLayers(selectedSlideIndex);
      }

      // If the removed layer was the only textbox, clear textbox content so it disappears from the slide.
      final hasTextbox = layers.any((l) => l.kind == _LayerKind.textbox);
      if (removedLayer?.kind == _LayerKind.textbox && !hasTextbox) {
        _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(
          body: '',
        );
        _slideBodyController.text = '';
      }
    });
    _pruneVideoControllers();
  }

  void _duplicateLayer(String layerId) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    setState(() {
      final slide = _slides[selectedSlideIndex];
      final layers = [...slide.layers];
      final idx = layers.indexWhere((l) => l.id == layerId);
      if (idx == -1) return;

      final src = layers[idx];
      final duplicate = src.copyWith(
        id: 'layer-${DateTime.now().millisecondsSinceEpoch}',
        label: '${src.label} Copy',
        addedAt: DateTime.now(),
      );

      layers.insert(idx + 1, duplicate);
      _applyLayerUpdate(layers, triggerSetState: false);
      _selectedLayerId = duplicate.id;
    });
  }

  Future<void> _showLayerContextMenu(
    BuildContext context,
    _SlideLayer layer,
    Offset globalPosition,
  ) async {
    final isMedia =
        layer.kind == _LayerKind.media && (layer.path?.isNotEmpty ?? false);

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        if (isMedia)
          const PopupMenuItem<String>(value: 'replace', child: Text('Replace')),
        const PopupMenuItem<String>(
          value: 'duplicate',
          child: Text('Duplicate'),
        ),
        const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
      ],
    );

    switch (selection) {
      case 'replace':
        await _replaceLayerMedia(layer);
        break;
      case 'duplicate':
        _duplicateLayer(layer.id);
        break;
      case 'delete':
        _deleteLayer(layer.id);
        break;
      default:
        break;
    }
  }

  Future<void> _replaceLayerMedia(_SlideLayer layer) async {
    if (kIsWeb) {
      _showSnack('Media picking not supported in web build');
      return;
    }
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length) {
      return;
    }

    // Determine if current layer is image or video
    final currentType = layer.mediaType;
    final choice = await showDialog<_SlideMediaType>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          backgroundColor: bgMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Replace with',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
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

    if (choice == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: choice == _SlideMediaType.image ? FileType.image : FileType.video,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;

    setState(() {
      final slide = _slides[selectedSlideIndex];
      final layers = slide.layers.map((l) {
        if (l.id == layer.id) {
          return l.copyWith(
            path: path,
            mediaType: choice,
            label: _fileName(path),
          );
        }
        return l;
      }).toList();

      // Update background if this was a background layer
      final updatedLayer = layers.firstWhere((l) => l.id == layer.id);
      final isBackground = updatedLayer.role == _LayerRole.background;

      _slides[selectedSlideIndex] = slide.copyWith(
        layers: layers,
        mediaPath: isBackground ? path : slide.mediaPath,
        mediaType: isBackground ? choice : slide.mediaType,
      );
      _updateSlideThumbnailFromLayers(selectedSlideIndex);
    });
    _pruneVideoControllers();
    _syncSlideEditors();
    _showSnack(
      'Replaced media with ${choice == _SlideMediaType.image ? 'picture' : 'video'}',
    );
  }

  void _nudgeLayer(int index, int delta) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    final layers = [..._slides[selectedSlideIndex].layers];
    final target = (index + delta).clamp(0, layers.length - 1);
    if (target == index) return;
    setState(() {
      final layer = layers.removeAt(index);
      layers.insert(target, layer);
      _applyLayerUpdate(layers, triggerSetState: false);
    });
  }

  void _applyLayerUpdate(
    List<_SlideLayer> layers, {
    int? slideIndex,
    bool triggerSetState = true,
  }) {
    void apply() {
      final idx = slideIndex ?? selectedSlideIndex;
      if (idx < 0 || idx >= _slides.length) return;
      final slide = _slides[idx].copyWith(layers: layers);
      final bg = _backgroundLayerFor(slide);
      final updated = slide.copyWith(
        mediaPath: bg?.path,
        mediaType: bg?.mediaType,
      );
      _slides[idx] = updated;
      _updateSlideThumbnailFromLayers(idx);
      if (idx == selectedSlideIndex) {
        _ensureSelectedLayerValid(forcePickFirst: true);
      }
      _pruneVideoControllers();
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Add media',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
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

  Widget _mediaOptionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
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
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    final result = await FilePicker.platform.pickFiles(
      type: type == _SlideMediaType.image ? FileType.image : FileType.video,
    );
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
      // Only map mediaPath/mediaType when explicitly background; foreground stays independent.
      _slides[selectedSlideIndex] = slide.copyWith(
        mediaPath: role == _LayerRole.background ? path : slide.mediaPath,
        mediaType: role == _LayerRole.background ? type : slide.mediaType,
        layers: updatedLayers,
      );
      _updateSlideThumbnailFromLayers(selectedSlideIndex);
    });
    _syncSlideEditors();
    _showSnack(
      'Attached ${type == _SlideMediaType.image ? 'picture' : 'video'} to slide ${selectedSlideIndex + 1}',
    );
  }

  void _clearSlideMedia() {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    setState(() {
      _slides[selectedSlideIndex] = _slides[selectedSlideIndex].copyWith(
        mediaPath: null,
        mediaType: null,
        layers: [],
      );
      _slideThumbnails[selectedSlideIndex] = null;
    });
    _pruneVideoControllers();
    _syncSlideEditors();
  }

  void _onGridPointerDown(PointerDownEvent event) {
    _requestSlidesFocus();
    final stackBox =
        _slidesStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == kPrimaryButton) {
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
    final stackBox =
        _slidesStackKey.currentContext?.findRenderObject() as RenderBox?;
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
    final stackBox =
        _slidesStackKey.currentContext?.findRenderObject() as RenderBox?;
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
    if (event is RawKeyDownEvent &&
        event.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyA) {
      setState(() {
        selectedSlides = {for (int i = 0; i < _slides.length; i++) i};
        selectedSlideIndex = selectedSlides.isNotEmpty
            ? selectedSlides.first
            : 0;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  int _reorderTargetIndex({
    required int from,
    required int desiredInsertIndex,
  }) {
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
              builder: (context, candidate, rejected) =>
                  const IgnorePointer(child: SizedBox.expand()),
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
                          child: Text(
                            'No slides',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                            ),
                          ),
                        )
                      : GridView.builder(
                          controller: _slidesScrollController,
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 44),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 360,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 16 / 9,
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
                              onSecondaryTapDown: (details) =>
                                  _showSlideContextMenu(i, details),
                              onTap: () {
                                _requestSlidesFocus();
                                _selectSlide(i);
                              },
                              child: Opacity(
                                opacity: isDragging ? 0.35 : 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppPalette.carbonBlack,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: isSelected
                                          ? accentPink
                                          : Colors.white12,
                                      width: isSelected ? 1.5 : 0.8,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            const BoxShadow(
                                              color: Colors.black54,
                                              blurRadius: 8,
                                              offset: Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: _renderSlidePreview(
                                          _slides[i],
                                          compact: true,
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.78,
                                            ),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  bottom: Radius.circular(8),
                                                ),
                                            border: const Border(
                                              top: BorderSide(
                                                color: Colors.white12,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                '${i + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Center(
                                                  child: Text(
                                                    _slides[i].title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
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
                                    builder:
                                        (context, candidateData, rejectedData) {
                                          final isActive =
                                              candidateData.isNotEmpty;
                                          return Draggable<int>(
                                            data: i,
                                            dragAnchorStrategy:
                                                pointerDragAnchorStrategy,
                                            maxSimultaneousDrags: 1,
                                            onDragStarted: () => setState(() {
                                              _draggingIndex = i;
                                              _dragSelecting = false;
                                            }),
                                            onDragEnd: (_) => setState(
                                              () => _draggingIndex = null,
                                            ),
                                            feedback: Material(
                                              color: Colors.transparent,
                                              child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints.tightFor(
                                                      width: 180,
                                                      height: 135,
                                                    ),
                                                child: Opacity(
                                                  opacity: 0.9,
                                                  child: tile,
                                                ),
                                              ),
                                            ),
                                            childWhenDragging:
                                                const SizedBox.shrink(),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 120,
                                              ),
                                              decoration: isActive
                                                  ? BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color: accentPink
                                                            .withOpacity(0.6),
                                                        width: 2,
                                                      ),
                                                    )
                                                  : null,
                                              child: tile,
                                            ),
                                          );
                                        },
                                  ),
                                ),
                                _slideReorderDropZone(
                                  insertIndex: i + 1,
                                  width: 6,
                                ),
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
                  border: Border.all(
                    color: accentPink.withOpacity(0.6),
                    width: 1,
                  ),
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

  // ignore: unused_element
  Widget _frostedBox({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.fromLTRB(8, 6, 8, 8),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.dustyMauve),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _miniNavItem(
    String label,
    List<_MiniNavAction> actions,
    GlobalKey anchorKey,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        key: anchorKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => _showMiniMenu(anchorKey, actions),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  void _showMiniMenu(GlobalKey anchorKey, List<_MiniNavAction> actions) {
    final context = anchorKey.currentContext;
    if (context == null || actions.isEmpty) return;

    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final position = box.localToGlobal(Offset.zero, ancestor: overlay);
    showMenu<_MiniNavAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + box.size.height,
        position.dx + box.size.width,
        position.dy,
      ),
      items: [
        for (final action in actions)
          PopupMenuItem<_MiniNavAction>(
            value: action,
            enabled: action.enabled,
            child: Row(
              children: [
                if (action.icon != null) ...[
                  Icon(
                    action.icon,
                    size: 16,
                    color: action.enabled ? Colors.white70 : Colors.white24,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(action.label)),
                if (action.shortcut != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    action.shortcut!,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ],
            ),
          ),
      ],
    ).then((selected) {
      if (selected != null && selected.enabled) {
        selected.onSelected();
      }
    });
  }

  Widget _topTab({
    required IconData icon,
    required String label,
    bool selected = false,
    required VoidCallback onTap,
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0.5, end: selected ? 1.0 : 0.5),
                    builder: (context, opacity, child) => Icon(
                      icon,
                      size: 14,
                      color: Colors.white.withValues(alpha: opacity),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(label),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerList(
    String title,
    List<FileSystemEntity> items,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
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
                ? const Center(
                    child: Text('Empty', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final name = items[i].path
                          .split(Platform.pathSeparator)
                          .last;
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
    final selectedShow =
        (selectedShowIndex != null &&
            selectedShowIndex! >= 0 &&
            selectedShowIndex! < shows.length)
        ? shows[selectedShowIndex!]
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget body(double listHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.playlist_play,
                    size: 16,
                    color: AppPalette.dustyMauve,
                  ),
                  SizedBox(width: 6),
                  Text('Shows', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: listHeight,
                child: Row(
                  children: [
                    // Categories column
                    SizedBox(
                      width: 170,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 4,
                            ),
                            child: Text(
                              'Categories',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedCategoryIndex == null
                                          ? Colors.white10
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.all_inclusive,
                                          size: 16,
                                          color: Colors.white70,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'All',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
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
                                      child: Text(
                                        'No categories yet',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  )
                                else
                                  ...List.generate(showCategories.length, (i) {
                                    final selected = selectedCategoryIndex == i;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: InkWell(
                                        onTap: () => setState(() {
                                          selectedCategoryIndex = i;
                                          _clampSelectedShow();
                                        }),
                                        onSecondaryTapDown: (details) =>
                                            _showCategoryContextMenu(
                                              i,
                                              details,
                                            ),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? Colors.white10
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.label_outline,
                                                size: 16,
                                                color: selected
                                                    ? accentPink
                                                    : Colors.white70,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  showCategories[i],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: selected
                                                        ? Colors.white
                                                        : Colors.white70,
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
                            label: const Text(
                              'New category',
                              style: TextStyle(fontSize: 12),
                            ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              children: const [
                                Expanded(
                                  child: Text(
                                    'Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Modified',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(
                            color: Colors.white12,
                            height: 0.5,
                            thickness: 0.5,
                          ),
                          Expanded(
                            child: visible.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No shows yet',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: visible.length,
                                    separatorBuilder: (_, __) => const Divider(
                                      color: Colors.white10,
                                      height: 1,
                                    ),
                                    itemBuilder: (context, i) {
                                      final globalIndex = shows.indexOf(
                                        visible[i],
                                      );
                                      final selected =
                                          selectedShowIndex == globalIndex;
                                      return InkWell(
                                        onTap: () => setState(
                                          () => selectedShowIndex = globalIndex,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? Colors.white10
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  visible[i].name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: selected
                                                        ? Colors.white
                                                        : Colors.white70,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                '—',
                                                style: TextStyle(
                                                  color: selected
                                                      ? Colors.white
                                                      : Colors.white54,
                                                  fontSize: 12,
                                                ),
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
                          color: AppPalette.carbonBlack,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: selectedShow == null
                            ? const Center(
                                child: Text(
                                  'Select a show',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedShow.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _metaRow('Created', '—'),
                                    _metaRow('Modified', '—'),
                                    _metaRow('Used', '—'),
                                    _metaRow(
                                      'Category',
                                      selectedShow.category ?? 'None',
                                    ),
                                    _metaRow(
                                      'Slides',
                                      _slides.length.toString(),
                                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          );
        }

        // Keep content scrollable when the drawer is short to avoid overflows.
        const double headerHeight = 24;
        const double buttonHeight = 40;
        const double spacing = 16; // two SizedBox(height: 8)
        final double availableHeight =
            constraints.maxHeight - headerHeight - buttonHeight - spacing;
        final bool needsScroll = availableHeight < 160;

        return Container(
          decoration: BoxDecoration(
            color: AppPalette.carbonBlack,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: body(needsScroll ? 200 : math.max(0, availableHeight)),
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
    final bool isEditTab = selectedTopTab == 1;
    final bool isShowTab = selectedTopTab == 0;

    return Container(
      color: AppPalette.carbonBlack,
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive sizing based on available width so the panel stays compact when squeezed.
          final double w = constraints.maxWidth;
          final double previewHeight = (w * (isEditTab ? 0.38 : 0.45)).clamp(
            120.0,
            isEditTab ? 180.0 : 210.0,
          );
          final double gap = w < 360 ? 4 : 6;
          final double buttonHeight = w < 360 ? 28 : 32;

          final topCommon = <Widget>[
            _buildPreviewPane(height: previewHeight, showTitle: !isEditTab),
            SizedBox(height: gap),
            _buildTransportRow(
              height: buttonHeight,
              iconSize: w < 360 ? 14 : 16,
            ),
            _buildMediaControlsRow(),
            SizedBox(height: gap),
            if (isShowTab) ...[
              _buildOutputControlCard(),
              SizedBox(height: gap),
            ],
          ];

          final Widget content = isEditTab
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...topCommon,
                    _buildSlideEditorPanel(),
                    if (_slideEditorTabIndex == 2) ...[
                      SizedBox(height: gap),
                      _buildLayerTimeline(),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...topCommon,
                    _buildAutoAdvanceRow(),
                    SizedBox(height: gap),
                    _buildGroupsCard(),
                    SizedBox(height: gap + 2),
                    _buildShowsMetaPanel(),
                  ],
                );

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransportRow({double height = 32, double iconSize = 16}) {
    final constraints = BoxConstraints.tightFor(width: height, height: height);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          IconButton(
            constraints: constraints,
            padding: EdgeInsets.zero,
            onPressed: _prevSlide,
            icon: Icon(
              Icons.chevron_left,
              size: iconSize,
              color: Colors.white70,
            ),
            tooltip: 'Previous slide',
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  constraints: constraints,
                  padding: EdgeInsets.zero,
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: iconSize,
                    color: Colors.white70,
                  ),
                  tooltip: isPlaying ? 'Pause' : 'Play',
                ),
                const SizedBox(width: 10),
                IconButton(
                  constraints: constraints,
                  padding: EdgeInsets.zero,
                  onPressed: _nextSlide,
                  icon: Icon(
                    Icons.chevron_right,
                    size: iconSize,
                    color: Colors.white70,
                  ),
                  tooltip: 'Next slide',
                ),
              ],
            ),
          ),
          IconButton(
            constraints: constraints,
            padding: EdgeInsets.zero,
            onPressed: _clearAllOutputs,
            icon: Icon(Icons.clear_all, size: iconSize, color: Colors.white70),
            tooltip: 'Clear outputs',
          ),
        ],
      ),
    );
  }

  /// Returns the video controller for the current slide's media, if any.
  VideoPlayerController? _currentSlideVideoController() {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length) {
      return null;
    }
    final slide = _slides[selectedSlideIndex];
    // Check for background video
    final bgPath = slide.mediaPath;
    if (bgPath != null &&
        bgPath.isNotEmpty &&
        slide.mediaType == _SlideMediaType.video) {
      final entry = _videoControllers[bgPath];
      if (entry != null && entry.controller.value.isInitialized) {
        return entry.controller;
      }
    }
    // Check for foreground video layers
    for (final layer in slide.layers) {
      if (layer.kind == _LayerKind.media &&
          layer.mediaType == _SlideMediaType.video &&
          (layer.path?.isNotEmpty ?? false)) {
        final entry = _videoControllers[layer.path!];
        if (entry != null && entry.controller.value.isInitialized) {
          return entry.controller;
        }
      }
    }
    return null;
  }

  Widget _buildMediaControlsRow() {
    final controller = _currentSlideVideoController();
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final position = value.position;
        final duration = value.duration;
        final isVideoPlaying = value.isPlaying;

        String formatDuration(Duration d) {
          final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
          final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
          if (d.inHours > 0) {
            final hours = d.inHours.toString();
            return '$hours:$minutes:$seconds';
          }
          return '$minutes:$seconds';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Play/Pause button for video
              GestureDetector(
                onTap: () {
                  if (isVideoPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
                child: Icon(
                  isVideoPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              // Current time
              Text(
                formatDuration(position),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              // Seek bar
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                    activeTrackColor: accentPink,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: accentPink.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: duration.inMilliseconds > 0
                        ? (position.inMilliseconds / duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (v) {
                      final newPosition = Duration(
                        milliseconds: (v * duration.inMilliseconds).round(),
                      );
                      controller.seekTo(newPosition);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Duration
              Text(
                formatDuration(duration),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              // Volume button
              GestureDetector(
                onTap: () {
                  controller.setVolume(value.volume > 0 ? 0 : 1);
                },
                child: Icon(
                  value.volume > 0 ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _clearAllOutputs() async {
    debugPrint('out: clearing all outputs count=${_outputWindowIds.length}');

    // Reset all layer toggle states to off
    setState(() {
      outputBackgroundActive = false;
      outputForegroundMediaActive = false;
      outputSlideActive = false;
      outputOverlayActive = false;
      outputAudioActive = false;
      outputTimerActive = false;
      outputPreviewCleared = true;
    });

    final payload = {
      'clear': true,
      'slide': null,
      'content': '',
      'alignment': 'center',
      'imagePath': null,
      'output': {'locked': false},
      'state': {
        'layers': {
          'background': false,
          'foregroundMedia': false,
          'slide': false,
          'overlay': false,
          'audio': false,
          'timer': false,
        },
        'locked': false,
        'transition': 'none',
      },
    };

    for (final entry in _outputWindowIds.entries.toList()) {
      try {
        debugPrint(
          'out: clearing windowId=${entry.value} outputId=${entry.key}',
        );
        await DesktopMultiWindow.invokeMethod(
          entry.value,
          'updateContent',
          payload,
        );
      } catch (_) {
        // If a window was closed or unreachable, ignore and continue clearing others.
      }
    }

    for (final id in _outputWindowIds.keys) {
      _outputRuntime[id] = _OutputRuntimeState(
        active: false,
        locked: false,
        ndi: enableNdiOutput,
        disconnected: false,
      );
    }

    _showSnack('Cleared output windows');
  }

  void _toggleOutputLayer(String layer) {
    setState(() {
      switch (layer) {
        case 'background':
          outputBackgroundActive = !outputBackgroundActive;
          break;
        case 'foregroundMedia':
          outputForegroundMediaActive = !outputForegroundMediaActive;
          break;
        case 'slide':
          outputSlideActive = !outputSlideActive;
          break;
        case 'overlay':
          outputOverlayActive = !outputOverlayActive;
          break;
        case 'audio':
          outputAudioActive = !outputAudioActive;
          break;
        case 'timer':
          outputTimerActive = !outputTimerActive;
          break;
      }
      outputPreviewCleared =
          !(outputBackgroundActive ||
              outputForegroundMediaActive ||
              outputSlideActive ||
              outputOverlayActive);
    });
    _sendCurrentSlideToOutputs();
  }

  void _toggleOutputsLocked() {
    setState(() => outputsLocked = !outputsLocked);
    for (final id in _outputs.map((o) => o.id)) {
      final state = _outputRuntime[id] ?? _OutputRuntimeState();
      state.locked = outputsLocked;
      _outputRuntime[id] = state;
    }
    _sendCurrentSlideToOutputs();
  }

  void _toggleOutputLock(String outputId) {
    setState(() {
      final state = _outputRuntime[outputId] ?? _OutputRuntimeState();
      state.locked = !state.locked;
      _outputRuntime[outputId] = state;
    });
    _sendCurrentSlideToOutputs();
  }

  Widget _buildClearAllButton() {
    return _buildClearAllButtonSized(height: 32);
  }

  Widget _buildClearAllButtonSized({double height = 32}) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: accentPink,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: height * 0.35,
            vertical: math.max(6, height * 0.22),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height * 0.55),
          ),
        ),
        onPressed: _clearAllOutputs,
        icon: Icon(Icons.clear_all, size: height * 0.5),
        label: Text(
          'Clear all',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: height * 0.38,
          ),
        ),
      ),
    );
  }

  Widget _buildAutoAdvanceRow() {
    return Row(
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
        const Text(
          'Auto-advance',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const Spacer(),
        Text(
          '${autoAdvanceInterval.inSeconds}s',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        SizedBox(
          width: 120,
          child: Slider(
            value: autoAdvanceInterval.inSeconds.toDouble(),
            min: 3,
            max: 30,
            divisions: 27,
            activeColor: accentPink,
            onChanged: (v) {
              setState(
                () => autoAdvanceInterval = Duration(seconds: v.round()),
              );
              if (isPlaying && autoAdvanceEnabled) {
                _restartAutoAdvanceTimer();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsCard() {
    return _frostedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Groups', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Divider(color: Colors.white12),
          SizedBox(
            height: 50,
            child: Center(
              child: Text('No groups', style: TextStyle(color: Colors.white54)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPane({double height = 200, bool showTitle = true}) {
    if (_slides.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(12),
            child: const Center(
              child: Text('No slides', style: TextStyle(color: Colors.white54)),
            ),
          ),
        ),
      );
    }

    final safeIndex = _safeIntClamp(selectedSlideIndex, 0, _slides.length - 1);
    final slide = _slides[safeIndex];
    final bool showContent =
        !outputPreviewCleared &&
        (outputBackgroundActive || outputSlideActive || outputOverlayActive);
    final previewFrame = Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: showContent
          ? _renderSlidePreview(slide)
          : Container(color: Colors.black),
    );

    return SizedBox(
      width: double.infinity,
      child: AspectRatio(aspectRatio: 16 / 9, child: previewFrame),
    );
  }

  /// Check if the current slide has a background layer (image or video)
  bool _currentSlideHasBackground() {
    if (_slides.isEmpty) return false;
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    final bgLayer = _backgroundLayerFor(slide);
    return bgLayer != null && (bgLayer.path?.isNotEmpty ?? false);
  }

  /// Check if the current slide has text content (title, body, or textbox layer)
  bool _currentSlideHasText() {
    if (_slides.isEmpty) return false;
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    if (slide.title.trim().isNotEmpty || slide.body.trim().isNotEmpty)
      return true;
    return slide.layers.any(
      (l) => l.kind == _LayerKind.textbox && (l.text?.isNotEmpty ?? false),
    );
  }

  /// Check if the current slide has foreground overlay layers (non-background media or other layers)
  bool _currentSlideHasOverlay() {
    if (_slides.isEmpty) return false;
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    final fgLayers = _foregroundLayers(slide);
    return fgLayers.isNotEmpty;
  }

  /// Check if the current slide has foreground media layers (images/videos in foreground)
  bool _currentSlideHasForegroundMedia() {
    if (_slides.isEmpty) return false;
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    final fgLayers = _foregroundLayers(slide);
    return fgLayers.any(
      (l) => l.kind == _LayerKind.media && (l.path?.isNotEmpty ?? false),
    );
  }

  /// Check if the current slide has timer layer
  bool _currentSlideHasTimer() {
    if (_slides.isEmpty) return false;
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    return slide.layers.any((l) => l.kind == _LayerKind.timer);
  }

  Widget _buildOutputControlCard() {
    // Determine if current slide has each layer type
    final hasBackground = _currentSlideHasBackground();
    final hasForegroundMedia = _currentSlideHasForegroundMedia();
    final hasText = _currentSlideHasText();
    final hasOverlay = _currentSlideHasOverlay();
    final hasTimer = _currentSlideHasTimer();
    // Audio is always potentially available (not tracked per-slide for now)
    const hasAudio = true;

    final layerStates = [
      (
        icon: Icons.image,
        tooltip: 'Toggle background layer',
        active: outputBackgroundActive,
        key: 'background',
        hasContent: hasBackground,
      ),
      (
        icon: Icons.video_library,
        tooltip: 'Toggle foreground media',
        active: outputForegroundMediaActive,
        key: 'foregroundMedia',
        hasContent: hasForegroundMedia,
      ),
      (
        icon: Icons.text_fields,
        tooltip: 'Toggle slide/text layer',
        active: outputSlideActive,
        key: 'slide',
        hasContent: hasText,
      ),
      (
        icon: Icons.layers,
        tooltip: 'Toggle overlay layer',
        active: outputOverlayActive,
        key: 'overlay',
        hasContent: hasOverlay,
      ),
      (
        icon: Icons.music_note,
        tooltip: 'Toggle audio layer',
        active: outputAudioActive,
        key: 'audio',
        hasContent: hasAudio,
      ),
      (
        icon: Icons.timer,
        tooltip: 'Toggle timer layer',
        active: outputTimerActive,
        key: 'timer',
        hasContent: hasTimer,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF20232E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _clearAllOutputs,
              icon: const Icon(Icons.close, size: 16, color: Colors.white70),
              label: const Text(
                'Clear all',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                backgroundColor: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ...layerStates.map((layer) {
                  // Button is lit only if toggle is active AND slide has that content
                  final isLit = layer.active && layer.hasContent;
                  final canToggle = layer.hasContent;
                  return Tooltip(
                    message: layer.hasContent
                        ? layer.tooltip
                        : '${layer.tooltip} (no content)',
                    child: InkWell(
                      onTap: canToggle
                          ? () => _toggleOutputLayer(layer.key)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isLit
                              ? accentPink.withOpacity(0.16)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLit ? accentPink : Colors.white12,
                          ),
                        ),
                        child: Icon(
                          layer.icon,
                          size: 16,
                          color: isLit
                              ? accentPink
                              : (canToggle ? Colors.white70 : Colors.white30),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerTimeline() {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length) {
      return _frostedBox(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Layer Stack',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'No slide selected',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final slide = _slides[selectedSlideIndex];
    if (slide.layers.isEmpty && !_hydratedLayerSlides.contains(slide.id)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _hydrateLegacyLayers(selectedSlideIndex),
      );
    }
    final layers = slide.layers;

    return _frostedBox(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.layers, size: 16, color: Colors.white70),
                SizedBox(width: 8),
                Text(
                  'Layer Stack',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (layers.isEmpty)
              const Text(
                'No media layers yet.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: layers.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white10, height: 10),
                itemBuilder: (context, index) {
                  final layer = layers[index];
                  final typeLabel = _layerKindLabel(layer);
                  final selected = _selectedLayerId == layer.id;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedLayerId = layer.id;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? accentPink.withOpacity(0.5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      layer.role == _LayerRole.background
                                      ? accentBlue.withOpacity(0.2)
                                      : accentPink.withOpacity(0.2),
                                  child: Icon(
                                    _layerIcon(layer),
                                    size: 16,
                                    color: layer.role == _LayerRole.background
                                        ? accentBlue
                                        : accentPink,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        typeLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Move up',
                            icon: const Icon(
                              Icons.arrow_upward,
                              color: Colors.white54,
                              size: 18,
                            ),
                            onPressed: index > 0
                                ? () => _nudgeLayer(index, -1)
                                : null,
                          ),
                          IconButton(
                            tooltip: 'Move down',
                            icon: const Icon(
                              Icons.arrow_downward,
                              color: Colors.white54,
                              size: 18,
                            ),
                            onPressed: index < layers.length - 1
                                ? () => _nudgeLayer(index, 1)
                                : null,
                          ),
                          IconButton(
                            tooltip: 'Delete layer',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white70,
                              size: 18,
                            ),
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
    // Pause any currently playing video before switching
    if (isPlaying) _pauseCurrentSlideVideo();

    setState(() {
      selectedSlideIndex = (selectedSlideIndex + 1) % _slides.length;
      selectedSlides = {selectedSlideIndex};
      _ensureSelectedLayerValid(forcePickFirst: true);
      _isInlineTextEditing = false;
      _editingLayerId = null;
      _layerTextController.clear();
    });

    // Precache upcoming slide images for smoother transitions
    _precacheUpcomingSlideImages();

    // Start playback for new slide if slideshow is playing
    if (isPlaying) {
      _startCurrentSlidePlayback();
    }
    _sendCurrentSlideToOutputs();
  }

  void _prevSlide() {
    if (_slides.isEmpty) return;
    // Pause any currently playing video before switching
    if (isPlaying) _pauseCurrentSlideVideo();

    setState(() {
      selectedSlideIndex =
          (selectedSlideIndex - 1 + _slides.length) % _slides.length;
      selectedSlides = {selectedSlideIndex};
      _ensureSelectedLayerValid(forcePickFirst: true);
      _isInlineTextEditing = false;
      _editingLayerId = null;
      _layerTextController.clear();
    });

    // Precache upcoming slide images for smoother transitions
    _precacheUpcomingSlideImages();

    // Start playback for new slide if slideshow is playing
    if (isPlaying) {
      _startCurrentSlidePlayback();
    }
    _sendCurrentSlideToOutputs();
  }

  /// Precache images for the next 2-3 slides to prevent white/black flash on transition
  void _precacheUpcomingSlideImages() {
    if (!mounted || _slides.isEmpty) return;

    // Precache next 2-3 slides
    for (int offset = 1; offset <= 3; offset++) {
      final nextIndex = (selectedSlideIndex + offset) % _slides.length;
      if (nextIndex == selectedSlideIndex) continue;

      final slide = _slides[nextIndex];

      // Precache background layer image
      final bgLayer = _backgroundLayerFor(slide);
      if (bgLayer?.mediaType == _SlideMediaType.image &&
          bgLayer?.path?.isNotEmpty == true) {
        _precacheImagePath(bgLayer!.path!);
      }

      // Precache foreground layer images
      for (final layer in _foregroundLayers(slide)) {
        if (layer.mediaType == _SlideMediaType.image &&
            layer.path?.isNotEmpty == true) {
          _precacheImagePath(layer.path!);
        }
      }
    }
  }

  /// Precache a single image from file path
  void _precacheImagePath(String path) {
    if (!mounted) return;
    try {
      final file = File(path);
      if (file.existsSync()) {
        precacheImage(FileImage(file), context).catchError((_) {
          // Silently ignore precache errors
        });
      }
    } catch (_) {
      // Ignore errors during precaching
    }
  }

  void _togglePlayPause() {
    setState(() {
      isPlaying = !isPlaying;
    });
    if (isPlaying) {
      _startCurrentSlidePlayback();
    } else {
      _cancelAutoAdvanceTimer();
      _pauseCurrentSlideVideo();
    }
    // Update output windows with new isPlaying state
    _sendCurrentSlideToOutputs(createIfMissing: false);
  }

  /// Get all video paths from the current slide (background and foreground layers)
  List<String> _getCurrentSlideVideoPaths() {
    if (_slides.isEmpty) return [];
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    final paths = <String>[];
    // Check background layer
    final bgLayer = _backgroundLayerFor(slide);
    if (bgLayer?.mediaType == _SlideMediaType.video &&
        bgLayer?.path?.isNotEmpty == true) {
      paths.add(bgLayer!.path!);
    }
    // Check foreground layers
    for (final layer in _foregroundLayers(slide)) {
      if (layer.mediaType == _SlideMediaType.video &&
          layer.path?.isNotEmpty == true) {
        paths.add(layer.path!);
      }
    }
    return paths;
  }

  /// Start playback for the current slide - starts video if present, else uses timer
  void _startCurrentSlidePlayback() {
    if (!isPlaying || _slides.isEmpty) return;

    final videoPaths = _getCurrentSlideVideoPaths();
    if (videoPaths.isNotEmpty) {
      // Current slide has video - start video and listen for completion
      _startVideoWithCompletionListener(videoPaths.first);
    } else if (autoAdvanceEnabled) {
      // No video - use timed auto-advance
      _restartAutoAdvanceTimer();
    }
  }

  /// Start a video and set up completion listener for slideshow advancement
  void _startVideoWithCompletionListener(String videoPath) async {
    _cancelAutoAdvanceTimer();
    final entry = _ensureVideoController(videoPath, autoPlay: false);
    final controller = entry.controller;

    // Wait for video to be initialized before playing
    await entry.initialize;

    if (!mounted || !isPlaying) return;

    // Set looping to false for slideshow mode
    controller.setLooping(false);

    // Listen for video completion
    void listener() {
      if (!mounted || !isPlaying) return;
      final value = controller.value;
      if (value.isInitialized &&
          value.position >=
              value.duration - const Duration(milliseconds: 200) &&
          value.duration > Duration.zero) {
        // Video finished - advance to next slide
        controller.removeListener(listener);
        if (autoAdvanceEnabled) {
          _nextSlide();
        }
      }
    }

    controller.removeListener(listener); // Remove any existing listener
    controller.addListener(listener);

    // Start playing
    if (!controller.value.isPlaying) {
      controller.seekTo(Duration.zero);
      controller.play();
    }
  }

  /// Pause video on current slide
  void _pauseCurrentSlideVideo() {
    final videoPaths = _getCurrentSlideVideoPaths();
    for (final path in videoPaths) {
      final entry = _videoControllers[path];
      if (entry != null && entry.controller.value.isPlaying) {
        entry.controller.pause();
      }
    }
  }

  void _restartAutoAdvanceTimer() {
    _cancelAutoAdvanceTimer();
    if (!isPlaying || !autoAdvanceEnabled || _slides.isEmpty) return;

    // If current slide has video, let video completion handler handle advancement
    final videoPaths = _getCurrentSlideVideoPaths();
    if (videoPaths.isNotEmpty) {
      // Video slides use completion listener, not timer
      return;
    }

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

    final activeSelection = selectedSlides.isNotEmpty
        ? selectedSlides
        : {index};
    final selectionList = activeSelection.toList()..sort();
    final selectionCount = selectionList.length;

    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          details.globalPosition.dx,
          details.globalPosition.dy,
          0,
          0,
        ),
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
          child: Text(
            selectionCount > 1
                ? 'Delete $selectionCount slides'
                : 'Delete slide',
          ),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
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
      final categories = List<String>.from(showCategories);
      categories.removeAt(index);
      showCategories = categories;
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

  Future<void> _showCategoryContextMenu(
    int index,
    TapDownDetails details,
  ) async {
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          details.globalPosition.dx,
          details.globalPosition.dy,
          0,
          0,
        ),
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
    if (selectedCategoryIndex != null &&
        selectedCategoryIndex! < showCategories.length) {
      final cat = showCategories[selectedCategoryIndex!];
      return shows.where((s) => s.category == cat).toList();
    }
    return shows;
  }

  String? _selectedCategoryName() {
    if (selectedCategoryIndex == null) return null;
    if (selectedCategoryIndex! >= 0 &&
        selectedCategoryIndex! < showCategories.length) {
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
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                ),
                onSubmitted: (_) {},
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    final name = result?.trim();
    if (name == null || name.isEmpty) return;
    final cat = categoryController.text.trim().isEmpty
        ? null
        : categoryController.text.trim();
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
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

  Future<void> _promptAddFolder() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgMedium,
          title: const Text('New folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Folder name'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    final name = result?.trim();
    if (name == null || name.isEmpty) return;
    setState(() {
      folders = [...folders, name];
    });
  }

  Future<void> _promptAddProject() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgMedium,
          title: const Text('New project'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Project name'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    final name = result?.trim();
    if (name == null || name.isEmpty) return;
    setState(() {
      projects = [...projects, name];
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
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

  Future<void> _promptAddProfile() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgMedium,
        title: const Text('New profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Profile name'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    final name = result?.trim();
    if (name == null || name.isEmpty) return;
    setState(() => profiles = {...profiles, name}.toList());
    _saveProfiles();
  }

  Future<void> _promptAddNdiSource() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgMedium,
        title: const Text('Add NDI® Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Source name',
                hintText: 'e.g., OBS NDI Output',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'NDI URL / IP Address',
                hintText: 'e.g., 192.168.1.100 or ndi://...',
              ),
              onSubmitted: (_) => Navigator.of(context).pop({
                'name': nameController.text.trim(),
                'url': urlController.text.trim(),
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop({
              'name': nameController.text.trim(),
              'url': urlController.text.trim(),
            }),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final name = result['name'] ?? '';
    final url = result['url'] ?? '';
    if (name.isEmpty || url.isEmpty) return;

    setState(() {
      _ndiSources.add(_NdiSource(
        id: 'ndi_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        url: url,
      ));
    });
  }

  void _deleteSlides(Set<int> indices) {
    if (indices.isEmpty) return;
    final sorted = indices.where((i) => i >= 0 && i < _slides.length).toList()
      ..sort();
    if (sorted.isEmpty) return;

    setState(() {
      final slides = List<_SlideContent>.from(_slides);
      final thumbs = List<String?>.from(_slideThumbnails);

      for (final idx in sorted.reversed) {
        slides.removeAt(idx);
        thumbs.removeAt(idx);
      }

      _slides = slides;
      _slideThumbnails = thumbs;

      selectedSlides = selectedSlides.where((i) => i < _slides.length).toSet();
      if (selectedSlides.isEmpty && _slides.isNotEmpty) {
        selectedSlides = {
          _safeIntClamp(selectedSlideIndex, 0, _slides.length - 1),
        };
      }
      if (_slides.isEmpty) {
        selectedSlideIndex = 0;
      } else {
        final next = selectedSlides.isNotEmpty
            ? (selectedSlides.toList()..sort()).first
            : 0;
        selectedSlideIndex = _safeIntClamp(next, 0, _slides.length - 1);
      }
    });
    _syncSlideEditors();
  }

  void _openSettingsPage() {
    _SettingsTab currentTab = _settingsTab;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              void changeTab(_SettingsTab tab) {
                setLocal(() => currentTab = tab);
                setState(() => _settingsTab = tab);
              }

              return Scaffold(
                backgroundColor: bgDark,
                appBar: AppBar(
                  backgroundColor: AppPalette.carbonBlack,
                  title: const Text('Settings'),
                  actions: [
                    Tooltip(
                      message: _outputWindowIds.isNotEmpty
                          ? 'Outputs live (double-click to stop)'
                          : 'Show Output',
                      child: InkWell(
                        onTap: _outputWindowIds.isEmpty
                            ? () {
                                debugPrint(
                                  'out: opening output windows (from settings)',
                                );
                                _togglePresent();
                              }
                            : null,
                        onDoubleTap: _outputWindowIds.isNotEmpty
                            ? () async {
                                debugPrint(
                                  'out: double-tap detected (settings), closing outputs',
                                );
                                await _disarmPresentation();
                                if (mounted) setState(() {});
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.slideshow_outlined,
                                color: _outputWindowIds.isNotEmpty
                                    ? Colors.redAccent
                                    : Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _outputWindowIds.isNotEmpty
                                    ? 'Outputs Live'
                                    : 'Show Output',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                body: _buildSettingsPageBody(currentTab, changeTab),
              );
            },
          );
        },
      ),
    );
  }

  void _showAboutSheet() {
    showAboutDialog(
      context: context,
      applicationName: 'AuraShow',
      applicationVersion: 'Preview build',
      applicationIcon: const Icon(Icons.slideshow_outlined),
      children: const [
        Text('AuraShow dashboard preview with custom palette and stage tools.'),
      ],
    );
  }

  Widget _buildSettingsPageBody([
    _SettingsTab? currentTab,
    ValueChanged<_SettingsTab>? onTabChange,
  ]) {
    final tab = currentTab ?? _settingsTab;
    final onChange = onTabChange ?? (t) => setState(() => _settingsTab = t);
    final detectedScreens = _connectedScreens.map((s) => s.name).join(', ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 220,
          color: AppPalette.carbonBlack,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              _settingsNavItem(
                tab,
                _SettingsTab.general,
                Icons.dashboard_customize,
                'General',
                onChange,
              ),
              _settingsNavItem(
                tab,
                _SettingsTab.outputs,
                Icons.slideshow_outlined,
                'Outputs',
                onChange,
              ),
              _settingsNavItem(
                tab,
                _SettingsTab.styles,
                Icons.palette_outlined,
                'Styles',
                onChange,
              ),
              _settingsNavItem(
                tab,
                _SettingsTab.connection,
                Icons.devices_other,
                'Connection',
                onChange,
              ),
              _settingsNavItem(
                tab,
                _SettingsTab.files,
                Icons.folder_open,
                'Files',
                onChange,
              ),
              _settingsNavItem(
                tab,
                _SettingsTab.profiles,
                Icons.admin_panel_settings_outlined,
                'Profiles',
                onChange,
              ),
              _settingsNavItem(
                tab,
                _SettingsTab.theme,
                Icons.color_lens_outlined,
                'Theme',
                onChange,
              ),
              _settingsNavItem(
                tab,
                _SettingsTab.other,
                Icons.more_horiz,
                'Other',
                onChange,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: _buildSettingsContent(tab, detectedScreens),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsContent(
    _SettingsTab currentTab,
    String detectedScreens,
  ) {
    switch (currentTab) {
      case _SettingsTab.general:
        return _settingsGeneralPanel();
      case _SettingsTab.outputs:
        return _settingsOutputsPanel(detectedScreens);
      case _SettingsTab.styles:
        return _settingsStylesPanel();
      case _SettingsTab.connection:
        return _settingsConnectionPanel();
      case _SettingsTab.files:
        return _settingsFilesPanel();
      case _SettingsTab.profiles:
        return _settingsProfilesPanel();
      case _SettingsTab.theme:
        return _settingsThemePanel();
      case _SettingsTab.other:
        return _settingsOtherPanel();
    }
  }

  Widget _settingsNavItem(
    _SettingsTab current,
    _SettingsTab tab,
    IconData icon,
    String label,
    ValueChanged<_SettingsTab> onTap,
  ) {
    final selected = current == tab;
    return ListTile(
      leading: Icon(icon, color: selected ? accentPink : Colors.white70),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      selectedTileColor: AppPalette.carbonBlack,
      onTap: () => onTap(tab),
    );
  }

  Widget _settingsSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _settingsGeneralPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsSection('General', [
          SwitchListTile(
            value: use24HourClock,
            onChanged: (v) =>
                _setBoolPref('use_24h_clock', v, (val) => use24HourClock = val),
            title: const Text('Use 24-hour clock'),
            subtitle: const Text('Display times using 24-hour format'),
            activeThumbColor: accentPink,
          ),
          SwitchListTile(
            value: disableLabels,
            onChanged: (v) =>
                _setBoolPref('disable_labels', v, (val) => disableLabels = val),
            title: const Text('Disable labels'),
            subtitle: const Text('Hide inline labels across the UI'),
            activeThumbColor: accentPink,
          ),
        ]),
        _settingsSection('Project', [
          SwitchListTile(
            value: showProjectsOnStartup,
            onChanged: (v) => _setBoolPref(
              'show_projects_on_startup',
              v,
              (val) => showProjectsOnStartup = val,
            ),
            title: const Text('Show the projects list on startup'),
            activeThumbColor: accentPink,
          ),
        ]),
        _settingsSection('Output', [
          SwitchListTile(
            value: autoLaunchOutput,
            onChanged: (v) => _setBoolPref(
              'auto_launch_output',
              v,
              (val) => autoLaunchOutput = val,
            ),
            title: const Text('Activate output screen on startup'),
            activeThumbColor: accentPink,
          ),
          SwitchListTile(
            value: hideCursorInOutput,
            onChanged: (v) => _setBoolPref(
              'hide_cursor_output',
              v,
              (val) => hideCursorInOutput = val,
            ),
            title: const Text('Hide cursor in output'),
            activeThumbColor: accentPink,
          ),
        ]),
        _settingsSection('Online', [
          _settingsTextField(
            label: 'YouTube API Key',
            value: youtubeApiKey ?? '',
            hint: 'AIza...',
            onSubmit: _saveYoutubeApiKey,
          ),
          _settingsTextField(
            label: 'Vimeo Access Token',
            value: vimeoAccessToken ?? '',
            hint: 'Paste token',
            onSubmit: _saveVimeoAccessToken,
          ),
        ]),
        _settingsSection('Slide', [
          SwitchListTile(
            value: autoAdvanceEnabled,
            onChanged: (v) => setState(() => autoAdvanceEnabled = v),
            title: const Text('Enable Auto-Advance'),
            subtitle: const Text('Automatically advance slides when playing'),
            activeThumbColor: accentPink,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-advance interval'),
            subtitle: Slider(
              value: autoAdvanceInterval.inSeconds.toDouble(),
              min: 3,
              max: 30,
              divisions: 27,
              label: '${autoAdvanceInterval.inSeconds}s',
              activeColor: accentPink,
              onChanged: (v) => setState(
                () => autoAdvanceInterval = Duration(seconds: v.round()),
              ),
            ),
            trailing: Text(
              '${autoAdvanceInterval.inSeconds}s',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _settingsOutputsPanel(String detectedScreens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsSection('Outputs', [
          if (_connectedScreens.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Detected displays: $detectedScreens',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'No displays detected. Using demo entries.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          SwitchListTile(
            value: enableNdiOutput,
            onChanged: (v) => _setBoolPref(
              'enable_ndi_output',
              v,
              (val) => enableNdiOutput = val,
            ),
            title: const Text('Enable NDI®'),
            subtitle: const Text('Send output as an NDI stream'),
            activeThumbColor: accentPink,
          ),
          const SizedBox(height: 4),
          _outputs.isEmpty
              ? const Text(
                  'No outputs configured',
                  style: TextStyle(color: Colors.white54),
                )
              : Column(children: _outputs.map(_buildOutputTile).toList()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _addOutput,
                icon: const Icon(Icons.add),
                label: const Text('Add Output'),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _sendCurrentSlideToOutputs(createIfMissing: true),
                icon: const Icon(Icons.cast),
                label: const Text('Send Current Slide'),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 16),
        _buildStagePreviewCard(),
      ],
    );
  }

  Widget _settingsStylesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsSection('Styles', [
          ..._styles.map((style) => _buildStyleTile(style)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _addStylePreset,
            icon: const Icon(Icons.add),
            label: const Text('New Style'),
          ),
          const SizedBox(height: 12),
          _settingsSection('Lower Third Options', [
            SwitchListTile(
              value: lowerThirdGradient,
              onChanged: (v) => _setBoolPref(
                'lower_third_gradient',
                v,
                (val) => lowerThirdGradient = val,
              ),
              title: const Text('Use background gradient'),
              subtitle: const Text(
                'Adds a soft gradient behind lower-third text',
              ),
              activeThumbColor: accentPink,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lower-third height'),
              subtitle: Slider(
                value: lowerThirdHeight,
                min: 0.15,
                max: 0.5,
                divisions: 7,
                label: '${(lowerThirdHeight * 100).round()}%',
                activeColor: accentPink,
                onChanged: (v) => _setDoublePref(
                  'lower_third_height',
                  v,
                  (val) => lowerThirdHeight = val,
                ),
              ),
              trailing: Text(
                '${(lowerThirdHeight * 100).round()}%',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Stage notes scale'),
              subtitle: Slider(
                value: stageNotesScale,
                min: 0.6,
                max: 1.2,
                divisions: 6,
                label: '${(stageNotesScale * 100).round()}%',
                activeColor: accentPink,
                onChanged: (v) => _setDoublePref(
                  'stage_notes_scale',
                  v,
                  (val) => stageNotesScale = val,
                ),
              ),
              trailing: Text(
                '${(stageNotesScale * 100).round()}%',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ]),
        ]),
      ],
    );
  }

  Widget _buildStyleTile(_StylePreset style) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: style.name,
                  decoration: const InputDecoration(
                    labelText: 'Style name',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    style.name = v;
                    _saveStyles();
                    setState(() {});
                  },
                ),
              ),
              IconButton(
                tooltip: 'Delete style',
                onPressed: () {
                  setState(() => _styles.removeWhere((s) => s.id == style.id));
                  _saveStyles();
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: style.mediaFit,
                  decoration: const InputDecoration(labelText: 'Media fit'),
                  dropdownColor: AppPalette.carbonBlack,
                  items: const [
                    DropdownMenuItem(value: 'Contain', child: Text('Contain')),
                    DropdownMenuItem(value: 'Cover', child: Text('Cover')),
                    DropdownMenuItem(value: 'Fill', child: Text('Fill')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      style.mediaFit = v;
                      _saveStyles();
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: style.aspectRatio,
                  decoration: const InputDecoration(labelText: 'Aspect ratio'),
                  dropdownColor: AppPalette.carbonBlack,
                  items: const [
                    DropdownMenuItem(value: '16:9', child: Text('16:9')),
                    DropdownMenuItem(value: '4:3', child: Text('4:3')),
                    DropdownMenuItem(value: '21:9', child: Text('21:9')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      style.aspectRatio = v;
                      _saveStyles();
                      setState(() {});
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              FilterChip(
                label: const Text('Background'),
                selected: style.activeBackground,
                selectedColor: accentPink.withOpacity(0.25),
                onSelected: (v) {
                  style.activeBackground = v;
                  _saveStyles();
                  setState(() {});
                },
              ),
              FilterChip(
                label: const Text('Slide'),
                selected: style.activeSlide,
                selectedColor: accentPink.withOpacity(0.25),
                onSelected: (v) {
                  style.activeSlide = v;
                  _saveStyles();
                  setState(() {});
                },
              ),
              FilterChip(
                label: const Text('Overlays'),
                selected: style.activeOverlays,
                selectedColor: accentPink.withOpacity(0.25),
                onSelected: (v) {
                  style.activeOverlays = v;
                  _saveStyles();
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addStylePreset() {
    setState(() {
      _styles.add(
        _StylePreset(
          id: 'style-${DateTime.now().microsecondsSinceEpoch}',
          name: 'New Style',
          mediaFit: 'Contain',
          aspectRatio: '16:9',
          activeBackground: true,
          activeSlide: true,
          activeOverlays: true,
        ),
      );
    });
    _saveStyles();
  }

  Widget _settingsConnectionPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsSection('Connection', [
          SwitchListTile(
            value: enableRemoteShow,
            onChanged: (v) => _setBoolPref(
              'enable_remote_show',
              v,
              (val) => enableRemoteShow = val,
            ),
            title: const Text('RemoteShow'),
            subtitle: const Text('Allow remote devices to follow the show'),
            activeThumbColor: accentPink,
          ),
          SwitchListTile(
            value: enableStageShow,
            onChanged: (v) => _setBoolPref(
              'enable_stage_show',
              v,
              (val) => enableStageShow = val,
            ),
            title: const Text('StageShow'),
            subtitle: const Text('Enable stage view connections'),
            activeThumbColor: accentPink,
          ),
          SwitchListTile(
            value: enableControlShow,
            onChanged: (v) => _setBoolPref(
              'enable_control_show',
              v,
              (val) => enableControlShow = val,
            ),
            title: const Text('ControlShow'),
            subtitle: const Text('Allow remote control endpoints'),
            activeThumbColor: accentPink,
          ),
          SwitchListTile(
            value: enableApiAccess,
            onChanged: (v) => _setBoolPref(
              'enable_api_access',
              v,
              (val) => enableApiAccess = val,
            ),
            title: const Text('API Access'),
            subtitle: const Text('Enable API endpoints (WebSocket/REST)'),
            activeThumbColor: accentPink,
          ),
        ]),
      ],
    );
  }

  Widget _settingsFilesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsSection('Libraries', [
          _settingsFolderTile('Video Folder', videoFolder, 'video_folder'),
          _settingsFolderTile('Song Folder', songFolder, 'song_folder'),
          _settingsFolderTile('Lyrics Folder', lyricsFolder, 'lyrics_folder'),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _scanLibraries,
            icon: const Icon(Icons.sync),
            label: const Text('Rescan Libraries'),
          ),
        ]),
        _settingsSection('Saves', [
          _settingsFolderTile('Save Folder', saveFolder, 'save_folder'),
          const SizedBox(height: 6),
          const Text(
            'Save and Export will write state files to this folder.',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ]),
        _settingsSection('Cloud', [
          _settingsTextField(
            label: 'Google API service account key',
            value: '',
            hint: 'Path or JSON key',
            onSubmit: (_) => _showSnack('Cloud sync not wired yet'),
          ),
          SwitchListTile(
            value: false,
            onChanged: (_) => _showSnack('Cloud sync not wired yet'),
            title: const Text('Disable uploading data'),
            activeThumbColor: accentPink,
          ),
        ]),
      ],
    );
  }

  Widget _settingsProfilesPanel() {
    return _settingsSection('Profiles', [
      ...profiles.map(
        (p) => ListTile(
          title: Text(p),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() => profiles.remove(p));
              _saveProfiles();
            },
          ),
        ),
      ),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: _promptAddProfile,
        icon: const Icon(Icons.add),
        label: const Text('New Profile'),
      ),
    ]);
  }

  Widget _settingsThemePanel() {
    final themes = <String, Map<String, Color>>{
      'Default': {
        'accentPink': AppPalette.dustyMauve,
        'accentBlue': AppPalette.dustyRose,
        'bgDark': AppPalette.carbonBlack,
        'bgMedium': AppPalette.carbonBlack,
      },
      'Aqua': {
        'accentPink': AppPalette.dustyRose,
        'accentBlue': AppPalette.dustyRose,
        'bgDark': AppPalette.carbonBlack,
        'bgMedium': AppPalette.carbonBlack,
      },
      'Papyrus': {
        'accentPink': AppPalette.dustyRose,
        'accentBlue': AppPalette.dustyRose,
        'bgDark': AppPalette.carbonBlack,
        'bgMedium': AppPalette.carbonBlack,
      },
      'Light': {
        'accentPink': AppPalette.dustyMauve,
        'accentBlue': AppPalette.dustyRose,
        'bgDark': AppPalette.carbonBlack,
        'bgMedium': AppPalette.carbonBlack,
      },
    };

    return _settingsSection('Theme', [
      DropdownButtonFormField<String>(
        initialValue: selectedThemeName,
        dropdownColor: AppPalette.carbonBlack,
        decoration: const InputDecoration(labelText: 'Theme preset'),
        items: themes.keys
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            final preset = themes[v]!;
            setState(() {
              selectedThemeName = v;
              accentPink = preset['accentPink']!;
              accentBlue = preset['accentBlue']!;
              bgDark = preset['bgDark']!;
              bgMedium = preset['bgMedium']!;
            });
            _setStringPref('theme_name', v, (val) => selectedThemeName = val);
          }
        },
      ),
      const SizedBox(height: 8),
      Text(
        'Active theme: $selectedThemeName',
        style: const TextStyle(color: Colors.white70),
      ),
    ]);
  }

  void _applyThemePreset(String name, {bool persist = true}) {
    final themes = <String, Map<String, Color>>{
      'Default': {
        'accentPink': AppPalette.dustyMauve, // rust
        'accentBlue': AppPalette.willowGreen, // slate
        'bgDark': AppPalette.carbonBlack,
        'bgMedium': AppPalette.carbonBlack,
      },
    };

    if (!themes.containsKey(name)) return;
    final preset = themes[name]!;
    setState(() {
      selectedThemeName = name;
      accentPink = preset['accentPink']!;
      accentBlue = preset['accentBlue']!;
      bgDark = preset['bgDark']!;
      bgMedium = preset['bgMedium']!;
    });
    if (persist) {
      _setStringPref('theme_name', name, (val) => selectedThemeName = val);
    }
  }

  Widget _settingsOtherPanel() {
    return _settingsSection('Other', [
      SwitchListTile(
        value: autoUpdates,
        onChanged: (v) =>
            _setBoolPref('auto_updates', v, (val) => autoUpdates = val),
        title: const Text('Auto updates'),
        activeThumbColor: accentPink,
      ),
      SwitchListTile(
        value: alertOnUpdate,
        onChanged: (v) =>
            _setBoolPref('alert_on_update', v, (val) => alertOnUpdate = val),
        title: const Text('Alert when a new update is available'),
        activeThumbColor: accentPink,
      ),
      SwitchListTile(
        value: alertOnBeta,
        onChanged: (v) =>
            _setBoolPref('alert_on_beta', v, (val) => alertOnBeta = val),
        title: const Text('Alert when a new beta version is available'),
        activeThumbColor: accentPink,
      ),
      SwitchListTile(
        value: enableCloseConfirm,
        onChanged: (v) => _setBoolPref(
          'enable_close_confirm',
          v,
          (val) => enableCloseConfirm = val,
        ),
        title: const Text('Enable close confirmation popup'),
        activeThumbColor: accentPink,
      ),
      SwitchListTile(
        value: logSongUsage,
        onChanged: (v) =>
            _setBoolPref('log_song_usage', v, (val) => logSongUsage = val),
        title: const Text('Log song usage to a file'),
        activeThumbColor: accentPink,
      ),
      SwitchListTile(
        value: autoErrorReporting,
        onChanged: (v) => _setBoolPref(
          'auto_error_reporting',
          v,
          (val) => autoErrorReporting = val,
        ),
        title: const Text('Auto error reporting'),
        activeThumbColor: accentPink,
      ),
      SwitchListTile(
        value: disableHardwareAcceleration,
        onChanged: (v) => _setBoolPref(
          'disable_hw_accel',
          v,
          (val) => disableHardwareAcceleration = val,
        ),
        title: const Text('Disable hardware acceleration'),
        activeThumbColor: accentPink,
      ),
    ]);
  }

  Widget _settingsTextField({
    required String label,
    String? value,
    String? hint,
    required ValueChanged<String> onSubmit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value ?? '',
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFF1A2336),
          border: const OutlineInputBorder(),
        ),
        onFieldSubmitted: onSubmit,
      ),
    );
  }

  Widget _settingsFolderTile(String label, String? path, String key) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        path ?? 'Not Set',
        style: const TextStyle(fontSize: 10, color: Colors.grey),
        maxLines: 1,
      ),
      trailing: const Icon(Icons.folder_open, size: 18),
      onTap: () => _pickLibraryFolder(key),
    );
  }

  Widget _buildOutputTile(OutputConfig output) {
    final screens = _connectedScreens;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2336),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: output.name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      isDense: true,
                    ),
                    onChanged: (v) => _updateOutput(output.copyWith(name: v)),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<_OutputDestination>(
                  value: output.destination,
                  dropdownColor: const Color(0xFF1A2336),
                  items: _OutputDestination.values
                      .map(
                        (d) => DropdownMenuItem(value: d, child: Text(d.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null)
                      _updateOutput(output.copyWith(destination: v));
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<_OutputStyleProfile>(
                    isExpanded: true,
                    value: output.styleProfile,
                    dropdownColor: const Color(0xFF1A2336),
                    items: const [
                      DropdownMenuItem(
                        value: _OutputStyleProfile.audienceFull,
                        child: Text('Audience / Full'),
                      ),
                      DropdownMenuItem(
                        value: _OutputStyleProfile.streamLowerThird,
                        child: Text('Stream / Lower Third'),
                      ),
                      DropdownMenuItem(
                        value: _OutputStyleProfile.stageNotes,
                        child: Text('Stage / Notes'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null)
                        _updateOutput(output.copyWith(styleProfile: v));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: output.stageNotes,
                  onChanged: (v) =>
                      _updateOutput(output.copyWith(stageNotes: v)),
                  activeThumbColor: accentPink,
                ),
                const SizedBox(width: 4),
                const Text('Stage notes', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Text scale',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      Slider(
                        value: output.textScale.clamp(0.5, 2.0),
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        label: output.textScale.toStringAsFixed(2),
                        activeColor: accentPink,
                        onChanged: (v) => _updateOutput(
                          output.copyWith(
                            textScale: double.parse(v.toStringAsFixed(2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: output.maxLines.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Max lines',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) {
                        _updateOutput(
                          output.copyWith(maxLines: parsed.clamp(1, 24)),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: screens.any((s) => s.id == output.targetScreenId)
                        ? output.targetScreenId
                        : null,
                    hint: const Text('Select screen'),
                    dropdownColor: const Color(0xFF1A2336),
                    items: screens
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.name} (${s.detail})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        _updateOutput(output.copyWith(targetScreenId: v)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: output.width?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Width',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _updateOutput(output.copyWith(width: int.tryParse(v))),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: output.height?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Height',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _updateOutput(output.copyWith(height: int.tryParse(v))),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Show window',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    Switch(
                      value: output.visible,
                      onChanged: (v) =>
                          _updateOutput(output.copyWith(visible: v)),
                      activeThumbColor: accentPink,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      t,
      style: TextStyle(
        color: accentBlue,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
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
        await _promptAddFolder();
        break;
      case 'project':
        await _promptAddProject();
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _selectableRow({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
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
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : Colors.white70,
            ),
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

  // ignore: unused_element
  Widget _toolbarButton(String label, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: accentBlue),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  _SlideTemplate _templateFor(String id) {
    return _templates.firstWhere(
      (t) => t.id == id,
      orElse: () => _templates.first,
    );
  }

  // moved to view_widgets.dart

  _VideoControllerEntry _ensureVideoController(
    String path, {
    bool autoPlay = false,
  }) {
    return _videoControllers.putIfAbsent(path, () {
      debugPrint('dashboard: creating VideoPlayerController for path=$path');
      final controller = VideoPlayerController.file(File(path));
      final initialize = controller
          .initialize()
          .then((_) {
            debugPrint(
              'dashboard: video initialized path=$path size=${controller.value.size} hasError=${controller.value.hasError}',
            );
            controller.setLooping(true);
            if (autoPlay && !controller.value.isPlaying) {
              controller.play();
            }
          })
          .catchError((e, st) {
            debugPrint('dashboard: video init error path=$path error=$e');
            debugPrint('$st');
          });
      return _VideoControllerEntry(
        controller: controller,
        initialize: initialize,
      );
    });
  }

  double? _videoAspectRatio(String? path) {
    if (path == null) return null;
    final entry = _videoControllers[path];
    if (entry == null) return null;
    final size = entry.controller.value.size;
    if (size.isEmpty || size.width == 0 || size.height == 0) return null;
    return size.width / size.height;
  }

  void _pruneVideoControllers() {
    final active = <String>{};
    for (final slide in _slides) {
      if (slide.mediaType == _SlideMediaType.video &&
          slide.mediaPath?.isNotEmpty == true) {
        active.add(slide.mediaPath!);
      }
      for (final layer in slide.layers) {
        if (layer.mediaType == _SlideMediaType.video &&
            layer.path?.isNotEmpty == true) {
          active.add(layer.path!);
        }
      }
    }
    final stale = _videoControllers.keys
        .where((p) => !active.contains(p))
        .toList();
    for (final path in stale) {
      final entry = _videoControllers.remove(path);
      entry?.controller.dispose();
    }
  }

  Widget _videoControls(
    VideoPlayerController controller, {
    bool compact = false,
  }) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: compact ? 12 : 14,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Positioned(
      left: compact ? 8 : 12,
      right: compact ? 8 : 12,
      bottom: compact ? 8 : 12,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
        ),
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final duration = value.duration;
            final position = value.position;
            final ready = duration.inMilliseconds > 0;
            final progress = ready && duration.inMilliseconds > 0
                ? (position.inMilliseconds / duration.inMilliseconds).clamp(
                    0.0,
                    1.0,
                  )
                : 0.0;
            return Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minHeight: compact ? 40 : 46,
                    minWidth: compact ? 40 : 46,
                  ),
                  onPressed: () {
                    value.isPlaying ? controller.pause() : controller.play();
                  },
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.white,
                    size: compact ? 26 : 30,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: compact ? 4 : 5,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: compact ? 6 : 7,
                      ),
                      overlayShape: RoundSliderOverlayShape(
                        overlayRadius: compact ? 10 : 12,
                      ),
                    ),
                    child: Slider(
                      value: progress,
                      min: 0,
                      max: 1,
                      onChanged: ready
                          ? (v) {
                              final target = Duration(
                                milliseconds: (duration.inMilliseconds * v)
                                    .toInt(),
                              );
                              controller.seekTo(target);
                            }
                          : null,
                      activeColor: accentPink,
                      inactiveColor: Colors.white30,
                      thumbColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: compact ? 10 : 14),
                SizedBox(
                  width: compact ? 88 : 110,
                  child: Text(
                    '${_formatDuration(position)}/${_formatDuration(duration)}',
                    style: textStyle,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlideBackground(
    _SlideContent slide,
    _SlideTemplate template, {
    bool compact = false,
    bool autoPlayVideo = false,
  }) {
    final fallbackBg = slide.backgroundColor ?? template.background;
    final overlayTopOpacity = compact ? 0.08 : 0.2;
    final overlayBottomOpacity = compact ? 0.04 : 0.12;
    final overlay = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(overlayTopOpacity),
            Colors.black.withOpacity(overlayBottomOpacity),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );

    final bgLayer = _backgroundLayerFor(slide);
    final mediaPath = bgLayer?.path ?? slide.mediaPath;
    final mediaType = bgLayer?.mediaType ?? slide.mediaType;
    final bgOpacity = (bgLayer?.opacity ?? 1.0).clamp(0.0, 1.0);

    if (mediaPath == null || mediaPath.isEmpty || mediaType == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  fallbackBg,
                  Color.lerp(fallbackBg, Colors.black, 0.12)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          overlay,
        ],
      );
    }

    if (kIsWeb) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: fallbackBg),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mediaType == _SlideMediaType.image
                      ? Icons.image_outlined
                      : Icons.video_library_outlined,
                  color: Colors.white70,
                  size: compact ? 28 : 40,
                ),
                const SizedBox(height: 6),
                Text(
                  'Media preview unsupported on web',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          overlay,
        ],
      );
    }

    final file = File(mediaPath);
    if (!file.existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  fallbackBg,
                  Color.lerp(fallbackBg, Colors.black, 0.35)!,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mediaType == _SlideMediaType.video
                      ? Icons.smart_display
                      : Icons.image_outlined,
                  color: Colors.white70,
                  size: compact ? 28 : 40,
                ),
                const SizedBox(height: 6),
                Text(
                  'Missing media',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          overlay,
        ],
      );
    }

    if (mediaType == _SlideMediaType.image) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: bgOpacity,
            child: Image.file(file, fit: BoxFit.cover),
          ),
          overlay,
        ],
      );
    }

    if (mediaType == _SlideMediaType.video) {
      final entry = _ensureVideoController(mediaPath, autoPlay: autoPlayVideo);
      // Use ValueListenableBuilder to properly react to video initialization state changes
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: entry.controller,
        builder: (context, value, child) {
          final initialized = value.isInitialized;
          if (!initialized) {
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
                      const SizedBox(height: 4),
                      const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _fileName(mediaPath),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                overlay,
              ],
            );
          }

          final controller = entry.controller;
          final size = value.size;
          // Use RepaintBoundary to cache video frame rendering
          return RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: bgOpacity,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
                overlay,
                if (!compact) _videoControls(controller, compact: compact),
              ],
            ),
          );
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
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
      ],
    );
  }

  Widget _buildLayerWidget(
    _SlideLayer layer, {
    bool compact = false,
    BoxFit fit = BoxFit.contain,
    bool showControls = true,
    bool autoPlayVideo = false,
  }) {
    final opacity = (layer.opacity ?? 1.0).clamp(0.0, 1.0);
    if (layer.kind == _LayerKind.media && layer.path != null) {
      final file = File(layer.path!);
      if (layer.mediaType == _SlideMediaType.video && file.existsSync()) {
        final entry = _ensureVideoController(
          layer.path!,
          autoPlay: autoPlayVideo,
        );
        // Use ValueListenableBuilder to properly react to video initialization state changes
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: entry.controller,
          builder: (context, value, child) {
            final initialized = value.isInitialized;
            if (!initialized) {
              return Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        layer.label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final controller = entry.controller;
            final size = value.size;
            // Use RepaintBoundary for GPU caching of video frames
            return RepaintBoundary(
              child: Opacity(
                opacity: opacity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: fit,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
                    if (showControls && !compact)
                      _videoControls(controller, compact: compact),
                  ],
                ),
              ),
            );
          },
        );
      }
      if (layer.mediaType == _SlideMediaType.image && file.existsSync()) {
        return Opacity(
          opacity: opacity,
          child: IgnorePointer(
            child: Image.file(
              file,
              fit: fit,
              opacity: AlwaysStoppedAnimation(compact ? 0.9 : 1.0),
            ),
          ),
        );
      }
    }

    if (layer.kind == _LayerKind.textbox) {
      final text = (layer.text ?? '').trim();
      final display = text.isEmpty ? 'Textbox' : text;
      return Opacity(
        opacity: opacity,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          color: Colors.black.withOpacity(0.04),
          child: Text(
            display,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12 : 18,
              height: 1.1,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            maxLines: compact ? 3 : 6,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // Camera layer - show live thumbnail if available
    if (layer.kind == _LayerKind.camera) {
      final cameraId = layer.path;
      final camera = _connectedCameras.firstWhere(
        (c) => c.id == cameraId,
        orElse: () => _LiveDevice(id: '', name: layer.label, detail: ''),
      );
      
      return Opacity(
        opacity: opacity,
        child: Container(
          color: Colors.black,
          child: camera.thumbnail != null && camera.thumbnail!.isNotEmpty
              ? Image.memory(
                  camera.thumbnail!,
                  fit: fit,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => _buildCameraPlaceholder(layer, compact),
                )
              : _buildCameraPlaceholder(layer, compact),
        ),
      );
    }

    // Screen layer - show live capture
    if (layer.kind == _LayerKind.screen) {
      final captureType = layer.text ?? 'display';
      final pathValue = layer.path ?? '';
      
      // Parse hwnd or displayIndex from path
      int? hwnd;
      int? displayIndex;
      
      if (pathValue.startsWith('hwnd:')) {
        hwnd = int.tryParse(pathValue.substring(5));
      } else if (pathValue.startsWith('display:')) {
        displayIndex = int.tryParse(pathValue.substring(8));
      }
      
      return Opacity(
        opacity: opacity,
        child: Container(
          color: Colors.black,
          child: _LiveScreenCapture(
            captureType: captureType,
            captureId: pathValue,
            hwnd: hwnd,
            displayIndex: displayIndex,
            fit: fit,
            placeholder: _buildScreenPlaceholder(layer, captureType, compact),
          ),
        ),
      );
    }

    final icon = _layerIcon(layer);
    final double iconSize = compact ? 22 : 32;
    final double gap = 4;
    return Opacity(
      opacity: opacity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: iconSize),
            SizedBox(height: gap),
            Text(
              layer.label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Rect _resolvedBoxRect(_SlideContent slide) {
    const defaultBox = Rect.fromLTWH(0.1, 0.18, 0.8, 0.64);
    final left = slide.boxLeft ?? defaultBox.left;
    final top = slide.boxTop ?? defaultBox.top;
    final width = slide.boxWidth ?? defaultBox.width;
    final height = slide.boxHeight ?? defaultBox.height;
    return _clampRectWithOverflow(Rect.fromLTWH(left, top, width, height));
  }

  Rect _resolvedLayerRect(_SlideLayer layer) {
    if (layer.role == _LayerRole.background) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    const Rect defaultRect = Rect.fromLTWH(0.15, 0.15, 0.6, 0.6);
    final left = layer.left ?? defaultRect.left;
    final top = layer.top ?? defaultRect.top;
    final width = layer.width ?? defaultRect.width;
    final height = layer.height ?? defaultRect.height;
    return _clampRectWithOverflow(Rect.fromLTWH(left, top, width, height));
  }

  /// Build camera placeholder widget
  Widget _buildCameraPlaceholder(_SlideLayer layer, bool compact) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentPink.withOpacity(0.15),
            accentPink.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam,
              size: compact ? 28 : 48,
              color: accentPink.withOpacity(0.6),
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              layer.label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: compact ? 10 : 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: compact ? 2 : 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 5 : 6,
                    height: compact ? 5 : 6,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: compact ? 3 : 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: compact ? 8 : 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build screen placeholder widget
  Widget _buildScreenPlaceholder(_SlideLayer layer, String captureType, bool compact) {
    final iconData = captureType == 'window' 
        ? Icons.web_asset 
        : captureType == 'desktop' 
            ? Icons.desktop_windows 
            : Icons.monitor;
    final typeLabel = captureType == 'window' 
        ? 'Window Capture' 
        : captureType == 'desktop' 
            ? 'Desktop Capture' 
            : 'Display Capture';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentBlue.withOpacity(0.15),
            accentBlue.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              size: compact ? 28 : 48,
              color: accentBlue.withOpacity(0.6),
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              layer.label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: compact ? 10 : 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              typeLabel,
              style: TextStyle(
                color: Colors.white38,
                fontSize: compact ? 8 : 11,
              ),
            ),
            SizedBox(height: compact ? 4 : 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentBlue.withOpacity(0.25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 5 : 6,
                    height: compact ? 5 : 6,
                    decoration: BoxDecoration(
                      color: accentBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: compact ? 3 : 4),
                  Text(
                    'CAPTURE',
                    style: TextStyle(
                      fontSize: compact ? 8 : 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero || d.inMilliseconds.isNegative) return '00:00';
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).clamp(0, 99);
    final seconds = (totalSeconds % 60).abs();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ignore: unused_element
  // moved to view_widgets.dart

  // ignore: unused_element
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _slideReorderDropZone({
    required int insertIndex,
    required double width,
  }) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        return data is int && data >= 0 && data < _slides.length;
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is int) {
          final target = _reorderTargetIndex(
            from: data,
            desiredInsertIndex: insertIndex,
          );
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
  bool shouldRepaint(covariant _GridNoisePainter oldDelegate) =>
      oldDelegate.color != color;
}

class OutputConfig {
  OutputConfig({
    required this.id,
    required this.name,
    required this.destination,
    required this.styleProfile,
    this.targetScreenId,
    this.width,
    this.height,
    this.stageNotes = false,
    this.textScale = 1.0,
    this.maxLines = 12,
    this.visible = true,
  });

  final String id;
  final String name;
  final _OutputDestination destination;
  final _OutputStyleProfile styleProfile;
  final String? targetScreenId;
  final int? width;
  final int? height;
  final bool stageNotes;
  final double textScale;
  final int maxLines;
  final bool visible;

  factory OutputConfig.defaultAudience() {
    return OutputConfig(
      id: 'output-default',
      name: 'Audience',
      destination: _OutputDestination.screen,
      styleProfile: _OutputStyleProfile.audienceFull,
      stageNotes: false,
      textScale: 1.0,
      maxLines: 12,
      visible: true,
    );
  }

  OutputConfig copyWith({
    String? id,
    String? name,
    _OutputDestination? destination,
    _OutputStyleProfile? styleProfile,
    String? targetScreenId,
    int? width,
    int? height,
    bool? stageNotes,
    double? textScale,
    int? maxLines,
    bool? visible,
  }) {
    return OutputConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      destination: destination ?? this.destination,
      styleProfile: styleProfile ?? this.styleProfile,
      targetScreenId: targetScreenId ?? this.targetScreenId,
      width: width ?? this.width,
      height: height ?? this.height,
      stageNotes: stageNotes ?? this.stageNotes,
      textScale: textScale ?? this.textScale,
      maxLines: maxLines ?? this.maxLines,
      visible: visible ?? this.visible,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'destination': destination.name,
    'styleProfile': styleProfile.name,
    'targetScreenId': targetScreenId,
    'width': width,
    'height': height,
    'stageNotes': stageNotes,
    'textScale': textScale,
    'maxLines': maxLines,
    'visible': visible,
  };

  factory OutputConfig.fromJson(Map<String, dynamic> json) {
    _OutputDestination parseDest(String? v) {
      return _OutputDestination.values.firstWhere(
        (e) => e.name == v,
        orElse: () => _OutputDestination.screen,
      );
    }

    _OutputStyleProfile parseStyle(String? v) {
      return _OutputStyleProfile.values.firstWhere(
        (e) => e.name == v,
        orElse: () => _OutputStyleProfile.audienceFull,
      );
    }

    return OutputConfig(
      id: json['id'] ?? 'output-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] ?? 'Output',
      destination: parseDest(json['destination'] as String?),
      styleProfile: parseStyle(json['styleProfile'] as String?),
      targetScreenId: json['targetScreenId'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      stageNotes: json['stageNotes'] as bool? ?? false,
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
      maxLines: (json['maxLines'] as num?)?.toInt() ?? 12,
      visible:
          json['visible'] as bool? ??
          parseDest(json['destination'] as String?) ==
              _OutputDestination.screen,
    );
  }
}

class _StylePreset {
  _StylePreset({
    required this.id,
    required this.name,
    required this.mediaFit,
    required this.aspectRatio,
    required this.activeBackground,
    required this.activeSlide,
    required this.activeOverlays,
  });

  final String id;
  String name;
  String mediaFit;
  String aspectRatio;
  bool activeBackground;
  bool activeSlide;
  bool activeOverlays;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mediaFit': mediaFit,
    'aspectRatio': aspectRatio,
    'activeBackground': activeBackground,
    'activeSlide': activeSlide,
    'activeOverlays': activeOverlays,
  };

  static _StylePreset fromJson(Map<String, dynamic> json) {
    return _StylePreset(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Style',
      mediaFit: json['mediaFit'] as String? ?? 'Contain',
      aspectRatio: json['aspectRatio'] as String? ?? '16:9',
      activeBackground: json['activeBackground'] as bool? ?? true,
      activeSlide: json['activeSlide'] as bool? ?? true,
      activeOverlays: json['activeOverlays'] as bool? ?? true,
    );
  }
}

class _OutputRuntimeState {
  _OutputRuntimeState({
    this.active = false,
    this.locked = false,
    this.ndi = false,
    this.disconnected = false,
    this.headless = false,
  });

  bool active;
  bool locked;
  bool ndi;
  bool disconnected;
  bool headless;
}

/// Camera picker dialog with live thumbnails
class _CameraPickerDialog extends StatefulWidget {
  const _CameraPickerDialog({
    required this.cameras,
    required this.bgColor,
    required this.accentColor,
  });

  final List<_LiveDevice> cameras;
  final Color bgColor;
  final Color accentColor;

  @override
  State<_CameraPickerDialog> createState() => _CameraPickerDialogState();
}

class _CameraPickerDialogState extends State<_CameraPickerDialog> {
  late List<_LiveDevice> _cameras;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _cameras = List.from(widget.cameras);
    
    // Refresh thumbnails periodically
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshThumbnails(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshThumbnails() async {
    // Request fresh thumbnails from device service
    try {
      await DeviceService.instance.refreshDevices();
      if (!mounted) return;
      
      // Update local camera list with new thumbnails
      final updatedCameras = DeviceService.instance.cameras;
      setState(() {
        for (int i = 0; i < _cameras.length; i++) {
          final match = updatedCameras.firstWhere(
            (c) => c.id == _cameras[i].id,
            orElse: () => updatedCameras.isNotEmpty 
                ? updatedCameras.first 
                : LiveDevice(
                    id: _cameras[i].id,
                    name: _cameras[i].name,
                    detail: _cameras[i].detail,
                    type: DeviceType.camera,
                  ),
          );
          _cameras[i] = _LiveDevice(
            id: match.id,
            name: match.name,
            detail: match.detail,
            thumbnail: match.thumbnail,
            isActive: match.isActive,
          );
        }
      });
    } catch (e) {
      // Silently handle errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.bgColor,
      title: const Text('Select Camera'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: _cameras.isEmpty
            ? const Center(
                child: Text(
                  'No cameras detected',
                  style: TextStyle(color: Colors.white54),
                ),
              )
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 16 / 10,
                ),
                itemCount: _cameras.length,
                itemBuilder: (context, index) {
                  final camera = _cameras[index];
                  return _CameraCard(
                    camera: camera,
                    accentColor: widget.accentColor,
                    onTap: () => Navigator.of(context).pop(camera),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Individual camera card with live thumbnail
class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.camera,
    required this.accentColor,
    required this.onTap,
  });

  final _LiveDevice camera;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
            color: Colors.white.withOpacity(0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                  child: _buildThumbnail(),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      camera.detail,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (camera.thumbnail != null && camera.thumbnail!.isNotEmpty) {
      return Image.memory(
        camera.thumbnail!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam,
              size: 32,
              color: accentColor.withOpacity(0.5),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen capture type
enum _ScreenCaptureType {
  display,  // Capture a specific monitor
  window,   // Capture a specific window
  desktop,  // Capture entire desktop (all monitors)
}

/// Screen selection model
class _ScreenSelection {
  _ScreenSelection({
    required this.id,
    required this.name,
    required this.type,
    this.detail,
    this.thumbnail,
    this.hwnd,
    this.displayIndex,
  });

  final String id;
  final String name;
  final _ScreenCaptureType type;
  final String? detail;
  final Uint8List? thumbnail;
  final int? hwnd;           // Window handle for window captures
  final int? displayIndex;   // Display index for display captures
}

/// Screen picker dialog with displays and windows
class _ScreenPickerDialog extends StatefulWidget {
  const _ScreenPickerDialog({
    required this.screens,
    required this.bgColor,
    required this.accentColor,
  });

  final List<_LiveDevice> screens;
  final Color bgColor;
  final Color accentColor;

  @override
  State<_ScreenPickerDialog> createState() => _ScreenPickerDialogState();
}

class _ScreenPickerDialogState extends State<_ScreenPickerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<_LiveDevice> _displays;
  List<_WindowInfo> _windows = [];
  bool _loadingWindows = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _displays = List.from(widget.screens);
    _loadWindows();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWindows() async {
    setState(() => _loadingWindows = true);
    
    final windows = <_WindowInfo>[];
    
    try {
      // Use Win32 native API to enumerate actual windows
      final win32Windows = Win32CaptureService.instance.getWindows();
      
      for (final win in win32Windows) {
        // Capture a thumbnail for each window
        final thumbnail = Win32CaptureService.instance.captureWindow(
          win.hwnd,
          thumbnailWidth: 240,
          thumbnailHeight: 135,
        );
        
        windows.add(_WindowInfo(
          id: 'window-${win.hwnd}',
          title: win.title,
          processName: win.processName,
          hwnd: win.hwnd,
          thumbnail: thumbnail,
        ));
      }
    } catch (e) {
      debugPrint('Error loading windows via Win32: $e');
    }
    
    if (mounted) {
      setState(() {
        _windows = windows;
        _loadingWindows = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.bgColor,
      title: const Text('Select Screen Source'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: widget.accentColor,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'Displays', icon: Icon(Icons.monitor, size: 18)),
                Tab(text: 'Windows', icon: Icon(Icons.web_asset, size: 18)),
                Tab(text: 'Desktop', icon: Icon(Icons.desktop_windows, size: 18)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDisplaysTab(),
                  _buildWindowsTab(),
                  _buildDesktopTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildDisplaysTab() {
    if (_displays.isEmpty) {
      return const Center(
        child: Text(
          'No displays detected',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 10,
      ),
      itemCount: _displays.length,
      itemBuilder: (context, index) {
        final display = _displays[index];
        return _ScreenCard(
          title: display.name,
          subtitle: display.detail,
          icon: Icons.monitor,
          accentColor: widget.accentColor,
          thumbnail: display.thumbnail,
          onTap: () => Navigator.of(context).pop(
            _ScreenSelection(
              id: display.id,
              name: display.name,
              type: _ScreenCaptureType.display,
              detail: display.detail,
              thumbnail: display.thumbnail,
              displayIndex: index,  // Pass the display index for capture
            ),
          ),
        );
      },
    );
  }

  Widget _buildWindowsTab() {
    if (_loadingWindows) {
      return const Center(child: CircularProgressIndicator());
    }

    final appWindows = _windows.where((w) => !w.isDesktop).toList();
    
    if (appWindows.isEmpty) {
      return const Center(
        child: Text(
          'No windows found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      itemCount: appWindows.length,
      itemBuilder: (context, index) {
        final window = appWindows[index];
        return _WindowTile(
          window: window,
          accentColor: widget.accentColor,
          onTap: () => Navigator.of(context).pop(
            _ScreenSelection(
              id: window.id,
              name: window.title,
              type: _ScreenCaptureType.window,
              detail: window.processName,
              hwnd: window.hwnd,
              thumbnail: window.thumbnail,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTab() {
    return Center(
      child: _ScreenCard(
        title: 'Entire Desktop',
        subtitle: 'Capture all monitors combined',
        icon: Icons.desktop_windows,
        accentColor: widget.accentColor,
        isLarge: true,
        onTap: () => Navigator.of(context).pop(
          _ScreenSelection(
            id: 'desktop-all',
            name: 'Entire Desktop',
            type: _ScreenCaptureType.desktop,
            detail: 'All monitors',
          ),
        ),
      ),
    );
  }
}

/// Window info model
class _WindowInfo {
  _WindowInfo({
    required this.id,
    required this.title,
    required this.processName,
    this.hwnd = 0,
    this.thumbnail,
    this.isDesktop = false,
  });

  final String id;
  final String title;
  final String processName;
  final int hwnd;
  final Uint8List? thumbnail;
  final bool isDesktop;
}

/// Screen/display card widget
class _ScreenCard extends StatelessWidget {
  const _ScreenCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.thumbnail,
    this.isLarge = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final Uint8List? thumbnail;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
            color: Colors.white.withOpacity(0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                  child: _buildPreview(),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isLarge) {
      return SizedBox(
        width: 280,
        height: 200,
        child: content,
      );
    }
    return content;
  }

  Widget _buildPreview() {
    if (thumbnail != null && thumbnail!.isNotEmpty) {
      return Image.memory(
        thumbnail!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isLarge ? 48 : 36,
              color: accentColor.withOpacity(0.5),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CAPTURE',
                style: TextStyle(
                  fontSize: isLarge ? 10 : 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Window list tile
class _WindowTile extends StatelessWidget {
  const _WindowTile({
    required this.window,
    required this.accentColor,
    required this.onTap,
  });

  final _WindowInfo window;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
              color: Colors.white.withOpacity(0.03),
            ),
            child: Row(
              children: [
                // Window thumbnail or icon
                Container(
                  width: 80,
                  height: 45,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: _buildThumbnail(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        window.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        window.processName,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white24,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (window.thumbnail != null && window.thumbnail!.isNotEmpty) {
      return Image.memory(
        window.thumbnail!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
      );
    }
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Icon(
        Icons.web_asset,
        color: accentColor,
        size: 22,
      ),
    );
  }
}

/// Live screen capture widget that refreshes periodically
/// Global screen capture manager that handles captures during idle time only.
/// This prevents UI blocking by only capturing when the app is idle.
class _ScreenCaptureManager implements TickerProvider {
  _ScreenCaptureManager._();
  static final instance = _ScreenCaptureManager._();
  
  final Map<String, Uint8List?> _frames = {};
  final Map<String, VoidCallback> _listeners = {};
  final Set<String> _activeCaptures = {};
  
  Ticker? _ticker;
  bool _isCapturing = false;
  bool _isPaused = false;
  DateTime _lastPointerEvent = DateTime.now();
  DateTime _lastCaptureTime = DateTime.now();
  int _currentCaptureIndex = 0;
  
  // Performance tracking
  int _targetFrameTimeMs = 16; // 60fps = ~16ms per frame
  int _frameTimeMs = 16;
  int _missedFrames = 0;
  
  /// Start the capture manager with 60fps target (30fps minimum)
  void start() {
    _ticker?.dispose();
    _ticker = createTicker(_onTick);
    _ticker!.start();
  }
  
  /// Stop the capture manager
  void stop() {
    _ticker?.dispose();
    _ticker = null;
  }
  
  /// Pause capturing (called during pointer events)
  void pauseCapture() {
    _isPaused = true;
    _lastPointerEvent = DateTime.now();
  }
  
  /// Tick callback for frame-based capture
  void _onTick(Duration elapsed) {
    final now = DateTime.now();
    
    // Wait at least 100ms after last pointer event before capturing
    final timeSincePointer = now.difference(_lastPointerEvent);
    if (timeSincePointer.inMilliseconds < 100) {
      _isPaused = true;
      return;
    }
    _isPaused = false;
    
    // Check if we should capture this frame
    final timeSinceCapture = now.difference(_lastCaptureTime);
    if (timeSinceCapture.inMilliseconds < _frameTimeMs) {
      return; // Not time for next frame yet
    }
    
    if (_isCapturing || _activeCaptures.isEmpty) return;
    
    // Capture next source in rotation
    _captureNext();
  }
  
  void _captureNext() {
    if (_activeCaptures.isEmpty || _isCapturing || _isPaused) return;
    
    // Round-robin through active captures
    final captureList = _activeCaptures.toList();
    if (captureList.isEmpty) return;
    
    _currentCaptureIndex = _currentCaptureIndex % captureList.length;
    final captureId = captureList[_currentCaptureIndex];
    _currentCaptureIndex = (_currentCaptureIndex + 1) % captureList.length;
    
    _isCapturing = true;
    final startTime = DateTime.now();
    
    try {
      _performCapture(captureId);
      
      // Measure capture time for adaptive frame rate
      final captureTime = DateTime.now().difference(startTime).inMilliseconds;
      
      // Adaptive frame rate: target 60fps, fall back to 30fps if we can't keep up
      if (captureTime > 25) {
        // Too slow for 60fps, use 30fps (33ms)
        _frameTimeMs = 33;
        _missedFrames++;
      } else if (_missedFrames == 0 && captureTime < 12) {
        // We're fast enough for 60fps
        _frameTimeMs = 16;
      }
      
      // Reset missed frames counter occasionally
      if (_missedFrames > 10) _missedFrames = 0;
      
      _lastCaptureTime = DateTime.now();
    } catch (e) {
      debugPrint('ScreenCaptureManager: Error in capture: $e');
    } finally {
      _isCapturing = false;
    }
  }
  
  void _performCapture(String captureId) {
    try {
      // Parse capture info from ID (format: "type:value")
      final parts = captureId.split(':');
      if (parts.length < 2) return;
      
      final captureType = parts[0];
      final captureValue = parts.sublist(1).join(':');
      
      Uint8List? bytes;
      
      // Use smaller thumbnails for faster capture (160x90)
      const thumbWidth = 160;
      const thumbHeight = 90;
      
      switch (captureType) {
        case 'window':
          final hwnd = int.tryParse(captureValue);
          if (hwnd != null && hwnd > 0) {
            bytes = Win32CaptureService.instance.captureWindow(
              hwnd,
              thumbnailWidth: thumbWidth,
              thumbnailHeight: thumbHeight,
            );
          }
          break;
        case 'display':
          final idx = int.tryParse(captureValue) ?? 0;
          bytes = Win32CaptureService.instance.captureDisplay(
            idx,
            thumbnailWidth: thumbWidth,
            thumbnailHeight: thumbHeight,
          );
          break;
        case 'desktop':
          bytes = Win32CaptureService.instance.captureScreen(
            thumbnailWidth: thumbWidth,
            thumbnailHeight: thumbHeight,
          );
          break;
      }
      
      if (bytes != null && bytes.isNotEmpty) {
        _frames[captureId] = bytes;
        _listeners[captureId]?.call();
      }
    } catch (e) {
      debugPrint('ScreenCaptureManager: Error capturing $captureId: $e');
    }
  }
  
  /// Register a capture source
  void register(String captureId, VoidCallback onUpdate) {
    _activeCaptures.add(captureId);
    _listeners[captureId] = onUpdate;
    
    // Initial capture
    if (!_frames.containsKey(captureId)) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_activeCaptures.contains(captureId)) {
          _performCapture(captureId);
        }
      });
    }
  }
  
  /// Unregister a capture source
  void unregister(String captureId) {
    _activeCaptures.remove(captureId);
    _listeners.remove(captureId);
  }
  
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
  
  /// Get the latest frame for a capture source
  Uint8List? getFrame(String captureId) => _frames[captureId];
}

/// Live screen capture widget that uses idle-time capturing to avoid UI blocking.
class _LiveScreenCapture extends StatefulWidget {
  const _LiveScreenCapture({
    required this.captureType,
    required this.captureId,
    this.hwnd,
    this.displayIndex,
    this.fit = BoxFit.contain,
    this.placeholder,
  });

  final String captureType; // 'display', 'window', 'desktop'
  final String captureId;
  final int? hwnd;
  final int? displayIndex;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  State<_LiveScreenCapture> createState() => _LiveScreenCaptureState();
}

class _LiveScreenCaptureState extends State<_LiveScreenCapture> {
  late String _registrationId;
  
  @override
  void initState() {
    super.initState();
    _registrationId = _buildRegistrationId();
    _ScreenCaptureManager.instance.start();
    _ScreenCaptureManager.instance.register(_registrationId, _onFrameUpdate);
  }

  @override
  void dispose() {
    _ScreenCaptureManager.instance.unregister(_registrationId);
    super.dispose();
  }

  @override
  void didUpdateWidget(_LiveScreenCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newId = _buildRegistrationId();
    if (newId != _registrationId) {
      _ScreenCaptureManager.instance.unregister(_registrationId);
      _registrationId = newId;
      _ScreenCaptureManager.instance.register(_registrationId, _onFrameUpdate);
    }
  }
  
  String _buildRegistrationId() {
    switch (widget.captureType) {
      case 'window':
        return 'window:${widget.hwnd ?? 0}';
      case 'display':
        return 'display:${widget.displayIndex ?? 0}';
      default:
        return 'desktop:0';
    }
  }
  
  void _onFrameUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final frame = _ScreenCaptureManager.instance.getFrame(_registrationId);
    
    if (frame == null || frame.isEmpty) {
      return widget.placeholder ?? Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_share, color: Colors.white38, size: 24),
              SizedBox(height: 8),
              Text(
                'Screen Capture',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    // Wrap in Listener to pause capture during interaction
    return Listener(
      onPointerDown: (_) => _ScreenCaptureManager.instance.pauseCapture(),
      onPointerMove: (_) => _ScreenCaptureManager.instance.pauseCapture(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            frame,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.black,
              child: const Center(
                child: Icon(Icons.error_outline, color: Colors.red),
              ),
            ),
          ),
          // Live badge indicator
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
