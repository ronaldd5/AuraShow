import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

enum VocalRemoverType {
  uvr, // Audio Separator (UVR MDX-Net) - High Quality
  instant, // Flash/Phase Cancel - Fast
}

/// Represents an ongoing vocal removal operation
class VocalRemovalTask {
  /// Future that completes with the result file (or null if failed/cancelled)
  final Future<File?> future;

  /// Stream of status messages (e.g. "Downloading...", "Separating...")
  final Stream<String> statusStream;

  /// Call to cancel the operation
  final VoidCallback cancel;

  VocalRemovalTask({
    required this.future,
    required this.statusStream,
    required this.cancel,
  });
}

class VocalRemoverService {
  static final VocalRemoverService _instance = VocalRemoverService._internal();
  factory VocalRemoverService() => _instance;
  VocalRemoverService._internal();

  /// Check tools. Returns error message or null.
  Future<String?> checkAvailability(VocalRemoverType type) async {
    // 1. Instant Mode only needs FFmpeg
    String? ffmpegPath;
    try {
      if ((await Process.run('ffmpeg', ['-version'])).exitCode == 0) {
        ffmpegPath = 'ffmpeg';
      }
    } catch (_) {}

    if (ffmpegPath == null) {
      if (Platform.isWindows) {
        final manualFfmpeg = File(
          r'E:\ffmpeg-8.0-full_build-shared\bin\ffmpeg.exe',
        );
        if (manualFfmpeg.existsSync()) ffmpegPath = manualFfmpeg.path;
      } else if (Platform.isMacOS) {
        if (File('/opt/homebrew/bin/ffmpeg').existsSync())
          ffmpegPath = '/opt/homebrew/bin/ffmpeg';
        else if (File('/usr/local/bin/ffmpeg').existsSync())
          ffmpegPath = '/usr/local/bin/ffmpeg';
      }
    }

    if (ffmpegPath == null) {
      return 'FFmpeg is required. Please install it.';
    }

    if (type == VocalRemoverType.instant) return null;

    // 2. UVR (Audio Separator)
    if (type == VocalRemoverType.uvr) {
      // Check for audio-separator command
      // On Windows it's likely a script in Python Scripts folder, or widely available if installed via pip
      bool found = false;
      try {
        if ((await Process.run('audio-separator', ['--version'])).exitCode == 0)
          found = true;
      } catch (_) {}

      if (!found && Platform.isWindows) {
        // Fallback check: py -m audio_separator
        try {
          final res = await Process.run('py', [
            '-3.11',
            '-m',
            'audio_separator',
            '--version',
          ]);
          if (res.exitCode == 0) found = true;
        } catch (_) {}
      }

      if (!found) {
        return 'UVR not found. Run: pip install "audio-separator[cpu]"';
      }
    }

    return null;
  }

  // Helper: Install GPU Support
  Future<int> installGpuSupport() async {
    String pythonExe = 'python';
    List<String> preArgs = [];
    if (Platform.isWindows) {
      try {
        if ((await Process.run('py', ['-3.11', '--version'])).exitCode == 0) {
          pythonExe = 'py';
          preArgs = ['-3.11'];
        }
      } catch (_) {}
    } else if (Platform.isMacOS) {
      // macOS uses python3 by default
      pythonExe = 'python3';
    }

    // Command: pip install "audio-separator[gpu]"
    final args = [...preArgs, '-m', 'pip', 'install', 'audio-separator[gpu]'];
    debugPrint('Installing GPU Support: $pythonExe ${args.join(' ')}');

    final process = await Process.start(pythonExe, args);
    process.stdout
        .transform(const SystemEncoding().decoder)
        .listen((data) => debugPrint('PIP [OUT]: $data'));
    process.stderr
        .transform(const SystemEncoding().decoder)
        .listen((data) => debugPrint('PIP [ERR]: $data'));

    return process.exitCode;
  }

