part of '../dashboard_screen.dart';

extension StageExtensions on DashboardScreenState {
  void _initStageLayouts() {
    if (_stageLayouts.isNotEmpty) return;
    _stageLayouts = const [
      StageLayout(
        id: 'layout-lyrics',
        name: 'Lyrics only',
        elements: [
          StageElement(
            id: 'lyrics-main',
            type: StageElementType.currentSlide,
            rect: Rect.fromLTWH(0.05, 0.05, 0.9, 0.9),
          ),
        ],
      ),
      StageLayout(
        id: 'layout-current-next',
        name: 'Current & Next',
        elements: [
          StageElement(
            id: 'current',
            type: StageElementType.currentSlide,
            rect: Rect.fromLTWH(0.02, 0.1, 0.47, 0.5),
          ),
          StageElement(
            id: 'next',
            type: StageElementType.nextSlide,
            rect: Rect.fromLTWH(0.51, 0.1, 0.47, 0.5),
          ),
        ],
      ),
      StageLayout(
        id: 'layout-clock',
        name: 'Clock + Timer',
        elements: [
          StageElement(
            id: 'clock',
            type: StageElementType.clock,
            rect: Rect.fromLTWH(0.7, 0.05, 0.25, 0.15),
          ),
          StageElement(
            id: 'lyrics',
            type: StageElementType.currentSlide,
            rect: Rect.fromLTWH(0.05, 0.25, 0.9, 0.7),
          ),
        ],
      ),
    ];
    _selectedStageLayoutId ??= _stageLayouts.first.id;
  }

  void _addStageLayout() {
    final nextIndex = _stageLayouts.length + 1;
    final id = 'layout-${DateTime.now().millisecondsSinceEpoch}';
    final layout = StageLayout(id: id, name: 'New Layout $nextIndex');
    // ignore: invalid_use_of_protected_member
    setState(() {
      _stageLayouts = [..._stageLayouts, layout];
      _selectedStageLayoutId = id;
    });
  }

  void _reorderStageLayouts(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    // ignore: invalid_use_of_protected_member
    setState(() {
      final layouts = List<StageLayout>.from(_stageLayouts);
      final item = layouts.removeAt(oldIndex);
      layouts.insert(newIndex, item);
      _stageLayouts = layouts;
    });
    _ensureStageLayoutSelection();
  }

