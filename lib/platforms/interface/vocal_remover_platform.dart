import 'dart:io';

abstract class VocalRemoverPlatform {
  /// Get the path to the FFmpeg executable
  Future<String?> getFfmpegPath();

  /// Get the path to the audio-separator executable
  Future<String?> getAudioSeparatorPath();

  /// Get the python executable name (e.g. 'python', 'python3', 'py')
  String getPythonExecutable();

  /// Get the python pre-arguments (e.g. ['-3.11'])
  List<String> getPythonPreArgs();

  /// Get the environment variables for running commands
  Map<String, String>? getEnvironmentVariables();
}
