// lib/screens/dashboard/widgets/slide_editor.dart

part of '../dashboard_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

extension SlideEditor on DashboardScreenState {
  Widget _buildEditorToolbar() {
    final hasLayerInClipboard = _clipboardLayers.isNotEmpty;
    final hasSelection = _selectedLayerIds.isNotEmpty;

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // COPY BUTTON
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy Selected (Ctrl+C)',
            onPressed: hasSelection ? copySelection : null,
            color: hasSelection ? Colors.white : Colors.white24,
          ),

          // PASTE BUTTON
          IconButton(
            icon: const Icon(Icons.paste, size: 18),
            tooltip: 'Paste (Ctrl+V)',
            onPressed: hasLayerInClipboard ? pasteSelection : null,
            color: hasLayerInClipboard ? Colors.white : Colors.white24,
          ),

          const VerticalDivider(color: Colors.white24, indent: 8, endIndent: 8),

          // PASTE TO ALL BUTTON (The "Magic" Button)
          TextButton.icon(
            icon: const Icon(
              Icons.copy_all,
              size: 18,
              color: AppPalette.accent,
            ),
            label: const Text(
              'Apply to All',
              style: TextStyle(fontSize: 12, color: AppPalette.accent),
            ),
            onPressed: hasLayerInClipboard ? pasteToAllSlides : null,
            style: TextButton.styleFrom(
              disabledForegroundColor: Colors.white10,
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
    return Focus(
      autofocus: true,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          final isCtrl = event.isControlPressed || event.isMetaPressed;
          if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyA) {
            if (hasSlide && slide != null) {
              setState(() {
                _selectedLayerIds = slide.layers.map((l) => l.id).toSet();
              });
              return KeyEventResult.handled;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.delete ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (hasSlide &&
                _selectedLayerIds.isNotEmpty &&
                _editingLayerId == null) {
              recordHistory();
              _deleteSelectedLayers();
              return KeyEventResult.handled;
            }
          }

          // UNDO (Ctrl + Z)
          if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
            if (event.isShiftPressed) {
              redo();
            } else {
              undo();
            }
            return KeyEventResult.handled;
          }

          // REDO (Ctrl + Y)
          if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
            redo();
            return KeyEventResult.handled;
          }

          // 1. DUPLICATE (Ctrl + D)
          if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyD) {
            duplicateSelection();
            return KeyEventResult.handled;
          }

          // 2. COPY STYLE (Ctrl + Shift + C)
          if (isCtrl &&
              event.isShiftPressed &&
              event.logicalKey == LogicalKeyboardKey.keyC) {
            copyStyle();
            return KeyEventResult.handled;
          }

          // 3. PASTE STYLE (Ctrl + Shift + V)
          if (isCtrl &&
              event.isShiftPressed &&
              event.logicalKey == LogicalKeyboardKey.keyV) {
            pasteStyle();
            return KeyEventResult.handled;
          }

