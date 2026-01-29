part of dashboard_screen;

/// Extension for settings, preferences, and dialog helpers
extension SettingsExtensions on DashboardScreenState {
  /// Open the Group Color customization dialog
  void _showGroupColorDialog() {
    showDialog(
      context: context,
      builder: (context) => const GroupColorDialog(),
    );
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
          backgroundColor: AppPalette.surface,
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success ? AppPalette.primary : AppPalette.accent,
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
    print('_setBoolPref: key=$key, value=$value, calling setState');
    setState(() => apply(value));
    // Also trigger settings dialog rebuild if open
    _settingsLocalSetState?.call(() {});
    print('_setBoolPref: setState completed');
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

  Future<void> _setIntPref(
    String key,
    int value,
    void Function(int) apply,
  ) async {
    print('_setIntPref: key=$key, value=$value, calling setState');
    setState(() => apply(value));
    // Also trigger settings dialog rebuild if open
    print(
      '_setIntPref: _settingsLocalSetState is ${_settingsLocalSetState == null ? "NULL" : "SET"}',
    );
    if (_settingsLocalSetState != null) {
      print('_setIntPref: calling _settingsLocalSetState');
      _settingsLocalSetState!(() {
        print(
          '_setIntPref: inside setLocal callback - this should trigger rebuild',
        );
      });
      print('_setIntPref: _settingsLocalSetState called');
    }
    print('_setIntPref: setState completed');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final envYoutubeKey = '';
    final envVimeoToken = '';
    final osYoutubeKey = Platform.environment['YOUTUBE_API_KEY'] ?? '';
    final osVimeoToken = Platform.environment['VIMEO_ACCESS_TOKEN'] ?? '';
    setState(() {
      videoFolder = prefs.getString('video_folder');
      songFolder = prefs.getString('song_folder');
      imageFolder = prefs.getString('image_folder');
      lyricsFolder = prefs.getString('lyrics_folder');
      saveFolder = prefs.getString('save_folder');
      final prefYoutubeKey = prefs.getString('youtube_api_key');
      final prefVimeoToken = prefs.getString('vimeo_access_token');
      youtubeApiKey = _firstNonEmpty([
        prefYoutubeKey ?? '',
        envYoutubeKey,
        osYoutubeKey,
      ]);
      vimeoAccessToken = _firstNonEmpty([
        prefVimeoToken ?? '',
        envVimeoToken,
        osVimeoToken,
      ]);
      savedYouTubeVideos = (prefs.getStringList('youtube_saved') ?? [])
          .map((e) => Map<String, String>.from(json.decode(e)))
          .toList();
      pixabayResults = (prefs.getStringList('pixabay_saved') ?? [])
          .map((e) => Map<String, String>.from(json.decode(e)))
          .toList();
      unsplashResults = (prefs.getStringList('unsplash_saved') ?? [])
          .map((e) => Map<String, String>.from(json.decode(e)))
          .toList();
      final savedStyles = prefs.getString('styles_json');
      if (savedStyles != null && savedStyles.isNotEmpty) {
        final list = json.decode(savedStyles) as List<dynamic>;
        _styles
          ..clear()
          ..addAll(
            list.map((e) => StylePreset.fromJson(Map<String, dynamic>.from(e))),
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
      // enableNdiOutput removed
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
      audioStopFadeDuration =
          prefs.getDouble('audio_stop_fade_duration') ?? audioStopFadeDuration;

      // Load GPU & Performance settings
      targetFrameRate = prefs.getInt('target_frame_rate') ?? targetFrameRate;
      enableShaderWarmup =
          prefs.getBool('enable_shader_warmup') ?? enableShaderWarmup;
      rasterCacheSize = prefs.getInt('raster_cache_size') ?? rasterCacheSize;
      enableRasterCache =
          prefs.getBool('enable_raster_cache') ?? enableRasterCache;
      textureCompressionEnabled =
          prefs.getBool('texture_compression') ?? textureCompressionEnabled;
      useSkia = prefs.getBool('use_skia_renderer') ?? useSkia;

      selectedThemeName = prefs.getString('theme_name') ?? selectedThemeName;
      final savedOutputs = prefs.getString('outputs_json');
      if (savedOutputs != null && savedOutputs.isNotEmpty) {
        try {
          final list = json.decode(savedOutputs) as List<dynamic>;
          _outputs = list
              .map((e) => OutputConfig.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } catch (e) {
          debugPrint('Error loading outputs: $e');
        }
      }

      // Aggressive cleanup: Ensure only Output 1 remains by default
      final int beforeCount = _outputs.length;
      _outputs.removeWhere((o) {
        final name = o.name.trim();
        return ['Output 2', 'Output 3', 'Output 4'].contains(name);
      });

      if (_outputs.length != beforeCount) {
        _saveOutputs();
      }

      if (_outputs.isEmpty) {
        _outputs = [OutputConfig.defaultAudience()];
      }
      _ensureOutputPreviewVisibilityDefaults();
    });
    _applyThemePreset(selectedThemeName, persist: false);
    await _scanLibraries();
  }

  void _ensureOutputPreviewVisibilityDefaults() {
    for (final output in _outputs) {
      _outputPreviewVisible.putIfAbsent(output.id, () => true);
    }
    final existingIds = _outputs.map((o) => o.id).toSet();
    _outputPreviewVisible.removeWhere((key, _) => !existingIds.contains(key));
  }

  // Deprecated helper to find first non-empty string
  String? _firstNonEmpty(List<String> values) {
    for (final v in values) {
      if (v.isNotEmpty) return v;
    }
    return null;
  }
}
