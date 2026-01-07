part of dashboard_screen;

/// Service mixin for managing output/projection windows.
/// 
/// Handles creating, updating, and closing output windows via desktop_multi_window.
mixin OutputWindowService on State<DashboardScreen> {
  // These fields must be declared in _DashboardScreenState
  // Map<String, int> _outputWindowIds;
  // Set<String> _pendingOutputCreates;
  // Map<String, _OutputRuntimeState> _outputRuntime;
  // Map<String, Map<String, dynamic>> _headlessOutputPayloads;
  // bool _isSendingOutputs;
  
  /// Send the current slide to all armed/configured outputs.
  Future<void> sendCurrentSlideToOutputs({bool createIfMissing = false});
  
  /// Close all open output windows.
  Future<void> closeAllOutputWindows();
  
  /// Open/show output windows and start presenting.
  Future<void> armPresentation();
  
  /// Close output windows and stop presenting.
  Future<void> disarmPresentation();
  
  /// Resolve the screen frame for a given output configuration.
  Future<Rect?> resolveOutputFrame(OutputConfig output);
  
  /// Ensure an output window exists and is showing the given payload.
  Future<bool> ensureOutputWindow(
    OutputConfig output,
    Map<String, dynamic> payload, {
    bool createIfMissing = false,
  });
}
