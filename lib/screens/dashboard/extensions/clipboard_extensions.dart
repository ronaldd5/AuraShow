part of dashboard_screen;

/// Extension for clipboard operations (cut, copy, paste, delete, select all)
extension ClipboardExtensions on DashboardScreenState {
  // --- PUBLIC ACTIONS ---

  void copySelection() {
    // 1. Layer Priority: Copy specific selected layers
    if (_selectedLayerIds.isNotEmpty) {
      _copyLayers();
      return;
    }

    // 2. Slide Fallback: Copy the whole slide
    if (_hasSelection()) {
      _copySlides();
    }
  }

  void pasteSelection() {
    // 1. Layer Priority: Paste layers if we have them
    if (_clipboardLayers.isNotEmpty) {
      _pasteLayersToSlide(selectedSlideIndex);
      return;
    }

    // 2. Slide Fallback
    if (_clipboardSlides.isNotEmpty) {
      _pasteSlides();
    } else {
      _showSnack('Clipboard empty');
    }
  }

  /// THE NEW FEATURE: Pastes copied layers to EVERY slide in the show
  void pasteToAllSlides() {
    if (_clipboardLayers.isEmpty) {
      _showSnack('No layers copied! Select a layer and click Copy first.');
      return;
    }

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Paste to All Slides?'),
        content: Text(
          'This will add ${_clipboardLayers.length} layer(s) to all ${_slides.length} slides.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              _executePasteToAll();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // --- INTERNAL LOGIC (Layers) ---

  void _copyLayers() {
    final currentSlide = _slides[selectedSlideIndex];

    // Filter to only what is currently selected
    _clipboardLayers = currentSlide.layers
        .where((l) => _selectedLayerIds.contains(l.id))
        .map((l) => l.copyWith()) // Detach from original
        .toList();

    // Handle Background Selection
    if (_selectedLayerIds.contains('__BACKGROUND__')) {
      // 1. Check if there is an ACTUAL background layer (with filters, etc)
      final actualBg = currentSlide.layers.firstWhereOrNull(
        (l) => l.role == LayerRole.background,
      );

      if (actualBg != null) {
        _clipboardLayers.add(
          actualBg.copyWith(
            id: 'bg-pseudo-${DateTime.now().microsecondsSinceEpoch}',
          ),
        );
      } else {
        // 2. Fallback to legacy slide media fields
        _clipboardLayers.add(
          SlideLayer(
            id: 'bg-pseudo-${DateTime.now().microsecondsSinceEpoch}',
            label: 'Background',
            kind: LayerKind.media,
            role: LayerRole.background,
            path: currentSlide.mediaPath,
            mediaType: currentSlide.mediaType,
            boxColor: currentSlide.backgroundColor,
          ),
        );
      }
    }

    // NEW: System Clipboard Support (Enables Paste Replace)
    if (_clipboardLayers.isNotEmpty) {
      final json = jsonEncode({
        "type": "aurashow_layers",
        "data": _clipboardLayers.map((l) => l.toJson()).toList(),
      });
      Clipboard.setData(ClipboardData(text: json));
    }

    _clipboardSlides.clear(); // Clear slide buffer to avoid confusion
    _showSnack('Copied ${_clipboardLayers.length} layer(s)');
  }

  void _pasteLayersToSlide(int slideIndex, {bool selectAfter = true}) {
    if (slideIndex < 0 || slideIndex >= _slides.length) return;

    final targetSlide = _slides[slideIndex];

    // 1. Separate Background Pseudo-layers
    final bgLayer = _clipboardLayers.firstWhereOrNull(
      (l) => l.role == LayerRole.background,
    );

    // 2. Separate Normal Layers
    final normalLayers = _clipboardLayers.where(
      (l) => l.role != LayerRole.background,
    );

    var updatedSlide = targetSlide;

    // Apply Background if present
    if (bgLayer != null) {
      // Compatibility Sync
      updatedSlide = updatedSlide.copyWith(
        mediaPath: bgLayer.path,
        mediaType: bgLayer.mediaType,
        backgroundColor: bgLayer.boxColor,
      );

      // Replace existing background layer in the list if one exists
      final layersWithoutBg = updatedSlide.layers
          .where((l) => l.role != LayerRole.background)
          .toList();

      // The pasted background layer should have a new ID but keep its role
      final newBgLayer = bgLayer.copyWith(
        id: 'bg-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(999)}',
      );

      // Reconstruct layer list with new bg at bottom (index 0)
      final updatedLayerList = [newBgLayer, ...layersWithoutBg];
      updatedSlide = updatedSlide.copyWith(layers: updatedLayerList);
    }

    // Generate NEW unique IDs for Normal Layers
    final newLayers = normalLayers.map((l) {
      return l.copyWith(
        id: 'L-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(9999)}',
        left: (slideIndex == selectedSlideIndex)
            ? (l.left ?? 0) + 0.02
            : l.left,
        top: (slideIndex == selectedSlideIndex) ? (l.top ?? 0) + 0.02 : l.top,
      );
    }).toList();

    setState(() {
      // Add new foreground layers on top
      final finalLayerList = [...updatedSlide.layers, ...newLayers];
      _slides[slideIndex] = updatedSlide.copyWith(layers: finalLayerList);

      if (selectAfter && slideIndex == selectedSlideIndex) {
        final newIds = newLayers.map((l) => l.id).toSet();
        if (bgLayer != null) {
          // Find the ID we just gave the bg layer
          final actualBgId = _slides[slideIndex].layers
              .firstWhere((l) => l.role == LayerRole.background)
              .id;
          newIds.add(actualBgId);
          // Also add the virtual ID so the editor knows to show background props immediately
          newIds.add('__BACKGROUND__');
        }
        _selectedLayerIds = newIds;
        _editingLayerId = null;
      }
    });
  }

  void _executePasteToAll() {
    recordHistory();
    setState(() {
      final bgLayer = _clipboardLayers.firstWhereOrNull(
        (l) => l.role == LayerRole.background,
      );

      final normalLayers = _clipboardLayers
          .where((l) => l.role != LayerRole.background)
          .toList();

      for (int i = 0; i < _slides.length; i++) {
        var targetSlide = _slides[i];

        if (bgLayer != null) {
          // Compatibility Sync
          targetSlide = targetSlide.copyWith(
            mediaPath: bgLayer.path,
            mediaType: bgLayer.mediaType,
            backgroundColor: bgLayer.boxColor,
          );

          final layersWithoutBg = targetSlide.layers
              .where((l) => l.role != LayerRole.background)
              .toList();

          final newBgLayer = bgLayer.copyWith(
            id: 'bg-${DateTime.now().microsecondsSinceEpoch}-$i',
          );

          targetSlide = targetSlide.copyWith(
            layers: [newBgLayer, ...layersWithoutBg],
          );
        }

        final newLayers = normalLayers.map((l) {
          return l.copyWith(
            id: 'L-${DateTime.now().microsecondsSinceEpoch}-$i-${math.Random().nextInt(9999)}',
          );
        }).toList();

        final finalLayers = [...targetSlide.layers, ...newLayers];
        _slides[i] = targetSlide.copyWith(layers: finalLayers);
      }
    });

    _syncSlideThumbnails();
    _showSnack('Applied layer(s) to ${_slides.length} slides');
  }

  // ===========================================================================
  // NEW: POWER USER FEATURES
  // ===========================================================================

  /// FEATURE 1: Smart Duplicate (Ctrl+D)
  /// Instantly clones selection with an offset, without touching the clipboard.
  void duplicateSelection() {
    if (_selectedLayerIds.isEmpty) return;

    final currentSlide = _slides[selectedSlideIndex];

    // 1. Clone immediately
    final newLayers = currentSlide.layers
        .where((l) => _selectedLayerIds.contains(l.id))
        .map((l) {
          return l.copyWith(
            id: 'L-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(9999)}',
            // Smart Offset: Move it 2% down/right so it's visible
            left: (l.left ?? 0) + 0.02,
            top: (l.top ?? 0) + 0.02,
          );
        })
        .toList();

    setState(() {
      // 2. Add to slide
      final updatedLayers = List<SlideLayer>.from(currentSlide.layers)
        ..addAll(newLayers);
      _slides[selectedSlideIndex] = currentSlide.copyWith(
        layers: updatedLayers,
      );

      // 3. Auto-select the duplicates (so you can hit Ctrl+D again immediately)
      _selectedLayerIds = newLayers.map((l) => l.id).toSet();
      _editingLayerId = null;
    });
  }

  /// FEATURE 2: Copy Style (Format Painter)
  /// Grabs visual attributes (color, font, border) but ignores content/pos.
  void copyStyle() {
    if (_selectedLayerIds.isEmpty) return;

    // Grab the first selected layer as the "Master Style"
    final source = _slides[selectedSlideIndex].layers.firstWhere(
      (l) => l.id == _selectedLayerIds.first,
    );

    // Save to a specialized "Style Buffer" (add this variable to your State or make static)
    // For now, we can use a simpler approach by encoding a special JSON object
    final styleData = jsonEncode({
      "type": "aurashow_style",
      "style": {
        "textColor": source.textColor?.value,
        "fontFamily": source.fontFamily,
        "fontSize": source.fontSize,
        "isBold": source.isBold,
        "isItalic": source.isItalic,
        "boxColor": source.boxColor?.value,
        "boxBorderRadius": source.boxBorderRadius,
        "outlineColor": source.outlineColor?.value,
        "outlineWidth": source.outlineWidth,
        "opacity": source.opacity,
        "align": source.align?.name,
      },
    });

    Clipboard.setData(ClipboardData(text: styleData));
    _showSnack('Style copied 🎨');
  }

  /// FEATURE 2 Part B: Paste Style
  /// Applies the copied attributes to the CURRENT selection.
  Future<void> pasteStyle() async {
    if (_selectedLayerIds.isEmpty) {
      _showSnack('Select a layer to paste style onto');
      return;
    }

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;

    try {
      final json = jsonDecode(data!.text!);
      if (json['type'] != 'aurashow_style') return;
      final style = json['style'];

      setState(() {
        final currentSlide = _slides[selectedSlideIndex];
        final updatedLayers = currentSlide.layers.map((l) {
          if (_selectedLayerIds.contains(l.id)) {
            // APPLY STYLE OVERRIDES
            return l.copyWith(
              textColor: style['textColor'] != null
                  ? Color(style['textColor'])
                  : l.textColor,
              fontFamily: style['fontFamily'] ?? l.fontFamily,
              fontSize: (style['fontSize'] as num?)?.toDouble() ?? l.fontSize,
              isBold: style['isBold'] ?? l.isBold,
              isItalic: style['isItalic'] ?? l.isItalic,
              boxColor: style['boxColor'] != null
                  ? Color(style['boxColor'])
                  : l.boxColor,
              boxBorderRadius:
                  (style['boxBorderRadius'] as num?)?.toDouble() ??
                  l.boxBorderRadius,
              outlineColor: style['outlineColor'] != null
                  ? Color(style['outlineColor'])
                  : l.outlineColor,
              outlineWidth:
                  (style['outlineWidth'] as num?)?.toDouble() ?? l.outlineWidth,
              opacity: (style['opacity'] as num?)?.toDouble() ?? l.opacity,
              align: style['align'] != null
                  ? TextAlign.values.firstWhere((e) => e.name == style['align'])
                  : l.align,
            );
          }
          return l;
        }).toList();

        _slides[selectedSlideIndex] = currentSlide.copyWith(
          layers: updatedLayers,
        );
      });
      _showSnack('Style pasted!');
    } catch (e) {
      // Ignore invalid data
    }
  }

  /// FEATURE 3: Paste Replace
  /// Replaces the CONTENT (Text/Image) but keeps POSITION/STYLE
  Future<void> pasteReplace() async {
    if (_selectedLayerIds.length != 1) {
      _showSnack('Select exactly one layer to replace');
      return;
    }

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;

    // Is it a layer we copied?
    try {
      final json = jsonDecode(data!.text!);
      if (json['type'] == 'aurashow_layers') {
        final sourceLayer = SlideLayer.fromJson(json['data'][0]);

        setState(() {
          final currentSlide = _slides[selectedSlideIndex];
          final targetId = _selectedLayerIds.first;

          final updatedLayers = currentSlide.layers.map((l) {
            if (l.id == targetId) {
              // SWAP logic: Keep L's ID/Pos, take Source's Content
              return l.copyWith(
                text: sourceLayer.text,
                path: sourceLayer.path,
                mediaType: sourceLayer.mediaType,
                kind: sourceLayer.kind, // If swapping text -> image
              );
            }
            return l;
          }).toList();

          _slides[selectedSlideIndex] = currentSlide.copyWith(
            layers: updatedLayers,
          );
        });
        _showSnack('Content replaced 🔄');
      }
    } catch (_) {
      // It might be plain text from outside app
      setState(() {
        final currentSlide = _slides[selectedSlideIndex];
        final targetId = _selectedLayerIds.first;
        final updatedLayers = currentSlide.layers.map((l) {
          if (l.id == targetId && l.kind == LayerKind.textbox) {
            return l.copyWith(text: data!.text);
          }
          return l;
        }).toList();
        _slides[selectedSlideIndex] = currentSlide.copyWith(
          layers: updatedLayers,
        );
      });
      _showSnack('Text replaced');
    }
  }

  // --- LEGACY SLIDE OPERATIONS (Preserved) ---

  void _cutAction() {
    if (!_hasSelection()) return;
    _copySlides();
    _deleteAction();
    _showSnack('Cut selection');
  }

  void _copySlides() {
    if (!_hasSelection()) return;
    final indices = selectedSlides.isNotEmpty
        ? selectedSlides.toList()
        : [selectedSlideIndex];

    _clipboardSlides = [
      for (final i in indices.where((i) => i >= 0 && i < _slides.length))
        _slides[i].copyWith(),
    ];
    _clipboardLayers.clear(); // Clear layer buffer
    _showSnack('Copied ${_clipboardSlides.length} slide(s)');
  }

  void _pasteSlides() {
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
}
