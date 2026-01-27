import 'dart:io';
import '../interface/vocal_remover_platform.dart';

class WindowsVocalRemover implements VocalRemoverPlatform {
  @override
  Future<String?> getFfmpegPath() async {
    try {
      final res = await Process.run('ffmpeg', ['-version']);
      if (res.exitCode == 0) return 'ffmpeg';
    } catch (_) {}

    final manualFfmpeg = File(
      r'E:\ffmpeg-8.0-full_build-shared\bin\ffmpeg.exe',
    );
    if (manualFfmpeg.existsSync()) return manualFfmpeg.path;

    return null;
  }

  @override
  Future<String?> getAudioSeparatorPath() async {
    try {
      final res = await Process.run('audio-separator', ['--version']);
      if (res.exitCode == 0) return 'audio-separator';
    } catch (_) {}

    final scriptPath = File(
      r'C:\Users\Ronald Datcher\AppData\Local\Programs\Python\Python311\Scripts\audio-separator.exe',
    );
    if (scriptPath.existsSync()) return scriptPath.path;

    // Try py -m audio_separator
    try {
      final res = await Process.run('py', [
        '-3.11',
        '-m',
        'audio_separator',
        '--version',
      ]);
      if (res.exitCode == 0)
        return 'audio-separator-py'; // Marker for service to use special command
    } catch (_) {}

    return null;
  }

  @override
  String getPythonExecutable() => 'py';

  @override
  List<String> getPythonPreArgs() => ['-3.11'];

  @override
  Map<String, String>? getEnvironmentVariables() {
    final ffmpegBin = r'E:\ffmpeg-8.0-full_build-shared\bin';
    final currentPath = Platform.environment['Path'] ?? '';
    return {'Path': '$ffmpegBin;$currentPath'};
  }
}
