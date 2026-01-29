import 'package:flutter/material.dart';
import '../../../models/song_model.dart';
import '../../../core/theme/palette.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/alignment_service.dart';
import '../../../services/lyrics_service.dart';

class SongEditorDialog extends StatefulWidget {
  final Song? song; // If null, creating new song

  const SongEditorDialog({super.key, this.song});

  @override
  State<SongEditorDialog> createState() => _SongEditorDialogState();
}

class _SongEditorDialogState extends State<SongEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _copyrightController;
  late TextEditingController _ccliController;
  late TextEditingController _contentController;
  String? _audioPath;
  String? _alignmentData;
  bool _isAligning = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song?.title ?? '');
    _authorController = TextEditingController(text: widget.song?.author ?? '');
    _copyrightController = TextEditingController(
      text: widget.song?.copyright ?? '',
    );
    _ccliController = TextEditingController(text: widget.song?.ccli ?? '');
    _contentController = TextEditingController(
      text: widget.song?.content ?? '',
    );
    _audioPath = widget.song?.audioPath;
    _alignmentData = widget.song?.alignmentData;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _copyrightController.dispose();
    _ccliController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.border, width: 1),
      ),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.song == null ? 'Create New Song' : 'Edit Song',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Title',
                    controller: _titleController,
                    autoFocus: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'Author',
                    controller: _authorController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Copyright',
                    controller: _copyrightController,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'CCLI #',
                    controller: _ccliController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Audio / Sync Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backing Track',
                        style: TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppPalette.border),
                              ),
                              child: Text(
                                _audioPath != null
                                    ? _audioPath!.split(RegExp(r'[/\\]')).last
                                    : 'No audio attached',
                                style: const TextStyle(
                                  color: AppPalette.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _pickAudio,
                            tooltip: 'Attach Audio',
                            icon: const Icon(
                              Icons.audio_file,
                              color: AppPalette.primary,
                            ),
                          ),
                          if (_audioPath != null)
                            IconButton(
                              onPressed: () => setState(() {
                                _audioPath = null;
                                _alignmentData = null;
                              }),
                              tooltip: 'Remove Audio',
                              icon: const Icon(
                                Icons.close,
                                color: Colors.redAccent,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Karaoke Sync',
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onPressed: (_audioPath != null && !_isAligning)
                          ? _runAlignment
                          : null,
                      icon: _isAligning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _alignmentData != null ? Icons.check : Icons.sync,
                              size: 16,
                            ),
                      label: Text(
                        _alignmentData != null
                            ? 'Re-Align'
                            : (_isAligning ? 'Aligning...' : 'Auto-Align'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Lyrics',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _contentController,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontFamily: 'Consolas',
                ),
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppPalette.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppPalette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppPalette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppPalette.primary),
                  ),
                  hintText:
                      'Enter lyrics here...\nSeparated each stanza with an empty line.',
                  hintStyle: TextStyle(color: AppPalette.textMuted),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppPalette.textSecondary),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool autoFocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          autofocus: autoFocus,
          style: const TextStyle(color: AppPalette.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppPalette.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppPalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppPalette.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      // Show error?
      return;
    }

    final song = (widget.song ?? Song.create(title: '')).copyWith(
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      copyright: _copyrightController.text.trim(),
      ccli: _ccliController.text.trim(),
      content: _contentController.text, // keep formating
      audioPath: _audioPath,
      alignmentData: _alignmentData,
    );

    // Metadata Import feature:
    // If the user used "Title=...", update the song object before saving
    final updatedSong = LyricsService.instance.updateMetaFromContent(song);

    Navigator.of(context).pop(updatedSong);
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _audioPath = result.files.single.path;
        // Reset alignment when audio changes
        _alignmentData = null;
      });
    }
  }

  Future<void> _runAlignment() async {
    if (_audioPath == null) return;

    setState(() => _isAligning = true);

    try {
      final text = _contentController.text;
      // Filter out [tags] for alignment input
      final alignmentText = text.replaceAll(RegExp(r'\[.*?\]'), '').trim();

      final result = await AlignmentService.instance.align(
        _audioPath!,
        alignmentText,
      );

      if (mounted) {
        setState(() {
          _alignmentData = result;
          _isAligning = false;
        });
      }
    } catch (e) {
      debugPrint('Alignment UI error: $e');
      if (mounted) {
        setState(() => _isAligning = false);
      }
    }
  }
}
