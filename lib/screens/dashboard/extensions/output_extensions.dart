part of dashboard_screen;

extension OutputExtensions on DashboardScreenState {
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

    // Auto-enable layers if output was previously cleared
    if (outputPreviewCleared || shouldClearPreview) {
      setState(() {
        outputBackgroundActive = true;
        outputForegroundMediaActive = true;
        outputSlideActive = true;
        outputOverlayActive = true;
        outputAudioActive = true;
        outputPreviewCleared = false;
      });
    } else if (!shouldClearPreview) {
      setState(() => outputPreviewCleared = false);
    }
    final slide = _slides[selectedSlideIndex];
    final template = _templateFor(slide.templateId);
    final payloadBase = _buildProjectionPayload(slide, template);

    final visibleOutputs = _outputs.where((o) => o.visible).toList();
    final screenOutputs = _outputs
        .where((o) => o.destination == OutputDestination.screen)
        .toList();
    final visibleScreenOutputs = screenOutputs.where((o) => o.visible).toList();
    List<OutputConfig> outputsToSend;
    if (_armedOutputs.isNotEmpty) {
      outputsToSend = _outputs
          .where((o) => _armedOutputs.contains(o.id))
          .toList();
    } else {
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
        // Ghost Mode: Freeze Audience/Stream outputs, but update Stage Displays
        if (isGhostMode &&
            output.styleProfile != OutputStyleProfile.stageNotes) {
          continue;
        }

        final locked = (_outputRuntime[output.id]?.locked ?? outputsLocked);
        final slideLayerActive =
            outputSlideActive || slide.body.trim().isNotEmpty;
        final bool isScreen = output.destination == OutputDestination.screen;
        final bool isNdi = output.destination == OutputDestination.ndi;
        final bool needsWindow =
            (isScreen || isNdi) && (output.visible || createIfMissing);
        final bool isHeadless = !needsWindow;
        // Use the selected stage layout if the output is configured for stage notes
        Map<String, dynamic>? stageLayoutJson;
        if (output.styleProfile == OutputStyleProfile.stageNotes) {
          final layout = _stageLayouts.firstWhere(
            (l) => l.id == _selectedStageLayoutId,
            orElse: () => const StageLayout(id: '', name: 'Default'),
          );
          stageLayoutJson = layout.toJson();
        }

        // Get next slide for stage display
        Map<String, dynamic>? nextSlideJson;
        if (selectedSlideIndex + 1 < _slides.length) {
          final nextSlide = _slides[selectedSlideIndex + 1];
          final nextTemplate = _templateFor(nextSlide.templateId);
          // We can reuse buildProjectionPayload but we need the 'slide' part only
          // Or just construct it manually/helper.
          // _buildProjectionPayload returns { 'slide': ..., 'content': ... }
          // We want the 'slide' object which matches ProjectionSlide.fromJson
          final nextPayload = _buildProjectionPayload(nextSlide, nextTemplate);
          nextSlideJson = nextPayload['slide'];
        }

        final payload = {
          'stageLayout': stageLayoutJson,
          'nextSlide': nextSlideJson,
          'stageTimerTarget': stageTimerTarget?.toIso8601String(),
          'stageTimerDuration': stageTimerDuration.inSeconds,
          'stageMessage': stageMessage,
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
            'transitionDuration': transitionDuration.inMilliseconds,
            'isPlaying': isPlaying,
            'videoPositionMs': _getBackgroundVideoPositionMs(),
            'videoPath': _getCurrentSlideVideoPath(),
          },
        };
        if (isHeadless) {
          final runtime = _outputRuntime[output.id] ?? _OutputRuntimeState();
          runtime.active = true;
          runtime.locked = locked;
          runtime.disconnected = false;
          runtime.ndi =
              output.destination == OutputDestination.ndi || enableNdiOutput;
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
    if (_outputWindowIds.isNotEmpty) {
      _showSnack('Double-click to close outputs');
      return;
    }
    setState(() {
      _awaitingPresentStopConfirm = false;
      _presentStopRequestedAt = null;
    });
    await _armPresentation();
  }