          // 4. PASTE REPLACE (Ctrl + Shift + R)
          if (isCtrl &&
              event.isShiftPressed &&
              event.logicalKey == LogicalKeyboardKey.keyR) {
            pasteReplace();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: _frostedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _sectionHeader('Canvas'),
                const SizedBox(width: 16),
                _buildEditorToolbar(),
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
            Flexible(
              child: hasSlide
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        const double stageWidth = 1920;
                        const double stageHeight = 1080;
                        return Center(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: stageWidth,
                              height: stageHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppPalette.accent,
                                    width: 1,
                                  ),
                                ),
                                child: _buildEditableCanvas(slide!),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : !hasActiveShow
                  ? _emptyStageBox('Select a show from the Project Panel')
                  : _slides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.slideshow,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "This show has no slides",
                            style: TextStyle(color: Colors.white54),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text("Create First Slide"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                            onPressed: () {
                              _addNewSlide();
                            },
                          ),
                        ],
                      ),
                    )
                  : _emptyStageBox('No slide selected'),
            ),
            SizedBox(height: _drawerHeight + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCanvas(SlideContent slide) {
    final template = _templateFor(slide.templateId);
    final align = slide.alignOverride ?? template.alignment;
    final verticalAlign = slide.verticalAlign ?? VerticalAlign.middle;

    return LayoutBuilder(
      builder: (context, constraints) {
        // const double stageWidth = 1920; // Unused in fixed logic
        // const double stageHeight = 1080; // Unused in fixed logic
        final box = _resolvedBoxRect(slide);
        final boxLeft = box.left * constraints.maxWidth;
        final boxTop = box.top * constraints.maxHeight;
        final boxWidth = box.width * constraints.maxWidth;
        final boxHeight = box.height * constraints.maxHeight;
        final hasTextboxLayer = slide.layers.any(
          (l) => l.kind == LayerKind.textbox || l.kind == LayerKind.scripture,
        );
        final fgLayers = _foregroundLayers(slide);

        // FIXED: Return raw delta. The logic normalizes against constraints.maxWidth/Height
        // later, so we want the delta in the same coordinate space (Screen Pixels).
        Offset scaleDelta(Offset rawDelta) {
          return rawDelta;
        }

        final bool showDefaultTextbox =
            !hasTextboxLayer && (slide.body.trim().isNotEmpty);

        return DragTarget<Map<String, String>>(
          builder: (context, candidateData, rejectedData) {
            return MouseRegion(
              cursor: SystemMouseCursors.basic,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          final bgLayer = _backgroundLayerFor(slide);
                          if (bgLayer != null) {
                            if (_selectedLayerIds.contains('__BACKGROUND__')) {
                              _selectedLayerIds.clear();
                            } else {
                              _selectedLayerIds = {'__BACKGROUND__'};
                              _editingLayerId = null;
                              _slideEditorTabIndex = 2; // "Item" tab
                            }
                          } else {
                            _selectedLayerIds.clear();
                            _editingLayerId = null;
                            _slideEditorTabIndex = 3; // "Slide" tab
                          }
                        });
                      },
                      onSecondaryTapDown: (details) {
                        setState(() {
                          final bgLayer = _backgroundLayerFor(slide);
                          if (bgLayer != null) {
                            _selectedLayerIds = {'__BACKGROUND__'};
                            _slideEditorTabIndex = 2;
                          } else {
                            _selectedLayerIds.clear();
                            _slideEditorTabIndex = 3;
                          }
                          _editingLayerId = null;
                        });

                        final RenderBox overlay =
                            Overlay.of(context).context.findRenderObject()
                                as RenderBox;
                        final RelativeRect position = RelativeRect.fromRect(
                          Rect.fromPoints(
                            details.globalPosition,
                            details.globalPosition,
                          ),
                          Offset.zero & overlay.size,
                        );

                        showMenu(
                          context: context,
                          position: position,
                          color: AppPalette.surface,
                          items: <PopupMenuEntry<String>>[
                            if (_backgroundLayerFor(slide) != null)
                              PopupMenuItem(
                                value: 'copy',
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.copy,
                                      size: 18,
                                      color: Colors.white70,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Copy Background',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                                onTap: () => copySelection(),
                              ),
                            if (_backgroundLayerFor(slide) != null)
                              PopupMenuItem(
                                value: 'to_fg',
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.layers,
                                      size: 18,
                                      color: Colors.white70,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Bring to Foreground',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  final bgLayer = _backgroundLayerFor(slide);
                                  if (bgLayer != null) {
                                    _setLayerRole(
                                      bgLayer.id,
                                      LayerRole.foreground,
                                    );
                                  }
                                },
                              ),
                            if (_backgroundLayerFor(slide) != null)
                              PopupMenuItem(
                                value: 'copy_style',
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.palette,
                                      size: 18,
                                      color: Colors.white70,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Copy Style (Ctrl+Shift+C)',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                                onTap: () => copyStyle(),
                              ),
                            PopupMenuItem(
                              value: 'paste_style',
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.brush,
                                    size: 18,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Paste Style (Ctrl+Shift+V)',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              onTap: () => pasteStyle(),
                            ),
                            PopupMenuItem(
                              value: 'paste_replace',
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.swap_horiz,
                                    size: 18,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Paste Replace (Ctrl+Shift+R)',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              onTap: () => pasteReplace(),
                            ),
                            if (_clipboardLayers.isNotEmpty)
                              PopupMenuItem(
                                value: 'paste_all',
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.copy_all,
                                      size: 18,
                                      color: Colors.white70,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Paste to All Slides',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                                onTap: () => pasteToAllSlides(),
                              ),
                          ],
                        );
                      },
                      onPanStart: (details) {
                        recordHistory(
                          immediate: true,
                        ); // Save state before box selection/move begins
                        setState(() {
                          _isBoxSelecting = true;
                          _selectionRect = Rect.fromPoints(
                            details.localPosition,
                            details.localPosition,
                          );
                        });
                      },
                      onPanUpdate: (details) {
                        if (!_isBoxSelecting || _selectionRect == null) return;
                        setState(() {
                          _selectionRect = Rect.fromPoints(
                            _selectionRect!.topLeft,
                            details.localPosition,
                          );
                        });
                      },
                      onPanEnd: (details) {
                        if (!_isBoxSelecting || _selectionRect == null) return;
                        final selection = <String>{};
                        final box = _selectionRect!;

                        // Find intersecting layers
                        for (final layer in fgLayers) {
                          final lRect = _resolvedLayerRect(layer);
                          // Convert normalized layer rect to pixel space
                          final pixelRect = Rect.fromLTWH(
                            lRect.left * constraints.maxWidth,
                            lRect.top * constraints.maxHeight,
                            lRect.width * constraints.maxWidth,
                            lRect.height * constraints.maxHeight,
                          );

                          if (box.overlaps(pixelRect)) {
                            selection.add(layer.id);
                          }
                        }

                        // Handle Ctrl key for appending to selection
                        final isMulti = HardwareKeyboard
                            .instance
                            .logicalKeysPressed
                            .any(
                              (k) =>
                                  k == LogicalKeyboardKey.controlLeft ||
                                  k == LogicalKeyboardKey.controlRight ||
                                  k == LogicalKeyboardKey.metaLeft ||
                                  k == LogicalKeyboardKey.metaRight,
                            );

                        setState(() {
                          if (isMulti) {
                            _selectedLayerIds.addAll(selection);
                          } else {
                            _selectedLayerIds = selection;
                          }
                          _isBoxSelecting = false;
                          _selectionRect = null;
                        });
                      },
                      child: Container(
                        foregroundDecoration:
                            (_selectedLayerIds.contains('__BACKGROUND__') &&
                                _backgroundLayerFor(slide) != null)
                            ? BoxDecoration(
                                border: Border.all(
                                  color: AppPalette.accent,
                                  width: 2,
                                ),
                              )
                            : null,
                        child: _applyFilters(
                          _buildSlideBackground(slide, template),
                          slide,
                        ),
                      ),
                    ),
                  ),
                  for (final layer in fgLayers)
                    () {
                      final rect = _resolvedLayerRect(layer);
                      final layerLeft = rect.left * constraints.maxWidth;
                      final layerTop = rect.top * constraints.maxHeight;
                      final layerWidth = rect.width * constraints.maxWidth;
                      final layerHeight = rect.height * constraints.maxHeight;
                      final selected = _selectedLayerIds.contains(layer.id);
                      final editingLayer = _editingLayerId == layer.id;

                      return Positioned(
                        left: layerLeft,
                        top: layerTop,
                        width: layerWidth,
                        height: layerHeight,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onDoubleTap: () {
                              if (layer.kind == LayerKind.textbox ||
                                  showDefaultTextbox) {
                                setState(() {
                                  _editingLayerId = layer.id;
                                  _selectedLayerIds = {
                                    layer.id,
                                  }; // Ensure singular selection for edit
                                  _layerTextController.text = layer.text ?? '';
                                });
                              }
                            },
                            onSecondaryTapDown: (details) =>
                                _showLayerContextMenu(details, layer),
                            onTap: () {
                              final isMulti = HardwareKeyboard
                                  .instance
                                  .logicalKeysPressed
                                  .any(
                                    (k) =>
                                        k == LogicalKeyboardKey.controlLeft ||
                                        k == LogicalKeyboardKey.controlRight ||
                                        k == LogicalKeyboardKey.metaLeft ||
                                        k == LogicalKeyboardKey.metaRight,
                                  );

                              setState(() {
                                if (isMulti) {
                                  if (_selectedLayerIds.contains(layer.id)) {
                                    _selectedLayerIds.remove(layer.id);
                                  } else {
                                    _selectedLayerIds.add(layer.id);
                                  }
                                } else {
                                  if (!_selectedLayerIds.contains(layer.id)) {
                                    _selectedLayerIds = {layer.id};
                                  }
                                }

                                if (_editingLayerId != null &&
                                    !_selectedLayerIds.contains(
                                      _editingLayerId,
                                    )) {
                                  _editingLayerId = null;
                                  _layerTextController.clear();
                                }
                              });
                            },
                            onPanStart: (details) {
                              if (_isLayerResizing || editingLayer) return;

                              recordHistory(immediate: true);

                              setState(() {
                                // Ensure dragged item is selected if not already
                                if (!_selectedLayerIds.contains(layer.id)) {
                                  final isMulti = HardwareKeyboard
                                      .instance
                                      .logicalKeysPressed
                                      .any(
                                        (k) =>
                                            k ==
                                                LogicalKeyboardKey
                                                    .controlLeft ||
                                            k ==
                                                LogicalKeyboardKey
                                                    .controlRight ||
                                            k == LogicalKeyboardKey.metaLeft ||
                                            k == LogicalKeyboardKey.metaRight,
                                      );
                                  if (!isMulti) {
                                    _selectedLayerIds = {layer.id};
                                  } else {
                                    _selectedLayerIds.add(layer.id);
                                  }
                                }

                                _layerDragStartPointer = Offset.zero;
                                _layerDragAccum = Offset.zero;
                                _multiDragStartRects.clear();

                                // Record start positions for ALL selected layers
                                for (final l in slide.layers) {
                                  if (_selectedLayerIds.contains(l.id)) {
                                    _multiDragStartRects[l.id] =
                                        _resolvedLayerRect(l);
                                  }
                                }
                              });
                            },
                            onPanUpdate: (details) {
                              if (_isLayerResizing || editingLayer) return;
                              if (_multiDragStartRects.isEmpty) return;

                              _layerDragAccum += scaleDelta(details.delta);
                              final dx = _layerDragAccum.dx;
                              final dy = _layerDragAccum.dy;
                              final totalW = constraints.maxWidth;
                              final totalH = constraints.maxHeight;

                              // 1. Calculate Raw Position of PRIMARY Layer
                              // layer is the one captured by this GestureDetector
                              if (!_multiDragStartRects.containsKey(layer.id))
                                return;

                              final primaryStart =
                                  _multiDragStartRects[layer.id]!;
                              final rawLeft =
                                  (primaryStart.left * totalW + dx) / totalW;
                              final rawTop =
                                  (primaryStart.top * totalH + dy) / totalH;
                              final rawRect = Rect.fromLTWH(
                                rawLeft,
                                rawTop,
                                primaryStart.width,
                                primaryStart.height,
                              );

                              // 2. Snap PRIMARY Layer
                              // Others = All layers NOT in selection
                              final others = slide.layers
                                  .where(
                                    (l) => !_selectedLayerIds.contains(l.id),
                                  )
                                  .map((l) => _resolvedLayerRect(l))
                                  .toList();

                              final snapResult = _calculateSnapping(
                                currentRect: rawRect,
                                otherLayers: others,
                              );

                              // 3. Update Guides
                              setState(() {
                                _activeVGuides = snapResult.verticalGuides;
                                _activeHGuides = snapResult.horizontalGuides;
                              });

                              // 4. Calculate effective delta (normalized)
                              final effectiveDx =
                                  snapResult.rect.left - primaryStart.left;
                              final effectiveDy =
                                  snapResult.rect.top - primaryStart.top;

                              // 5. Apply effective delta to ALL selected layers
                              setState(() {
                                for (final l in slide.layers) {
                                  if (_multiDragStartRects.containsKey(l.id)) {
                                    final curStart =
                                        _multiDragStartRects[l.id]!;
                                    final newR = Rect.fromLTWH(
                                      curStart.left + effectiveDx,
                                      curStart.top + effectiveDy,
                                      curStart.width,
                                      curStart.height,
                                    );
                                    _setLayerRect(l, newR);
                                  }
                                }
                              });
                            },
                            onPanEnd: (_) {
                              if (_isLayerResizing || editingLayer) return;
                              setState(() {
                                _activeVGuides = [];
                                _activeHGuides = [];
                              });
                              _layerDragStartPointer = null;
                              _multiDragStartRects.clear();
                              _layerDragAccum = Offset.zero;
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Transform.rotate(
                                    angle:
                                        (layer.rotation ?? 0) *
                                        (3.1415926535 / 180),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: selected
                                            ? Border.all(
                                                color: accentPink,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: _buildLayerWidget(
                                        layer.copyWith(rotation: 0),
                                        slide: slide,
                                        fit: _mapFit(layer.fit),
                                      ),
                                    ),
                                  ),
                                ),
                                // Handles moved to Global Stack
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
                      child: GestureDetector(
                        onPanStart: (details) {
                          if (_isBoxResizing) return;
                          _boxDragStartRect = box;
                          _boxDragAccum = Offset.zero;
                        },
                        onPanUpdate: (details) {
                          if (_isBoxResizing) return;
                          if (_boxDragStartRect == null) return;
                          _boxDragAccum += scaleDelta(details.delta);
                          final totalW = constraints.maxWidth;
                          final totalH = constraints.maxHeight;
                          final dx = _boxDragAccum.dx;
                          final dy = _boxDragAccum.dy;
                          final newLeft =
                              (_boxDragStartRect!.left * totalW + dx) / totalW;
                          final newTop =
                              (_boxDragStartRect!.top * totalH + dy) / totalH;
                          final moved = Rect.fromLTWH(
                            newLeft,
                            newTop,
                            _boxDragStartRect!.width,
                            _boxDragStartRect!.height,
                          );
                          _setTextboxRect(_snapRect(moved, totalW, totalH));
                        },
                        child: Transform.rotate(
                          angle: (slide.rotation ?? 0) * (3.1415926535 / 180),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white30,
                                width: 1,
                              ),
                              color:
                                  (slide.boxBackgroundColor ?? Colors.black26),
                              borderRadius: BorderRadius.circular(
                                (slide.boxBorderRadius ?? 0).toDouble(),
                              ),
                            ),
                            child: Center(
                              child: ValueListenableBuilder<int>(
                                valueListenable: TextTokenService().ticker,
                                builder: (context, _, __) {
                                  final text = slide.body;
                                  final resolved =
                                      TextTokenService().hasTokens(text)
                                      ? TextTokenService().resolve(text)
                                      : text;

                                  return LiturgyTextRenderer.build(
                                    resolved,
                                    style: TextStyle(
                                      color:
                                          slide.textColorOverride ??
                                          template.textColor,
                                      fontSize: _autoSizedFont(
                                        slide,
                                        slide.fontSizeOverride ??
                                            template.fontSize,
                                        box,
                                      ),
                                    ),
                                    align: align,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Selected Layer Handles (Global)
                  // Drag Selection Box
                  if (_isBoxSelecting && _selectionRect != null)
                    Positioned.fromRect(
                      rect: _selectionRect!,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            border: Border.all(color: Colors.blue),
                          ),
                        ),
                      ),
                    ),

                  // Selected Layer Handles (Global)
                  if (_selectedLayerId != null)
                    Builder(
                      builder: (context) {
                        final layer = slide.layers.firstWhere(
                          (l) => l.id == _selectedLayerId,
                          // Use dummy if not found
                          orElse: () => SlideLayer(
                            id: 'dummy',
                            kind: LayerKind.textbox,
                            boxColor: Colors.transparent,
                            label: 'dummy',
                            role: LayerRole.foreground,
                          ),
                        );
                        if (layer.id == 'dummy') return const SizedBox.shrink();

                        // Re-calculate editing state for this layer
                        final editingLayer = _editingLayerId == layer.id;

                        final leftPx = (layer.left ?? 0) * constraints.maxWidth;
                        final topPx = (layer.top ?? 0) * constraints.maxHeight;
                        final widthPx =
                            (layer.width ?? 0) * constraints.maxWidth;
                        final heightPx =
                            (layer.height ?? 0) * constraints.maxHeight;
                        final globalRect = Rect.fromLTWH(
                          leftPx,
                          topPx,
                          widthPx,
                          heightPx,
                        );

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (!editingLayer)
                              ...buildResizeHandles(
                                rect: globalRect,
                                rotation: layer.rotation ?? 0,
                                scaleDelta: (d) => d,
                                onResize: (pos, delta) {
                                  if (_layerDragStartRect == null) return;
                                  // delta is incremental now
                                  _layerResizeAccum += delta;
                                  final startRect = _layerDragStartRect!;
                                  final resized = _resizeRectFromHandle(
                                    startRect,
                                    _layerResizeAccum,
                                    pos,
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                    aspectRatio: layer.kind == LayerKind.media
                                        ? 1.0
                                        : null,
                                  );
                                  _setLayerRect(layer, resized);
                                },
                                onStart: (pos) {
                                  setState(() {
                                    _isLayerResizing = true;
                                    _layerDragStartRect = _resolvedLayerRect(
                                      layer,
                                    );
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
                            if (!editingLayer &&
                                layer.kind == LayerKind.textbox)
                              buildRadiusHandle(
                                rect: globalRect,
                                radius: layer.boxBorderRadius ?? 0,
                                rotation: layer.rotation ?? 0,
                                scaleDelta: (d) => d,
                                onRadiusChanged: (v) {
                                  _updateLayerField(
                                    layer.id,
                                    (l) => l.copyWith(boxBorderRadius: v),
                                  );
                                },
                              ),
                            if (!editingLayer) ...[
                              buildRotateHandle(
                                rect: globalRect,
                                rotation: layer.rotation ?? 0,
                                scaleDelta: (d) => d,
                                alignment: Alignment.topLeft,
                                onRotationChanged: (v) {
                                  _updateLayerField(
                                    layer.id,
                                    (l) => l.copyWith(rotation: v),
                                  );
                                },
                              ),
                              buildRotateHandle(
                                rect: globalRect,
                                rotation: layer.rotation ?? 0,
                                scaleDelta: (d) => d,
                                alignment: Alignment.topRight,
                                onRotationChanged: (v) {
                                  _updateLayerField(
                                    layer.id,
                                    (l) => l.copyWith(rotation: v),
                                  );
                                },
                              ),
                              buildRotateHandle(
                                rect: globalRect,
                                rotation: layer.rotation ?? 0,
                                scaleDelta: (d) => d,
                                alignment: Alignment.bottomLeft,
                                onRotationChanged: (v) {
                                  _updateLayerField(
                                    layer.id,
                                    (l) => l.copyWith(rotation: v),
                                  );
                                },
                              ),
                              buildRotateHandle(
                                rect: globalRect,
                                rotation: layer.rotation ?? 0,
                                scaleDelta: (d) => d,
                                alignment: Alignment.bottomRight,
                                onRotationChanged: (v) {
                                  _updateLayerField(
                                    layer.id,
                                    (l) => l.copyWith(rotation: v),
                                  );
                                },
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                  if (showDefaultTextbox && _selectedLayerId == null) ...[
                    buildRadiusHandle(
                      rect: Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
                      radius: slide.boxBorderRadius ?? 0,
                      rotation: slide.rotation ?? 0,
                      scaleDelta: (d) => d,
                      onRadiusChanged: (v) {
                        safeSetState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                boxBorderRadius: v,
                              );
                        });
                      },
                    ),
                    buildRotateHandle(
                      rect: Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
                      rotation: slide.rotation ?? 0,
                      scaleDelta: (d) => d,
                      onRotationChanged: (v) {
                        safeSetState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(rotation: v);
                        });
                      },
                    ),
                  ],
                  // Snap Guides
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: SnapGuidePainter(
                        vGuides: _activeVGuides,
                        hGuides: _activeHGuides,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          onAccept: (Map<String, String> data) {
            final path = data['fullUrl'] ?? data['url'] ?? data['path'];
            if (path == null) return;
            // Logic to add layer
            _addMediaAsNewSlide(
              MediaEntry(
                id: 'dropped',
                title: 'Dropped',
                category: MediaFilter.images,
                icon: Icons.image,
                tint: Colors.white,
                isLive: false,
                badge: '',
                thumbnailUrl: path,
              ),
            );
          },
        );
      },
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

  // Note: Removed _pickMediaForSlide, _setTextboxRect helper, etc to rely on existing ones IF they exist as methods.
  // Actually, _setTextboxRect and _pickMediaForSlide ARE called above.
  // If they are not in DashboardScreenState (but in the user's extension), I need to include them OR ensure existing ones are accessible.
  // I will check if they exist in dashboard_screen.dart.
  // If not, I'll add them to this extension.
  // "setTextboxRect" was in user code. "pickMediaForSlide" was in user code.
}

// -----------------------------------------------------------------------------
// Magnetic Snapping Helpers
// -----------------------------------------------------------------------------

class SnapResult {
  final Rect rect;
  final List<double>
  verticalGuides; // X-coordinates to draw lines at (normalized 0-1)
  final List<double>
  horizontalGuides; // Y-coordinates to draw lines at (normalized 0-1)

  SnapResult(this.rect, this.verticalGuides, this.horizontalGuides);
}

// THE MAGNET LOGIC
SnapResult _calculateSnapping({
  required Rect currentRect,
  required List<Rect> otherLayers, // Pass in other objects to snap to
}) {
  double newLeft = currentRect.left;
  double newTop = currentRect.top;

  // The "Magnet Strength" (in % of stage). 0.01 = 1% (~19px on 1080p)
  const double threshold = 0.01;

  final vGuides = <double>[];
  final hGuides = <double>[];

  // --- VERTICAL SNAPPING (X-Axis) ---

  // 1. Center of Stage
  if ((currentRect.center.dx - 0.5).abs() < threshold) {
    newLeft = 0.5 - (currentRect.width / 2);
    vGuides.add(0.5);
  }
  // 2. Left Edge of Stage
  else if ((currentRect.left - 0.0).abs() < threshold) {
    newLeft = 0.0;
    vGuides.add(0.0);
  }
  // 3. Right Edge of Stage
  else if ((currentRect.right - 1.0).abs() < threshold) {
    newLeft = 1.0 - currentRect.width;
    vGuides.add(1.0);
  }

  // --- HORIZONTAL SNAPPING (Y-Axis) ---

  // 1. Center of Stage
  if ((currentRect.center.dy - 0.5).abs() < threshold) {
    newTop = 0.5 - (currentRect.height / 2);
    hGuides.add(0.5);
  }
  // 2. Top Edge of Stage
  else if ((currentRect.top - 0.0).abs() < threshold) {
    newTop = 0.0;
    hGuides.add(0.0);
  }
  // 3. Bottom Edge of Stage
  else if ((currentRect.bottom - 1.0).abs() < threshold) {
    newTop = 1.0 - currentRect.height;
    hGuides.add(1.0);
  }

  // --- OBJECT-TO-OBJECT SNAPPING ---
  for (final other in otherLayers) {
    // Left align with others
    if ((currentRect.left - other.left).abs() < threshold) {
      newLeft = other.left;
      vGuides.add(other.left);
    }
    // Right align with others
    if ((currentRect.right - other.right).abs() < threshold) {
      newLeft = other.right - currentRect.width;
      vGuides.add(other.right);
    }
    // Top align with others
    if ((currentRect.top - other.top).abs() < threshold) {
      newTop = other.top;
      hGuides.add(other.top);
    }
    // Bottom align with others
    if ((currentRect.bottom - other.bottom).abs() < threshold) {
      newTop = other.bottom - currentRect.height;
      hGuides.add(other.bottom);
    }
    // Center Align X
    if ((currentRect.center.dx - other.center.dx).abs() < threshold) {
      newLeft = other.center.dx - (currentRect.width / 2);
      vGuides.add(other.center.dx);
    }
    // Center Align Y
    if ((currentRect.center.dy - other.center.dy).abs() < threshold) {
      newTop = other.center.dy - (currentRect.height / 2);
      hGuides.add(other.center.dy);
    }
  }

  return SnapResult(
    Rect.fromLTWH(newLeft, newTop, currentRect.width, currentRect.height),
    vGuides,
    hGuides,
  );
}

class SnapGuidePainter extends CustomPainter {
  final List<double> vGuides;
  final List<double> hGuides;

  SnapGuidePainter({required this.vGuides, required this.hGuides});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw Vertical Lines
    for (final xPercent in vGuides) {
      final x = xPercent * size.width;
      _drawDashedLine(canvas, paint, Offset(x, 0), Offset(x, size.height));
    }

    // Draw Horizontal Lines
    for (final yPercent in hGuides) {
      final y = yPercent * size.height;
      _drawDashedLine(canvas, paint, Offset(0, y), Offset(size.width, y));
    }
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset p1, Offset p2) {
    const dashWidth = 5;
    const dashSpace = 3;
    double distance = (p2 - p1).distance;
    double startY = 0;

    // Vertical
    if (p1.dx == p2.dx) {
      while (startY < distance) {
        canvas.drawLine(
          Offset(p1.dx, startY),
          Offset(p1.dx, startY + dashWidth),
          paint,
        );
        startY += dashWidth + dashSpace;
      }
    }
    // Horizontal
    else {
      double startX = 0;
      while (startX < distance) {
        canvas.drawLine(
          Offset(startX, p1.dy),
          Offset(startX + dashWidth, p1.dy),
          paint,
        );
        startX += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SnapGuidePainter oldDelegate) {
    return oldDelegate.vGuides != vGuides || oldDelegate.hGuides != hGuides;
  }
}