  VocalRemovalTask process(
    File inputFile,
    VocalRemoverType type, {
    bool isFastMode = false,
    bool useGpu = false,
  }) {
    if (type == VocalRemoverType.instant) {
      return _removeVocalsInstant(inputFile);
    } else {
      return _removeVocalsUVR(
        inputFile,
        isFastMode: isFastMode,
        useGpu: useGpu,
      );
    }
  }

  // --- ENGINE 1: INSTANT (FFmpeg) ---
  VocalRemovalTask _removeVocalsInstant(File inputFile) {
    final statusController = StreamController<String>.broadcast();
    final completer = Completer<File?>();
    Process? process;
    bool isCancelled = false;

    void cancel() {
      if (isCancelled) return;
      isCancelled = true;
      process?.kill();
      statusController.add('Cancelled');
      statusController.close();
      if (!completer.isCompleted) completer.complete(null);
    }

    Future<void> run() async {
      try {
        final inputName = path.basenameWithoutExtension(inputFile.path);
        final outputName = '$inputName (Instant Instrumental).wav';
        final outputPath = path.join(inputFile.parent.path, outputName);

        statusController.add('Initializing FFmpeg...');

        String ffmpegCmd = 'ffmpeg';
        if (Platform.isWindows) {
          final manual = File(
            r'E:\ffmpeg-8.0-full_build-shared\bin\ffmpeg.exe',
          );
          if (manual.existsSync()) ffmpegCmd = manual.path;
        }

        final args = [
          '-i',
          inputFile.path,
          '-af',
          'pan=stereo|c0=c0-c1|c1=c1-c0',
          '-y',
          outputPath,
        ];

        statusController.add('Processing audio...');
        process = await Process.start(ffmpegCmd, args);

        if (isCancelled) {
          process?.kill();
          return;
        }

        final exitCode = await process!.exitCode;

        if (isCancelled) return;

        if (exitCode == 0 && File(outputPath).existsSync()) {
          statusController.add('Success!');
          completer.complete(File(outputPath));
        } else {
          statusController.add('Failed (Exit code $exitCode)');
          completer.complete(null);
        }
      } catch (e) {
        if (!completer.isCompleted) completer.complete(null);
      } finally {
        statusController.close();
      }
    }

    run();
    return VocalRemovalTask(
      future: completer.future,
      statusStream: statusController.stream,
      cancel: cancel,
    );
  }

