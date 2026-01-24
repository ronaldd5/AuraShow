import 'dart:io';

void main() {
  final file = File(
    'e:/AuraShow/aurashow (original)/AuraShow/lib/screens/dashboard/dashboard_screen.dart',
  );
  final lines = file.readAsLinesSync();
  // Delete lines 678-2338 (inclusive, 1-based)
  // Index 677 to 2337
  final keptLines = [...lines.sublist(0, 677), ...lines.sublist(2338)];
  file.writeAsStringSync(keptLines.join('\n'));
  print('Deleted lines 678-2338. New length: ${keptLines.length}');
}