  void _selectStageLayout(String id) {
    if (!_stageLayouts.any((l) => l.id == id)) return;
    // ignore: invalid_use_of_protected_member
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

  void _updateStageLayout(StageLayout updated) {
    // ignore: invalid_use_of_protected_member
    setState(() {
      _stageLayouts = _stageLayouts
          .map((l) => l.id == updated.id ? updated : l)
          .toList();
    });
  }

  void _addStageElement(StageElementType type) {
    if (_selectedStageLayoutId == null) return;
    final layout = _stageLayouts.firstWhere(
      (l) => l.id == _selectedStageLayoutId,
    );
    final newElement = StageElement(
      id: 'el-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      rect: const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4),
    );
    _updateStageLayout(
      layout.copyWith(elements: [...layout.elements, newElement]),
    );
  }

  void _removeStageElement(String elementId) {
    if (_selectedStageLayoutId == null) return;
    final layout = _stageLayouts.firstWhere(
      (l) => l.id == _selectedStageLayoutId,
    );
    _updateStageLayout(
      layout.copyWith(
        elements: layout.elements.where((e) => e.id != elementId).toList(),
      ),
    );
  }

  void _updateStageElement(String elementId, {Rect? rect}) {
    if (_selectedStageLayoutId == null) return;
    final layout = _stageLayouts.firstWhere(
      (l) => l.id == _selectedStageLayoutId,
    );
    final elements = layout.elements.map((e) {
      if (e.id == elementId) {
        return e.copyWith(rect: rect);
      }
      return e;
    }).toList();
    _updateStageLayout(layout.copyWith(elements: elements));
  }

  // Timer Logic
  void _toggleStageTimer() {
    // ignore: invalid_use_of_protected_member
    setState(() {
      if (stageTimerTarget != null) {
        stageTimerTarget = null;
      } else {
        stageTimerTarget = DateTime.now().add(stageTimerDuration);
      }
    });
  }

  void _resetStageTimer() {
    // ignore: invalid_use_of_protected_member
    setState(() {
      stageTimerTarget = null;
    });
  }

  void _updateStageTimerDuration(Duration newDuration) {
    if (newDuration.inMinutes < 1) return;
    // ignore: invalid_use_of_protected_member
    setState(() {
      stageTimerDuration = newDuration;
    });
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
                      padding: EdgeInsets.only(bottom: _drawerHeight + 20),
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
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            _buildTimerControls(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStageViewPanel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Bottom Layer: Content
        _stageSubTab == 0 ? _buildStageLayoutEditor() : _buildStagePreview(),

        // Top Layer: Switcher Overlay
        Align(
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            opacity: _isStageSwitcherVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_isStageSwitcherVisible,
              child: MouseRegion(
                onEnter: (_) => _resetStageSwitcherTimer(),
                child: Transform.translate(
                  // Shift to align with global center (Main Switcher)
                  offset: Offset((_rightPaneWidth - _leftPaneWidth) / 2, 0),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.translate(
                        // Reduced offset for tighter animation
                        offset: Offset(0, -15 * (1 - value)),
                        child: Opacity(
                          opacity: value.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Center(
                      heightFactor: 1.0,
                      child: Container(
                        height: 28, // Slender height
                        margin: const EdgeInsets.only(top: 0, bottom: 4),
                        padding: const EdgeInsets.all(2), // Reduced padding
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _stageSubTabButton(
                              0,
                              'Layout Editor',
                              Icons.dashboard_customize,
                            ),
                            _stageSubTabButton(
                              1,
                              'Stage Preview',
                              Icons.slideshow,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stageSubTabButton(int index, String label, IconData icon) {
    final selected = _stageSubTab == index;
    return GestureDetector(
      // ignore: invalid_use_of_protected_member
      onTap: () => setState(() => _stageSubTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: BoxDecoration(
          color: selected
              ? accentPink.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? accentPink : Colors.white54),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStagePreview() {
    final visibleOutputs = _outputs
        .where((o) => _outputPreviewVisible[o.id] ?? true)
        .toList();

    // We use a different padding/container structure here than the settings card
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _frostedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _sectionHeader('Stage Preview'),
                const Spacer(),
                // Optional: Add a "Refresh" or "Settings" button here if needed
              ],
            ),
            const SizedBox(height: 12),
            // Filter chips for toggling output visibility
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _outputs
                  .map(
                    (o) => FilterChip(
                      label: Text(o.name, style: const TextStyle(fontSize: 11)),
                      selected: _outputPreviewVisible[o.id] ?? true,
                      onSelected: (v) => setState(() {
                        _outputPreviewVisible[o.id] = v;
                      }),
                      selectedColor: _outputColor(o).withValues(alpha: 0.25),
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.white10,
                      side: BorderSide(
                        color: _outputColor(o).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (visibleOutputs.isEmpty)
              Expanded(child: _emptyStageBox('No previews selected'))
            else
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    // Responsive column logic
                    int columns = 1;
                    if (width > 1200) {
                      columns = 3;
                    } else if (width > 800) {
                      columns = 2;
                    }

                    final spacing = 12.0;
                    final totalSpacing = spacing * (columns - 1);
                    final itemWidth = (width - totalSpacing) / columns;

                    return SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: _drawerHeight + 20),
                      child: Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (int i = 0; i < visibleOutputs.length; i++)
                            SizedBox(
                              width: itemWidth,
                              child: _outputPreviewTile(visibleOutputs[i], i),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageLayoutEditor() {
    final selectedLayout = _stageLayouts.firstWhere(
      (l) => l.id == _selectedStageLayoutId,
      orElse: () => _stageLayouts.isNotEmpty
          ? _stageLayouts.first
          : const StageLayout(id: '', name: ''),
    );
    final hasSelectedLayout =
        _stageLayouts.isNotEmpty && _selectedStageLayoutId != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: _frostedBox(
        child: Column(
          children: [
            Row(
              children: [
                _sectionHeader('Layout Editor'),
                const Spacer(),
                if (hasSelectedLayout) ...[
                  _stageToolButton(
                    Icons.slideshow,
                    'Current Slide',
                    () => _addStageElement(StageElementType.currentSlide),
                  ),
                  _stageToolButton(
                    Icons.skip_next,
                    'Next Slide',
                    () => _addStageElement(StageElementType.nextSlide),
                  ),
                  _stageToolButton(
                    Icons.access_time,
                    'Clock',
                    () => _addStageElement(StageElementType.clock),
                  ),
                  _stageToolButton(
                    Icons.timer,
                    'Timer',
                    () => _addStageElement(StageElementType.timer),
                  ),
                  _stageToolButton(
                    Icons.message,
                    'Message',
                    () => _addStageElement(StageElementType.message),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final dw = constraints.maxWidth;
                        final dh = constraints.maxHeight;
                        if (!hasSelectedLayout) {
                          return const Center(
                            child: Text(
                              'Select a layout',
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        return Stack(
                          children: [
                            for (final element in selectedLayout.elements)
                              Positioned(
                                left: element.rect.left * dw,
                                top: element.rect.top * dh,
                                width: element.rect.width * dw,
                                height: element.rect.height * dh,
                                child: RepaintBoundary(
                                  child: _buildStageElementWrapper(
                                    element,
                                    dw,
                                    dh,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageToolButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        icon: Icon(icon, size: 20, color: Colors.white70),
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      ),
    );
  }

  // Wrapper to handle drag/resize without rebuilding element content
  Widget _buildStageElementWrapper(StageElement element, double dw, double dh) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) {
            // Direct inline update - no method calls
            if (_selectedStageLayoutId == null || dw == 0 || dh == 0) return;

            final dx = (details.delta.dx / dw) * 3.0; // Higher sensitivity
            final dy = (details.delta.dy / dh) * 3.0;
            final newRect = element.rect.shift(Offset(dx, dy));
            final clampedRect = Rect.fromLTWH(
              newRect.left.clamp(0.0, 1.0 - newRect.width),
              newRect.top.clamp(0.0, 1.0 - newRect.height),
              newRect.width,
              newRect.height,
            );

            // Inline update
            final layout = _stageLayouts.firstWhere(
              (l) => l.id == _selectedStageLayoutId,
            );
            final elements = layout.elements
                .map(
                  (e) => e.id == element.id ? e.copyWith(rect: clampedRect) : e,
                )
                .toList();
            _stageLayouts = _stageLayouts
                .map(
                  (l) => l.id == layout.id
                      ? layout.copyWith(elements: elements)
                      : l,
                )
                .toList();

            // ignore: invalid_use_of_protected_member
            setState(() {});
          },
          onSecondaryTap: () {
            if (element.type == StageElementType.clock) {
              _showClockSettings(element);
            } else if (element.type == StageElementType.timer) {
              _showTimerSettings();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white10,
              border: Border.all(color: Colors.white30),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: _buildStageElement(element, dw, dh)),
                // Close button
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: () => _removeStageElement(element.id),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white38,
                    ),
                  ),
                ),
                // Resize handle
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      if (_selectedStageLayoutId == null || dw == 0 || dh == 0)
                        return;

                      final dx = (details.delta.dx / dw) * 3.0;
                      final dy = (details.delta.dy / dh) * 3.0;
                      final newWidth = (element.rect.width + dx).clamp(
                        0.05,
                        1.0 - element.rect.left,
                      );
                      final newHeight = (element.rect.height + dy).clamp(
                        0.05,
                        1.0 - element.rect.top,
                      );
                      final newRect = Rect.fromLTWH(
                        element.rect.left,
                        element.rect.top,
                        newWidth,
                        newHeight,
                      );

                      final layout = _stageLayouts.firstWhere(
                        (l) => l.id == _selectedStageLayoutId,
                      );
                      final elements = layout.elements
                          .map(
                            (e) => e.id == element.id
                                ? e.copyWith(rect: newRect)
                                : e,
                          )
                          .toList();
                      _stageLayouts = _stageLayouts
                          .map(
                            (l) => l.id == layout.id
                                ? layout.copyWith(elements: elements)
                                : l,
                          )
                          .toList();

                      // ignore: invalid_use_of_protected_member
                      setState(() {});
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppPalette.accent,
                              AppPalette.accent.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.accent.withValues(alpha: 0.4),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStageElement(StageElement element, double dw, double dh) {
    Widget child;
    // Scale fontSize relative to 1080p height
    final scale = dh / 1080.0;

    if (element.type == StageElementType.clock) {
      child = StageClockWidget(element: element, scale: scale);
    } else if (element.type == StageElementType.currentSlide ||
        element.type == StageElementType.nextSlide) {
      // Determine which slide to show
      int targetIndex = selectedSlideIndex;
      String label = 'Current Slide';

      if (element.type == StageElementType.nextSlide) {
        targetIndex = selectedSlideIndex + 1;
        label = 'Next Slide';
      }

      Widget previewContent;
      if (targetIndex >= 0 && targetIndex < _slides.length) {
        // Build live preview
        final slide = _slides[targetIndex];
        final template = _templateFor(slide.templateId);
        final payload = _buildProjectionPayload(slide, template);
        final projectionSlide = ProjectionSlide.fromJson(payload['slide']);

        previewContent = RepaintBoundary(
          child: IgnorePointer(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 1920,
                height: 1080,
                child: StyledSlide(
                  slide: projectionSlide,
                  stageWidth: 1920,
                  stageHeight: 1080,
                  // Simplify preview for performance/clarity in editor
                  backgroundActive: false,
                  foregroundMediaActive: true,
                  slideActive: true,
                  overlayActive: false,
                ),
              ),
            ),
          ),
        );
      } else {
        previewContent = Center(
          child: Text(
            'End of Presentation',
            style: TextStyle(color: Colors.white54, fontSize: 12 * scale),
            textAlign: TextAlign.center,
          ),
        );
      }

      child = Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(child: previewContent),
            // Label overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                color: Colors.black54,
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (element.type == StageElementType.timer) {
      // Show timer value with real-time updates
      child = Container(
        color: Colors.black87,
        child: StreamBuilder<int>(
          stream: Stream.periodic(const Duration(milliseconds: 100), (i) => i),
          builder: (context, snapshot) {
            final isRunning = stageTimerTarget != null;
            String displayText;

            if (isRunning && stageTimerTarget != null) {
              final remaining = stageTimerTarget!.difference(DateTime.now());
              final minutes = remaining.inMinutes.abs();
              final seconds = (remaining.inSeconds % 60).abs();
              displayText =
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
            } else {
              final minutes = stageTimerDuration.inMinutes;
              final seconds = stageTimerDuration.inSeconds % 60;
              displayText =
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
            }

            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    displayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else if (element.type == StageElementType.message) {
      // Show functional message input
      child = Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader('Stage Message'),
            const SizedBox(height: 8),
            if (stageMessage.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppPalette.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppPalette.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  stageMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type message and press Enter',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                filled: true,
                fillColor: AppPalette.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                suffixIcon: stageMessage.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(() => stageMessage = ''),
                      )
                    : null,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  setState(() => stageMessage = value.trim());
                  _sendCurrentSlideToOutputs();
                }
              },
            ),
          ],
        ),
      );
    } else {
      child = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getStageElementIcon(element.type),
              color: Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              element.type.name,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Main element with move gesture
        Positioned.fill(
          child: GestureDetector(
            onPanUpdate: (details) {
              if (dw == 0 || dh == 0) return;
              // Immediate visual update with increased sensitivity
              final dx = (details.delta.dx / dw) * 2.0;
              final dy = (details.delta.dy / dh) * 2.0;
              final newRect = element.rect.shift(Offset(dx, dy));
              // Clamp to bounds
              final clampedRect = Rect.fromLTWH(
                newRect.left.clamp(0.0, 1.0 - newRect.width),
                newRect.top.clamp(0.0, 1.0 - newRect.height),
                newRect.width,
                newRect.height,
              );

              // Direct update without full rebuild
              if (_selectedStageLayoutId == null) return;
              final layout = _stageLayouts.firstWhere(
                (l) => l.id == _selectedStageLayoutId,
              );
              final elements = layout.elements.map((e) {
                if (e.id == element.id) {
                  return e.copyWith(rect: clampedRect);
                }
                return e;
              }).toList();

              // Only update the layout list, don't save yet
              _stageLayouts = _stageLayouts
                  .map(
                    (l) => l.id == layout.id
                        ? layout.copyWith(elements: elements)
                        : l,
                  )
                  .toList();

              // Trigger minimal rebuild
              // ignore: invalid_use_of_protected_member
              setState(() {});
            },
            onSecondaryTap: () {
              if (element.type == StageElementType.clock) {
                _showClockSettings(element);
              } else if (element.type == StageElementType.timer) {
                _showTimerSettings();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                border: Border.all(color: Colors.white30),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: child),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: GestureDetector(
                      onTap: () => _removeStageElement(element.id),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Resize handle - bottom-right corner
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onPanUpdate: (details) {
              if (dw == 0 || dh == 0) return;
              // Immediate visual update with increased sensitivity
              final dx = (details.delta.dx / dw) * 2.0;
              final dy = (details.delta.dy / dh) * 2.0;
              final newWidth = (element.rect.width + dx).clamp(
                0.05,
                1.0 - element.rect.left,
              );
              final newHeight = (element.rect.height + dy).clamp(
                0.05,
                1.0 - element.rect.top,
              );
              final newRect = Rect.fromLTWH(
                element.rect.left,
                element.rect.top,
                newWidth,
                newHeight,
              );

              // Direct update without full rebuild
              if (_selectedStageLayoutId == null) return;
              final layout = _stageLayouts.firstWhere(
                (l) => l.id == _selectedStageLayoutId,
              );
              final elements = layout.elements.map((e) {
                if (e.id == element.id) {
                  return e.copyWith(rect: newRect);
                }
                return e;
              }).toList();

              // Only update the layout list
              _stageLayouts = _stageLayouts
                  .map(
                    (l) => l.id == layout.id
                        ? layout.copyWith(elements: elements)
                        : l,
                  )
                  .toList();

              // Trigger minimal rebuild
              // ignore: invalid_use_of_protected_member
              setState(() {});
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeDownRight,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppPalette.accent,
                      AppPalette.accent.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.accent.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showClockSettings(StageElement element) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ClockSettingsDialog(currentData: element.data),
    );

    if (result != null) {
      // Update element data
      // ignore: invalid_use_of_protected_member
      setState(() {
        final layout = _stageLayouts.firstWhere(
          (l) => l.id == _selectedStageLayoutId,
        );
        final updatedElements = layout.elements.map((e) {
          if (e.id == element.id) {
            return e.copyWith(data: result);
          }
          return e;
        }).toList();
        _updateStageLayout(layout.copyWith(elements: updatedElements));
      });
    }
  }

  Future<void> _showTimerSettings() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppPalette.carbonBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white24),
        ),
        title: const Text('Timer Settings'),
        content: SizedBox(width: 300, child: _buildTimerControls()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  IconData _getStageElementIcon(StageElementType type) {
    switch (type) {
      case StageElementType.clock:
        return Icons.access_time;
      case StageElementType.timer:
        return Icons.timer;
      case StageElementType.nextSlide:
        return Icons.skip_next;
      case StageElementType.currentSlide:
        return Icons.slideshow;
      case StageElementType.message:
        return Icons.message;
      case StageElementType.customText:
        return Icons.text_fields;
    }
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

  Widget _buildTimerControls() {
    final isRunning = stageTimerTarget != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader('Stage Timer'),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.timer, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              '${stageTimerDuration.inMinutes} min',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              onPressed: () => _updateStageTimerDuration(
                stageTimerDuration - const Duration(minutes: 1),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white70, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              onPressed: () => _updateStageTimerDuration(
                stageTimerDuration + const Duration(minutes: 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  icon: Icon(
                    isRunning ? Icons.stop : Icons.play_arrow,
                    size: 16,
                  ),
                  label: Text(isRunning ? 'Stop' : 'Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRunning
                        ? Colors.red.withOpacity(0.8)
                        : accentPink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _toggleStageTimer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: Colors.white70,
                ),
                tooltip: 'Reset',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _resetStageTimer,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
