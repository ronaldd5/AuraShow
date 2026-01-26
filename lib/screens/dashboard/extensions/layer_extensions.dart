part of '../dashboard_screen.dart';

extension LayerExtensions on DashboardScreenState {
  // --- Layer Management Helpers (Re-implemented) ---

  void _reorderLayers(int oldIndex, int newIndex) {
    if (selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    safeSetState(() {
      final slide = _slides[selectedSlideIndex];
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final layers = List<SlideLayer>.from(slide.layers);
      final item = layers.removeAt(oldIndex);
      layers.insert(newIndex, item);
      _slides[selectedSlideIndex] = slide.copyWith(
        layers: layers,
        modifiedAt: DateTime.now(),
      );
    });
  }

  void _deleteLayer(String layerId) {
    if (selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    safeSetState(() {
      final slide = _slides[selectedSlideIndex];
      final layers = slide.layers.where((l) => l.id != layerId).toList();
      _slides[selectedSlideIndex] = slide.copyWith(
        layers: layers,
        modifiedAt: DateTime.now(),
      );
      if (_editingLayerId == layerId) {
        _editingLayerId = null;
      }
      _selectedLayerIds.remove(layerId);
    });
  }

  void _deleteSelectedLayers() {
    if (selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    if (_selectedLayerIds.isEmpty) return;

    safeSetState(() {
      final slide = _slides[selectedSlideIndex];
      final layers = slide.layers
          .where((l) => !_selectedLayerIds.contains(l.id))
          .toList();
      _slides[selectedSlideIndex] = slide.copyWith(
        layers: layers,
        modifiedAt: DateTime.now(),
      );

      _editingLayerId = null;
      _selectedLayerIds.clear();
    });
  }

  void _nudgeLayer(int index, int delta) {
    if (selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    final slide = _slides[selectedSlideIndex];
    final newIndex = (index + delta).clamp(0, slide.layers.length - 1);
    if (newIndex != index) {
      _reorderLayers(index, delta > 0 ? newIndex + 1 : newIndex);
    }
  }

  void _setLayerRole(String layerId, LayerRole role) {
    recordHistory();
    _updateLayerField(layerId, (l) => l.copyWith(role: role));
  }

  IconData _layerIcon(SlideLayer layer) {
    switch (layer.kind) {
      case LayerKind.textbox:
        return Icons.title;
      case LayerKind.media:
        return Icons.image;
      case LayerKind.camera:
        return Icons.videocam;
      case LayerKind.screen:
        return Icons.desktop_windows;
      case LayerKind.clock:
        return Icons.access_time;
      case LayerKind.timer:
        return Icons.timer;
      case LayerKind.website:
        return Icons.language;
      case LayerKind.qr:
        return Icons.qr_code;
      case LayerKind.progress:
        return Icons.percent;
      case LayerKind.events:
        return Icons.event;
      case LayerKind.weather:
        return Icons.cloud;
      case LayerKind.visualizer:
        return Icons.graphic_eq;
      case LayerKind.captions:
        return Icons.closed_caption;
      case LayerKind.icon:
        return Icons.star;
      case LayerKind.shader:
        return Icons.gradient;
      case LayerKind.scripture:
        return Icons.menu_book;
      default:
        return Icons.layers;
    }
  }

  String LayerKindLabel(SlideLayer layer) {
    switch (layer.kind) {
      case LayerKind.textbox:
        return 'Text Box';
      case LayerKind.media:
        return 'Media';
      case LayerKind.camera:
        return 'Camera';
      case LayerKind.screen:
        return 'Screen Capture';
      case LayerKind.clock:
        return 'Clock';
      case LayerKind.timer:
        return 'Timer';
      case LayerKind.website:
        return 'Website';
      case LayerKind.qr:
        return 'QR Code';
      case LayerKind.shader:
        return 'Shader';
      case LayerKind.scripture:
        return 'Scripture';
      default:
        return layer.kind.name[0].toUpperCase() + layer.kind.name.substring(1);
    }
  }

  SlideLayer? _backgroundLayerFor(SlideContent slide) {
    try {
      return slide.layers.firstWhere((l) => l.role == LayerRole.background);
    } catch (_) {
      return null;
    }
  }

  void _clearSlideMedia() {
    if (selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    final slide = _slides[selectedSlideIndex];
    final bgLayer = _backgroundLayerFor(slide);
    safeSetState(() {
      if (bgLayer != null) {
        _deleteLayer(bgLayer.id);
      } else {
        // Clear legacy media fields
        _slides[selectedSlideIndex] = slide.copyWith(
          mediaPath: '',
          mediaType: null,
          modifiedAt: DateTime.now(),
        );
      }
    });
  }

  Future<void> _pickMediaForSlide(SlideMediaType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: type == SlideMediaType.video ? FileType.video : FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      _addMediaLayer(path, type);
    }
  }

  void _addMediaLayer(String path, SlideMediaType type) {
    if (selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    safeSetState(() {
      final slide = _slides[selectedSlideIndex];
      final layer = SlideLayer(
        id: 'layer-${DateTime.now().microsecondsSinceEpoch}',
        label: _fileName(path),
        kind: LayerKind.media,
        role: LayerRole.foreground,
        path: path,
        mediaType: type,
        left: 0.2,
        top: 0.2,
        width: 0.6,
        height: 0.6,
      );
      final updated = [...slide.layers, layer];
      _slides[selectedSlideIndex] = slide.copyWith(
        layers: updated,
        modifiedAt: DateTime.now(),
      );
    });
  }

  void _hydrateLegacyLayers(int index) {
    if (index < 0 || index >= _slides.length) return;
    final slide = _slides[index];
    if (!_hydratedLayerSlides.contains(slide.id)) {
      safeSetState(() {
        _hydratedLayerSlides.add(slide.id);
      });
    }
  }

  // --- Extracted UI Logic ---

  Widget _itemTab() {
    if (selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length)
      return const SizedBox();

    final slide = _slides[selectedSlideIndex];
    final template = _templates.firstWhere(
      (t) => t.id == slide.templateId,
      orElse: () => _templates.first,
    );
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
                              selectedLayer.role == LayerRole.background
                              ? accentBlue.withOpacity(0.2)
                              : accentPink.withOpacity(0.2),
                          child: Icon(
                            _layerIcon(selectedLayer),
                            size: 16,
                            color: selectedLayer.role == LayerRole.background
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
                                LayerKindLabel(selectedLayer),
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
                        selectedLayer.role == LayerRole.background,
                        selectedLayer.role == LayerRole.foreground,
                      ],
                      onPressed: (i) {
                        final role = i == 0
                            ? LayerRole.background
                            : LayerRole.foreground;
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
                      onChangeStart: (_) => recordHistory(immediate: true),
                      onChanged: (v) {
                        _updateLayerField(
                          selectedLayer.id,
                          (layer) => layer.copyWith(opacity: v),
                        );
                      },
                    ),
                    if (selectedLayer.kind == LayerKind.media) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Fit to box',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: selectedLayer.fit ?? 'cover',
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          filled: true,
                          fillColor: Colors.white10,
                        ),
                        dropdownColor: bgMedium,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'cover',
                            child: Text('Cover'),
                          ),
                          DropdownMenuItem(
                            value: 'contain',
                            child: Text('Contain'),
                          ),
                          DropdownMenuItem(value: 'fill', child: Text('Fill')),
                          DropdownMenuItem(
                            value: 'fitWidth',
                            child: Text('Fit Width'),
                          ),
                          DropdownMenuItem(
                            value: 'fitHeight',
                            child: Text('Fit Height'),
                          ),
                          DropdownMenuItem(value: 'none', child: Text('None')),
                        ],
                        onChanged: (v) {
                          recordHistory();
                          if (v == null) return;
                          _updateLayerField(
                            selectedLayer.id,
                            (layer) => layer.copyWith(fit: v),
                          );
                        },
                      ),
                    ],
                    if (selectedLayer.kind == LayerKind.media &&
                        selectedLayer.role == LayerRole.foreground)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _setLayerRole(
                            selectedLayer.id,
                            LayerRole.background,
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
          // Show text styling only when a TEXTBOX LAYER IS SELECTED
          if (selectedLayer != null &&
              (selectedLayer.kind == LayerKind.textbox ||
                  selectedLayer.kind == LayerKind.clock ||
                  selectedLayer.kind == LayerKind.weather)) ...[
            _sectionHeader('Text styling'),
            const SizedBox(height: 6),
            _frostedBox(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Font Family Dropdown
                    Text(
                      'Font Family',
                      style: TextStyle(color: accentPink, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String?>(
                      value: _allFonts.contains(selectedLayer.fontFamily)
                          ? selectedLayer.fontFamily
                          : null,
                      decoration: const InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      dropdownColor: bgMedium,
                      iconEnabledColor: Colors.white70,
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Use template default'),
                        ),
                        ..._allFonts
                            .where((f) => f != null)
                            .map(
                              (f) => DropdownMenuItem<String?>(
                                value: f,
                                child: Text(
                                  f!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: f,
                                  ),
                                ),
                              ),
                            ),
                      ],
                      onChanged: (value) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(fontFamily: value),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    if (selectedLayer.kind == LayerKind.textbox) ...[
                      Text(
                        'Font Size',
                        style: TextStyle(color: accentPink, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: (selectedLayer.fontSize ?? 48)
                                  .clamp(8, 200)
                                  .toDouble(),
                              min: 8,
                              max: 200,
                              activeColor: accentPink,
                              inactiveColor: Colors.white24,
                              onChangeStart: (_) =>
                                  recordHistory(immediate: true),
                              onChanged: (value) {
                                _updateLayerField(
                                  selectedLayer.id,
                                  (l) => l.copyWith(fontSize: value),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            child: Text(
                              (selectedLayer.fontSize ?? 48).toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 12),

                    // Style Toggles & Alignment
                    Row(
                      children: [
                        // Bold
                        IconButton(
                          icon: Icon(
                            Icons.format_bold,
                            color: (selectedLayer.isBold ?? false)
                                ? accentPink
                                : Colors.white70,
                          ),
                          onPressed: () => _updateLayerField(
                            selectedLayer.id,
                            (l) => l.copyWith(isBold: !(l.isBold ?? false)),
                          ),
                          tooltip: 'Bold',
                        ),
                        // Italic
                        IconButton(
                          icon: Icon(
                            Icons.format_italic,
                            color: (selectedLayer.isItalic ?? false)
                                ? accentPink
                                : Colors.white70,
                          ),
                          onPressed: () => _updateLayerField(
                            selectedLayer.id,
                            (l) => l.copyWith(isItalic: !(l.isItalic ?? false)),
                          ),
                          tooltip: 'Italic',
                        ),
                        // Underline
                        IconButton(
                          icon: Icon(
                            Icons.format_underline,
                            color: (selectedLayer.isUnderline ?? false)
                                ? accentPink
                                : Colors.white70,
                          ),
                          onPressed: () => _updateLayerField(
                            selectedLayer.id,
                            (l) => l.copyWith(
                              isUnderline: !(l.isUnderline ?? false),
                            ),
                          ),
                          tooltip: 'Underline',
                        ),
                        const Spacer(),
                        // Alignment
                        ToggleButtons(
                          isSelected: [
                            selectedLayer.align == TextAlign.left,
                            selectedLayer.align == TextAlign.center,
                            selectedLayer.align == TextAlign.right,
                          ],
                          onPressed: (index) {
                            final align = [
                              TextAlign.left,
                              TextAlign.center,
                              TextAlign.right,
                            ][index];
                            _updateLayerField(
                              selectedLayer!.id,
                              (l) => l.copyWith(align: align),
                            );
                          },
                          color: Colors.white30,
                          selectedColor: accentPink,
                          fillColor: accentPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          constraints: const BoxConstraints(
                            minHeight: 32,
                            minWidth: 32,
                          ),
                          children: const [
                            Icon(Icons.format_align_left, size: 18),
                            Icon(Icons.format_align_center, size: 18),
                            Icon(Icons.format_align_right, size: 18),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Text Color
                    Row(
                      children: [
                        Text(
                          'Text Color',
                          style: TextStyle(color: accentPink, fontSize: 12),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDialog<Color>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Text Color'),
                                content: SingleChildScrollView(
                                  child: BlockPicker(
                                    pickerColor:
                                        selectedLayer.textColor ?? Colors.white,
                                    onColorChanged: (c) =>
                                        Navigator.pop(context, c),
                                  ),
                                ),
                              ),
                            );
                            if (picked != null) {
                              _updateLayerField(
                                selectedLayer.id,
                                (l) => l.copyWith(textColor: picked),
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                selectedLayer.textColor ?? Colors.white,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Divider(color: Colors.white12),
                    const SizedBox(height: 12),

                    // Box Styling
                    Text(
                      'Box Styling',
                      style: TextStyle(color: accentPink, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: (selectedLayer.boxPadding ?? 0)
                                .toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Padding',
                              isDense: true,
                              border: OutlineInputBorder(),
                              suffixText: 'px',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final val = double.tryParse(v);
                              if (val != null) {
                                _updateLayerField(
                                  selectedLayer.id,
                                  (l) => l.copyWith(boxPadding: val),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: (selectedLayer.outlineWidth ?? 0)
                                .toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Outline',
                              isDense: true,
                              border: OutlineInputBorder(),
                              suffixText: 'px',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final val = double.tryParse(v);
                              if (val != null) {
                                _updateLayerField(
                                  selectedLayer.id,
                                  (l) => l.copyWith(outlineWidth: val),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (selectedLayer != null &&
              selectedLayer.kind == LayerKind.weather) ...[
            const SizedBox(height: 12),
            _sectionHeader('Weather Settings'),
            const SizedBox(height: 6),
            _frostedBox(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: selectedLayer.weatherCity ?? '',
                      decoration: const InputDecoration(
                        labelText: 'City',
                        hintText: 'e.g. New York',
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(weatherCity: val),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text(
                        'Use Celsius',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: selectedLayer.weatherCelsius ?? false,
                      activeColor: accentPink,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(weatherCelsius: val),
                        );
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Show Condition',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: selectedLayer.weatherShowCondition ?? false,
                      activeColor: accentPink,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(weatherShowCondition: val),
                        );
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Show Humidity',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: selectedLayer.weatherShowHumidity ?? false,
                      activeColor: accentPink,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(weatherShowHumidity: val),
                        );
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Show Wind',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: selectedLayer.weatherShowWind ?? false,
                      activeColor: accentPink,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(weatherShowWind: val),
                        );
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Show Feels Like',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: selectedLayer.weatherShowFeelsLike ?? false,
                      activeColor: accentPink,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(weatherShowFeelsLike: val),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Visualizer Settings
          if (selectedLayer != null &&
              selectedLayer.kind == LayerKind.visualizer) ...[
            const SizedBox(height: 12),
            _sectionHeader('Visualizer Settings'),
            const SizedBox(height: 6),
            _frostedBox(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview Mode Toggle
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (selectedLayer.visualizerPreviewMode ?? false)
                            ? accentPink.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (selectedLayer.visualizerPreviewMode ?? false)
                              ? accentPink
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            (selectedLayer.visualizerPreviewMode ?? false)
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color:
                                (selectedLayer.visualizerPreviewMode ?? false)
                                ? accentPink
                                : Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Preview Mode',
                                  style: TextStyle(
                                    color:
                                        (selectedLayer.visualizerPreviewMode ??
                                            false)
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  (selectedLayer.visualizerPreviewMode ?? false)
                                      ? 'Showing simulated audio'
                                      : 'Waiting for audio',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: selectedLayer.visualizerPreviewMode ?? false,
                            activeColor: accentPink,
                            onChanged: (val) {
                              _updateLayerField(
                                selectedLayer.id,
                                (l) => l.copyWith(visualizerPreviewMode: val),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Audio Source Selector
                    const Text(
                      'Audio Source Type',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _audioSourceChip(
                          selectedLayer,
                          'app_audio',
                          'App Audio',
                          Icons.music_note,
                        ),
                        _audioSourceChip(
                          selectedLayer,
                          'system_audio',
                          'System Audio',
                          Icons.computer,
                        ),
                        _audioSourceChip(
                          selectedLayer,
                          'microphone',
                          'Microphone',
                          Icons.mic,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Audio Device Dropdown
                    const Text(
                      'Audio Device',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    _buildAudioDeviceDropdown(selectedLayer),
                    const Divider(color: Colors.white24, height: 24),
                    // Visualizer Type Selector
                    const Text(
                      'Visualizer Type',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _visualizerTypeChip(
                          selectedLayer,
                          'bars',
                          'Bars',
                          Icons.bar_chart,
                        ),
                        _visualizerTypeChip(
                          selectedLayer,
                          'waveform',
                          'Wave',
                          Icons.waves,
                        ),
                        _visualizerTypeChip(
                          selectedLayer,
                          'circular',
                          'Circular',
                          Icons.radio_button_unchecked,
                        ),
                        _visualizerTypeChip(
                          selectedLayer,
                          'particles',
                          'Particles',
                          Icons.bubble_chart,
                        ),
                        _visualizerTypeChip(
                          selectedLayer,
                          'spectrum',
                          'Spectrum',
                          Icons.area_chart,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Bar Count
                    Text(
                      'Bar Count: ${selectedLayer.visualizerBarCount ?? 32}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Slider(
                      value: (selectedLayer.visualizerBarCount ?? 32)
                          .toDouble(),
                      min: 8,
                      max: 128,
                      divisions: 15,
                      activeColor: accentPink,
                      onChangeStart: (_) => recordHistory(immediate: true),
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(visualizerBarCount: val.toInt()),
                        );
                      },
                    ),
                    // Sensitivity
                    Text(
                      'Sensitivity: ${(selectedLayer.visualizerSensitivity ?? 1.0).toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Slider(
                      value: selectedLayer.visualizerSensitivity ?? 1.0,
                      min: 0.1,
                      max: 3.0,
                      activeColor: accentPink,
                      onChangeStart: (_) => recordHistory(immediate: true),
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(visualizerSensitivity: val),
                        );
                      },
                    ),
                    // Smoothing
                    Text(
                      'Smoothing: ${((selectedLayer.visualizerSmoothing ?? 0.5) * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Slider(
                      value: selectedLayer.visualizerSmoothing ?? 0.5,
                      min: 0.0,
                      max: 1.0,
                      activeColor: accentPink,
                      onChangeStart: (_) => recordHistory(immediate: true),
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(visualizerSmoothing: val),
                        );
                      },
                    ),
                    const Divider(color: Colors.white24),
                    // Color Mode
                    const Text(
                      'Color Mode',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _colorModeChip(selectedLayer, 'solid', 'Solid'),
                        _colorModeChip(selectedLayer, 'gradient', 'Gradient'),
                        _colorModeChip(selectedLayer, 'rainbow', 'Rainbow'),
                        _colorModeChip(selectedLayer, 'reactive', 'Reactive'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Colors
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Color 1',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  _openShaderColorPicker(
                                    context,
                                    selectedLayer.visualizerColor1 ??
                                        Colors.cyan,
                                    (c) {
                                      _updateLayerField(
                                        selectedLayer.id,
                                        (l) => l.copyWith(visualizerColor1: c),
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color:
                                        selectedLayer.visualizerColor1 ??
                                        Colors.cyan,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Color 2',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  _openShaderColorPicker(
                                    context,
                                    selectedLayer.visualizerColor2 ??
                                        Colors.purple,
                                    (c) {
                                      _updateLayerField(
                                        selectedLayer.id,
                                        (l) => l.copyWith(visualizerColor2: c),
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color:
                                        selectedLayer.visualizerColor2 ??
                                        Colors.purple,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24),
                    // Effects
                    SwitchListTile(
                      title: const Text(
                        'Mirror Effect',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      value: selectedLayer.visualizerMirror ?? false,
                      activeColor: accentPink,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(visualizerMirror: val),
                        );
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Glow Effect',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      value: selectedLayer.visualizerGlow ?? true,
                      activeColor: accentPink,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(visualizerGlow: val),
                        );
                      },
                    ),
                    if (selectedLayer.visualizerGlow ?? true) ...[
                      Text(
                        'Glow Intensity: ${(selectedLayer.visualizerGlowIntensity ?? 1.0).toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      Slider(
                        value: selectedLayer.visualizerGlowIntensity ?? 1.0,
                        min: 0.1,
                        max: 2.0,
                        activeColor: accentPink,
                        onChangeStart: (_) => recordHistory(immediate: true),
                        onChanged: (val) {
                          _updateLayerField(
                            selectedLayer.id,
                            (l) => l.copyWith(visualizerGlowIntensity: val),
                          );
                        },
                      ),
                    ],
                    SwitchListTile(
                      title: const Text(
                        'Filled',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      value: selectedLayer.visualizerFilled ?? true,
                      activeColor: accentPink,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(visualizerFilled: val),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Line Width
                    Text(
                      'Line Width: ${(selectedLayer.visualizerLineWidth ?? 4.0).toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Slider(
                      value: selectedLayer.visualizerLineWidth ?? 4.0,
                      min: 1.0,
                      max: 20.0,
                      activeColor: accentPink,
                      onChangeStart: (_) => recordHistory(immediate: true),
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(visualizerLineWidth: val),
                        );
                      },
                    ),
                    // Gap
                    Text(
                      'Gap: ${(selectedLayer.visualizerGap ?? 2.0).toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Slider(
                      value: selectedLayer.visualizerGap ?? 2.0,
                      min: 0.0,
                      max: 10.0,
                      activeColor: accentPink,
                      onChangeStart: (_) => recordHistory(immediate: true),
                      onChanged: (val) {
                        _updateLayerField(
                          selectedLayer.id,
                          (l) => l.copyWith(visualizerGap: val),
                        );
                      },
                    ),
                    // Circular-specific settings
                    if (selectedLayer.visualizerType == 'circular') ...[
                      const Divider(color: Colors.white24),
                      Text(
                        'Inner Radius: ${((selectedLayer.visualizerRadius ?? 0.3) * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      Slider(
                        value: selectedLayer.visualizerRadius ?? 0.3,
                        min: 0.1,
                        max: 0.8,
                        activeColor: accentPink,
                        onChangeStart: (_) => recordHistory(immediate: true),
                        onChanged: (val) {
                          _updateLayerField(
                            selectedLayer.id,
                            (l) => l.copyWith(visualizerRadius: val),
                          );
                        },
                      ),
                      Text(
                        'Rotation Speed: ${(selectedLayer.visualizerRotationSpeed ?? 0.5).toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      Slider(
                        value: selectedLayer.visualizerRotationSpeed ?? 0.5,
                        min: 0.0,
                        max: 3.0,
                        activeColor: accentPink,
                        onChangeStart: (_) => recordHistory(immediate: true),
                        onChanged: (val) {
                          _updateLayerField(
                            selectedLayer.id,
                            (l) => l.copyWith(visualizerRotationSpeed: val),
                          );
                        },
                      ),
                    ],
                    const Divider(color: Colors.white24),
                    // Frequency Range
                    const Text(
                      'Frequency Range',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _frequencyRangeChip(selectedLayer, 'full', 'Full'),
                        _frequencyRangeChip(selectedLayer, 'bass', 'Bass'),
                        _frequencyRangeChip(selectedLayer, 'mid', 'Mids'),
                        _frequencyRangeChip(selectedLayer, 'treble', 'Treble'),
                      ],
                    ),
                    // Shape
                    const SizedBox(height: 12),
                    const Text(
                      'Shape',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _shapeChip(selectedLayer, 'rounded', 'Rounded'),
                        _shapeChip(selectedLayer, 'rectangle', 'Sharp'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (selectedLayer != null &&
              selectedLayer.kind == LayerKind.shader) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shader Settings',
                    style: TextStyle(color: accentPink, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  // Speed
                  Text(
                    'Speed: ${(selectedLayer!.shaderParams?['speed'] ?? 1.0).toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Slider(
                    value: selectedLayer!.shaderParams?['speed'] ?? 1.0,
                    min: 0.1,
                    max: 5.0,
                    activeColor: accentPink,
                    onChangeStart: (_) => recordHistory(immediate: true),
                    onChanged: (val) {
                      _updateLayerField(selectedLayer!.id, (l) {
                        final params = Map<String, double>.from(
                          l.shaderParams ?? {},
                        );
                        params['speed'] = val;
                        return l.copyWith(shaderParams: params);
                      });
                    },
                  ),
                  // Intensity
                  Text(
                    'Audio Intensity: ${(selectedLayer!.shaderParams?['intensity'] ?? 1.0).toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Slider(
                    value: selectedLayer!.shaderParams?['intensity'] ?? 1.0,
                    min: 0.0,
                    max: 5.0,
                    activeColor: accentPink,
                    onChangeStart: (_) => recordHistory(immediate: true),
                    onChanged: (val) {
                      _updateLayerField(selectedLayer!.id, (l) {
                        final params = Map<String, double>.from(
                          l.shaderParams ?? {},
                        );
                        params['intensity'] = val;
                        return l.copyWith(shaderParams: params);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  // Colors
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Color 1',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                _openShaderColorPicker(
                                  context,
                                  selectedLayer!.boxColor ?? Colors.purple,
                                  (c) {
                                    _updateLayerField(
                                      selectedLayer!.id,
                                      (l) => l.copyWith(boxColor: c),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                height: 30,
                                decoration: BoxDecoration(
                                  color:
                                      selectedLayer!.boxColor ?? Colors.purple,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Color 2',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                _openShaderColorPicker(
                                  context,
                                  selectedLayer!.outlineColor ?? Colors.blue,
                                  (c) {
                                    _updateLayerField(
                                      selectedLayer!.id,
                                      (l) => l.copyWith(outlineColor: c),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                height: 30,
                                decoration: BoxDecoration(
                                  color:
                                      selectedLayer!.outlineColor ??
                                      Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Import
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Import .frag File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: const Color(0xFF2A2A2A),
                          title: const Text(
                            'Importing Shaders',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            'To add a new shader:\n1. Place your .frag file in the "shaders/" folder.\n2. Add it to pubspec.yaml.\n3. Restart the app.\n\nRuntime compilation of new shaders is not yet fully supported in this version.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          if (selectedLayer != null && selectedLayer.kind == LayerKind.qr) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code Settings',
                    style: TextStyle(color: accentPink, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  // QR Data
                  const Text(
                    'Data (URL, Text, etc.)',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: selectedLayer!.qrData ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                      fillColor: Colors.white10,
                      filled: true,
                    ),
                    onChanged: (v) {
                      _updateLayerField(
                        selectedLayer!.id,
                        (l) => l.copyWith(qrData: v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Colors
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Foreground',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                _openShaderColorPicker(
                                  context,
                                  selectedLayer!.qrForegroundColor ??
                                      Colors.black,
                                  (c) {
                                    _updateLayerField(
                                      selectedLayer!.id,
                                      (l) => l.copyWith(qrForegroundColor: c),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                height: 30,
                                decoration: BoxDecoration(
                                  color:
                                      selectedLayer!.qrForegroundColor ??
                                      Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Background',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                _openShaderColorPicker(
                                  context,
                                  selectedLayer!.qrBackgroundColor ??
                                      Colors.white,
                                  (c) {
                                    _updateLayerField(
                                      selectedLayer!.id,
                                      (l) => l.copyWith(qrBackgroundColor: c),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                height: 30,
                                decoration: BoxDecoration(
                                  color:
                                      selectedLayer!.qrBackgroundColor ??
                                      Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (selectedLayer != null &&
              selectedLayer.kind == LayerKind.clock) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clock Settings',
                    style: TextStyle(color: accentPink, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedLayer.clockType ?? 'digital',
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      isDense: true,
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    dropdownColor: bgMedium,
                    items: const [
                      DropdownMenuItem(
                        value: 'digital',
                        child: Text('Digital'),
                      ),
                      DropdownMenuItem(value: 'analog', child: Text('Analog')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      _updateLayerField(
                        selectedLayer.id,
                        (l) => l.copyWith(clockType: v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text(
                      'Show Seconds',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    value: selectedLayer.clockShowSeconds ?? true,
                    activeColor: accentPink,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => _updateLayerField(
                      selectedLayer.id,
                      (l) => l.copyWith(clockShowSeconds: v),
                    ),
                  ),
                  if (selectedLayer.clockType == 'digital' ||
                      selectedLayer.clockType == null)
                    SwitchListTile(
                      title: const Text(
                        '24-Hour Format',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      value: selectedLayer.clock24Hour ?? false,
                      activeColor: accentPink,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => _updateLayerField(
                        selectedLayer.id,
                        (l) => l.copyWith(clock24Hour: v),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (selectedLayer?.kind == LayerKind.textbox)
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
                  safeSetState(() {
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
    SlideContent slide,
    SlideTemplate template, {
    bool showExtras = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
                    () => _addUtilityLayer(LayerKind.textbox, 'Textbox'),
                  ),
                  _itemButton('Media', Icons.image, _showMediaPickerSheet),
                  _itemButton(
                    'Website',
                    Icons.language,
                    () => _addUtilityLayer(LayerKind.website, 'Website'),
                  ),
                  _itemButton(
                    'Shader',
                    Icons.gradient,
                    () =>
                        _addUtilityLayer(LayerKind.shader, 'Background Shader'),
                  ),
                  _itemButton(
                    'QR Code',
                    Icons.qr_code,
                    () => _addUtilityLayer(LayerKind.qr, 'QR Code'),
                  ),
                  _itemButton(
                    'Timer',
                    Icons.timer,
                    () => _addUtilityLayer(LayerKind.timer, 'Timer'),
                  ),
                  _itemButton(
                    'Clock',
                    Icons.access_time,
                    () => _addUtilityLayer(LayerKind.clock, 'Clock'),
                  ),
                  _itemButton('Camera', Icons.videocam, _showCameraPicker),
                  _itemButton(
                    'Screen',
                    Icons.desktop_windows,
                    _showScreenPicker,
                  ),
                  _itemButton(
                    'Progress',
                    Icons.percent,
                    () => _addUtilityLayer(LayerKind.progress, 'Progress'),
                  ),
                  _itemButton(
                    'Events',
                    Icons.event,
                    () => _addUtilityLayer(LayerKind.events, 'Events'),
                  ),
                  _itemButton(
                    'Weather',
                    Icons.cloud,
                    () => _addUtilityLayer(LayerKind.weather, 'Weather'),
                  ),
                  _itemButton(
                    'Visualizer',
                    Icons.graphic_eq,
                    () => _addUtilityLayer(LayerKind.visualizer, 'Visualizer'),
                  ),
                  _itemButton(
                    'Captions',
                    Icons.closed_caption,
                    () => _addUtilityLayer(LayerKind.captions, 'Captions'),
                  ),
                  _itemButton(
                    'Icon',
                    Icons.star,
                    () => _addUtilityLayer(LayerKind.icon, 'Icon'),
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
    SlideContent slide,
    SlideTemplate template,
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

  Widget _slideTab(SlideContent slide, SlideTemplate template) {
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
                    safeSetState(() {
                      _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                          .copyWith(backgroundColor: c);
                    });
                  },
                ),
              TextButton(
                onPressed: () {
                  safeSetState(() {
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
              safeSetState(() {
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
              safeSetState(() {
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                    .copyWith(overlayNote: v.trim().isEmpty ? null : v.trim());
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _filtersTab(SlideContent slide, SlideTemplate template) {
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
    SlideContent slide, {
    double? hue,
    double? invert,
    double? blur,
    double? brightness,
    double? contrast,
    double? saturate,
  }) {
    safeSetState(() {
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

  Widget _mediaAttachmentCard(SlideContent slide) {
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
    final SlideMediaType? effectiveType = bgLayer?.mediaType ?? slide.mediaType;
    final typeLabel = effectiveType == SlideMediaType.image
        ? 'Picture'
        : effectiveType == SlideMediaType.video
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
                    onPressed: () => _pickMediaForSlide(SlideMediaType.image),
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
                    onPressed: () => _pickMediaForSlide(SlideMediaType.video),
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
                          backgroundColor: layer.role == LayerRole.background
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
                      ],
                    ),
                    title: Text(
                      layer.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${layer.role.name} • ${LayerKindLabel(layer)}',
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
                        DropdownButton<LayerRole>(
                          value: layer.role,
                          dropdownColor: bgMedium,
                          underline: const SizedBox.shrink(),
                          onChanged: (v) {
                            if (v == null) return;
                            _setLayerRole(layer.id, v);
                          },
                          items: const [
                            DropdownMenuItem(
                              value: LayerRole.background,
                              child: Text('Background'),
                            ),
                            DropdownMenuItem(
                              value: LayerRole.foreground,
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

  void _addUtilityLayer(LayerKind kind, String label) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    safeSetState(() {
      final slide = _slides[selectedSlideIndex];
      final idx = slide.layers.length;
      final double baseLeft = 0.15;
      final double baseTop = 0.15;
      final double baseWidth = 0.6;
      final double baseHeight = 0.6;
      final double offset = 0.04 * (idx % 4);
      final left = (baseLeft + offset).clamp(
        -DashboardScreenState._overflowAllowance,
        1 - baseWidth + DashboardScreenState._overflowAllowance,
      );
      final top = (baseTop + offset).clamp(
        -DashboardScreenState._overflowAllowance,
        1 - baseHeight + DashboardScreenState._overflowAllowance,
      );

      final layer = SlideLayer(
        id: 'layer-${DateTime.now().microsecondsSinceEpoch}',
        label: label,
        kind: kind,
        role: LayerRole.foreground,
        text: kind == LayerKind.textbox ? 'Edit me' : null,
        left: left,
        top: top,
        width: baseWidth,
        height: baseHeight,
        clockType: kind == LayerKind.clock ? 'digital' : null,
        clockShowSeconds: kind == LayerKind.clock ? true : null,
        clock24Hour: kind == LayerKind.clock ? false : null,
        weatherCity: kind == LayerKind.weather ? 'New York' : null,
        weatherCelsius: kind == LayerKind.weather ? false : null,
      );
      final updated = [...slide.layers, layer];
      _slides[selectedSlideIndex] = slide.copyWith(layers: updated);
    });
  }

  Future<void> _showCameraPicker() async {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;

    final cameras = [..._connectedCameras];

    if (cameras.isEmpty) {
      _showSnack('No cameras detected', isError: true);
      return;
    }

    final selected = await showDialog<LiveDevice>(
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

  void _addCameraLayer(LiveDevice camera) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;

    safeSetState(() {
      final slide = _slides[selectedSlideIndex];
      final idx = slide.layers.length;
      final double baseLeft = 0.15;
      final double baseTop = 0.15;
      final double baseWidth = 0.6;
      final double baseHeight = 0.6;
      final double offset = 0.04 * (idx % 4);
      final left = (baseLeft + offset).clamp(
        -DashboardScreenState._overflowAllowance,
        1 - baseWidth + DashboardScreenState._overflowAllowance,
      );
      final top = (baseTop + offset).clamp(
        -DashboardScreenState._overflowAllowance,
        1 - baseHeight + DashboardScreenState._overflowAllowance,
      );

      final layer = SlideLayer(
        id: 'layer-${DateTime.now().microsecondsSinceEpoch}',
        label: camera.name,
        kind: LayerKind.camera,
        role: LayerRole.foreground,
        path: camera.id,
        left: left,
        top: top,
        width: baseWidth,
        height: baseHeight,
      );
      final updated = [...slide.layers, layer];
      _slides[selectedSlideIndex] = slide.copyWith(layers: updated);
    });
  }

  Future<void> _showScreenPicker() async {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;

    final screens = [..._connectedScreens];

    if (screens.isEmpty) {
      _showSnack('No displays detected', isError: true);
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

  void _addScreenLayer(_ScreenSelection selection) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;

    safeSetState(() {
      final slide = _slides[selectedSlideIndex];
      final idx = slide.layers.length;
      final double baseLeft = 0.10;
      final double baseTop = 0.10;
      final double baseWidth = 0.8;
      final double baseHeight = 0.8;
      final double offset = 0.03 * (idx % 4);
      final left = (baseLeft + offset).clamp(
        -DashboardScreenState._overflowAllowance,
        1 - baseWidth + DashboardScreenState._overflowAllowance,
      );
      final top = (baseTop + offset).clamp(
        -DashboardScreenState._overflowAllowance,
        1 - baseHeight + DashboardScreenState._overflowAllowance,
      );

      String pathValue = selection.id;
      if (selection.type == _ScreenCaptureType.window &&
          selection.hwnd != null) {
        pathValue = 'hwnd:${selection.hwnd}';
      } else if (selection.type == _ScreenCaptureType.display &&
          selection.displayIndex != null) {
        pathValue = 'display:${selection.displayIndex}';
      }

      final layer = SlideLayer(
        id: 'layer-${DateTime.now().microsecondsSinceEpoch}',
        label: selection.name,
        kind: LayerKind.screen,
        role: LayerRole.foreground,
        path: pathValue,
        text: selection.type.name,
        left: left,
        top: top,
        width: baseWidth,
        height: baseHeight,
      );
      final updated = [...slide.layers, layer];
      _slides[selectedSlideIndex] = slide.copyWith(layers: updated);
    });
  }

  List<SlideLayer> _foregroundLayers(SlideContent slide) {
    return slide.layers.where((l) => l.role == LayerRole.foreground).toList();
  }

  void _updateLayerField(
    String layerId,
    SlideLayer Function(SlideLayer) updater,
  ) {
    if (selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    safeSetState(() {
      final slide = _slides[selectedSlideIndex];
      final layers = slide.layers.map((l) {
        if (l.id == layerId) return updater(l);
        return l;
      }).toList();
      _slides[selectedSlideIndex] = slide.copyWith(
        layers: layers,
        modifiedAt: DateTime.now(),
      );
    });
  }

  void _updateSlideBox(
    SlideContent slide, {
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    if (selectedSlideIndex < 0 || selectedSlideIndex >= _slides.length) return;
    safeSetState(() {
      _slides[selectedSlideIndex] = slide.copyWith(
        boxLeft: left ?? slide.boxLeft,
        boxTop: top ?? slide.boxTop,
        boxWidth: width ?? slide.boxWidth,
        boxHeight: height ?? slide.boxHeight,
      );
    });
  }

  void _showLayerContextMenu(TapDownDetails details, SlideLayer layer) {
    // Ensure the right-clicked item is selected
    if (!_selectedLayerIds.contains(layer.id)) {
      safeSetState(() {
        _selectedLayerIds = {layer.id};
      });
    }

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    final isMulti = _selectedLayerIds.length > 1;

    showMenu(
      context: context,
      position: position,
      color: AppPalette.surface,
      items: <PopupMenuEntry<String>>[
        if (!isMulti) ...[
          PopupMenuItem(
            value: 'front',
            child: _popMenuItem(Icons.flip_to_front, 'Bring to front'),
            onTap: () {
              final slide = _slides[selectedSlideIndex];
              final idx = slide.layers.indexWhere((l) => l.id == layer.id);
              if (idx != -1 && idx < slide.layers.length - 1) {
                _reorderLayers(idx, slide.layers.length - 1);
              }
            },
          ),
          PopupMenuItem(
            value: 'back',
            child: _popMenuItem(Icons.flip_to_back, 'Send to back'),
            onTap: () {
              final slide = _slides[selectedSlideIndex];
              final idx = slide.layers.indexWhere((l) => l.id == layer.id);
              if (idx > 0) {
                _reorderLayers(idx, 0);
              }
            },
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          value: 'copy',
          child: _popMenuItem(Icons.copy, 'Copy'),
          onTap: () => copySelection(),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: _popMenuItem(Icons.copy_all, 'Duplicate (Ctrl+D)'),
          onTap: () => duplicateSelection(),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'copy_style',
          child: _popMenuItem(Icons.palette, 'Copy Style (Ctrl+Shift+C)'),
          onTap: () => copyStyle(),
        ),
        PopupMenuItem(
          value: 'paste_style',
          child: _popMenuItem(Icons.brush, 'Paste Style (Ctrl+Shift+V)'),
          onTap: () => pasteStyle(),
        ),
        PopupMenuItem(
          value: 'paste_replace',
          child: _popMenuItem(Icons.swap_horiz, 'Paste Replace (Ctrl+Shift+R)'),
          onTap: () => pasteReplace(),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'paste_all',
          child: _popMenuItem(Icons.library_add_check, 'Paste to All Slides'),
          onTap: () {
            copySelection();
            pasteToAllSlides();
          },
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _popMenuItem(
            Icons.delete,
            isMulti
                ? 'Delete ${_selectedLayerIds.length} items'
                : 'Delete layer',
          ),
          onTap: () {
            if (isMulti) {
              _deleteSelectedLayers();
            } else {
              _deleteLayer(layer.id);
            }
          },
        ),
      ],
    );
  }

  Widget _popMenuItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Future<void> _openShaderColorPicker(
    BuildContext context,
    Color currentColor,
    Function(Color) onColorChanged,
  ) async {
    final List<Color> swatches = [
      Colors.purple,
      Colors.blue,
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.teal,
      Colors.cyan,
      Colors.indigo,
      Colors.pink,
      Colors.white,
      Colors.grey,
      Colors.black,
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Pick Color',
            style: TextStyle(color: Colors.white),
          ),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: swatches.map((c) {
              return GestureDetector(
                onTap: () {
                  onColorChanged(c);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c == currentColor ? Colors.white : Colors.white24,
                      width: c == currentColor ? 2 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Visualizer helper chips
  Widget _visualizerTypeChip(
    SlideLayer layer,
    String type,
    String label,
    IconData icon,
  ) {
    final isSelected = (layer.visualizerType ?? 'bars') == type;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.white : Colors.white70,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: accentPink,
      backgroundColor: Colors.white10,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      onSelected: (_) {
        _updateLayerField(layer.id, (l) => l.copyWith(visualizerType: type));
      },
    );
  }

  Widget _colorModeChip(SlideLayer layer, String mode, String label) {
    final isSelected = (layer.visualizerColorMode ?? 'gradient') == mode;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
      selected: isSelected,
      selectedColor: accentPink,
      backgroundColor: Colors.white10,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      onSelected: (_) {
        _updateLayerField(
          layer.id,
          (l) => l.copyWith(visualizerColorMode: mode),
        );
      },
    );
  }

  Widget _frequencyRangeChip(SlideLayer layer, String range, String label) {
    final isSelected = (layer.visualizerFrequencyRange ?? 'full') == range;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
      selected: isSelected,
      selectedColor: accentPink,
      backgroundColor: Colors.white10,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      onSelected: (_) {
        _updateLayerField(
          layer.id,
          (l) => l.copyWith(visualizerFrequencyRange: range),
        );
      },
    );
  }

  Widget _shapeChip(SlideLayer layer, String shape, String label) {
    final isSelected = (layer.visualizerShape ?? 'rounded') == shape;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
      selected: isSelected,
      selectedColor: accentPink,
      backgroundColor: Colors.white10,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      onSelected: (_) {
        _updateLayerField(layer.id, (l) => l.copyWith(visualizerShape: shape));
      },
    );
  }

  Widget _audioSourceChip(
    SlideLayer layer,
    String source,
    String label,
    IconData icon,
  ) {
    final isSelected = (layer.visualizerAudioSource ?? 'app_audio') == source;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.white : Colors.white70,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: accentPink,
      backgroundColor: Colors.white10,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      onSelected: (_) {
        _updateLayerField(
          layer.id,
          (l) => l.copyWith(visualizerAudioSource: source),
        );
      },
    );
  }

  Widget _buildAudioDeviceDropdown(SlideLayer layer) {
    final audioSource = layer.visualizerAudioSource ?? 'app_audio';
    final devices = AudioDeviceService.instance.devices;

    // Filter devices based on selected audio source type
    List<AudioDevice> filteredDevices;
    IconData leadingIcon;
    String emptyMessage;

    switch (audioSource) {
      case 'system_audio':
        filteredDevices = devices
            .where(
              (d) =>
                  d.type == AudioDeviceType.loopback ||
                  d.type == AudioDeviceType.output,
            )
            .toList();
        leadingIcon = Icons.computer;
        emptyMessage = 'No system audio devices found';
        break;
      case 'microphone':
        filteredDevices = devices
            .where((d) => d.type == AudioDeviceType.input)
            .toList();
        leadingIcon = Icons.mic;
        emptyMessage = 'No microphones found';
        break;
      case 'app_audio':
      default:
        // App audio only has one option
        filteredDevices = [
          AudioDevice(
            id: 'app_audio',
            name: 'Music Player Audio',
            type: AudioDeviceType.loopback,
            isDefault: true,
          ),
        ];
        leadingIcon = Icons.music_note;
        emptyMessage = '';
        break;
    }

    // Get current selected device - ensure it exists in the filtered list
    String? selectedDeviceId = layer.visualizerAudioDevice;

    // Check if the stored device ID exists in the current filtered list
    final deviceExists = filteredDevices.any((d) => d.id == selectedDeviceId);
    if (!deviceExists) {
      // Use the first available device if stored ID doesn't exist
      selectedDeviceId = filteredDevices.isNotEmpty
          ? filteredDevices.first.id
          : null;
    }

    if (filteredDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(leadingIcon, color: Colors.white38, size: 18),
            const SizedBox(width: 8),
            Text(
              emptyMessage,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedDeviceId,
          isExpanded: true,
          dropdownColor: const Color(0xFF2A2A2A),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: filteredDevices.map((device) {
            IconData icon;
            switch (device.type) {
              case AudioDeviceType.output:
                icon = Icons.speaker;
                break;
              case AudioDeviceType.input:
                icon = Icons.mic;
                break;
              case AudioDeviceType.loopback:
                icon = Icons.surround_sound;
                break;
            }

            return DropdownMenuItem<String>(
              value: device.id,
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: device.isDefault ? accentPink : Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: device.isDefault ? Colors.white : Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (device.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accentPink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'Default',
                        style: TextStyle(fontSize: 9, color: Colors.white70),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              _updateLayerField(
                layer.id,
                (l) => l.copyWith(visualizerAudioDevice: value),
              );
            }
          },
        ),
      ),
    );
  }
}
