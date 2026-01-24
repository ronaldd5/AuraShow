import 'package:flutter/material.dart';
import '../../../models/slide_model.dart';

class LayerListItem extends StatelessWidget {
  final SlideLayer layer;
  final bool isSelected;
  final VoidCallback onTap;

  const LayerListItem({
    super.key,
    required this.layer,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: isSelected,
      onTap: onTap,
      title: Text(layer.label),
      subtitle: Text(layer.kind.name),
      // Add more UI details here
    );
  }
}
