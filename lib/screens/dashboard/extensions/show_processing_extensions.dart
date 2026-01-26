part of dashboard_screen;

extension ShowProcessingExtensions on DashboardScreenState {
  void _toggleLinesOptions() {
    if (_linesOptionsOverlay != null) {
      _closeLinesOptions();
    } else {
      _showLinesOptions();
    }
  }

  void _closeLinesOptions() {
    _linesOptionsOverlay?.remove();
    _linesOptionsOverlay = null;
  }

  void _showLinesOptions() {
    final show = _activeShow;
    if (show == null) return;

    _linesOptionsOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeLinesOptions,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            width: 260,
            child: CompositedTransformFollower(
              link: _linesOptionsLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(
                -270,
                -280,
              ), // Positioned above and to the left
              child: LinesOptionsPopup(
                currentLines: show.maxLinesPerSlide ?? 4,
                onSelected: (count) {
                  _closeLinesOptions();
                  _applyLinesLimit(count);
                },
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_linesOptionsOverlay!);
  }

  void _applyLinesLimit(int count) {
    if (_activeShow == null) return;

    recordHistory();
    setState(() {
      _activeShow!.maxLinesPerSlide = count;
      _reflowShow(count);
    });
    _saveSlides();
  }

  /// The complex logic of re-paginating a show based on a line limit.
  void _reflowShow(int maxLines) {
    if (_activeShow == null || _activeShow!.slides.isEmpty) return;

    // 1. Extract ALL text from the existing show
    // We treat the show as one continuous lyric stream.
    final List<String> allTextLines = [];
    for (final slide in _activeShow!.slides) {
      final text = slide.body.trim();
      if (text.isNotEmpty) {
        allTextLines.addAll(text.split('\n'));
      }
    }

    if (allTextLines.isEmpty) return;

    // 2. Clear sub-lists but preserve a "Master Template/Background" from the first slide if available
    final masterSlide = _activeShow!.slides.first;
    final List<SlideContent> newSlides = [];

    // 3. Re-split
    final effectiveLimit = maxLines == 0 ? 999 : maxLines;

    for (int i = 0; i < allTextLines.length; i += effectiveLimit) {
      final end = (i + effectiveLimit > allTextLines.length)
          ? allTextLines.length
          : i + effectiveLimit;
      final chunk = allTextLines.sublist(i, end).join('\n');

      final newSlide = masterSlide.copyWith(
        id: 'reflow-${DateTime.now().microsecondsSinceEpoch}-$i',
        body: chunk,
        layers: masterSlide.layers.map((l) {
          if (l.kind == LayerKind.textbox) {
            return l.copyWith(
              id: 'reflow-L-${DateTime.now().microsecondsSinceEpoch}-$i',
              text: chunk,
            );
          }
          return l.copyWith(
            id: 'reflow-L-${DateTime.now().microsecondsSinceEpoch}-$i',
          );
        }).toList(),
      );
      newSlides.add(newSlide);
    }

    setState(() {
      _activeShow!.slides = newSlides;
      _slides = newSlides; // Backward compatibility with flat list if used
      selectedSlideIndex = 0;
      selectedSlides = {0};
    });

    _syncSlideThumbnails();
    _showSnack('Re-paginated into ${newSlides.length} slides');
  }
}
