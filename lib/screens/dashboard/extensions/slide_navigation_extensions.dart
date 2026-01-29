part of dashboard_screen;

/// Extension for slide navigation, selection, and management
extension SlideNavigationExtensions on DashboardScreenState {
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
    if (isPlaying) {
      playSlideAudio(_slides[index]);
    }
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
      final slides = List<SlideContent>.from(_slides);
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

  bool _hasSelection() =>
      selectedSlides.isNotEmpty ||
      selectedSlideIndex >= 0 && selectedSlideIndex < _slides.length;

  void _deleteSlides(Set<int> indices) {
    if (indices.isEmpty) return;
    final sorted = indices.where((i) => i >= 0 && i < _slides.length).toList()
      ..sort();
    if (sorted.isEmpty) return;

    setState(() {
      final slides = List<SlideContent>.from(_slides);
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

  /// Get all video paths from the current slide (background and foreground layers)
  List<String> _getCurrentSlideVideoPaths() {
    if (_slides.isEmpty) return [];
    final slide =
        _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)];
    final paths = <String>[];
    // Check background layer
    final bgLayer = _backgroundLayerFor(slide);
    if (bgLayer?.mediaType == SlideMediaType.video &&
        bgLayer?.path?.isNotEmpty == true) {
      paths.add(bgLayer!.path!);
    }
    // Check foreground layers
    for (final layer in _foregroundLayers(slide)) {
      if (layer.mediaType == SlideMediaType.video &&
          layer.path?.isNotEmpty == true) {
        paths.add(layer.path!);
      }
    }
    return paths;
  }

  void _addMediaToSlide(MediaEntry entry, int slideIndex) {
    if (slideIndex < 0 || slideIndex >= _slides.length) return;
    _syncSlideThumbnails();

    // Determine media type
    SlideMediaType mediaType = SlideMediaType.image;
    String path = entry.thumbnailUrl ?? '';

    if (entry.onlineSource == OnlineSource.youtube) {
      mediaType = SlideMediaType.video;
      path = 'yt:${entry.id}';
    } else if (entry.onlineSource == OnlineSource.youtubeMusic) {
      mediaType = SlideMediaType.video;
      path = 'ytm:${entry.id}';
    } else if (entry.onlineSource == OnlineSource.vimeo) {
      mediaType = SlideMediaType.video;
      path = 'vimeo:${entry.id}';
    } else if (entry.category == MediaFilter.audio) {
      mediaType = SlideMediaType.audio;
      path = entry.id; // Audio uses ID as path (usually absolute path)
    }

    final newLayer = SlideLayer(
      id: 'l-${DateTime.now().microsecondsSinceEpoch}',
      label: entry.title,
      kind: LayerKind.media,
      role: LayerRole.foreground,
      mediaType: mediaType,
      path: path,
      // Default position/size for new media
      left: 0.1,
      top: 0.1,
      width: 0.5,
      height: 0.5,
      opacity: 1.0,
    );

    setState(() {
      final s = _slides[slideIndex];
      _slides[slideIndex] = s.copyWith(layers: [...s.layers, newLayer]);
    });
    _selectSlide(slideIndex);
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
              onWillAcceptWithDetails: (details) => details.data is MediaEntry,
              onAcceptWithDetails: (details) {
                final data = details.data;
                if (data is MediaEntry) {
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
                // Show header with close button (visible only when a show is open)
                if (_activeShow != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bgMedium,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.slideshow, color: accentBlue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _activeShow!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Close Show',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: _closeShow,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                color: Colors.white54,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          padding: EdgeInsets.fromLTRB(
                            0,
                            0,
                            0,
                            _drawerHeight + 44,
                          ),
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
                            final tile = MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _hoveredSlideIndex = i),
                              onExit: (_) =>
                                  setState(() => _hoveredSlideIndex = null),
                              child: GestureDetector(
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
                                            forceLivePreview:
                                                _hoveredSlideIndex == i,
                                          ),
                                        ),
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 0,
                                          child: Builder(
                                            builder: (context) {
                                              final group = _slides[i].title
                                                  .toUpperCase()
                                                  .replaceAll(
                                                    RegExp(r'\s*\(\d+/\d+\)'),
                                                    '',
                                                  )
                                                  .replaceAll(
                                                    RegExp(r'\s+\d+$'),
                                                    '',
                                                  )
                                                  .trim();

                                              final baseColor =
                                                  _slides[i].groupColor ??
                                                  (group.isNotEmpty
                                                      ? LabelColorService
                                                            .instance
                                                            .getColor(group)
                                                      : Colors.black);

                                              final isDefault =
                                                  baseColor.value ==
                                                      Colors.black.value ||
                                                  baseColor.opacity == 0;
                                              final bg = isDefault
                                                  ? Colors.black.withOpacity(
                                                      0.78,
                                                    )
                                                  : baseColor.withOpacity(0.9);

                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: bg,
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        bottom: Radius.circular(
                                                          8,
                                                        ),
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Center(
                                                        child: Text(
                                                          _slides[i].title,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 12,
                                                            shadows: [
                                                              Shadow(
                                                                color: Colors
                                                                    .black45,
                                                                offset: Offset(
                                                                  0,
                                                                  1,
                                                                ),
                                                                blurRadius: 2,
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
                                          ),
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: accentPink,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
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
                                      if (data is MediaEntry) return true;
                                      return false;
                                    },
                                    onAcceptWithDetails: (details) {
                                      final data = details.data;
                                      if (data is int) {
                                        _moveSlide(data, i);
                                      } else if (data is MediaEntry) {
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

          Positioned(
            right: 135,
            bottom: _drawerHeight + 24,
            child: CompositedTransformTarget(
              link: _linesOptionsLayerLink,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _toggleLinesOptions,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF3EB4F0,
                      ), // Aura blue from screenshot
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3EB4F0).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.format_line_spacing,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            right: 24,
            bottom: _drawerHeight + 24,
            child: ElevatedButton.icon(
              onPressed: _addSlide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Black background
                foregroundColor: Colors.white, // White text/icon
                side: BorderSide(
                  color: accentPink,
                  width: 1.5,
                ), // Thin orange bezel
                elevation: 4,
                shadowColor: Colors.black45,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 32), // Slimmer vertical height
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.add, size: 16), // Smaller icon
              label: const Text(
                'New Slide',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12, // Smaller text
                ),
              ),
            ),
          ),
        ],
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

  void _addSlide() {
    _syncSlideThumbnails();
    setState(() {
      final newIndex = _slides.length + 1;
      _slides = [
        ..._slides,
        SlideContent(
          id: 'slide-${DateTime.now().millisecondsSinceEpoch}',
          title: 'New Slide $newIndex',
          body: '',
          templateId: _templates.first.id,
          createdAt: DateTime.now(),
          layers: [
            SlideLayer(
              id: 'l-${DateTime.now().microsecondsSinceEpoch}',
              label: 'Text',
              kind: LayerKind.textbox,
              role: LayerRole.foreground,
              text: 'Edit me',
              left: 0.1,
              top: 0.3,
              width: 0.8,
              height: 0.4,
              opacity: 1.0,
            ),
          ],
        ),
      ];
      _slideThumbnails = [..._slideThumbnails, null];
      selectedSlideIndex = _slides.length - 1;
      selectedSlides = {selectedSlideIndex};
    });
    _syncSlideEditors();
  }

  /// Add a new slide at a specific index
  void _addSlideAt(int insertIndex) {
    _syncSlideThumbnails();
    final safeIndex = _safeIntClamp(insertIndex, 0, _slides.length);
    final newSlide = SlideContent(
      id: 'slide-${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Slide',
      body: '',
      templateId: _templates.first.id,
      createdAt: DateTime.now(),
      layers: [
        SlideLayer(
          id: 'l-${DateTime.now().microsecondsSinceEpoch}',
          label: 'Text',
          kind: LayerKind.textbox,
          role: LayerRole.foreground,
          text: 'Edit me',
          left: 0.1,
          top: 0.3,
          width: 0.8,
          height: 0.4,
          opacity: 1.0,
        ),
      ],
    );
    setState(() {
      final slides = List<SlideContent>.from(_slides);
      final thumbs = List<String?>.from(_slideThumbnails);
      slides.insert(safeIndex, newSlide);
      thumbs.insert(safeIndex, null);
      _slides = slides;
      _slideThumbnails = thumbs;
      selectedSlideIndex = safeIndex;
      selectedSlides = {safeIndex};
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
        const PopupMenuItem(
          value: 'add_before',
          child: Row(
            children: [
              Icon(Icons.add, size: 18, color: Colors.white70),
              SizedBox(width: 8),
              Text('Add slide before'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'add_after',
          child: Row(
            children: [
              Icon(Icons.add, size: 18, color: Colors.white70),
              SizedBox(width: 8),
              Text('Add slide after'),
            ],
          ),
        ),
        const PopupMenuDivider(),
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
      case 'add_before':
        _addSlideAt(index);
        break;
      case 'add_after':
        _addSlideAt(index + 1);
        break;
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
      _slides[index] = _slides[index].copyWith(
        title: newName,
        modifiedAt: DateTime.now(),
      );
      selectedSlideIndex = index;
      selectedSlides = {index};
    });
  }
}
