import 'package:flutter/material.dart';
import '../../../models/song_model.dart';
import '../../../core/theme/palette.dart';
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
    );

    // Metadata Import feature:
    // If the user used "Title=...", update the song object before saving
    final updatedSong = LyricsService.instance.updateMetaFromContent(song);

    Navigator.of(context).pop(updatedSong);
  }
}
