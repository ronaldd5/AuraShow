import 'dart:io';

void main() {
  final file = File(
    'e:/AuraShow/aurashow (original)/AuraShow/lib/screens/dashboard/dashboard_screen.dart',
  );
  final lines = file.readAsLinesSync();
  // Delete lines 678-868 (inclusive, 1-based)
  // 678 is now 678 + 1 (because I added a line at 52) = 679
  // 868 is 868 + 1 = 869
  // Range to delete: 679 to 869
  // 0-based index: 678 to 868

  // Checking content to be sure
  // Line 679 (index 678): Widget _applyFilters(Widget child, _SlideContent slide) {
  // Line 869 (index 868):   } (closing brace of _matrixMultiply)

  if (lines[678].contains('_applyFilters') && lines[868].trim() == '}') {
    final keptLines = [...lines.sublist(0, 678), ...lines.sublist(869)];
    file.writeAsStringSync(keptLines.join('\n'));
    print('Deleted lines 679-869 (1-based). New length: ${keptLines.length}');
  } else {
    print(
      'Error: Line content mismatch. Index 678: ${lines[678]}, Index 868: ${lines[868]}',
    );
    exit(1);
  }
}
