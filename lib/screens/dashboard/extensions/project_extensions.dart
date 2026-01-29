part of dashboard_screen;

/// Extension for project management (New, Save, Open, Export)
extension ProjectExtensions on DashboardScreenState {
  Map<String, dynamic> _buildProgramStateSnapshot() {
    return {
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'shows': shows
          .map((s) => {'name': s.name, 'category': s.category})
          .toList(),
      'folders': folders,
      'showCategories': showCategories,
      'playlists': playlists,
      'preShowPlaylists': _preshowPlaylists.map((p) => p.toJson()).toList(),
      'projects': projects,
      'slides': _slides.map((s) => s.toJson()).toList(),
      'styles': _styles.map((s) => s.toJson()).toList(),
      'outputs': _outputs.map((o) => o.toJson()).toList(),
      'profiles': profiles,
      'settings': {
        'selectedTheme': selectedThemeName,
        'use24HourClock': use24HourClock,
        'lowerThirdHeight': lowerThirdHeight,
        'lowerThirdGradient': lowerThirdGradient,
        'stageNotesScale': stageNotesScale,
        'selectedTopTab': selectedTopTab,
      },
    };
  }

  String _generateTimestamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<File?> _writeStateFile(String directory, {String? fileName}) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final name =
        fileName ??
        'aurashow-state-${_generateTimestamp()}.${DashboardScreenState._stateFileExtension}';
    final path = directory + Platform.pathSeparator + name;
    final file = File(path);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(_buildProgramStateSnapshot()));
    return file;
  }

  Future<String?> _promptSaveFileName() async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppPalette.carbonBlack,
          title: const Text('Save As'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'File name',
              hintText: 'Leave blank for automatic name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _coerceFileName(String? raw) {
    final fallback =
        'aurashow-state-${_generateTimestamp()}.${DashboardScreenState._stateFileExtension}';
    if (raw == null || raw.isEmpty) return fallback;
    var cleaned = raw.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[\\/:*?\"<>|]'), '_');
    // Strip any user-entered extension to enforce .psshow.
    if (cleaned.contains('.')) {
      cleaned = cleaned.split('.').first;
    }
    if (cleaned.isEmpty) return fallback;
    return '$cleaned.${DashboardScreenState._stateFileExtension}';
  }

  Future<void> _saveProgramStateToFile() async {
    final targetDir = saveFolder;
    if (targetDir == null || targetDir.isEmpty) {
      await _showNoticeDialog(
        'Save failed',
        'Set a Save Folder first in Settings > Saves. After that, clicking Save will write directly to that folder.',
        offerSettings: true,
      );
      return;
    }
    final desiredName = await _promptSaveFileName();
    if (desiredName == null) {
      return;
    }
    final finalName = _coerceFileName(desiredName);
    try {
      final file = await _writeStateFile(targetDir, fileName: finalName);
      if (file != null) {
        await _showNoticeDialog(
          'Save successful',
          'Saved to ${file.path}',
          success: true,
        );
      } else {
        await _showNoticeDialog(
          'Save failed',
          'No file was written. Check folder permissions.',
          success: false,
        );
      }
    } catch (e) {
      await _showNoticeDialog(
        'Save failed',
        'Could not save: $e',
        success: false,
      );
    }
  }

  Future<void> _exportProgramState() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) {
      _showSnack('Export canceled');
      return;
    }
    final file = await _writeStateFile(dir);
    if (file != null) {
      _showSnack('Exported to ${file.path}');
    }
  }

  Future<void> _importProgramStateFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [DashboardScreenState._stateFileExtension, 'json'],
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      _showSnack('Import canceled');
      return;
    }

    final path = result.files.first.path!;
    final file = File(path);
    if (!file.existsSync()) {
      _showSnack('File not found');
      return;
    }

    try {
      final content = await file.readAsString();
      final decoded = json.decode(content);
      if (decoded is! Map<String, dynamic>) {
        _showSnack('Invalid save file');
        return;
      }

      // Load state from map
      setState(() {
        if (decoded.containsKey('slides')) {
          _slides = (decoded['slides'] as List)
              .map((e) => SlideContent.fromJson(e))
              .toList();
          if (_slides.isNotEmpty) {
            selectedSlideIndex = 0;
            selectedSlides = {0};
          }
        }

        if (decoded.containsKey('styles')) {
          final list = decoded['styles'] as List;
          _styles
            ..clear()
            ..addAll(list.map((e) => StylePreset.fromJson(e)));
        }

        if (decoded.containsKey('outputs')) {
          final list = decoded['outputs'] as List;
          _outputs = list.map((e) => OutputConfig.fromJson(e)).toList();
        }

        if (decoded.containsKey('profiles')) {
          profiles = List<String>.from(decoded['profiles']);
        }

        if (decoded.containsKey('settings')) {
          final s = decoded['settings'];
          selectedThemeName = s['selectedTheme'] ?? selectedThemeName;
          use24HourClock = s['use24HourClock'] ?? use24HourClock;
          lowerThirdHeight = s['lowerThirdHeight'] ?? lowerThirdHeight;
          lowerThirdGradient = s['lowerThirdGradient'] ?? lowerThirdGradient;
          stageNotesScale = s['stageNotesScale'] ?? stageNotesScale;
          // Don't restore selectedTopTab to avoid confusion
        }

        // Restore simple lists
        if (decoded.containsKey('shows')) {
          final list = decoded['shows'] as List;
          shows = list
              .map((e) => ShowItem(name: e['name'], category: e['category']))
              .toList();
        }
        if (decoded.containsKey('folders')) {
          folders = List<String>.from(decoded['folders']);
        }
        if (decoded.containsKey('showCategories')) {
          showCategories = List<String>.from(decoded['showCategories']);
        }
        if (decoded.containsKey('playlists')) {
          playlists = List<String>.from(decoded['playlists']);
        }
        if (decoded.containsKey('projects')) {
          projects = List<String>.from(decoded['projects']);
        }
        if (decoded.containsKey('preShowPlaylists')) {
          final list = decoded['preShowPlaylists'] as List;
          _preshowPlaylists = list
              .map((e) => PreShowPlaylist.fromJson(e))
              .toList();
        }
      });

      _applyThemePreset(selectedThemeName, persist: false);
      _ensureOutputVisibilityDefaults();
      _syncSlideThumbnails();
      _syncSlideEditors();
      _showSnack('Program state loaded');
    } catch (e) {
      _showSnack('Import failed: $e');
    }
  }

  Widget _buildShowListPanel() {
    if (_activeProjectView != null) {
      return _buildProjectDetailView(_activeProjectView!);
    }

    return Container(
      color: AppPalette.carbonBlack,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + _drawerHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _frostedBox(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Center(
                      child: Text(
                        'Projects',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _projectsList()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _newProjectControl(),
        ],
      ),
    );
  }

  Widget _buildProjectDetailView(ShowItem project) {
    // Find the ProjectNode mapping to this ShowItem (hybrid state!)
    final projectNode = _fileSystem.firstWhereOrNull(
      (n) =>
          n is ProjectNode &&
          n.name == project.name &&
          n.type == NodeType.project,
    );
    final projectId = projectNode?.id;

    // Get children (Shows) of this project
    final showsInProject = getChildren(projectId);

    return Container(
      color: AppPalette.background,
      child: FocusTraversalGroup(
        child: Stack(
          children: [
            Column(
              children: [
                // HEADER
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppPalette.surface,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white70,
                        ),
                        tooltip: 'Back to Projects',
                        onPressed: () =>
                            setState(() => _activeProjectView = null),
                      ),
                      Expanded(
                        child: Text(
                          project.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                // BODY: List of Shows
                Expanded(
                  child: showsInProject.isEmpty
                      ? _projectEmptyState(
                          message:
                              "No shows in this project yet. Click '+ New Show' to add one.",
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            8,
                            8,
                            8,
                            8 + _drawerHeight + 80,
                          ),
                          itemCount: showsInProject.length,
                          itemBuilder: (context, index) {
                            final showNode = showsInProject[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.slideshow,
                                color: AppPalette.accent,
                              ),
                              title: Text(
                                showNode.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: const Text(
                                "Show",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              tileColor: Colors.white.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onTap: () {
                                if (showNode is ShowNode) {
                                  _openShow(showNode);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            // FLOATING ACTION BUTTON
            Positioned(
              right: 16,
              bottom: 16 + _drawerHeight,
              child: FloatingActionButton.extended(
                backgroundColor: AppPalette.accent,
                icon: const Icon(Icons.add),
                label: const Text("New Show"),
                onPressed: () => _showNewShowDialog(
                  context,
                  defaultCategory: project.category,
                  parentProjectId: projectId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectsList() {
    return ListView(
      padding: EdgeInsets.zero,
      children: _buildNodesForParent(null),
    );
  }

  List<Widget> _buildNodesForParent(String? parentId, {int depth = 0}) {
    final children = getChildren(parentId);
    return children.map((node) {
      if (node.type == NodeType.project) {
        return _buildProjectNodeTile(node as ProjectNode, depth);
      } else {
        return _buildFolderNodeTile(node as FolderNode, depth);
      }
    }).toList();
  }

  Widget _buildFolderNodeTile(FolderNode folder, int depth) {
    return DragTarget<String>(
      onAccept: (draggedNodeId) => moveNode(draggedNodeId, folder.id),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Column(
          children: [
            InkWell(
              onTap: () =>
                  setState(() => folder.isExpanded = !folder.isExpanded),
              onSecondaryTapDown: (d) => _showFolderMenu(
                context: context,
                category: folder.name, // Mapping expected category string
                position: d.globalPosition,
                // TODO: Pass nodeId for stricter actions
              ),
              child: Container(
                color: isHovered ? Colors.white10 : Colors.transparent,
                padding: EdgeInsets.only(
                  left: 12.0 + (depth * 16),
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      folder.isExpanded ? Icons.folder_open : Icons.folder,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        folder.name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (folder.isExpanded)
              ..._buildNodesForParent(folder.id, depth: depth + 1),
          ],
        );
      },
    );
  }

  Widget _buildProjectNodeTile(ProjectNode project, int depth) {
    // Get children (shows) of this project
    final showsInProject = getChildren(project.id);

    // Draggable wrapper for moving
    return Draggable<String>(
      data: project.id,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          color: AppPalette.carbonBlack.withOpacity(0.8),
          child: Row(
            children: [
              const Icon(Icons.description, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(project.name, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _renderProjectRowContent(project, depth, showsInProject.length),
      ),
      child: Column(
        children: [
          _renderProjectRowContent(project, depth, showsInProject.length),
          // Show child shows inline when expanded
          if (project.isExpanded)
            ...showsInProject.map(
              (showNode) => _buildShowNodeTile(showNode as ShowNode, depth + 1),
            ),
        ],
      ),
    );
  }

  /// Render a single show node (opens in center panel when clicked)
  Widget _buildShowNodeTile(ShowNode show, int depth) {
    final isActive = _activeShow?.id == show.id;

    return InkWell(
      onTap: () => _openShow(show),
      child: Container(
        padding: EdgeInsets.only(
          left: 12.0 + (depth * 16),
          right: 12,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppPalette.accent.withValues(alpha: 0.3)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.slideshow,
              size: 14,
              color: isActive ? Colors.white : AppPalette.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                show.name,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderProjectRowContent(
    ProjectNode project,
    int depth,
    int childCount,
  ) {
    // Legacy support: finding index in flat list for selection highlight
    final globalIndex = shows.indexWhere((s) => s.name == project.name);
    final selected = selectedShowIndex == globalIndex;

    return InkWell(
      onTap: () {
        // Toggle expansion to show child shows inline
        setState(() {
          project.isExpanded = !project.isExpanded;
          if (globalIndex != -1) {
            selectedShowIndex = globalIndex;
          }
        });
      },
      onSecondaryTapDown: (d) {
        // Create temp Item for menu compatibility
        final item = ShowItem(name: project.name, category: project.category);
        _showProjectMenu(item: item, position: d.globalPosition);
      },
      child: Container(
        padding: EdgeInsets.only(
          left: 12.0 + (depth * 16),
          right: 12,
          top: 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppPalette.accent : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.description,
              size: 16,
              color: selected ? Colors.white : AppPalette.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                project.name,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            // Show count badge if has children
            if (childCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$childCount',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            // Expand/collapse indicator
            Icon(
              project.isExpanded ? Icons.expand_less : Icons.chevron_right,
              color: Colors.white24,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectEmptyState({String message = 'No items yet'}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.dustyMauve),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _newProjectControl() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.dustyMauve),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pillButton(
            icon: Icons.folder_open,
            label: null,
            onTap: _createNewFolderFromShortcut,
            tooltip: 'New folder',
            isFirst: true,
          ),
          Container(width: 1, height: 30, color: Colors.white12),
          _pillButton(
            icon: Icons.add,
            label: 'New project',
            onTap: () => _showNewShowDialog(context),
            tooltip: 'New project',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
    String? tooltip,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 12 : 14,
        vertical: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppPalette.accent, size: 16),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        key: label == null ? _newProjectButtonKey : null,
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(isFirst ? 18 : 0),
          right: Radius.circular(isLast ? 18 : 0),
        ),
        child: content,
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _inlineNewProjectButton({String? targetFolder}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _createQuickProject(category: targetFolder),
        icon: Icon(Icons.add, size: 16, color: AppPalette.accent),
        label: const Text('New project'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: AppPalette.dustyMauve),
          backgroundColor: AppPalette.carbonBlack,
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Future<void> _showFolderMenu({
    required BuildContext context,
    required Offset position,
    String? category,
  }) async {
    final overlay = Overlay.of(context);
    final box = overlay.context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final items = <PopupMenuEntry<String>>[];
    if (category != null) {
      items.addAll(const [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
      ]);
      items.addAll(const [
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 8),
              Text('Duplicate'),
            ],
          ),
        ),
      ]);
      items.addAll(const [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
      ]);
      items.add(const PopupMenuDivider());
    }

    items.addAll(const [
      PopupMenuItem(
        value: 'newProject',
        child: Row(
          children: [
            Icon(Icons.add, size: 16),
            SizedBox(width: 8),
            Text('New project'),
          ],
        ),
      ),
    ]);
    items.addAll(const [
      PopupMenuItem(
        value: 'newFolder',
        child: Row(
          children: [
            Icon(Icons.create_new_folder_outlined, size: 16),
            SizedBox(width: 8),
            Text('New folder'),
          ],
        ),
      ),
    ]);

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & box.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: items,
    );

    switch (selection) {
      case 'rename':
        if (category != null) _promptRenameFolder(category);
        break;
      case 'duplicate':
        if (category != null) _duplicateFolder(category);
        break;
      case 'delete':
        if (category != null) _deleteFolder(category);
        break;
      case 'newProject':
        _createQuickProject(category: category);
        break;
      case 'newFolder':
        _createNewFolderFromShortcut();
        break;
      default:
        break;
    }
  }

  Future<void> _showProjectMenu({
    required ShowItem item,
    required Offset position,
  }) async {
    final overlay = Overlay.of(context);
    final box = overlay.context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & box.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: const [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 8),
              Text('Duplicate'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'newProject',
          child: Row(
            children: [
              Icon(Icons.add, size: 16),
              SizedBox(width: 8),
              Text('New project'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'newFolder',
          child: Row(
            children: [
              Icon(Icons.create_new_folder_outlined, size: 16),
              SizedBox(width: 8),
              Text('New folder'),
            ],
          ),
        ),
      ],
    );

    switch (selection) {
      case 'rename':
        _promptRenameProject(item);
        break;
      case 'duplicate':
        _duplicateProject(item);
        break;
      case 'delete':
        _deleteProject(item);
        break;
      case 'newProject':
        _showNewShowDialog(context, defaultCategory: item.category);
        break;
      case 'newFolder':
        _createNewFolderFromShortcut();
        break;
      default:
        break;
    }
  }

  void _createNewFolderFromShortcut() {
    _createFolder(name: 'Unnamed');
  }

  void _createFolder({required String name}) {
    final trimmed = name.trim();
    final unique = _uniqueFolderName(trimmed.isEmpty ? 'Unnamed' : trimmed);
    setState(() {
      _fileSystem.add(
        FolderNode(
          id: const Uuid().v4(),
          name: unique,
          parentId: null, // Always create at root for shortcut? Or selected?
        ),
      );
    });
  }

  String _uniqueFolderName(String base) {
    // Check against top-level folders in file system
    if (!_fileSystem.any((n) => n is FolderNode && n.name == base)) return base;
    int i = 2;
    while (_fileSystem.any((n) => n is FolderNode && n.name == '$base $i')) {
      i++;
    }
    return '$base $i';
  }

  Future<void> _showNewShowDialog(
    BuildContext context, {
    String? defaultCategory,
    String? parentProjectId,
  }) async {
    // Get unique categories for dropdown
    final categories = _fileSystem
        .whereType<FolderNode>()
        .map((f) => f.name)
        .toSet()
        .toList();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => NewShowDialog(
        availableCategories: categories,
        defaultCategory: defaultCategory,
      ),
    );

    if (result == null) return;

    final mode = result['mode'];
    final name = result['name'] as String;
    final category = result['category'] as String?;
    final data = result['data'];

    if (mode == 'empty' || mode == 'web_import') {
      _createQuickProject(
        name: name,
        category: category,
        importedSong: data,
        parentProjectId: parentProjectId,
      );
    } else if (mode == 'quick_lyrics') {
      // Open the Smart Quick Lyrics dialog
      final quickResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) =>
            QuickLyricsDialog(initialName: name, initialCategory: category),
      );

      if (quickResult != null) {
        final showName = quickResult['name'] as String? ?? 'Quick Lyrics';
        final slides = quickResult['slides'] as List<SlideContent>? ?? [];

        // Create the show with pre-parsed slides
        if (parentProjectId != null) {
          // Creating inside a project
          final finalName = _uniqueProjectName(showName, parentProjectId);
          setState(() {
            final newShow = ShowNode(
              id: const Uuid().v4(),
              name: finalName,
              parentId: parentProjectId,
              slides: slides,
            );
            _fileSystem.add(newShow);
            _openShow(newShow); // Open the newly created show
          });
        } else {
          // Create a new project first, then add the show
          String? parentFolderId;
          if (category != null && category.isNotEmpty) {
            final folder = _fileSystem.firstWhereOrNull(
              (n) => n is FolderNode && n.name == category,
            );
            parentFolderId = folder?.id;
          }

          final projectName = _uniqueProjectName(showName, parentFolderId);
          final projectId = const Uuid().v4();

          setState(() {
            // Create project
            _fileSystem.add(
              ProjectNode(
                id: projectId,
                name: projectName,
                parentId: parentFolderId,
                category: category,
              ),
            );

            // Create show inside project with slides
            final newShow = ShowNode(
              id: const Uuid().v4(),
              name: showName,
              parentId: projectId,
              slides: slides,
            );
            _fileSystem.add(newShow);
            _openShow(newShow);
          });
        }
        _showSnack('Created show with ${slides.length} slides');
      }
    } else if (mode == 'quick_lyrics_prefilled') {
      // Web search returned pre-formatted lyrics, open QuickLyricsDialog with them
      final prefilledLyrics = result['lyrics'] as String? ?? '';

      final quickResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => QuickLyricsDialog(
          initialName: name,
          initialCategory: category,
          initialLyrics: prefilledLyrics,
          canGoBack: true, // Allow user to go back to search results
        ),
      );

      // Handle "go back" to re-show NewShowDialog with same parameters
      if (quickResult != null && quickResult['mode'] == 'go_back') {
        // Re-show the New Show dialog so user can pick different search result
        _showNewShowDialog(
          context,
          defaultCategory: category,
          parentProjectId: parentProjectId,
        );
        return; // Exit current flow
      }

      if (quickResult != null) {
        final showName = quickResult['name'] as String? ?? 'Web Search';
        final slides = quickResult['slides'] as List<SlideContent>? ?? [];
        final alignmentData = quickResult['alignmentData'] as String?;

        // Process slides with sync data if available
        List<SlideContent> finalSlides = slides;
        if (alignmentData != null && alignmentData.isNotEmpty) {
          final timeMap = _parseLrc(alignmentData);
          if (timeMap.isNotEmpty) {
            finalSlides = _applySyncToSlides(slides, timeMap);
            // Ensure all slides have the alignmentData preserved for future editing
            for (var slide in finalSlides) {
              slide.alignmentData = alignmentData;
            }
          }
        }

        // Create the show with pre-parsed slides
        if (parentProjectId != null) {
          final finalName = _uniqueProjectName(showName, parentProjectId);
          setState(() {
            final newShow = ShowNode(
              id: const Uuid().v4(),
              name: finalName,
              parentId: parentProjectId,
              slides: finalSlides,
            );
            _fileSystem.add(newShow);
            _openShow(newShow);
          });
        } else {
          String? parentFolderId;
          if (category != null && category.isNotEmpty) {
            final folder = _fileSystem.firstWhereOrNull(
              (n) => n is FolderNode && n.name == category,
            );
            parentFolderId = folder?.id;
          }

          final projectName = _uniqueProjectName(showName, parentFolderId);
          final projectId = const Uuid().v4();

          setState(() {
            _fileSystem.add(
              ProjectNode(
                id: projectId,
                name: projectName,
                parentId: parentFolderId,
                category: category,
              ),
            );

            final newShow = ShowNode(
              id: const Uuid().v4(),
              name: showName,
              parentId: projectId,
              slides: finalSlides,
            );
            _fileSystem.add(newShow);
            _openShow(newShow);
          });
        }
        _showSnack('Created show with ${slides.length} slides from web search');
      }
    }
  }

  void _createQuickProject({
    String? name,
    String? category,
    dynamic importedSong,
    String? parentProjectId,
  }) {
    // If parentProjectId is provided, we are creating a SHOW inside a PROJECT
    if (parentProjectId != null) {
      final finalName = _uniqueProjectName(
        name ?? "New Show",
        parentProjectId,
      ); // Reusing uniqueness logic
      setState(() {
        final newShow = ShowNode(
          id: const Uuid().v4(),
          name: finalName,
          parentId: parentProjectId,
          originalSongId: importedSong is Song ? importedSong.id : null,
        );
        _fileSystem.add(newShow);
        _showSnack('Created show "$finalName" inside project');
      });
      return;
    }

    // Otherwise, creating a new PROJECT (potentially inside a folder)
    String? parentFolderId;
    if (category != null && category.isNotEmpty) {
      final folder = _fileSystem.firstWhereOrNull(
        (n) => n is FolderNode && n.name == category,
      );
      parentFolderId = folder?.id;
    }

    // Ensure unique name
    final finalName = _uniqueProjectName(
      name ?? _defaultProjectName(),
      parentFolderId,
    );

    setState(() {
      final newProject = ProjectNode(
        id: const Uuid().v4(),
        name: finalName,
        parentId: parentFolderId, // Use the resolved parentId
        category: category,
      );
      _fileSystem.add(newProject);

      if (importedSong is Song) {
        // TODO: convert song to slides and add to new project
        _showSnack(
          'Imported "${importedSong.title}" (Conversion to slides pending)',
        );
      }

      // Auto-open the new project
      _activeProjectView = ShowItem(name: finalName, category: category);
    });
  }

  String _uniqueProjectName(String base, String? parentId) {
    // Check name uniqueness within the same parent
    final siblings = getChildren(parentId);
    if (!siblings.any((n) => n.name == base)) return base;

    int i = 2;
    while (siblings.any((n) => n.name == '$base ($i)')) {
      i++;
    }
    return '$base ($i)';
  }

  String _defaultProjectName() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final yy = (now.year % 100).toString().padLeft(2, '0');
    return '$mm/$dd/$yy';
  }

  Future<void> _promptRenameFolder(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppPalette.carbonBlack,
          title: const Text('Rename folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Folder name'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final newNameRaw = result?.trim();
    if (newNameRaw == null || newNameRaw.isEmpty || newNameRaw == oldName)
      return;
    final newName = _uniqueFolderName(newNameRaw);

    setState(() {
      final folder = _fileSystem.firstWhereOrNull(
        (n) => n is FolderNode && n.name == oldName,
      );
      if (folder != null) {
        folder.name = newName;
      }
    });
  }

  Future<void> _promptRenameProject(ShowItem item) async {
    final controller = TextEditingController(text: item.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppPalette.carbonBlack,
          title: const Text('Rename project'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Project name'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final newNameRaw = result?.trim();
    if (newNameRaw == null || newNameRaw.isEmpty || newNameRaw == item.name)
      return;
    // Find parentId from existing item logic?
    // We are migrating, so item is a ShowItem.
    // Try to find the node.
    final projectNode = _fileSystem.firstWhereOrNull(
      (n) =>
          n is ProjectNode && n.name == item.name && n.type == NodeType.project,
    );
    final String? parentId = projectNode?.parentId;

    final newName = _uniqueProjectName(newNameRaw, parentId);

    setState(() {
      if (projectNode != null) {
        projectNode.name = newName;
      }

      // Keep legacy list in sync (if used)
      final legacyIdx = shows.indexOf(item);
      if (legacyIdx != -1) {
        shows = [
          for (var i = 0; i < shows.length; i++)
            if (i == legacyIdx)
              ShowItem(name: newName, category: item.category)
            else
              shows[i],
        ];
      }
      // Update selection if needed (legacy index irrelevant if building from tree usually)
    });
  }

  void _duplicateProject(ShowItem item) {
    final name = _uniqueProjectName('${item.name} Copy', item.category);
    final insertIndex = shows.indexOf(item) + 1;
    setState(() {
      shows = [
        ...shows.sublist(0, insertIndex),
        ShowItem(name: name, category: item.category),
        ...shows.sublist(insertIndex),
      ];
      selectedShowIndex = insertIndex;
    });
  }

  Future<void> _confirmDeleteProject(ShowItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.carbonBlack,
        title: const Text('Delete project?'),
        content: Text('Delete "${item.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteProject(item);
    }
  }

  void _deleteProject(ShowItem item) {
    setState(() {
      _fileSystem.removeWhere(
        (n) =>
            n is ProjectNode &&
            n.name == item.name &&
            n.type == NodeType.project,
      );

      // Also remove from legacy list to keep UI roughly in sync if mixed usage
      shows.remove(item);
    });
    // _clampSelectedShow(); // No longer applicable really
  }

  void _duplicateFolder(String oldName) {
    final newName = _uniqueFolderName('$oldName Copy');
    final items = shows.where((s) => s.category == oldName).toList();
    setState(() {
      folders = [...folders, newName];
      if (!showCategories.contains(newName)) {
        showCategories = [...showCategories, newName];
      }
      shows = [
        ...shows,
        for (final s in items)
          ShowItem(name: '${s.name} Copy', category: newName),
      ];
      selectedShowIndex = shows.isEmpty ? null : shows.length - 1;
    });
  }

  void _deleteFolder(String oldName) {
    setState(() {
      final folder = _fileSystem.firstWhereOrNull(
        (n) => n is FolderNode && n.name == oldName,
      );
      if (folder != null) {
        // Recursive delete
        final toRemove = <String>{folder.id};
        void collect(String pid) {
          final children = getChildren(pid);
          for (var c in children) {
            toRemove.add(c.id);
            if (c is FolderNode) collect(c.id);
          }
        }

        collect(folder.id);
        _fileSystem.removeWhere((n) => toRemove.contains(n.id));
      }
    });
  }
}
