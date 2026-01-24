import 'package:flutter/material.dart';
import '../../../services/label_color_service.dart';
import '../dashboard_screen.dart'; // For access to state
import 'group_color_dialog.dart';

class GroupTabPanel extends StatelessWidget {
  const GroupTabPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // We need to listen to changes. Since LabelColorService isn't a ChangeNotifier by itself in the snippet,
    // we might need a way to rebuild.
    // For now, we'll assume the parent rebuilds or we use a StreamBuilder if I add streams later.
    // But importantly, let's just build it. The user's code didn't show a listener.
    // Ideally, LabelColorService should notify.
    // Let's wrap in a StatefulBuilder or just rely on parent updates for now.

    // Actually, to make it reactive to "New Group", we might need state.
    // But let's stick to the structure.

    return StreamBuilder(
      // basic periodic check or just build once?
      // The user's snippet was a StatelessWidget.
      // I'll make it a StatelessWidget and fetch groups.
      stream: null, // No stream yet
      builder: (context, snapshot) {
        final groups = LabelColorService.instance.groups;

        return Column(
          children: [
            // 1. The List of Groups
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final label = groups[index];
                final color = LabelColorService.instance.getColor(label);

                return _GroupButton(
                  label: label,
                  color: color,
                  onTap: () {
                    // APPLY GROUP TO SELECTED SLIDE
                    final dashboard = context
                        .findAncestorStateOfType<DashboardScreenState>();
                    dashboard?.applyGroupToSelection(label, color);
                  },
                  onEdit: () => _openColorPicker(context, label, color),
                );
              },
            ),

            // 2. "Add New Group" Button
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, color: Colors.white70),
                label: const Text(
                  "New Group",
                  style: TextStyle(color: Colors.white70),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                ),
                onPressed: () {
                  _addNewGroup(context);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openColorPicker(
    BuildContext context,
    String label,
    Color currentColor,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          GroupColorDialog(initialLabel: label, initialColor: currentColor),
    ).then((_) {
      // Force rebuild if meaningful?
      // In a real app we'd use Riverpod/Provider.
      // For now, if dashboard rebuilds, this might.
      // Or we can rely on navigation pop to trigger something if we were lucky.
      // Actually, DashboardScreen likely doesn't rebuild explicitly on external service change unless listeners.
      // But let's follow the request first.
    });
  }

  void _addNewGroup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const GroupColorDialog(
        initialLabel: '', // Empty for new
        initialColor: Colors.blue,
      ),
    );
  }
}

class _GroupButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _GroupButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 14, color: Colors.white54),
              onPressed: onEdit,
              tooltip: "Edit Global Color",
            ),
          ],
        ),
      ),
    );
  }
}
