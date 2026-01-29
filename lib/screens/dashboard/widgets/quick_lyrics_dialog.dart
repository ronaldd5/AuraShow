import 'package:flutter/material.dart';
import '../../../core/theme/palette.dart';
import '../../../models/slide_model.dart';
import 'package:uuid/uuid.dart';

/// Smart Lyrics Parser Dialog - FreeShow-style Quick Lyrics workflow
class QuickLyricsDialog extends StatefulWidget {
  final String? initialName;
  final String? initialCategory;
  final String? initialLyrics;
  final bool
  canGoBack; // If true, show a back button to return to search results

  const QuickLyricsDialog({
    Key? key,
    this.initialName,
    this.initialCategory,
    this.initialLyrics,
    this.canGoBack = false,
  }) : super(key: key);

  @override
  State<QuickLyricsDialog> createState() => _QuickLyricsDialogState();
}

class _QuickLyricsDialogState extends State<QuickLyricsDialog> {
  final TextEditingController _lyricsController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  // Parser options
  bool _autoCapitalize = true;
  int _maxLinesPerSlide = 4;
  bool _detectGroups = true;

  // Extracted metadata
  String _extractedTitle = '';
  String _extractedAuthor = '';
  String _extractedCcli = '';
  String _extractedCopyright = '';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialName ?? '';
    // Pre-populate lyrics if provided (from web search)
    if (widget.initialLyrics != null && widget.initialLyrics!.isNotEmpty) {
      _lyricsController.text = widget.initialLyrics!;
    }
  }

  @override
  void dispose() {
    _lyricsController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  /// Parse raw lyrics text into structured slides
  List<SlideContent> _parseLyrics(String rawText) {
    final slides = <SlideContent>[];

    // First, extract metadata from ANYWHERE in text (not just top)
    final lines = rawText.split('\n');
    final contentLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      final lowerTrimmed = trimmed.toLowerCase();

      // Check for metadata patterns - these should be EXTRACTED, not included in slides
      if (lowerTrimmed.startsWith('title:') ||
          lowerTrimmed.startsWith('title=') ||
          lowerTrimmed.startsWith('title -')) {
        final sepIdx = trimmed.indexOf(RegExp(r'[:=\-]'));
        if (sepIdx > 0) {
          _extractedTitle = trimmed.substring(sepIdx + 1).trim();
          // Also set the title controller if empty
          if (_titleController.text.isEmpty && _extractedTitle.isNotEmpty) {
            _titleController.text = _extractedTitle;
          }
        }
        // DON'T add to contentLines - skip this line
        continue;
      } else if (lowerTrimmed.startsWith('author:') ||
          lowerTrimmed.startsWith('author=') ||
          lowerTrimmed.startsWith('artist:') ||
          lowerTrimmed.startsWith('by:')) {
        final sepIdx = trimmed.indexOf(RegExp(r'[:=]'));
        if (sepIdx > 0) {
          _extractedAuthor = trimmed.substring(sepIdx + 1).trim();
        }
        // DON'T add to contentLines - skip this line
        continue;
      } else if (lowerTrimmed.startsWith('ccli:') ||
          lowerTrimmed.startsWith('ccli=') ||
          lowerTrimmed.startsWith('ccli#') ||
          lowerTrimmed.startsWith('ccli #')) {
        final sepIdx = trimmed.indexOf(RegExp(r'[:=#]'));
        if (sepIdx > 0) {
          _extractedCcli = trimmed.substring(sepIdx + 1).trim();
        }
        continue;
      } else if (lowerTrimmed.startsWith('copyright:') ||
          lowerTrimmed.startsWith('copyright=') ||
          lowerTrimmed.startsWith('©')) {
        _extractedCopyright = trimmed
            .replaceFirst(
              RegExp(r'^(copyright[:=]|©)\s*', caseSensitive: false),
              '',
            )
            .trim();
        continue;
      }

      // Not metadata - add to content
      contentLines.add(line);
    }

    // Rejoin content and split by double newlines (blank lines)
    final content = contentLines.join('\n');
    final chunks = content.split(RegExp(r'\n\s*\n')); // Split by blank lines

    String currentGroup = 'Verse';
    int groupCounter = 1;

    for (final chunk in chunks) {
      if (chunk.trim().isEmpty) continue;

      final chunkLines = chunk.split('\n');
      String groupLabel = '$currentGroup $groupCounter';
      final textLines = <String>[];

      for (final line in chunkLines) {
        final trimmed = line.trim();

        // Check for group markers: [Verse 1], [Chorus], [Bridge], etc.
        if (_detectGroups && trimmed.startsWith('[') && trimmed.endsWith(']')) {
          final label = trimmed.substring(1, trimmed.length - 1).trim();
          if (label.isNotEmpty) {
            groupLabel = label;
            // Update current group type for next unmarked section
            if (label.toLowerCase().contains('verse')) {
              currentGroup = 'Verse';
              final numMatch = RegExp(r'\d+').firstMatch(label);
              if (numMatch != null) {
                groupCounter = int.tryParse(numMatch.group(0)!) ?? groupCounter;
              }
              groupCounter++;
            } else if (label.toLowerCase().contains('chorus')) {
              // Chorus doesn't increment, stays same
            }
          }
          continue; // Don't add the bracket line to text
        }

        // Apply auto-capitalize if enabled
        String processedLine = trimmed;
        if (_autoCapitalize && processedLine.isNotEmpty) {
          processedLine =
              processedLine[0].toUpperCase() + processedLine.substring(1);
        }

        if (processedLine.isNotEmpty) {
          textLines.add(processedLine);
        }
      }

      if (textLines.isEmpty) continue;

      // Apply max lines per slide splitting
      if (_maxLinesPerSlide > 0 && textLines.length > _maxLinesPerSlide) {
        // Split into multiple slides
        for (int i = 0; i < textLines.length; i += _maxLinesPerSlide) {
          final end = (i + _maxLinesPerSlide > textLines.length)
              ? textLines.length
              : i + _maxLinesPerSlide;
          final slideLines = textLines.sublist(i, end);
          final partNum = (i ~/ _maxLinesPerSlide) + 1;
          final totalParts = (textLines.length / _maxLinesPerSlide).ceil();

          slides.add(
            _createSlide(
              title: totalParts > 1
                  ? '$groupLabel ($partNum/$totalParts)'
                  : groupLabel,
              body: slideLines.join('\n'),
            ),
          );
        }
      } else {
        slides.add(_createSlide(title: groupLabel, body: textLines.join('\n')));
      }
    }

    // If no slides created, add an empty one
    if (slides.isEmpty) {
      slides.add(_createSlide(title: 'Slide 1', body: ''));
    }

    return slides;
  }

  SlideContent _createSlide({required String title, required String body}) {
    return SlideContent(
      id: const Uuid().v4(),
      title: title,
      body: body,
      templateId: 'default',
      fontSizeOverride: 60,
      alignOverride: TextAlign.center,
      verticalAlign: VerticalAlign.middle,
      layers: [
        SlideLayer(
          id: const Uuid().v4(),
          label: 'Text',
          kind: LayerKind.textbox,
          role: LayerRole.foreground,
          text: body,
          left: 0.05,
          top: 0.1,
          width: 0.9,
          height: 0.8,
          opacity: 1.0,
          fontSize: 60,
          textColor: Colors.white,
          align: TextAlign.center,
        ),
      ],
    );
  }

  void _createShow() {
    final slides = _parseLyrics(_lyricsController.text);
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (_extractedTitle.isNotEmpty ? _extractedTitle : 'Untitled Show');

    Navigator.of(context).pop({
      'mode': 'quick_lyrics',
      'name': title,
      'author': _extractedAuthor,
      'ccli': _extractedCcli,
      'copyright': _extractedCopyright,
      'slides': slides,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppPalette.carbonBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        height: 550,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                if (widget.canGoBack)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    tooltip: 'Back to search results',
                    onPressed: () =>
                        Navigator.of(context).pop({'mode': 'go_back'}),
                  ),
                const Text(
                  'Quick Lyrics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title input
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Show Title',
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Main content row
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Large text area
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _lyricsController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText:
                              'Paste or type lyrics here...\n\n'
                              'Use [Verse 1], [Chorus], [Bridge] to label sections.\n'
                              'Leave a blank line between sections.\n\n'
                              'Metadata (optional):\n'
                              'Title: Amazing Grace\n'
                              'Author: John Newton\n'
                              'CCLI: 12345',
                          hintStyle: TextStyle(
                            color: Colors.white24,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Options panel
                  SizedBox(
                    width: 180,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Options',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Auto-capitalize toggle
                          _optionToggle(
                            label: 'Auto-capitalize',
                            value: _autoCapitalize,
                            onChanged: (v) =>
                                setState(() => _autoCapitalize = v),
                          ),
                          const SizedBox(height: 12),

                          // Detect groups toggle
                          _optionToggle(
                            label: 'Detect groups',
                            value: _detectGroups,
                            onChanged: (v) => setState(() => _detectGroups = v),
                          ),
                          const SizedBox(height: 16),

                          // Max lines per slide
                          const Text(
                            'Max lines/slide',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _maxLinesPerSlide,
                            dropdownColor: AppPalette.carbonBlack,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.black26,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [2, 3, 4, 5, 6, 8, 0]
                                .map(
                                  (n) => DropdownMenuItem(
                                    value: n,
                                    child: Text(
                                      n == 0 ? 'No limit' : '$n lines',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _maxLinesPerSlide = v ?? 4),
                          ),

                          const Spacer(),

                          // Preview count
                          StreamBuilder<Object>(
                            stream: null,
                            builder: (context, snapshot) {
                              final slideCount =
                                  _lyricsController.text.isNotEmpty
                                  ? _parseLyrics(_lyricsController.text).length
                                  : 0;
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppPalette.accent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.slideshow,
                                      size: 16,
                                      color: AppPalette.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$slideCount slides',
                                      style: const TextStyle(
                                        color: AppPalette.accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Create Show'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _createShow,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppPalette.accent,
            side: const BorderSide(color: Colors.white38),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
