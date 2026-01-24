import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Service to parse and resolve dynamic text tokens.
/// Tokens:
/// - {time} -> Current time (e.g., "10:45 AM")
/// - {countdown:HH:mm} -> Countdown to target time (e.g., "05:00")
/// - {wifi_pass} -> "password123" (Needs provider)
/// - {next_song} -> "Song Title" (Needs provider)
class TextTokenService {
  // Singleton pattern for easy access, though dependency injection is better.
  static final TextTokenService _instance = TextTokenService._internal();
  factory TextTokenService() => _instance;
  TextTokenService._internal() {
    _startTimer();
  }

  Timer? _timer;
  final ValueNotifier<int> _ticker = ValueNotifier(0);

  /// Listen to this notifier to rebuild widgets every second
  ValueNotifier<int> get ticker => _ticker;

  // External data providers
  String Function()? wifiPasswordProvider;
  String Function()? nextSongProvider;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _ticker.value = timer.tick;
    });
  }

  /// Check if text contains any known tokens
  bool hasTokens(String text) {
    if (text.isEmpty) return false;
    return text.contains('{time}') ||
        text.contains('{countdown:') ||
        text.contains('{wifi_pass}') ||
        text.contains('{next_song}');
  }

  /// Resolve identifying tokens in the text with their current values.
  String resolve(String text) {
    if (text.isEmpty) return text;

    String result = text;

    // 1. {time}
    if (result.contains('{time}')) {
      final now = DateTime.now();
      final timeStr = DateFormat.jm().format(now); // 10:45 AM
      result = result.replaceAll('{time}', timeStr);
    }

    // 2. {wifi_pass}
    if (result.contains('{wifi_pass}')) {
      final pass = wifiPasswordProvider?.call() ?? 'No WiFi Configured';
      result = result.replaceAll('{wifi_pass}', pass);
    }

    // 3. {next_song}
    if (result.contains('{next_song}')) {
      final song = nextSongProvider?.call() ?? 'None';
      result = result.replaceAll('{next_song}', song);
    }

    // 4. {countdown:HH:mm} or {countdown:HH:mm:ss}
    // Regex to find all countdown tokens
    final countdownRegex = RegExp(r'\{countdown:([^}]+)\}');
    result = result.replaceAllMapped(countdownRegex, (match) {
      final targetStr = match.group(1); // e.g., "11:00" or "service_start"
      if (targetStr == null) return match.group(0)!;

      return _calculateCountdown(targetStr);
    });

    return result;
  }

  String _calculateCountdown(String targetStr) {
    // Handle "service_start" or other keywords if needed. For now assume HH:mm
    try {
      final now = DateTime.now();

      // Keep it simple: Parse HH:mm on CURRENT day.
      // If target is earlier than now, assumes tomorrow? Or just negative/zero?
      // Let's assume today.

      int targetHour = 0;
      int targetMinute = 0;
      int targetSecond = 0;

      final parts = targetStr.split(':');
      if (parts.isNotEmpty) targetHour = int.parse(parts[0]);
      if (parts.length > 1) targetMinute = int.parse(parts[1]);
      if (parts.length > 2) targetSecond = int.parse(parts[2]);

      final target = DateTime(
        now.year,
        now.month,
        now.day,
        targetHour,
        targetMinute,
        targetSecond,
      );

      Duration diff = target.difference(now);

      // If negative (passed), maybe show 00:00 or negative?
      // "Service starts in..." implies future.
      // If it's 11:01 and target is 11:00, show 00:00 or -00:01?
      // Convention: Show 00:00 if passed, or maybe user wants count UP?
      // Let's default to max(0, diff).
      if (diff.isNegative) {
        // Optional: If more than 12 hours ago, maybe it's for tomorrow? (e.g. 9 AM service, now is 10 PM)
        // For simplicity: just 00:00 for now.
        return "00:00";
      }

      final h = diff.inHours;
      final m = diff.inMinutes.remainder(60);
      final s = diff.inSeconds.remainder(60);

      if (h > 0) {
        return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      } else {
        return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return "[Invalid Time]";
    }
  }

  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
  }
}
