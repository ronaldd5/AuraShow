part of dashboard_screen;

extension TextExtensions on DashboardScreenState {
  Widget _textboxTab(SlideContent slide, SlideTemplate template) {
    // 1. Resolve Active Layer
    // We only want to target "textbox" kind layers, or maybe any layer that supports text?
    // For now, let's target any layer in the selection.

    // Target the selected layer if it exists.
    SlideLayer? activeLayer;
    if (_selectedLayerId != null) {
      try {
        activeLayer = slide.layers.firstWhere((l) => l.id == _selectedLayerId);
      } catch (_) {}
    }

    // 2. Helper to resolve values (Layer -> Slide -> Template/Default)
    T resolve<T>(T? layerValue, T? slideValue, T defaultValue) {
      return layerValue ?? slideValue ?? defaultValue;
    }

    // 3. Current Values
    final fontSize = resolve(
      activeLayer?.fontSize,
      slide.fontSizeOverride,
      template.fontSize,
    );
    final fontFamily = resolve(
      activeLayer?.fontFamily,
      slide.fontFamilyOverride,
      'Inter',
    );
    final textColor = resolve(
      activeLayer?.textColor,
      slide.textColorOverride,
      template.textColor,
    );
    // Gradient is not yet on layer (I didn't see it in the list I checked, checking again... no gradient on layer yet, only slide).
    // So gradient stays slide-level for now, or we disable it for layers?
    // User asked for "font and font size", let's worry about those primary.
    // If user sets color on layer, it overrides gradient?
    final gradient = slide.textGradientOverride;

    final textAlign = resolve(
      activeLayer?.align,
      slide.alignOverride,
      template.alignment,
    );
    final verticalAlign =
        slide.verticalAlign ??
        VerticalAlign
            .middle; // Vertical Align for layer? I didn't add it to layer properly? Layer has 'align' (TextAlign).
    // Checking layer_models.dart... 'align' is TextAlign. Top/Middle/Bottom is usually 'verticalAlign'.
    // layer_models.dart DOES NOT have verticalAlign. So vertical align remains slide-level or I need to add it.
    // For now, keep it slide level.

    final isBold = resolve(activeLayer?.isBold, slide.isBold, true);
    final isItalic = resolve(activeLayer?.isItalic, slide.isItalic, false);
    final isUnderline = resolve(
      activeLayer?.isUnderline,
      slide.isUnderline,
      false,
    );

    final autoSize = resolve(
      null,
      slide.autoSize,
      false,
    ); // Not on layer yet? I recall checking... no autoSize on layer in model.

    final boxPadding = resolve(activeLayer?.boxPadding, slide.boxPadding, 0.0);
    final outlineWidth = resolve(
      activeLayer?.outlineWidth,
      slide.outlineWidth,
      0.0,
    );
    final boxColor = resolve(
      activeLayer?.boxColor,
      slide.boxBackgroundColor,
      null,
    ); // Rename slide prop mismatch? slide.boxBackgroundColor vs layer.boxColor.

    // Shadow props not on layer yet.

    // 4. Update Helper
    void update(
      void Function(SlideLayer l) layerUpdater,
      void Function(SlideContent s) slideUpdater,
    ) {
      if (activeLayer != null) {
        _updateLayerField(activeLayer.id, (l) {
          layerUpdater(l);
          return l; // logic assumes updater mutates or returns? _updateLayerField expects "updater" to return new layer.
          // Wait, my helper below needs to return the new layer.
          // Let's rely on copyWith inside the lambda passing to _updateLayerField.
          // But I need to construct the lambda.
        });
        // Reread implementation of _updateLayerField below to be sure.
        _updateLayerField(activeLayer.id, (oldL) {
          // This is cleaner:
          // return oldL.copyWith(...);
          // But I'm passing a lambda to 'update' here.
          // Let's simplify: simply inline the logic in callbacks.
          return oldL; // Placeholder
        });
      } else {
        safeSetState(() {
          // slideUpdater...
        });
      }
    }

    Widget toolbarButton({
      required Widget child,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? accentPink.withOpacity(0.18)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? accentPink : Colors.white24,
                width: selected ? 2 : 1,
              ),
            ),
            child: child,
          ),
        ),
      );
    }

    Widget alignButton(IconData icon, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? accentPink.withOpacity(0.18)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: selected ? accentPink : Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    InputDecoration _denseLabel(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: accentPink, fontSize: 12),
        isDense: true,
      );
    }

    TextAlign _cycleAlign(TextAlign current) {
      const order = [
        TextAlign.left,
        TextAlign.center,
        TextAlign.right,
        TextAlign.justify,
      ];
      final idx = order.indexOf(current);
      final next = (idx + 1) % order.length;
      return order[next];
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Font family',
                            style: TextStyle(color: accentPink, fontSize: 12),
                          ),
                          Listener(
                            onPointerDown: (_) => _preventEditModeExit = true,
                            child: DropdownButton<String?>(
                              value: _allFonts.contains(fontFamily)
                                  ? fontFamily
                                  : null,
                              isExpanded: true,
                              dropdownColor: bgMedium,
                              iconEnabledColor: Colors.white70,
                              style: const TextStyle(color: Colors.white),
                              underline: const SizedBox.shrink(),
                              menuMaxHeight: 400,
                              items: _allFonts
                                  .map(
                                    (f) => DropdownMenuItem<String?>(
                                      value: f,
                                      child: MouseRegion(
                                        onEnter: (_) => safeSetState(
                                          () => _hoverFontPreview = f,
                                        ),
                                        onExit: (_) => safeSetState(
                                          () => _hoverFontPreview = null,
                                        ),
                                        child: Row(
                                          children: [
                                            if (_customFonts.contains(f))
                                              const Icon(
                                                Icons.star,
                                                size: 12,
                                                color: Colors.amber,
                                              ),
                                            if (_customFonts.contains(f))
                                              const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                f ?? 'Use template',
                                                overflow: TextOverflow.ellipsis,
                                                style: f != null
                                                    ? _getGoogleFontStyle(
                                                        f,
                                                        const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                        ),
                                                      )
                                                    : const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (activeLayer != null) {
                                  _updateLayerField(
                                    activeLayer.id,
                                    (l) => l.copyWith(fontFamily: value),
                                  );
                                } else {
                                  safeSetState(() {
                                    _slides[selectedSlideIndex] =
                                        _slides[selectedSlideIndex].copyWith(
                                          fontFamilyOverride: value,
                                          modifiedAt: DateTime.now(),
                                        );
                                  });
                                }
                                _recordRecentFont(value);
                              },
                            ),
                          ), // Close Listener
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _importCustomFont,
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Import Font'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    textStyle: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        // Color picker logic
                        // We need to support updating layer color.
                        // But `_openTextColorPicker` is a separate method that takes `slide`.
                        // Check execution step.
                        // For now, let's just duplicate the picker logic here or update `_openTextColorPicker` separately.
                        // Since `_openTextColorPicker` is complex, calling it might update slide.
                        // Let's implement a simple color picker here or rely on the existing one and fix it later/if needed.
                        // Wait, `textColor` is resolved properly.
                        // If I click it, I want to change layer color.
                        // `_openTextColorPicker` probably calls setState on slide.
                        // I should reimplement color picking here briefly or fix `_openTextColorPicker`.
                        // Let's use `_openTextColorPicker` for now but passing valid context? No, it takes slide.
                        // Let's do a simple color picker here inline like Box Color.
                        final picked = await showDialog<Color>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Text Color'),
                            content: SingleChildScrollView(
                              child: BlockPicker(
                                pickerColor: textColor ?? Colors.white,
                                onColorChanged: (c) {
                                  Navigator.of(context).pop(c);
                                },
                              ),
                            ),
                          ),
                        );
                        if (picked != null) {
                          if (activeLayer != null) {
                            _updateLayerField(
                              activeLayer.id,
                              (l) => l.copyWith(textColor: picked),
                            );
                          } else {
                            safeSetState(() {
                              _slides[selectedSlideIndex] =
                                  _slides[selectedSlideIndex].copyWith(
                                    textColorOverride: picked,
                                  );
                            });
                          }
                        }
                      },
                      child: Container(
                        width: 42,
                        height: 38,
                        decoration: gradient != null && gradient.isNotEmpty
                            ? BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 2,
                                ),
                              )
                            : BoxDecoration(
                                color: textColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Font Size Slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Font Size',
                      style: TextStyle(color: accentPink, fontSize: 12),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: fontSize.clamp(10, 400).toDouble(),
                            min: 10,
                            max: 400,
                            activeColor: accentPink,
                            inactiveColor: Colors.white24,
                            onChanged: (value) {
                              if (activeLayer != null) {
                                _updateLayerField(
                                  activeLayer.id,
                                  (l) => l.copyWith(fontSize: value),
                                );
                              } else {
                                safeSetState(() {
                                  _slides[selectedSlideIndex] =
                                      _slides[selectedSlideIndex].copyWith(
                                        fontSizeOverride: value,
                                      );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            fontSize.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Auto Size & Spacer (to keep half-width look)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        value: autoSize,
                        decoration: _denseLabel('Auto size'),
                        dropdownColor: bgMedium,
                        iconEnabledColor: Colors.white70,
                        items: const [
                          DropdownMenuItem(
                            value: false,
                            child: Text(
                              'None',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: true,
                            child: Text(
                              'Auto',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  autoSize: v,
                                );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    toolbarButton(
                      child: const Text(
                        'B',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      selected: isBold,
                      onTap: () {
                        if (activeLayer != null) {
                          _updateLayerField(
                            activeLayer.id,
                            (l) => l.copyWith(isBold: !isBold),
                          );
                        } else {
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  isBold: !isBold,
                                );
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                    toolbarButton(
                      child: const Text(
                        'I',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                        ),
                      ),
                      selected: isItalic,
                      onTap: () {
                        if (activeLayer != null) {
                          _updateLayerField(
                            activeLayer.id,
                            (l) => l.copyWith(isItalic: !isItalic),
                          );
                        } else {
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  isItalic: !isItalic,
                                );
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                    toolbarButton(
                      child: const Text(
                        'U',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: Colors.white,
                        ),
                      ),
                      selected: isUnderline,
                      onTap: () {
                        if (activeLayer != null) {
                          _updateLayerField(
                            activeLayer.id,
                            (l) => l.copyWith(isUnderline: !isUnderline),
                          );
                        } else {
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  isUnderline: !isUnderline,
                                );
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                    toolbarButton(
                      child: const Icon(
                        Icons.format_align_center,
                        color: Colors.white,
                      ),
                      selected: true,
                      onTap: () {
                        final nextAlign = _cycleAlign(textAlign);
                        if (activeLayer != null) {
                          _updateLayerField(
                            activeLayer.id,
                            (l) => l.copyWith(align: nextAlign),
                          );
                        } else {
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  alignOverride: nextAlign,
                                );
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _accordionSection(
            icon: Icons.format_align_left,
            label: 'Align',
            children: [
              Row(
                children: [
                  alignButton(
                    Icons.format_align_left,
                    textAlign == TextAlign.left,
                    () {
                      if (activeLayer != null) {
                        _updateLayerField(
                          activeLayer.id,
                          (l) => l.copyWith(align: TextAlign.left),
                        );
                      } else {
                        safeSetState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                alignOverride: TextAlign.left,
                              );
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  alignButton(
                    Icons.format_align_center,
                    textAlign == TextAlign.center,
                    () {
                      if (activeLayer != null) {
                        _updateLayerField(
                          activeLayer.id,
                          (l) => l.copyWith(align: TextAlign.center),
                        );
                      } else {
                        safeSetState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                alignOverride: TextAlign.center,
                              );
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  alignButton(
                    Icons.format_align_right,
                    textAlign == TextAlign.right,
                    () {
                      if (activeLayer != null) {
                        _updateLayerField(
                          activeLayer.id,
                          (l) => l.copyWith(align: TextAlign.right),
                        );
                      } else {
                        safeSetState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                alignOverride: TextAlign.right,
                              );
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  alignButton(
                    Icons.format_align_justify,
                    textAlign == TextAlign.justify,
                    () {
                      if (activeLayer != null) {
                        _updateLayerField(
                          activeLayer.id,
                          (l) => l.copyWith(align: TextAlign.justify),
                        );
                      } else {
                        safeSetState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                alignOverride: TextAlign.justify,
                              );
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Vertical align (keep slide only for now as discussed)
              Row(
                children: [
                  alignButton(
                    Icons.vertical_align_top,
                    verticalAlign == VerticalAlign.top,
                    () {
                      safeSetState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              verticalAlign: VerticalAlign.top,
                            );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  alignButton(
                    Icons.vertical_align_center,
                    verticalAlign == VerticalAlign.middle,
                    () {
                      safeSetState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              verticalAlign: VerticalAlign.middle,
                            );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  alignButton(
                    Icons.vertical_align_bottom,
                    verticalAlign == VerticalAlign.bottom,
                    () {
                      safeSetState(() {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              verticalAlign: VerticalAlign.bottom,
                            );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  const Spacer(),
                ],
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.text_fields,
            label: 'Text',
            onReset: () {
              // Reset slide defaults or layer?
              // For now reset slide.
              safeSetState(() {
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                    .copyWith(
                      letterSpacing: 0.0,
                      wordSpacing: 0.0,
                      textTransform: TextTransform.none,
                      singleLine: false,
                    );
              });
            },
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: (slide.letterSpacing ?? 0).toStringAsFixed(
                        1,
                      ),
                      decoration: _denseLabel('Letter spacing'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  letterSpacing: parsed.clamp(-2, 10),
                                );
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: (slide.wordSpacing ?? 0).toStringAsFixed(1),
                      decoration: _denseLabel('Word spacing'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  wordSpacing: parsed.clamp(-4, 16),
                                );
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButton<TextTransform>(
                value: slide.textTransform ?? TextTransform.none,
                isExpanded: true,
                dropdownColor: bgMedium,
                iconEnabledColor: Colors.white70,
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox.shrink(),
                items: TextTransform.values
                    .map(
                      (t) => DropdownMenuItem<TextTransform>(
                        value: t,
                        child: Text(
                          t.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  safeSetState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(textTransform: value);
                  });
                },
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: slide.singleLine ?? false,
                onChanged: (v) {
                  safeSetState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(singleLine: v ?? false);
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: accentPink,
                title: const Text(
                  'Text on one line',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.notes,
            label: 'Lines',
            onReset: () {
              safeSetState(() {
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                    .copyWith(lineHeight: 1.3);
              });
            },
            children: [
              Text(
                'Line spacing: ${(slide.lineHeight ?? 1.3).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Slider(
                value: (slide.lineHeight ?? 1.3).clamp(0.5, 3.0),
                min: 0.5,
                max: 3.0,
                divisions: 25,
                activeColor: accentPink,
                onChanged: (v) {
                  safeSetState(() {
                    _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                        .copyWith(lineHeight: v);
                  });
                },
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.rounded_corner,
            label: 'Box & Outline',
            onReset: () {
              if (activeLayer != null) {
                _updateLayerField(
                  activeLayer.id,
                  (l) => l.copyWith(
                    boxPadding: null,
                    outlineWidth: null,
                    boxColor: null,
                  ),
                );
              } else {
                safeSetState(() {
                  _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                      .copyWith(
                        boxPadding: 0.0,
                        outlineWidth: 0.0,
                        boxBackgroundColor: null,
                      );
                });
              }
            },
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('padding-${activeLayer?.id ?? "slide"}'),
                      initialValue: boxPadding.toStringAsFixed(0),
                      decoration: _denseLabel('Padding'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          if (activeLayer != null) {
                            _updateLayerField(
                              activeLayer.id,
                              (l) => l.copyWith(
                                boxPadding: parsed.clamp(0, 200).toDouble(),
                              ),
                            );
                          } else {
                            safeSetState(() {
                              _slides[selectedSlideIndex] =
                                  _slides[selectedSlideIndex].copyWith(
                                    boxPadding: parsed.clamp(0, 200).toDouble(),
                                  );
                            });
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('outline-${activeLayer?.id ?? "slide"}'),
                      initialValue: outlineWidth.toStringAsFixed(1),
                      decoration: _denseLabel('Outline width'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          if (activeLayer != null) {
                            _updateLayerField(
                              activeLayer.id,
                              (l) => l.copyWith(
                                outlineWidth: parsed.clamp(0, 20).toDouble(),
                              ),
                            );
                          } else {
                            safeSetState(() {
                              _slides[selectedSlideIndex] =
                                  _slides[selectedSlideIndex].copyWith(
                                    outlineWidth: parsed
                                        .clamp(0, 20)
                                        .toDouble(),
                                  );
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      // Pick box color
                      final picked = await showDialog<Color>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Box Color'),
                          content: SingleChildScrollView(
                            child: BlockPicker(
                              pickerColor: boxColor ?? Colors.transparent,
                              onColorChanged: (c) {
                                Navigator.of(context).pop(c);
                              },
                            ),
                          ),
                        ),
                      );
                      if (picked != null) {
                        if (activeLayer != null) {
                          _updateLayerField(
                            activeLayer.id,
                            (l) => l.copyWith(boxColor: picked),
                          );
                        } else {
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  boxBackgroundColor: picked,
                                );
                          });
                        }
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 38,
                      decoration: BoxDecoration(
                        color: boxColor ?? Colors.transparent,
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Box color',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Corner Radius:',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Expanded(
                    child: Slider(
                      value:
                          (activeLayer != null
                                  ? (activeLayer.boxBorderRadius ?? 0)
                                  : (slide.boxBorderRadius ?? 0))
                              .clamp(0.0, 100.0)
                              .toDouble(),
                      min: 0,
                      max: 100,
                      activeColor: accentPink,
                      onChanged: (v) {
                        if (activeLayer != null) {
                          _updateLayerField(
                            activeLayer.id,
                            (l) => l.copyWith(boxBorderRadius: v),
                          );
                        } else {
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  boxBorderRadius: v,
                                );
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Box Opacity:',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Expanded(
                    child: Slider(
                      value:
                          (activeLayer != null
                                  ? (activeLayer.boxColor?.opacity ?? 1.0)
                                  : (slide.boxBackgroundColor?.opacity ??
                                        (slide.boxBackgroundColor == null
                                            ? 0.0
                                            : 1.0)))
                              .clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      activeColor: accentPink,
                      onChanged: (v) {
                        if (activeLayer != null) {
                          final baseColor =
                              activeLayer.boxColor ?? Colors.black;
                          _updateLayerField(
                            activeLayer.id,
                            (l) =>
                                l.copyWith(boxColor: baseColor.withOpacity(v)),
                          );
                        } else {
                          final baseColor =
                              slide.boxBackgroundColor ?? Colors.black;
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  boxBackgroundColor: baseColor.withOpacity(v),
                                );
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Rotation:',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Expanded(
                    child: Slider(
                      value:
                          (activeLayer != null
                                  ? (activeLayer.rotation ?? 0).toDouble()
                                  : (slide.rotation ?? 0).toDouble())
                              .clamp(0.0, 360.0),
                      min: 0,
                      max: 360,
                      activeColor: accentPink,
                      inactiveColor: Colors.white24,
                      onChanged: (v) {
                        if (activeLayer != null) {
                          _updateLayerField(
                            activeLayer.id,
                            (l) => l.copyWith(rotation: v),
                          );
                        } else {
                          safeSetState(() {
                            _slides[selectedSlideIndex] =
                                _slides[selectedSlideIndex].copyWith(
                                  rotation: v,
                                );
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 35,
                    child: Text(
                      (activeLayer != null
                              ? activeLayer.rotation ?? 0
                              : slide.rotation ?? 0)
                          .toInt()
                          .toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _accordionSection(
            icon: Icons.blur_on,
            label: 'Shadow',
            onReset: () {
              safeSetState(() {
                _slides[selectedSlideIndex] = _slides[selectedSlideIndex]
                    .copyWith(
                      shadowBlur: null,
                      shadowColor: null,
                      shadowOffsetX: null,
                      shadowOffsetY: null,
                    );
              });
            },
            children: [
              Row(
                children: [
                  const Text(
                    'Blur:',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Expanded(
                    child: Slider(
                      value: (slide.shadowBlur ?? 0).clamp(0, 50),
                      min: 0,
                      max: 50,
                      activeColor: accentPink,
                      onChanged: (v) {
                        safeSetState(() {
                          _slides[selectedSlideIndex] =
                              _slides[selectedSlideIndex].copyWith(
                                shadowBlur: v,
                              );
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Presets
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Presets',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _applyTextPreset('heading'),
                        child: const Text('HEADING'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _applyTextPreset('verse'),
                        child: const Text('Verse'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _applyTextPreset('note'),
                        child: const Text('Note'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 200),
        ],
      ),
    );
  }

  Future<void> _openTextColorPicker(
    SlideContent slide,
    SlideTemplate template,
  ) async {
    final List<Color> normalSwatches = [
      Colors.white,
      const Color(0xFFE0E0E0),
      const Color(0xFFCCCCCC),
      const Color(0xFF888888),
      const Color(0xFF555555),
      AppPalette.dustyRose,
      AppPalette.dustyMauve,
      AppPalette.teaGreen,
      const Color(0xFF2FB3FF),
      const Color(0xFF6A7CFF),
      const Color(0xFFD943FF),
      const Color(0xFF00C86B),
      const Color(0xFFFF7A45),
      const Color(0xFFFFB347),
      Colors.black,
    ];

    final List<List<Color>> gradientSwatches = [
      [const Color(0xFFFF7A45), const Color(0xFFFFB347)],
      [AppPalette.dustyRose, AppPalette.dustyMauve],
      [const Color(0xFF2FB3FF), const Color(0xFF6A7CFF)],
      [const Color(0xFF00C86B), const Color(0xFF2FB3FF)],
      [const Color(0xFFD943FF), const Color(0xFF6A7CFF)],
      [Colors.white, AppPalette.dustyRose],
    ];

    final List<Color>? currentGradient = slide.textGradientOverride;
    Color currentColor = slide.textColorOverride ?? template.textColor;
    double opacity = (currentGradient?.first.opacity ?? currentColor.opacity)
        .clamp(0.05, 1.0);

    await showDialog(
      context: context,
      builder: (ctx) {
        List<Color>? previewGradient = currentGradient
            ?.map((c) => c.withOpacity(opacity))
            .toList();
        Color previewColor = currentColor.withOpacity(opacity);
        int selectedTab = currentGradient != null
            ? 1
            : 0; // 0=Normal,1=Gradient,2=Custom
        final TextEditingController customHex = TextEditingController(
          text:
              '#${(previewGradient == null ? previewColor : previewGradient.first).value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
        );

        Color _parseHex(String input, Color fallback) {
          final normalized = input.replaceAll('#', '').toUpperCase();
          if (normalized.length == 6 || normalized.length == 8) {
            final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
            final int? value = int.tryParse(hex, radix: 16);
            if (value != null) return Color(value);
          }
          return fallback;
        }

        return StatefulBuilder(
          builder: (context, setLocal) {
            Widget tabButton(String label, int tab) {
              final selected = selectedTab == tab;
              return Expanded(
                child: InkWell(
                  onTap: () => setLocal(() {
                    selectedTab = tab;
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? accentPink.withOpacity(0.18)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? accentPink : Colors.white24,
                      ),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: bgMedium,
              title: const Text(
                'Text color',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        tabButton('Normal', 0),
                        const SizedBox(width: 6),
                        tabButton('Gradient', 1),
                        const SizedBox(width: 6),
                        tabButton('Custom', 2),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Opacity Slider
                    Row(
                      children: [
                        const Text(
                          'Opacity',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Expanded(
                          child: Slider(
                            value: opacity,
                            min: 0.05,
                            max: 1.0,
                            activeColor: accentPink,
                            onChanged: (v) {
                              setLocal(() {
                                opacity = v;
                                if (previewGradient != null) {
                                  previewGradient = previewGradient!
                                      .map((c) => c.withOpacity(opacity))
                                      .toList();
                                } else {
                                  previewColor = previewColor.withOpacity(
                                    opacity,
                                  );
                                }
                              });
                            },
                          ),
                        ),
                        Text(
                          '${(opacity * 100).round()}%',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 10),

                    // Tab Content
                    if (selectedTab == 0) ...[
                      // Normal
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: normalSwatches.map((c) {
                          final cWithOpacity = c.withOpacity(opacity);
                          final isSelected =
                              previewGradient == null &&
                              previewColor.value == cWithOpacity.value;
                          return GestureDetector(
                            onTap: () {
                              setLocal(() {
                                previewGradient = null;
                                previewColor = cWithOpacity;
                                customHex.text =
                                    '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                              });
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? accentPink
                                      : Colors.white24,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ] else if (selectedTab == 1) ...[
                      // Gradient
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: gradientSwatches.map((colors) {
                          final colorsWithOpacity = colors
                              .map((c) => c.withOpacity(opacity))
                              .toList();
                          // Compare first color for simplicity
                          final isSelected =
                              previewGradient != null &&
                              previewGradient!.first.value ==
                                  colorsWithOpacity.first.value;
                          return GestureDetector(
                            onTap: () {
                              setLocal(() {
                                previewGradient = colorsWithOpacity;
                                customHex.text =
                                    '#${colors.first.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                              });
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: colors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? accentPink
                                      : Colors.white24,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      // Custom Hex
                      TextField(
                        controller: customHex,
                        style: const TextStyle(color: Colors.white),
                        decoration: _denseLabel('Hex Code (e.g. #FF0000)'),
                        onChanged: (v) {
                          final c = _parseHex(v, previewColor);
                          setLocal(() {
                            previewGradient = null;
                            previewColor = c.withOpacity(opacity);
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text(
                            'Preview:',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: previewGradient == null
                                  ? previewColor
                                  : null,
                              gradient: previewGradient != null
                                  ? LinearGradient(colors: previewGradient!)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    safeSetState(() {
                      if (previewGradient != null) {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              textGradientOverride: previewGradient,
                              textColorOverride: null,
                            );
                      } else {
                        _slides[selectedSlideIndex] =
                            _slides[selectedSlideIndex].copyWith(
                              textColorOverride: previewColor,
                              textGradientOverride: [], // optimize clear
                            );
                      }
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyTextPreset(String preset) {
    if (_slides.isEmpty ||
        selectedSlideIndex < 0 ||
        selectedSlideIndex >= _slides.length)
      return;
    final slide = _slides[selectedSlideIndex];
    final template = _templateFor(slide.templateId);

    SlideContent next = slide;
    switch (preset) {
      case 'heading':
        next = slide.copyWith(
          fontSizeOverride: (template.fontSize * 1.15).clamp(18, 80),
          isBold: true,
          isItalic: false,
          isUnderline: false,
          alignOverride: TextAlign.center,
          letterSpacing: 0.6,
          lineHeight: 1.1,
          shadowColor: Colors.black,
          shadowBlur: 8,
          shadowOffsetX: 1.2,
          shadowOffsetY: 2.2,
          outlineColor: Colors.black,
          outlineWidth: 1.5,
          textTransform: TextTransform.uppercase,
          boxPadding: 10,
          boxBackgroundColor: slide.boxBackgroundColor,
        );
        break;
      case 'note':
        next = slide.copyWith(
          fontSizeOverride: (template.fontSize * 0.78).clamp(14, 64),
          isBold: false,
          isItalic: true,
          isUnderline: false,
          letterSpacing: 0.2,
          lineHeight: 1.4,
          shadowColor: null,
          shadowBlur: 0,
          outlineWidth: 0,
          boxPadding: 12,
          boxBackgroundColor: Colors.black54,
          textTransform: TextTransform.none,
        );
        break;
      case 'verse':
      default:
        next = slide.copyWith(
          fontSizeOverride: template.fontSize,
          isBold: true,
          isItalic: false,
          isUnderline: false,
          letterSpacing: 0,
          lineHeight: 1.3,
          shadowColor: Colors.black,
          shadowBlur: 4,
          shadowOffsetX: 0,
          shadowOffsetY: 1.2,
          outlineWidth: 0,
          boxPadding: 10,
          boxBackgroundColor: slide.boxBackgroundColor,
          textTransform: TextTransform.none,
        );
        break;
    }

    safeSetState(() {
      _slides[selectedSlideIndex] = next;
    });
  }
}
