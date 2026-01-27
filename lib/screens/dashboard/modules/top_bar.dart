part of '../dashboard_screen.dart';

// Added for window dragging and controls
import 'dart:io';
import 'package:window_manager/window_manager.dart';

extension TopBarModule on DashboardScreenState {
  Widget _buildTopNavBar() {
    final ShowItem? selectedShow =
        (selectedShowIndex != null &&
            selectedShowIndex! >= 0 &&
            selectedShowIndex! < shows.length)
        ? shows[selectedShowIndex!]
        : null;

    final fileMenu = [
      _MiniNavAction(
        label: 'Save',
        icon: Icons.save_outlined,
        shortcut: 'Ctrl+S',
        onSelected: _saveProgramStateToFile,
      ),
      _MiniNavAction(
        label: 'Import',
        icon: Icons.download_outlined,
        shortcut: 'Ctrl+I',
        onSelected: _importProgramStateFromFile,
      ),
      _MiniNavAction(
        label: 'Export',
        icon: Icons.upload_outlined,
        shortcut: 'Ctrl+E',
        onSelected: _exportProgramState,
      ),
      _MiniNavAction(
        label: 'Quit',
        icon: Icons.close,
        shortcut: 'Ctrl+Q',
        onSelected: _quitApp,
      ),
    ];

    final editMenu = [
      _MiniNavAction(
        label: 'Undo',
        icon: Icons.undo,
        shortcut: 'Ctrl+Z',
        onSelected: _undoAction,
      ),
      _MiniNavAction(
        label: 'Redo',
        icon: Icons.redo,
        shortcut: 'Ctrl+Y',
        onSelected: _redoAction,
      ),
      _MiniNavAction(
        label: 'History',
        icon: Icons.history,
        shortcut: 'Ctrl+H',
        onSelected: _historyAction,
      ),
      _MiniNavAction(
        label: 'Cut',
        icon: Icons.cut,
        shortcut: 'Ctrl+X',
        onSelected: _cutAction,
        enabled: _hasSelection(),
      ),
      _MiniNavAction(
        label: 'Copy',
        icon: Icons.copy,
        shortcut: 'Ctrl+C',
        onSelected: copySelection,
        enabled: _hasSelection(),
      ),
      _MiniNavAction(
        label: 'Paste',
        icon: Icons.paste,
        shortcut: 'Ctrl+V',
        onSelected: pasteSelection,
      ),
      _MiniNavAction(
        label: 'Delete',
        icon: Icons.delete_outline,
        shortcut: 'Del',
        onSelected: _deleteAction,
        enabled: _hasSelection(),
      ),
      _MiniNavAction(
        label: 'Select all',
        icon: Icons.select_all,
        shortcut: 'Ctrl+A',
        onSelected: _selectAllAction,
        enabled: _slides.isNotEmpty,
      ),
    ];

    final viewMenu = [
      _MiniNavAction(
        label: 'Show tab',
        icon: Icons.tv,
        onSelected: () => setState(() => selectedTopTab = 0),
      ),
      _MiniNavAction(
        label: 'Edit tab',
        icon: Icons.edit,
        onSelected: () => setState(() => selectedTopTab = 1),
      ),
      _MiniNavAction(
        label: 'Stage tab',
        icon: Icons.personal_video,
        onSelected: () => setState(() => selectedTopTab = 2),
      ),
      _MiniNavAction(
        label: drawerExpanded ? 'Hide drawer' : 'Show drawer',
        icon: Icons.view_day_outlined,
        onSelected: () => setState(() {
          drawerExpanded = !drawerExpanded;
          _drawerHeight = drawerExpanded
              ? _drawerDefaultHeight
              : _drawerMinHeight;
        }),
      ),
    ];

    final helpMenu = [
      _MiniNavAction(
        label: 'About',
        icon: Icons.info_outline,
        onSelected: _showAboutSheet,
      ),
    ];

    // Tab dimensions for animation
    const double tabWidth = 80.0;
    const double tabHeight = 24.0; // Reduced from 28.0

    final tabSwitcher = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 32, // Reduced from 40 for slimmer look
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16), // Slightly tighter radius
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: -1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3), // 3px padding around 24px pill
          child: Stack(
            children: [
              // Animated sliding glass pill indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: (selectedTopTab * tabWidth),
                top: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: tabWidth,
                  height: tabHeight,
                  decoration: BoxDecoration(
                    // Strong Jelly Glass Effect
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(
                          alpha: 0.55,
                        ), // Strong top reflection
                        Colors.white.withValues(alpha: 0.15), // Clear middle
                        Colors.white.withValues(alpha: 0.05), // Darker bottom
                      ],
                      stops: const [
                        0.0,
                        0.45,
                        1.0,
                      ], // Sharp transition for "gloss"
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: 0.6,
                      ), // Defined glass edge
                      width: 1.0,
                    ),
                    boxShadow: [
                      // Rim light / Inner Glow simulation
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.4),
                        blurRadius: 2,
                        spreadRadius: 0,
                        offset: const Offset(0, 1), // Top rim light
                      ),
                      // Drop shadow for depth (Reduced to fit in slim container)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 2, // Reduced from 4
                        spreadRadius: 0,
                        offset: const Offset(0, 1), // Tighter shadow
                      ),
                    ],
                  ),
                ),
              ),
              // Tab buttons row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _topTab(
                    icon: Icons.tv,
                    label: 'Show',
                    selected: selectedTopTab == 0,
                    onTap: () => setState(() => selectedTopTab = 0),
                    width: tabWidth,
                    height: tabHeight,
                  ),
                  _topTab(
                    icon: Icons.edit,
                    label: 'Edit',
                    selected: selectedTopTab == 1,
                    onTap: () => setState(() => selectedTopTab = 1),
                    width: tabWidth,
                    height: tabHeight,
                  ),
                  MouseRegion(
                    onEnter: (_) => _resetStageSwitcherTimer(),
                    child: _topTab(
                      icon: Icons.personal_video,
                      label: 'Stage',
                      selected: selectedTopTab == 2,
                      onTap: () {
                        setState(() => selectedTopTab = 2);
                        _resetStageSwitcherTimer(); // Start timer on switch
                      },
                      width: tabWidth,
                      height: tabHeight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      height: 54, // Restore sleeker top bar height
      color: AppPalette.background,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onPanStart: (details) {
          windowManager.startDragging();
        },
        onDoubleTap: () async {
          if (await windowManager.isMaximized()) {
            windowManager.unmaximize();
          } else {
            windowManager.maximize();
          }
        },
        child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                 // On Mac, leave space for traffic lights
                if (Platform.isMacOS) const SizedBox(width: 70),
                _AnimatedGradientText(
                  text: 'AuraShow',
                  colors: [
                    AppPalette.dustyMauve,
                    AppPalette.willowGreen,
                    AppPalette.dustyMauve,
                  ],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 24),
                _miniNavItem('File', fileMenu, _fileNavKey),
                _miniNavItem('Edit', editMenu, _editNavKey),
                _miniNavItem('View', viewMenu, _viewNavKey),
                _miniNavItem('Help', helpMenu, _helpNavKey),
              ],
            ),
          ),
          Center(child: tabSwitcher),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _openSettingsPage,
                  icon: const Icon(
                    Icons.extension,
                    size: 18,
                    color: AppPalette.textSecondary,
                  ),
                ),
                IconButton(
                  onPressed: _openSettingsPage,
                  icon: const Icon(
                    Icons.settings,
                    size: 18,
                    color: AppPalette.textSecondary,
                  ),
                ),
                Tooltip(
                  message: 'Ghost Mode (Freeze Audience)',
                  child: InkWell(
                    onTap: () {
                      setState(() => isGhostMode = !isGhostMode);
                      // Force update to freeze or unfreeze the outputs
                      _sendCurrentSlideToOutputs();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        isGhostMode ? Icons.visibility_off : Icons.visibility,
                        size: 24,
                        color: isGhostMode ? Colors.amber : Colors.white54,
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: _outputWindowIds.isNotEmpty
                      ? 'Outputs live (double-click to stop)'
                      : 'Show Output',
                  child: InkWell(
                    onTap: _outputWindowIds.isEmpty
                        ? () {
                            debugPrint('out: opening output windows');
                            _togglePresent();
                          }
                        : null,
                    onDoubleTap: _outputWindowIds.isNotEmpty
                        ? () async {
                            debugPrint(
                              'out: double-tap detected, closing outputs',
                            );
                            await _disarmPresentation();
                            if (mounted) setState(() {});
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.present_to_all,
                        size: 24,
                        color: _outputWindowIds.isNotEmpty
                            ? Colors.redAccent
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                  ),
                ),
                // WINDOWS BUTTONS (Minimize, Maximize, Close)
                if (Platform.isWindows) ...[
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.minimize, color: Colors.white, size: 18),
                    onPressed: () => windowManager.minimize(),
                    tooltip: 'Minimize',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.check_box_outline_blank,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () async {
                      if (await windowManager.isMaximized()) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    },
                    tooltip: 'Maximize/Restore',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                    onPressed: () => windowManager.close(),
                    tooltip: 'Close',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _miniNavItem(
    String label,
    List<_MiniNavAction> actions,
    GlobalKey anchorKey,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        key: anchorKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => _showMiniMenu(anchorKey, actions),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  void _showMiniMenu(GlobalKey anchorKey, List<_MiniNavAction> actions) {
    final context = anchorKey.currentContext;
    if (context == null || actions.isEmpty) return;

    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final position = box.localToGlobal(Offset.zero, ancestor: overlay);
    showMenu<_MiniNavAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + box.size.height,
        position.dx + box.size.width,
        position.dy,
      ),
      items: [
        for (final action in actions)
          PopupMenuItem<_MiniNavAction>(
            value: action,
            enabled: action.enabled,
            child: Row(
              children: [
                if (action.icon != null) ...[
                  Icon(
                    action.icon,
                    size: 16,
                    color: action.enabled ? Colors.white70 : Colors.white24,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(action.label)),
                if (action.shortcut != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    action.shortcut!,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ],
            ),
          ),
      ],
    ).then((selected) {
      if (selected != null && selected.enabled) {
        selected.onSelected();
      }
    });
  }

  Widget _topTab({
    required IconData icon,
    required String label,
    bool selected = false,
    required VoidCallback onTap,
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0.5, end: selected ? 1.0 : 0.5),
                    builder: (context, opacity, child) => Icon(
                      icon,
                      size: 13,
                      color: Colors.white.withValues(alpha: opacity),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(label),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedGradientText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;

  const _AnimatedGradientText({
    required this.text,
    required this.style,
    required this.colors,
  });

  @override
  State<_AnimatedGradientText> createState() => _AnimatedGradientTextState();
}

class _AnimatedGradientTextState extends State<_AnimatedGradientText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: widget.colors,
              transform: _GradientRotation(_controller.value * 2 * math.pi),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.style.copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}

class _GradientRotation extends GradientTransform {
  final double radians;
  const _GradientRotation(this.radians);
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.rotationZ(radians);
  }
}
