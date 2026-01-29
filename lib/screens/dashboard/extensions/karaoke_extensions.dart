part of '../dashboard_screen.dart';

extension KaraokeExtensions on DashboardScreenState {
  /// Loads a song into the deck, handling karaoke sync and audio linking.
  Future<void> _loadKaraokeSongIntoDeck(Song song) async {
    if (_activeShow == null) {
      _showSnack('Open a show first to add songs.', isError: true);
      return;
    }

    // 1. Create Slides from Stanzas
    final stanzas = song.stanzas;
    if (stanzas.isEmpty) {
      _showSnack('Song content is empty.', isError: true);
      return;
    }

    // Create a robust ID for the new slides
    final baseId = DateTime.now().microsecondsSinceEpoch;
    final List<SlideContent> newSlides = [];

    // Use the first available template or default
    final templateId = _slides.isNotEmpty
        ? _slides.first.templateId
        : 'default';

    for (int i = 0; i < stanzas.length; i++) {
      final stanza = stanzas[i];
      final isTitleSlide = i == 0;

      // Use existing method logic or create generic slide
      // We'll mimic _addMediaAsNewSlide structure but for text

      final slideId = 'slide-${baseId}-$i';

      newSlides.add(
        SlideContent(
          id: slideId,
          templateId: templateId,
          title: isTitleSlide ? song.title : '${song.title} (${i + 1})',
          body:
              stanza, // The body contains the lyrics (possibly with timestamps)
          createdAt: DateTime.now(),
          // Preserve song metadata on the first slide (or all?)
          // Usually metadata is just visual.
          // Preserve song metadata on the first slide
          // We link audio using mediaPath/mediaType so the player picks it up
          audioPath: isTitleSlide ? song.audioPath : null,
          mediaPath: isTitleSlide ? song.audioPath : null,
          mediaType:
              (isTitleSlide &&
                  song.audioPath != null &&
                  song.audioPath!.isNotEmpty)
              ? SlideMediaType.audio
              : null,

          alignmentData: song.alignmentData, // Pass full alignment data

          layers: [], // Text slides need no extra layers
        ),
      );
    }

    // 2. Parse and Apply Timestamps
    // We try to parse timings from the song content (LRC format)
    // If explicit alignmentData exists and content is clean, we might need to parse alignmentData
    // But currently _parseLrc expects LRC string.
    // Assuming song.content contains the [mm:ss] tags if it's an LRC file.

    final Map<Duration, String> timeMap = _parseLrc(song.content);

    // If song.alignmentData is non-null and we parsed nothing from content,
    // maybe alignmentData IS the LRC content?
    if (timeMap.isEmpty && song.alignmentData != null) {
      // Try parsing alignmentData as LRC if it looks like it?
      // Or if it's JSON, we might need a parser.
      // For now, let's assume 'content' is the primary source for LRC.
    }

    List<SlideContent> syncedSlides = newSlides;
    bool hasSync = false;

    if (timeMap.isNotEmpty) {
      syncedSlides = _applySyncToSlides(newSlides, timeMap);
      hasSync = true;
    } else if (song.audioPath != null) {
      // If we have audio but no lyrics sync, we still attach audio to slide 1
      // (Handled by audioPath in SlideContent constructor above)
    }

    // 3. Update State
    setState(() {
      // Append to end of show? or Replace show?
      // Usually "Add to Show" appends.
      _slides.addAll(syncedSlides);

      // If the show was empty, select the first of new slides
      if (_slides.length == syncedSlides.length) {
        selectedSlideIndex = 0;
        selectedSlides = {0};
      } else {
        // Select the first new slide
        selectedSlideIndex = _slides.length - syncedSlides.length;
        selectedSlides = {selectedSlideIndex};
      }

      if (hasSync || song.audioPath != null) {
        autoAdvanceEnabled =
            hasSync; // Enable auto-advance if we have sync data
      }

      // Update active show reference if needed (usually _activeShow!.slides needs update too if it's the source of truth)
      if (_activeShow != null) {
        _activeShow!.slides = _slides;
      }
    });

    _syncSlideThumbnails();
    _saveSlides();
    _showSnack('Added "${song.title}" with ${newSlides.length} slides.');

    // If audio is present, maybe preload/prepare?
    // dashboard's logic for selection will handle playback when selected.
  }
}