  // --- ENGINE 2: UVR (Audio Separator) ---
  VocalRemovalTask _removeVocalsUVR(
    File inputFile, {
    bool isFastMode = false,
    bool useGpu = false,
  }) {
    final statusController = StreamController<String>.broadcast();
    final completer = Completer<File?>();
    Process? process;
    bool isCancelled = false;
    Directory? outputDir;

    Future<void> run() async {
      try {
        statusController.add(
          'Initializing UVR Engine ${useGpu ? "(GPU)" : "(CPU)"}...',
        );

        // 1. Output Directory
        final tempDir = await getTemporaryDirectory();
        outputDir = Directory(
          path.join(
            tempDir.path,
            'uvr_output_${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
        outputDir!.createSync(recursive: true);

        // 2. Command
        // Fast Mode: 'UVR-MDX-NET-Inst_1.onnx' (Lighter)
        // HQ Mode: 'UVR-MDX-NET-Inst_HQ_3.onnx' (Heavier, stricter)
        final modelName = isFastMode
            ? 'UVR-MDX-NET-Inst_1.onnx'
            : 'UVR-MDX-NET-Inst_HQ_3.onnx';

        // Persistent model directory
        final appSupportDir = await getApplicationSupportDirectory();
        final modelDir = Directory(path.join(appSupportDir.path, 'uvr_models'));
        if (!modelDir.existsSync()) modelDir.createSync(recursive: true);

        // Check if we run as 'audio-separator' or 'py -m audio_separator'
        String exe = 'audio-separator';
        List<String> preArgs = [];

        // On Windows, likely 'py -3.11 -m audio_separator' is safer if path isn't set
        if (Platform.isWindows) {
          final scriptPath = File(
            r'C:\Users\Ronald Datcher\AppData\Local\Programs\Python\Python311\Scripts\audio-separator.exe',
          );
          if (scriptPath.existsSync()) {
            exe = scriptPath.path;
          }
        }

        final args = [
          ...preArgs,
          inputFile.path,
          '--model_filename', modelName,
          '--model_file_dir', modelDir.path,
          '--output_dir', outputDir!.path,
          '--output_format', 'mp3',
          '--single_stem', 'instrumental', // Only save instrumental
        ];

        if (useGpu) {
          // Newer versions of audio-separator auto-detect GPU
          debugPrint('Enabling CUDA support (Auto-detect)');
        }

        debugPrint('Running UVR: $exe ${args.join(' ')}');
        statusController.add('Processing with UVR MDX-Net...');

        // Pass FFmpeg path in env
        Map<String, String>? env;
        if (Platform.isWindows) {
          final ffmpegBin = r'E:\ffmpeg-8.0-full_build-shared\bin';
          final currentPath = Platform.environment['Path'] ?? '';
          env = {'Path': '$ffmpegBin;$currentPath'};
        } else if (Platform.isMacOS) {
          // Homebrew paths for macOS
          const brewPaths = '/opt/homebrew/bin:/usr/local/bin';
          final currentPath = Platform.environment['PATH'] ?? '';
          env = {'PATH': '$brewPaths:$currentPath'};
        }

        process = await Process.start(exe, args, environment: env);

        if (isCancelled) {
          process!.kill();
          return;
        }

        process!.stdout.transform(const SystemEncoding().decoder).listen((
          data,
        ) {
          debugPrint('UVR [OUT]: $data');
          // Simple log parsing
          if (data.contains('Loading model'))
            statusController.add('Loading AI Model...');
          if (data.contains('Inference'))
            statusController.add(
              'Separating Vocals...',
            ); // UVR often says Inference
          if (data.contains('Downloading'))
            statusController.add('Downloading Model (First Run)...');
        });
        process!.stderr.transform(const SystemEncoding().decoder).listen((
          data,
        ) {
          debugPrint('UVR [ERR]: $data');
          if (data.contains('Downloading'))
            statusController.add('Downloading Model...');
          if (data.contains('Inference'))
            statusController.add('Separating Vocals...');
        });

        final exitCode = await process!.exitCode;
        if (exitCode != 0) {
          statusController.add('Failed (Code $exitCode)');
          completer.complete(null);
          statusController.close();
          return;
        }

        // 3. Find Result
        // UVR Naming: "{InputFilename}_(Instrumental)_{ModelName}.mp3"
        statusController.add('Finalizing...');
        File? resultFile;
        try {
          final files = outputDir!.listSync().whereType<File>();
          if (files.isNotEmpty) {
            // Look for 'Instrumental' and input name
            // Usually just picking the only file there is safe if output dir was empty.
            resultFile = files.first;
            // Better check:
            for (var f in files) {
              if (f.path.toLowerCase().contains('instrumental')) {
                resultFile = f;
                break;
              }
            }
          }
        } catch (_) {}

        if (resultFile != null && resultFile.existsSync()) {
          // Move to source
          final inputName = path.basenameWithoutExtension(inputFile.path);
          final finalName = '$inputName (UVR Instrumental).mp3';
          final finalPath = path.join(inputFile.parent.path, finalName);

          if (File(finalPath).existsSync()) {
            try {
              File(finalPath).deleteSync();
            } catch (_) {}
          }

          await resultFile.copy(finalPath);
          statusController.add('Done!');
          completer.complete(File(finalPath));
        } else {
          statusController.add('Output file not found.');
          completer.complete(null);
        }

        // Cleanup
        try {
          outputDir!.deleteSync(recursive: true);
        } catch (_) {}
        statusController.close();
      } catch (e) {
        debugPrint('UVR Error: $e');
        if (!completer.isCompleted) completer.complete(null);
        statusController.close();
      }
    }

    run();

    return VocalRemovalTask(
      future: completer.future,
      statusStream: statusController.stream,
      cancel: () {
        isCancelled = true;
        process?.kill();
      },
    );
  }
}
