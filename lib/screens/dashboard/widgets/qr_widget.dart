import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrWidget extends StatelessWidget {
  const QrWidget({
    super.key,
    required this.data,
    this.foregroundColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.size,
  });

  final String data;
  final Color foregroundColor;
  final Color backgroundColor;
  final double? size;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        color: backgroundColor,
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Icon(
          Icons.qr_code,
          color: foregroundColor.withOpacity(0.5),
          size: (size ?? 100) * 0.5,
        ),
      );
    }

    return Container(
      color: backgroundColor,
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.transparent, // Background handled by container
        foregroundColor: foregroundColor,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
