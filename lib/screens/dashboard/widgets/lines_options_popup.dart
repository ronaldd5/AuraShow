import 'package:flutter/material.dart';
import '../../../core/theme/palette.dart';
import 'animated_lines_thumbnail.dart';

class LinesOptionsPopup extends StatelessWidget {
  final int currentLines;
  final ValueChanged<int> onSelected;

  const LinesOptionsPopup({
    Key? key,
    required this.currentLines,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Show Line Limits',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Changes how lyrics are split across slides.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildOption(2),
                _buildOption(4),
                _buildOption(6),
                _buildOption(0, label: 'No Limit'),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.info_outline, size: 14, color: Colors.white38),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Re-paginates all slides in this show.',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(int count, {String? label}) {
    return InkWell(
      onTap: () => onSelected(count),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedLinesThumbnail(
        lines: count,
        isSelected: currentLines == count,
      ),
    );
  }
}
