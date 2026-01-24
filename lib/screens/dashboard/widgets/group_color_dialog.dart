import 'package:flutter/material.dart';
import '../../../core/theme/palette.dart';
import '../../../services/label_color_service.dart';

/// Dialog for creating or editing a group/section label and its color
class GroupColorDialog extends StatefulWidget {
  final String? initialLabel;
  final Color? initialColor;

  const GroupColorDialog({super.key, this.initialLabel, this.initialColor});

  @override
  State<GroupColorDialog> createState() => _GroupColorDialogState();
}

class _GroupColorDialogState extends State<GroupColorDialog> {
  late TextEditingController _textController;
  late Color _selectedColor;
  bool _isEditing = false;

  // Color palette for selection
  final List<Color> _swatches = [
    // Reds/Pinks
    const Color(0xFFE74C3C), const Color(0xFFC0392B), const Color(0xFFE91E63),
    const Color(0xFFD81B60), const Color(0xFFF06292),
    // Purples
    const Color(0xFF9B59B6), const Color(0xFF8E44AD), const Color(0xFF673AB7),
    const Color(0xFF7C4DFF), const Color(0xFFAB47BC),
    // Blues
    const Color(0xFF3498DB), const Color(0xFF2980B9), const Color(0xFF2196F3),
    const Color(0xFF1976D2), const Color(0xFF42A5F5),
    // Cyans/Teals
    const Color(0xFF1ABC9C), const Color(0xFF16A085), const Color(0xFF00BCD4),
    const Color(0xFF00ACC1), const Color(0xFF26C6DA),
    // Greens
    const Color(0xFF2ECC71), const Color(0xFF27AE60), const Color(0xFF4CAF50),
    const Color(0xFF43A047), const Color(0xFF66BB6A),
    // Yellows/Oranges
    const Color(0xFFF39C12), const Color(0xFFE67E22), const Color(0xFFFF9800),
    const Color(0xFFFFA726), const Color(0xFFFFB74D),
    // Greys/Darks
    const Color(0xFF34495E), const Color(0xFF2C3E50), const Color(0xFF607D8B),
    const Color(0xFF455A64), const Color(0xFF78909C),
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialLabel != null && widget.initialLabel!.isNotEmpty;
    _textController = TextEditingController(text: widget.initialLabel);
    _selectedColor =
        widget.initialColor ?? LabelColorService.instance.defaultColor;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppPalette.carbonBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _isEditing ? Icons.edit : Icons.add_circle,
                  color: AppPalette.accent,
                ),
                const SizedBox(width: 12),
                Text(
                  _isEditing ? 'Edit Group' : 'New Group',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Group Name Input
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. Chorus, Verse 1',
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white),
              enabled:
                  !_isEditing, // Disable renaming for now to avoid ID key issues or add rename logic later
            ),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Renaming groups is loosely supported. Create a new one if needed.', // Disclaimer
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            const SizedBox(height: 20),

            // Color Picker
            Text(
              'Select Color',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              padding: EdgeInsets.all(8),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _swatches.length,
                itemBuilder: (context, index) {
                  final swatch = _swatches[index];
                  final isSelected = swatch.value == _selectedColor.value;

                  return InkWell(
                    onTap: () {
                      setState(() => _selectedColor = swatch);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: swatch,
                        borderRadius: BorderRadius.circular(6),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : Border.all(color: Colors.white24),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: swatch.withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = _textController.text.trim();
                    if (name.isEmpty) return;

                    await LabelColorService.instance.setColor(
                      name,
                      _selectedColor,
                    );
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
