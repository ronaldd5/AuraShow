part of dashboard_screen;

/// Extension for clipboard operations (cut, copy, paste, delete, select all)
extension ClipboardExtensions on DashboardScreenState {
  void _cutAction() {
    if (!_hasSelection()) return;
    _copyAction();
    _deleteAction();
    _showSnack('Cut selection');
  }

  void _copyAction() {
    if (!_hasSelection()) return;
    final indices = selectedSlides.isNotEmpty
        ? selectedSlides.toList()
        : [selectedSlideIndex];
    _clipboardSlides = [
      for (final i in indices.where((i) => i >= 0 && i < _slides.length))
        _slides[i].copyWith(),
    ];
    _showSnack('Copied ${_clipboardSlides.length} slide(s)');
  }

  void _pasteAction() {
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
