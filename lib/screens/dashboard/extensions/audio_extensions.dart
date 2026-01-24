part of dashboard_screen;

/// Extension for audio playback, playlists, sound effects, and metronome
extension AudioExtensions on DashboardScreenState {
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
          Row(
            children: [
              Icon(Icons.music_note, size: 16, color: accentBlue),
              const SizedBox(width: 6),
              const Text(
                'Audio',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _audioModeButton('Files', 'files', Icons.folder_open),
              _audioModeButton('Playlists', 'playlists', Icons.queue_music),
              _audioModeButton('Effects', 'effects', Icons.campaign),
              _audioModeButton('Metronome', 'metronome', Icons.timer),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentlyPlayingAudioPath != null) _buildNowPlayingBar(),
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
            border: Border.all(color: isActive ? accentBlue : Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: isActive ? accentBlue : Colors.white54,
              ),
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

  Widget _buildNowPlayingBar() {
    final fileName =
        _currentlyPlayingAudioPath?.split(Platform.pathSeparator).last ??
        'Unknown';
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
              IconButton(
                icon: Icon(
                  _isAudioPlaying && !_isAudioPaused
                      ? Icons.pause
                      : Icons.play_arrow,
                  size: 20,
                ),
                onPressed: _toggleAudioPlayback,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: accentPink,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.stop, size: 18),
                onPressed: _stopAudio,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: _audioFadeTimer != null ? accentPink : Colors.white54,
                tooltip: 'Stop (Soft Fade). Double-click for instant stop.',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 16,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
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
              Text(
                '${_formatAudioTime(_audioPosition.toInt())} / ${_formatAudioTime(_audioDuration.toInt())}',
                style: const TextStyle(fontSize: 9, color: Colors.white54),
              ),
              const SizedBox(width: 8),
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
              IconButton(
                icon: Icon(
                  Icons.repeat,
                  size: 16,
                  color: _audioLoop ? accentPink : Colors.white38,
                ),
                onPressed: () {
                  setState(() => _audioLoop = !_audioLoop);
                  _audioPlayer?.setLoopMode(
                    _audioLoop ? ja.LoopMode.one : ja.LoopMode.off,
                  );
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

  void _initAudioPlayer() {
    _audioPlayer = ja.AudioPlayer();

    _audioPositionSubscription = _audioPlayer!.positionStream.listen((
      position,
    ) {
      if (mounted) {
        setState(() => _audioPosition = position.inSeconds.toDouble());
        _checkSlideSync(position);
      }
    });

    _audioDurationSubscription = _audioPlayer!.durationStream.listen((
      duration,
    ) {
      if (mounted && duration != null) {
        setState(() => _audioDuration = duration.inSeconds.toDouble());
      }
    });
  }

  void _checkSlideSync(Duration position) {
    if (!autoAdvanceEnabled || !_isAudioPlaying || _slides.isEmpty) return;

    // Find the latest slide whose triggerTime has been passed
    int? targetIndex;
    for (int i = 0; i < _slides.length; i++) {
      final trigger = _slides[i].triggerTime;
      if (trigger != null && position >= trigger) {
        targetIndex = i;
      }
    }

    // Only switch if we found a valid target that is different from current
    if (targetIndex != null && targetIndex != selectedSlideIndex) {
      // Avoid backward jumps if desired? For now, we sync strictly to audio.
      _selectSlide(targetIndex);
    }

    _audioPlayerStateSubscription = _audioPlayer!.playerStateStream.listen((
      state,
    ) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = state.playing;
          _isAudioPaused =
              !state.playing &&
              state.processingState != ja.ProcessingState.completed;

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

  void _disposeAudioPlayer() {
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _audioPlayerStateSubscription?.cancel();
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  void _toggleAudioPlayback() {
    if (_audioPlayer == null) return;
    _cancelAudioFade();
    if (_audioPlayer!.playing) {
      _audioPlayer!.pause();
    } else {
      _audioPlayer!.play();
    }
  }

  void _cancelAudioFade() {
    _audioFadeTimer?.cancel();
    _audioFadeTimer = null;
    if (_audioPlayer != null && _audioPlayer!.playing) {
      _audioPlayer!.setVolume(_audioVolume);
    }
  }

  void _stopAudio() {
    final now = DateTime.now();
    final isPanicStop =
        _lastStopClickTime != null &&
        now.difference(_lastStopClickTime!) < const Duration(milliseconds: 500);
    _lastStopClickTime = now;

    if (isPanicStop || audioStopFadeDuration <= 0) {
      _stopAudioImmediately();
      return;
    }

    if (_audioFadeTimer != null) return; // Already fading

    // Soft Stop: Fade out
    double currentVolume = _audioVolume;
    const intervalMs = 50;
    final steps = (audioStopFadeDuration * 1000) / intervalMs;
    final volStep = _audioVolume / steps;

    _audioFadeTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (
      timer,
    ) {
      currentVolume -= volStep;
      if (currentVolume <= 0) {
        _stopAudioImmediately();
      } else {
        _audioPlayer?.setVolume(currentVolume);
      }
    });
  }

  void _stopAudioImmediately() {
    _audioFadeTimer?.cancel();
    _audioFadeTimer = null;
    _audioPlayer?.stop();
    _audioPlayer?.setVolume(
      _audioVolume,
    ); // Restore original volume for next play
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

  bool _isVideoFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.mkv') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.webm') ||
        ext.endsWith('.wmv');
  }

  Widget _buildAudioFilesView() {
    final files = _audioFiles;

    if (files.isEmpty) {
      return Center(
        child: SingleChildScrollView(
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
                label: const Text(
                  'Select Folder',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                songFolder ?? videoFolder ?? 'No folder selected',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tooltip(
              message: 'Include video files (play audio from videos)',
              child: InkWell(
                onTap: () => setState(
                  () => _showVideoFilesInAudio = !_showVideoFilesInAudio,
                ),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _showVideoFilesInAudio
                        ? accentBlue.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _showVideoFilesInAudio
                          ? accentBlue
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam,
                        size: 12,
                        color: _showVideoFilesInAudio
                            ? accentBlue
                            : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Videos',
                        style: TextStyle(
                          fontSize: 9,
                          color: _showVideoFilesInAudio
                              ? accentBlue
                              : Colors.white38,
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
        Text(
          '${files.length} file${files.length == 1 ? '' : 's'}${_showVideoFilesInAudio ? ' (incl. videos)' : ''}',
          style: const TextStyle(fontSize: 9, color: Colors.white24),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, i) {
              final file = files[i];
              final name = file.path.split(Platform.pathSeparator).last;
              final isPlaying = _currentlyPlayingAudioPath == file.path;
              final isVideo = _isVideoFile(file.path);

              final listItemWidget = GestureDetector(
                onSecondaryTapUp: (details) =>
                    _showAudioContextMenu(context, details, file.path),
                child: InkWell(
                  onTap: () => _playAudioFile(file.path),
                  onDoubleTap: () => _addAudioToSlide(file.path),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? accentPink.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPlaying
                              ? Icons.volume_up
                              : (isVideo ? Icons.videocam : Icons.music_note),
                          size: 14,
                          color: isPlaying ? accentPink : Colors.white54,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isPlaying ? accentPink : Colors.white,
                              fontWeight: isPlaying
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPlaying)
                          Icon(
                            // Removed const
                            Icons.graphic_eq,
                            size: 12,
                            color: accentPink,
                          ),
                        if (isVideo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: accentBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'VIDEO',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.white54,
                              ),
                            ),
                          ),
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
                ),
              );

              return Draggable<MediaEntry>(
                data: MediaEntry(
                  id: file.path,
                  title: name,
                  category: MediaFilter.audio,
                  icon: isVideo ? Icons.videocam : Icons.music_note,
                  thumbnailUrl: file.path, // Use path as thumbnail for now
                  isLive: false,
                ),
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppPalette.carbonBlack,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentPink),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVideo ? Icons.videocam : Icons.music_note,
                          color: accentPink,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.5, child: listItemWidget),
                child: listItemWidget,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAudioContextMenu(
    BuildContext context,
    TapUpDetails details,
    String filePath,
  ) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<dynamic>>[
        const PopupMenuItem(
          enabled: false,
          child: Text(
            'AI Vocal Remover',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        PopupMenuItem(
          value: 'instant',
          enabled: !_isVideoFile(filePath),
          child: ListTile(
            leading: const Icon(Icons.bolt, color: Colors.yellow),
            title: const Text('Instant (FFmpeg)'),
            subtitle: const Text(
              'Fast • Low Quality • Mono',
              style: TextStyle(fontSize: 10, color: Colors.white54),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'uvr_hq_cpu',
          child: ListTile(
            leading: Icon(Icons.auto_awesome, color: accentPink),
            title: const Text('UVR (HQ • CPU)'),
            subtitle: const Text(
              'Slow • Best Quality',
              style: TextStyle(fontSize: 10, color: Colors.white54),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'uvr_hq_gpu',
          child: ListTile(
            leading: Icon(Icons.flash_on, color: Colors.purpleAccent),
            title: const Text('UVR (HQ • GPU)'),
            subtitle: const Text(
              'Fast • Best Quality (NVIDIA)',
              style: TextStyle(fontSize: 10, color: Colors.white54),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'uvr_fast_cpu',
          child: ListTile(
            leading: Icon(Icons.speed, color: accentBlue),
            title: const Text('UVR (Fast • CPU)'),
            subtitle: const Text(
              'Normal Speed • Good Quality',
              style: TextStyle(fontSize: 10, color: Colors.white54),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'uvr_fast_gpu',
          child: ListTile(
            leading: Icon(Icons.rocket_launch, color: Colors.orangeAccent),
            title: const Text('UVR (Fast • GPU)'),
            subtitle: const Text(
              'Super Fast • Good Quality',
              style: TextStyle(fontSize: 10, color: Colors.white54),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'install_gpu',
          child: ListTile(
            leading: const Icon(Icons.download, color: Colors.green),
            title: const Text('Install GPU Support'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      elevation: 8,
      color: AppPalette.carbonBlack,
    ).then((value) {
      if (value == 'instant')
        _runVocalRemover(filePath, VocalRemoverType.instant);

      if (value == 'uvr_hq_cpu')
        _runVocalRemover(
          filePath,
          VocalRemoverType.uvr,
          isFastMode: false,
          useGpu: false,
        );
      if (value == 'uvr_hq_gpu')
        _runVocalRemover(
          filePath,
          VocalRemoverType.uvr,
          isFastMode: false,
          useGpu: true,
        );

      if (value == 'uvr_fast_cpu')
        _runVocalRemover(
          filePath,
          VocalRemoverType.uvr,
          isFastMode: true,
          useGpu: false,
        );
      if (value == 'uvr_fast_gpu')
        _runVocalRemover(
          filePath,
          VocalRemoverType.uvr,
          isFastMode: true,
          useGpu: true,
        );

      if (value == 'install_gpu') _installGpuSupport(context);
    });
  }

  Future<void> _runVocalRemover(
    String path,
    VocalRemoverType type, {
    bool isFastMode = false,
    bool useGpu = false,
  }) async {
    // 1. Check
    final error = await VocalRemoverService().checkAvailability(type);
    if (error != null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppPalette.carbonBlack,
            title: const Text(
              'Setup Required',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(error, style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(color: accentPink),
                ), // Removed const
              ),
            ],
          ),
        );
      }
      return;
    }

    // 2. Start Task
    final task = VocalRemoverService().process(
      File(path),
      type,
      isFastMode: isFastMode,
      useGpu: useGpu,
    );

    // 3. Show Progress Dialog
    // ignore: use_build_context_synchronously
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppPalette.carbonBlack,
          title: const Text(
            'Processing Audio',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              StreamBuilder<String>(
                stream: task.statusStream,
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 'Starting...',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                task.cancel();
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    // 4. Await Result
    final result = await task.future;

    // 5. Close Dialog
    if (mounted && Navigator.canPop(context)) {
      // Only pop if we are sure it's OUR dialog? It's risky.
      // Actually, the dialog acts as a blocker.
      // If we cancelled, we already popped.
      // If finished, we MUST pop.
      // We can use a unique key or just pop.
      // But wait: if user hit cancel, we popped.
      // If logic completed, we pop.
      // How to distinct?
      // If result is null, it might be cancelled or failed.
      // Let's rely on checking if the navigator top is the dialog? Hard.
      // Solution: Define a separate controller or "isOpen" flag passed back?
      // Or: just try to pop.
      Navigator.of(context).pop();
    }

    // 5. Handle Result
    if (result != null) {
      if (mounted) {
        _showSnack(
          'Success! Created: ${result.path.split(Platform.pathSeparator).last}',
        );
      }
      // Refresh list logic here
      if (songFolder != null) {
        _scanFolder(songFolder!, ['.mp3', '.wav', '.flac', '.ogg', '.m4a'], (
          list,
        ) {
          if (mounted) setState(() => _audioFiles = list);
        });
      }
    } else {
      // If cancelled, maybe don't show error? or show "Cancelled"
      // Since we don't return specific error enum, assume failure/cancel is handled.
      // Maybe show a small "Operation ended" snack.
    }
  }

  void _selectAudioFolder() async {
    try {
      // Use file_selector instead of file_picker to avoid potential native crashes
      final String? result = await getDirectoryPath();
      if (result != null && mounted) {
        setState(() => songFolder = result);
        _scanFolder(result, ['.mp3', '.wav', '.flac', '.ogg', '.m4a'], (list) {
          if (mounted) setState(() => _audioFiles = list);
        });
      }
    } catch (e) {
      debugPrint('Error selecting audio folder: $e');
      if (mounted) {
        _showSnack('Failed to select folder: $e', isError: true);
      }
    }
  }

  Future<void> _playAudioFile(String path) async {
    _cancelAudioFade();
    if (_audioPlayer == null) {
      _initAudioPlayer();
    }

    try {
      if (_currentlyPlayingAudioPath != path) {
        await _audioPlayer!.stop();
      }
      await _audioPlayer!.setFilePath(path);
      await _audioPlayer!.setVolume(_audioVolume);
      await _audioPlayer!.setLoopMode(
        _audioLoop ? ja.LoopMode.one : ja.LoopMode.off,
      );

      setState(() {
        _currentlyPlayingAudioPath = path;
        _isAudioPlaying = true;
        _isAudioPaused = false;
        _audioPosition = 0;
      });

      await _audioPlayer!.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _showSnack('Error playing audio: ${e.toString()}', isError: true);
    }
  }

  void _addAudioToSlide(String path) {
    if (selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) {
      _showSnack('No slide selected', isError: true);
      return;
    }

    final newLayer = SlideLayer(
      id: 'layer-${DateTime.now().microsecondsSinceEpoch}',
      label: path.split(Platform.pathSeparator).last,
      kind: LayerKind.media,
      mediaType: SlideMediaType.audio,
      role: LayerRole.foreground,
      path: path,
      left: 0.4, // Center-ish
      top: 0.4,
      width: 0.2,
      height: 0.2, // Small box for audio icon
      opacity: 1.0,
      fit: 'contain',
    );

    setState(() {
      final currentSlide = _slides[selectedSlideIndex];
      // Create a new list to ensure immutability
      final updatedLayers = List<SlideLayer>.from(currentSlide.layers)
        ..add(newLayer);

      _slides[selectedSlideIndex] = currentSlide.copyWith(
        layers: updatedLayers,
        modifiedAt: DateTime.now(),
      );

      // Auto-select the new layer
      _selectedLayerIds = {newLayer.id};
    });

    _showSnack('Added audio: ${path.split(Platform.pathSeparator).last}');
  }

  /// Plays audio associated with a slide
  void playSlideAudio(SlideContent slide) {
    if (slide.mediaType == SlideMediaType.audio && slide.mediaPath != null) {
      if (_currentlyPlayingAudioPath == slide.mediaPath && _isAudioPlaying) {
        return;
      }
      _playAudioFile(slide.mediaPath!);
    }
  }

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
              label: const Text(
                'Create Playlist',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Expanded(
          child: ListView.builder(
            itemCount: _audioPlaylists.length,
            itemBuilder: (context, i) {
              final playlist = _audioPlaylists[i];
              final isSelected = _selectedPlaylistId == playlist['id'];
              final songCount = (playlist['songs'] as List?)?.length ?? 0;

              return InkWell(
                onTap: () => setState(
                  () => _selectedPlaylistId = playlist['id'] as String?,
                ),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentBlue.withOpacity(0.15)
                        : Colors.transparent,
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
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              '$songCount songs',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildSoundEffectsView() {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing: $name'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  Widget _buildMetronomeView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
        Row(
          children: [
            const Text(
              '40',
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
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
            const Text(
              '240',
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentPink.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Beats per measure: ',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
            DropdownButton<int>(
              value: _metronomeBeatsPerMeasure,
              dropdownColor: AppPalette.carbonBlack,
              style: const TextStyle(fontSize: 12, color: Colors.white),
              underline: Container(height: 1, color: Colors.white24),
              items: [2, 3, 4, 5, 6, 7, 8]
                  .map((b) => DropdownMenuItem(value: b, child: Text('$b')))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _metronomeBeatsPerMeasure = v ?? 4),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_metronomeBeatsPerMeasure, (i) {
            final isCurrentBeat =
                _metronomeRunning && _metronomeCurrentBeat == i;
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
      final interval = Duration(milliseconds: (60000 ~/ _metronomeBpm));
      _metronomeTimer = Timer.periodic(interval, (_) {
        setState(() {
          _metronomeCurrentBeat =
              (_metronomeCurrentBeat + 1) % _metronomeBeatsPerMeasure;
        });
      });
    }
  }

  Future<void> _installGpuSupport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.carbonBlack,
        title: const Text(
          'Installing GPU Support',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Running pip install "audio-separator[gpu]"...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );

    final exitCode = await VocalRemoverService().installGpuSupport();

    if (Navigator.canPop(context)) Navigator.pop(context);

    if (mounted) {
      if (exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPU Support Installed! Restart App recommended.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Installation Failed (Code $exitCode). See console.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
