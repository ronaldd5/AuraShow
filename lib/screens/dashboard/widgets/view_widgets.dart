part of dashboard_screen;

extension _DashboardViewWidgets on DashboardScreenState {
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
              _toolbarButton(
                'YOUTUBE',
                Icons.smart_display_outlined,
                _addYouTubeLink,
              ),
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

  Widget _buildYouTubeSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _youtubeQuery,
            decoration: const InputDecoration(
              hintText: 'Search YouTube videos',
              filled: true,
              fillColor: AppPalette.surface,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
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
    );
  }

  Widget _buildSearchAndSaved() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search Results',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: youtubeResults.isEmpty
                    ? const Center(child: Text('No results yet'))
                    : ListView.separated(
                        itemCount: youtubeResults.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final item = youtubeResults[i];
                          return Container(
                            decoration: BoxDecoration(
                              color: AppPalette.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  height: 60,
                                  child: _slideThumbOrPlaceholder(
                                    item['thumb'],
                                    label: 'YouTube',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item['title'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  tooltip: 'Save to media',
                                  onPressed: () => _addYouTubeVideo(
                                    item['id'] ?? '',
                                    item['title'] ?? 'YouTube',
                                  ),
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saved YouTube',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: savedYouTubeVideos.isEmpty
                    ? const Center(child: Text('Nothing saved yet'))
                    : ListView.separated(
                        itemCount: savedYouTubeVideos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final item = savedYouTubeVideos[i];
                          final id = item['id'] ?? '';
                          final title = item['title'] ?? '';
                          return Container(
                            decoration: BoxDecoration(
                              color: AppPalette.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'https://youtu.be/$id',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
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
      ],
    );
  }

  Widget _renderSlidePreview(
    SlideContent slide, {
    bool compact = false,
    OutputConfig? output,
    bool? backgroundActive,
    bool? slideActive,
    bool? overlayActive,
    bool? foregroundMediaActive,
    bool forceLivePreview = false,
  }) {
    // Use the passed-in visibility states, or default to true for thumbnails/compact previews
    final showBackground = backgroundActive ?? true;
    final showSlide = slideActive ?? true;
    final showOverlay = overlayActive ?? true;
    final showForegroundMedia = foregroundMediaActive ?? true;

    final template = _templateFor(slide.templateId);
    final align = slide.alignOverride ?? template.alignment;
    final verticalAlign = slide.verticalAlign ?? template.verticalAlign;
    final profile = output?.styleProfile;
    final isStageNotes =
        profile == OutputStyleProfile.stageNotes || output?.stageNotes == true;
    final applyLowerThird = profile == OutputStyleProfile.streamLowerThird;
    final textScale = (output?.textScale ?? 1.0).clamp(0.5, 2.0);
    final maxLines = output?.maxLines ?? (compact ? 6 : 12);
    final bool autoPlayVideo = output != null;
    // Use RepaintBoundary to cache this complex widget and improve performance
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double stageWidth = 1920;
          const double stageHeight = 1080;
          // Calculate effective height based on 16:9 aspect ratio from width
          // This ensures layers maintain correct proportions regardless of panel size
          final double effectiveWidth = constraints.maxWidth;
          final double effectiveHeight = effectiveWidth / (16 / 9);
          final double scale = (effectiveWidth / stageWidth).clamp(0.1, 2.0);

          final resolvedBox = _resolvedBoxRect(slide);
          final hasTextboxLayer = slide.layers.any(
            (l) => l.kind == LayerKind.textbox || l.kind == LayerKind.scripture,
          );
          final hasTextContent =
              hasTextboxLayer || slide.body.trim().isNotEmpty;
          final showLegibilityOverlay = compact && hasTextContent;
          // Boost compact and full previews further for legibility.
          final baseFontSize =
              (slide.fontSizeOverride ?? template.fontSize) *
              (compact ? 1.24 : 1.12) *
              scale *
              textScale;
          final fontSize =
              _autoSizedFont(slide, baseFontSize, resolvedBox) *
              (isStageNotes ? stageNotesScale : 1.0);
          final fontWeight = (slide.isBold ?? template.isBold)
              ? FontWeight.w700
              : FontWeight.w400;
          final fontStyle = (slide.isItalic ?? template.isItalic)
              ? FontStyle.italic
              : FontStyle.normal;
          final decoration = (slide.isUnderline ?? false)
              ? TextDecoration.underline
              : TextDecoration.none;
          final height = (slide.lineHeight ?? 1.3).clamp(0.6, 3.0);
          final letterSpacing = (slide.letterSpacing ?? 0).clamp(-2.0, 10.0);
          final wordSpacing = (slide.wordSpacing ?? 0).clamp(-4.0, 16.0);

          double boxLeft = resolvedBox.left * effectiveWidth;
          double boxTop = resolvedBox.top * effectiveHeight;
          double boxWidth = resolvedBox.width * effectiveWidth;
          double boxHeight = resolvedBox.height * effectiveHeight;

          if (applyLowerThird) {
            final heightFraction = lowerThirdHeight.clamp(0.1, 0.6);
            boxTop = effectiveHeight * (1 - heightFraction) + 12 * scale;
            boxHeight = effectiveHeight * heightFraction - 24 * scale;
          }

          final shaderRect = Rect.fromLTWH(0, 0, boxWidth, boxHeight);
          final gradientColors = slide.textGradientOverride;
          Paint? gradientPaint;
          if (gradientColors != null && gradientColors.isNotEmpty) {
            gradientPaint = Paint()
              ..shader = LinearGradient(
                colors: gradientColors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(shaderRect);
          }

          final textColor = slide.textColorOverride ?? template.textColor;
          final textStyle = TextStyle(
            color: gradientPaint == null ? textColor : null,
            foreground: gradientPaint,
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            height: height,
            fontFamily: slide.fontFamilyOverride,
            letterSpacing: letterSpacing,
            wordSpacing: wordSpacing,
            decoration: decoration,
            decorationColor: textColor,
            shadows: [
              ..._textShadows(slide),
              // Outline for compact previews to lift text off thumbnails.
              if (compact)
                ...[
                  const Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 0,
                    color: Colors.black,
                  ),
                ].expand(
                  (_) => [
                    const Shadow(offset: Offset(1, 0), color: Colors.black),
                    const Shadow(offset: Offset(-1, 0), color: Colors.black),
                    const Shadow(offset: Offset(0, 1), color: Colors.black),
                    const Shadow(offset: Offset(0, -1), color: Colors.black),
                  ],
                ),
            ],
          );

          final maxVisibleLines = slide.singleLine == true ? 1 : maxLines;

          final fgLayers = _foregroundLayers(slide);

          // Filter foreground layers based on visibility:
          // - Media layers: show if showForegroundMedia is true
          // - Textbox layers: show if showSlide is true
          final visibleFgLayers = fgLayers.where((l) {
            if (l.kind == LayerKind.textbox || l.kind == LayerKind.scripture) {
              return showSlide;
            }
            // Media layers (image/video)
            return showForegroundMedia;
          }).toList();

          // Wrap in SizedBox + ClipRect to enforce 16:9 aspect ratio
          // This prevents layers from stretching when parent isn't exactly 16:9
          return ClipRect(
            child: SizedBox(
              width: effectiveWidth,
              height: effectiveHeight,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (showBackground)
                    Positioned.fill(
                      child: _applyFilters(
                        _buildSlideBackground(
                          slide,
                          template,
                          compact: compact,
                          autoPlayVideo: autoPlayVideo,
                        ),
                        slide,
                      ),
                    ),
                  if (!showBackground)
                    Positioned.fill(child: Container(color: Colors.black)),
                  if (showLegibilityOverlay)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.08),
                              Colors.black.withOpacity(0.18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (applyLowerThird && lowerThirdGradient)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppPalette.carbonBlack.withOpacity(0.0),
                              AppPalette.carbonBlack.withOpacity(0.45),
                            ],
                          ),
                        ),
                      ),
                    ),
                  for (final layer in visibleFgLayers)
                    () {
                      final rect = _resolvedLayerRect(layer);
                      final layerLeft = rect.left * effectiveWidth;
                      final layerTop = rect.top * effectiveHeight;
                      final layerWidth = rect.width * effectiveWidth;
                      final layerHeight = rect.height * effectiveHeight;
                      return Positioned(
                        left: layerLeft,
                        top: layerTop,
                        width: layerWidth,
                        height: layerHeight,
                        child: _buildLayerWidget(
                          layer,
                          slide: slide,
                          compact: compact,
                          fit: _mapFit(layer.fit),
                          showControls: false,
                          autoPlayVideo: autoPlayVideo,
                          forceLivePreview: forceLivePreview,
                          scale: scale,
                        ),
                      );
                    }(),
                  if (showSlide &&
                      !hasTextboxLayer &&
                      (slide.body.trim().isNotEmpty ||
                          slide.boxBackgroundColor != null))
                    Positioned(
                      left: boxLeft,
                      top: boxTop,
                      width: boxWidth,
                      height: boxHeight,
                      child: Transform.rotate(
                        angle: (slide.rotation ?? 0) * (3.1415926535 / 180),
                        child: Container(
                          padding: EdgeInsets.all(
                            ((slide.boxPadding ?? 8).clamp(0, 48)).toDouble() *
                                scale,
                          ),
                          alignment: _textAlignToAlignment(
                            align,
                            verticalAlign,
                          ),
                          decoration: BoxDecoration(
                            color: slide.boxBackgroundColor ?? Colors.black26,
                            borderRadius: BorderRadius.circular(
                              (slide.boxBorderRadius ?? 0).toDouble(),
                            ),
                          ),
                          child: LiturgyTextRenderer.build(
                            _applyTransform(
                              slide.body,
                              slide.textTransform ?? TextTransform.none,
                            ),
                            align: align,
                            style: textStyle,
                            maxLines: maxVisibleLines,
                            overflow: slide.singleLine == true
                                ? TextOverflow.fade
                                : TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  if (showOverlay &&
                      slide.overlayNote != null &&
                      slide.overlayNote!.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: template.overlayAccent.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          slide.overlayNote!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _outputColor(OutputConfig output) {
    const palette = [
      Color(0xFFF4A261), // orange
      Color(0xFF2A9D8F), // teal
      Color(0xFF4CC9F0), // blue
      Color(0xFFE76F51), // coral
      Color(0xFF9B5DE5), // purple
    ];
    final idx = _outputs.indexWhere((o) => o.id == output.id);
    return palette[idx % palette.length];
  }

  Widget _outputPreviewTile(OutputConfig output, int index) {
    final hasSlides = _slides.isNotEmpty;
    final slide = hasSlides
        ? _slides[_safeIntClamp(selectedSlideIndex, 0, _slides.length - 1)]
        : null;
    final borderColor = _outputColor(output);
    final armed = _armedOutputs.isEmpty || _armedOutputs.contains(output.id);
    final runtime = _outputRuntime[output.id];
    final headless =
        (runtime?.headless ?? false) ||
        output.destination != OutputDestination.screen ||
        output.visible == false;
    final locked = runtime?.locked ?? false;
    final hasHeadlessPayload = _headlessOutputPayloads.containsKey(output.id);
    final active = runtime?.active ?? hasHeadlessPayload;
    final disconnected = runtime?.disconnected ?? false;
    final statusColor = disconnected
        ? Colors.redAccent
        : locked
        ? Colors.amber
        : active
        ? Colors.greenAccent
        : Colors.white38;
    final statusLabel = disconnected
        ? 'Disconnected'
        : locked
        ? 'Locked'
        : active
        ? 'Active'
        : 'Idle';
    final destinationLabel = headless
        ? '${output.destination.name} (hidden)'
        : output.destination.name;
    return GestureDetector(
      onTap: () => _toggleArmOutput(output.id),
      onLongPress: () {
        if (slide == null) return;
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 960,
                child: _renderSlidePreview(
                  slide,
                  output: output,
                  backgroundActive: outputBackgroundActive,
                  slideActive: outputSlideActive,
                  overlayActive: outputOverlayActive,
                  foregroundMediaActive: outputForegroundMediaActive,
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.carbonBlack.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: armed ? borderColor.withOpacity(0.9) : Colors.white24,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              spreadRadius: 1,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: armed ? borderColor.withOpacity(0.18) : Colors.white10,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    output.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.white54,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Rename output',
                    onPressed: () => _showRenameOutputDialog(output),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: armed
                          ? borderColor.withOpacity(0.28)
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: armed ? borderColor : Colors.white38,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          armed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 14,
                          color: armed ? borderColor : Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          armed ? 'Armed' : 'Muted',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      (_outputRuntime[output.id]?.locked ?? false)
                          ? Icons.lock
                          : Icons.lock_open,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    tooltip: 'Lock this output',
                    onPressed: () => _toggleOutputLock(output.id),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: outputPreviewCleared
                  ? Container(color: Colors.black) // Show cleared/black screen
                  : slide == null
                  ? _emptyStageBox('No slide')
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: _renderSlidePreview(
                            slide,
                            compact: true,
                            output: output,
                            backgroundActive: outputBackgroundActive,
                            slideActive: outputSlideActive,
                            overlayActive: outputOverlayActive,
                            foregroundMediaActive: outputForegroundMediaActive,
                          ),
                        ),
                        // Scripture Context Tools (Verses Around)
                        if (slide != null &&
                            slide.layers.any(
                              (l) =>
                                  l.kind == LayerKind.scripture &&
                                  (l.scriptureReference?.isNotEmpty ?? false),
                            ))
                          Stack(
                            children: [
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 24,
                                child: Center(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _extendScripture(false),
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(12),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                bottom: Radius.circular(12),
                                              ),
                                          border: Border.all(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 24,
                                child: Center(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _extendScripture(true),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                          border: Border.all(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.62),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      destinationLabel,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      statusLabel,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                _outputMeter(
                                  color: armed ? borderColor : Colors.white38,
                                ),
                              ],
                            ),
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

  Widget _outputMeter({required Color color}) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(milliseconds: 850), (i) => i),
      builder: (context, snapshot) {
        final tick = (snapshot.data ?? 0) % 5;
        final bars = List.generate(4, (i) => ((tick + i) % 4) / 3.0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: bars
              .map(
                (v) => Container(
                  width: 4,
                  height: 10 + v * 14,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
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
            return Center(
              child: Text(label, style: const TextStyle(color: Colors.white54)),
            );
          }

          final isHttp =
              url.startsWith('http://') || url.startsWith('https://');
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
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          label,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
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
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        label,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : Center(
                            child: Text(
                              label,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                  ),
                ),
                _thumbLabel(label),
              ],
            );
          }
        }(),
      ),
    );
  }

  BoxFit _mapFit(String? fit) {
    switch (fit) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'cover':
      default:
        return BoxFit.cover;
    }
  }

  Future<void> _showRenameOutputDialog(OutputConfig output) async {
    final controller = TextEditingController(text: output.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.carbonBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white24),
        ),
        title: const Text('Rename Output'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppPalette.accent),
            ),
          ),
          onSubmitted: (_) {
            if (controller.text.trim().isNotEmpty) {
              _updateOutput(output.copyWith(name: controller.text.trim()));
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _updateOutput(output.copyWith(name: controller.text.trim()));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class TemplatePreviewCard extends StatelessWidget {
  final SlideTemplate template;
  final bool isSelected;
  final VoidCallback onTap;

  const TemplatePreviewCard({
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Create a dummy slide for preview
    final dummySlide = SlideContent(
      id: 'preview',
      title: 'Preview',
      body: 'Title\nText',
      templateId: template.id,
      textColorOverride: null,
      boxBackgroundColor: null,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: AppPalette.dustyMauve, width: 2)
              : Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 1920,
                  height: 1080,
                  child: Stack(
                    children: [
                      // Background
                      Positioned.fill(
                        child: template.backgroundImagePath != null
                            ? Image.file(
                                File(template.backgroundImagePath!),
                                fit: BoxFit.cover,
                              )
                            : Container(color: template.background),
                      ),

                      // Text Content (Simulated)
                      Container(
                        alignment: template.verticalAlign == VerticalAlign.top
                            ? Alignment.topCenter
                            : (template.verticalAlign == VerticalAlign.bottom
                                  ? Alignment.bottomCenter
                                  : Alignment.center),
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          dummySlide.body,
                          textAlign: template.alignment,
                          style: TextStyle(
                            color: template.textColor,
                            fontSize: template.fontSize * 1.5,
                            fontWeight: template.isBold
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontStyle: template.isItalic
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),

                      // Overlay Accent
                      if (template.overlayAccent != Colors.transparent)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 20,
                          child: Container(color: template.overlayAccent),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
