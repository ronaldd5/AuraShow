import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AlignmentService {
  AlignmentService._();
  static final AlignmentService instance = AlignmentService._();

  /// Path to the external aligner executable or script
  /// For now, we assume a python script 'aligner.py' in the app directory,
  /// or a bundled executable.
  String? _alignerPath;

  /// Align audio and text to get syllable timing
  /// Returns a JSON string representing list of {word, start, end}
  Future<String> align(String audioPath, String text) async {
    try {
      debugPrint('AlignmentService: Aligning $audioPath with text...');

      // 1. Create temporary text file
      final tempDir = await getTemporaryDirectory();
      final textFile = File('${tempDir.path}/align_input.txt');
      await textFile.writeAsString(text);

      // 2. Locate aligner (Mocking for now if not found)
      // In a real scenario, this would call 'mfa_align' or similar
      // For this MVP, we will simulate alignment if no external tool is configured.

      // Check if we have a configured aligner
      if (_alignerPath == null) {
        return _mockAlignment(text); // Fallback "Fake" alignment for testing
      }

      // 3. Run external process
      // final result = await Process.run(_alignerPath!, [audioPath, textFile.path]);
      // if (result.exitCode != 0) {
      //   throw Exception('Aligner failed: ${result.stderr}');
      // }
      // return result.stdout.toString();

      return _mockAlignment(text);
    } catch (e) {
      debugPrint('Alignment error: $e');
      return '';
    }
  }

  /// Mock alignment: distributes text evenly over a fixed duration (e.g. 3 mins)
  /// Just for visualization testing "The Flex".
  String _mockAlignment(String text) {
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final List<Map<String, dynamic>> alignment = [];

    double currentTime = 0.0;
    const double wordDuration = 0.5; // Half second per word roughly

    for (var token in tokens) {
      alignment.add({
        'word': '$token ', // Add space back
        'start': currentTime,
        'end': currentTime + wordDuration,
      });
      currentTime += wordDuration;
    }

    return json.encode(alignment);
  }
}
