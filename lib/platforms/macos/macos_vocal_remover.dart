import 'dart:io';
import '../interface/vocal_remover_platform.dart';

class MacosVocalRemover implements VocalRemoverPlatform {
  @override
  Future<String?> getFfmpegPath() async {
    try {
      final res = await Process.run('ffmpeg', ['-version']);
      if (res.exitCode == 0) return 'ffmpeg';
    } catch (_) {}

    if (File('/opt/homebrew/bin/ffmpeg').existsSync())
      return '/opt/homebrew/bin/ffmpeg';
    if (File('/usr/local/bin/ffmpeg').existsSync())
      return '/usr/local/bin/ffmpeg';

    return null;
  }

  @override
  Future<String?> getAudioSeparatorPath() async {
    try {
      final res = await Process.run('audio-separator', ['--version']);
      if (res.exitCode == 0) return 'audio-separator';
    } catch (_) {}

    return null;
  }

  @override
  String getPythonExecutable() => 'python3';

  @override
  List<String> getPythonPreArgs() => [];

  @override
  Map<String, String>? getEnvironmentVariables() {
    const brewPaths = '/opt/homebrew/bin:/usr/local/bin';
    final currentPath = Platform.environment['PATH'] ?? '';
    return {'PATH': '$brewPaths:$currentPath'};
  }
}
