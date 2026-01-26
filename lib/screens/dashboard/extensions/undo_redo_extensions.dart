// lib/screens/dashboard/extensions/undo_redo_extensions.dart

part of '../dashboard_screen.dart';

/// A snapshot of the app state at a specific point in time.
class HistorySnapshot {
  final List<SlideContent> slides;
  final int selectedSlideIndex;
  final Set<String> selectedLayerIds;
  final String? editingLayerId;
  final DateTime timestamp;

  HistorySnapshot({
    required this.slides,
    required this.selectedSlideIndex,
    required this.selectedLayerIds,
    this.editingLayerId,
  }) : timestamp = DateTime.now();
}

extension UndoRedoExtensions on DashboardScreenState {
  // Configuration
  static const int _maxHistorySize = 50;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  // ===========================================================================
  // PUBLIC ACTIONS (Bind these to UI Buttons)
  // ===========================================================================

  void undo() {
    if (_undoStack.isEmpty) {
      _showSnack('Nothing to undo');
      return;
    }

    // 1. Save current state to Redo Stack before moving back
    _addToRedoStack();

    // 2. Pop the last state
    final previousState = _undoStack.removeLast();

    // 3. Restore Application State
    _restoreSnapshot(previousState);

    _showSnack('Undo');
  }

  void redo() {
    if (_redoStack.isEmpty) {
      _showSnack('Nothing to redo');
      return;
    }

    // 1. Save current state to Undo Stack before moving forward
    _addToUndoStack(snapshot: _createSnapshot(), clearRedo: false);

    // 2. Pop the future state
    final nextState = _redoStack.removeLast();

    // 3. Restore
    _restoreSnapshot(nextState);

    _showSnack('Redo');
  }

  /// Call this BEFORE making any change.
  /// [immediate] = true for button clicks (Delete, Align, Start Drag).
  /// [immediate] = false for sliders/dragging (Debounced).
  void recordHistory({bool immediate = true}) {
    if (immediate) {
      _addToUndoStack();
    } else {
      // For rapid changes (sliders), we only save if the user stops interacting
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(_debounceDuration, () {
        _addToUndoStack();
      });
    }
  }

  // ===========================================================================
  // INTERNAL LOGIC
  // ===========================================================================

  HistorySnapshot _createSnapshot() {
    // CRITICAL: We create deep copies of the list and slides
    return HistorySnapshot(
      slides: _slides.map((s) => s.copyWith()).toList(),
      selectedSlideIndex: selectedSlideIndex,
      selectedLayerIds: Set.from(_selectedLayerIds),
      editingLayerId: _editingLayerId,
    );
  }

  void _restoreSnapshot(HistorySnapshot snapshot) {
    setState(() {
      _slides = snapshot.slides;

      // Safety check in case indices are out of bounds
      if (snapshot.selectedSlideIndex < _slides.length) {
        selectedSlideIndex = snapshot.selectedSlideIndex;
      } else {
        selectedSlideIndex = 0;
      }

      _selectedLayerIds = snapshot.selectedLayerIds;
      _editingLayerId = snapshot.editingLayerId;
    });

    // Refresh UI components
    _syncSlideThumbnails();
    // Assuming _syncSlideEditors exists or is handled by setState/Build
  }

  void _addToUndoStack({HistorySnapshot? snapshot, bool clearRedo = true}) {
    // Snapshot the CURRENT state (before it changes)
    final state = snapshot ?? _createSnapshot();

    _undoStack.add(state);

    // Enforce limits
    if (_undoStack.length > _maxHistorySize) {
      _undoStack.removeAt(0); // Remove oldest
    }

    if (clearRedo) {
      _redoStack
          .clear(); // Branching history strategy: New change kills the future
    }
  }

  void _addToRedoStack() {
    final state = _createSnapshot();
    _redoStack.add(state);
  }
}