  Future<void> _armPresentation() async {
    debugPrint('out: arming presentation, sending current slide to outputs');
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

  Future<void> _closeOutputWindow(String outputId) async {
    final windowId = _outputWindowIds[outputId];
    if (windowId != null) {
      debugPrint('out: closing outputId=$outputId windowId=$windowId');
      try {
        await WindowController.fromWindowId(windowId).close();
      } catch (e) {
        debugPrint('out: error closing window $windowId: $e');
      }
      setState(() {
        _outputWindowIds.remove(outputId);
        final runtime = _outputRuntime[outputId] ?? _OutputRuntimeState();
        runtime.active = false;
        _outputRuntime[outputId] = runtime;
      });
    }
  }

  Future<void> _closeAllOutputWindows() async {
    debugPrint(
      'out: closing all output windows count=${_outputWindowIds.length}',
    );

    final entries = _outputWindowIds.entries.toList();

    for (final entry in entries) {
      final int id = entry.value;
      try {
        debugPrint('out: closing windowId=$id outputId=${entry.key}');
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
        if (!createIfMissing || _pendingOutputCreates.contains(output.id)) {
          return false;
        }
        _pendingOutputCreates.add(output.id);
        try {
          debugPrint('out: creating window for output=${output.id}');
          final window = await _safeCreateWindow('{}');
          if (window == null) {
            debugPrint('out: create window skipped due to plugin error');
            return false;
          }
          window.setTitle(output.name);
          await window.setFrame(
            targetFrame ?? const Rect.fromLTWH(0, 0, 1920, 1080),
          );
          if (output.invisibleWindow) {
            await window.hide();
          } else {
            await window.show();
          }
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
          if (output.invisibleWindow) {
            await WindowController.fromWindowId(windowId).hide();
          } else {
            await WindowController.fromWindowId(windowId).show();
          }
          await DesktopMultiWindow.invokeMethod(
            windowId,
            'updateContent',
            payloadJson,
          );
          return true;
        } on PlatformException {
          debugPrint('out: update failed for windowId=$windowId, recreating');
          _outputWindowIds.remove(output.id);
          if (!createIfMissing || _pendingOutputCreates.contains(output.id)) {
            return false;
          }
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
            if (output.invisibleWindow) {
              await window.hide();
            } else {
              await window.show();
            }
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
      debugPrint('out: createWindow failed; skipping output create. error=$e');
      return null;
    }
  }

  Map<String, dynamic> _buildProjectionPayload(
    SlideContent slide,
    SlideTemplate template,
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

  void _addOutput() {
    setState(() {
      _outputs = [
        ..._outputs,
        OutputConfig.defaultAudience().copyWith(
          id: 'output-${DateTime.now().microsecondsSinceEpoch}',
          name: 'Output ${_outputs.length + 1}',
        ),
      ];
      _ensureOutputVisibilityDefaults();
    });
    // _saveOutputs();
  }

  void _updateOutput(OutputConfig updated) {
    setState(() {
      final index = _outputs.indexWhere((o) => o.id == updated.id);
      if (index >= 0) {
        _outputs[index] = updated;
      } else {
        _outputs.add(updated);
      }
    });
    _ensureOutputPreviewVisibilityDefaults();

    _outputDebouncer(() {
      if (!updated.visible) {
        _closeOutputWindow(updated.id);
      }
      _sendCurrentSlideToOutputs(createIfMissing: updated.visible);
    });
    // _saveOutputs();
  }

  void _ensureOutputPreviewVisibilityDefaults() {
    for (final output in _outputs) {
      _outputPreviewVisible.putIfAbsent(output.id, () => true);
    }
    final existingIds = _outputs.map((o) => o.id).toSet();
    _outputPreviewVisible.removeWhere((key, _) => !existingIds.contains(key));
  }

  Future<void> _clearAllOutputs() async {
    debugPrint('out: clearing all outputs count=${_outputWindowIds.length}');
    // Fast fade out (500ms) instead of instant stop, per user request
    _stopAudio(fadeDuration: const Duration(milliseconds: 500));
    _cancelAutoAdvanceTimer(); // Ensure timer is stopped

    // Explicitly update Play/Pause button state immediately
    if (isPlaying) {
      isPlaying = false;
    }

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
      } catch (_) {}
    }

    for (final id in _outputWindowIds.keys) {
      _outputRuntime[id] = _OutputRuntimeState(
        active: false,
        locked: false,
        ndi: enableNdiOutput,
        disconnected: false,
      );
    }
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
        if (autoAdvanceEnabled &&
            _isAudioPlaying &&
            !_isAudioPaused &&
            _currentlyPlayingAudioPath != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accentPink.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: accentPink.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_alt, size: 10, color: accentPink),
                const SizedBox(width: 4),
                Text(
                  'SYNCED',
                  style: TextStyle(
                    color: accentPink,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    // Extract unique groups from current slides
    final Map<String, int> groupCounts = {};
    for (final slide in _slides) {
      final title = slide.title.trim();
      if (title.isNotEmpty) {
        // Normalize: "CHORUS (1/2)" -> "CHORUS", "Verse 1" -> "VERSE"
        String group = title
            .toUpperCase()
            .replaceAll(RegExp(r'\s*\(\d+/\d+\)'), '') // Remove (1/2) suffix
            .replaceAll(RegExp(r'\s+\d+$'), '') // Remove trailing numbers
            .trim();
        if (group.isNotEmpty) {
          groupCounts[group] = (groupCounts[group] ?? 0) + 1;
        }
      }
    }

    final groups = groupCounts.keys.toList();

    return _frostedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Groups',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Tooltip(
                message: 'Customize group colors',
                child: InkWell(
                  onTap: _showGroupColorDialog,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.palette, size: 16, color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12),
          if (groups.isEmpty)
            const SizedBox(
              height: 50,
              child: Center(
                child: Text(
                  'No groups',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            SizedBox(
              height: math.min(groups.length * 32.0 + 8, 120),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final color = LabelColorService.instance.getColor(group);
                  final count = groupCounts[group] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: InkWell(
                      onTap: () {
                        // Jump to first slide of this group
                        final idx = _slides.indexWhere(
                          (s) => s.title.toUpperCase().contains(group),
                        );
                        if (idx >= 0) {
                          setState(() => selectedSlideIndex = idx);
                          _sendCurrentSlideToOutputs();
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            group,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '×$count',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
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
          ? _renderSlidePreview(slide, compact: true)
          : Container(color: Colors.black),
    );

    return SizedBox(
      width: double.infinity,
      child: AspectRatio(aspectRatio: 16 / 9, child: previewFrame),
    );
  }

  bool _currentSlideHasBackground() {
    if (_slides.isEmpty) return false;
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    final bgLayer = _backgroundLayerFor(slide);
    return bgLayer != null && (bgLayer.path?.isNotEmpty ?? false);
  }

  bool _currentSlideHasText() {
    if (_slides.isEmpty) return false;
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    if (slide.title.trim().isNotEmpty || slide.body.trim().isNotEmpty) {
      return true;
    }
    return slide.layers.any(
      (l) => l.kind == LayerKind.textbox && (l.text?.isNotEmpty ?? false),
    );
  }

  bool _currentSlideHasOverlay() {
    if (_slides.isEmpty) return false;
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    final fgLayers = _foregroundLayers(slide);
    return fgLayers.isNotEmpty;
  }

  bool _currentSlideHasForegroundMedia() {
    if (_slides.isEmpty) return false;
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    final fgLayers = _foregroundLayers(slide);
    return fgLayers.any(
      (l) => l.kind == LayerKind.media && (l.path?.isNotEmpty ?? false),
    );
  }

  bool _currentSlideHasTimer() {
    if (_slides.isEmpty) return false;
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    return slide.layers.any((l) => l.kind == LayerKind.timer);
  }

  Widget _buildOutputControlCard() {
    final hasBackground = _currentSlideHasBackground();
    final hasForegroundMedia = _currentSlideHasForegroundMedia();
    final hasText = _currentSlideHasText();
    final hasOverlay = _currentSlideHasOverlay();
    final hasTimer = _currentSlideHasTimer();
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
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.animation,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Transition',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: outputTransition,
                      dropdownColor: const Color(0xFF2C2C2C),
                      isDense: true,
                      underline: const SizedBox(),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white54,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      items: const [
                        DropdownMenuItem(
                          value: 'none',
                          child: const Text('None'),
                        ),
                        DropdownMenuItem(
                          value: 'fade',
                          child: const Text('Fade'),
                        ),
                        DropdownMenuItem(
                          value: 'push',
                          child: const Text('Push'),
                        ),
                        DropdownMenuItem(
                          value: 'wipe',
                          child: const Text('Wipe'),
                        ),
                        DropdownMenuItem(
                          value: 'iris',
                          child: const Text('Iris'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => outputTransition = v);
                        }
                      },
                    ),
                  ],
                ),
                if (outputTransition != 'none') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${transitionDuration.inMilliseconds}ms',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 20,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              trackHeight: 2,
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(
                              value: transitionDuration.inMilliseconds
                                  .toDouble(),
                              min: 100,
                              max: 2000,
                              divisions: 19,
                              activeColor: accentPink,
                              inactiveColor: Colors.white10,
                              onChanged: (v) {
                                setState(
                                  () => transitionDuration = Duration(
                                    milliseconds: v.round(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                  final typeLabel = LayerKindLabel(layer);
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
                                      layer.role == LayerRole.background
                                      ? accentBlue.withOpacity(0.2)
                                      : accentPink.withOpacity(0.2),
                                  child: Icon(
                                    _layerIcon(layer),
                                    size: 16,
                                    color: layer.role == LayerRole.background
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

  SlideLayer? _effectiveMediaLayer(SlideContent slide) {
    try {
      return slide.layers.firstWhere(
        (l) =>
            l.role == LayerRole.background &&
            l.mediaType == SlideMediaType.video,
      );
    } catch (_) {}

    try {
      return slide.layers.firstWhere(
        (l) =>
            l.role == LayerRole.background &&
            l.mediaType == SlideMediaType.image,
      );
    } catch (_) {}

    try {
      return slide.layers.firstWhere(
        (l) => l.mediaType == SlideMediaType.video,
      );
    } catch (_) {}

    return null;
  }
}
