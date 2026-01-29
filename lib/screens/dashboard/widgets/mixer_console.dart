import 'package:flutter/material.dart';
import '../dashboard_screen.dart'; // For shared types/constants if needed
import '../../../services/xair_service.dart';
import 'mixer_fader.dart';

class MixerConsole extends StatefulWidget {
  const MixerConsole({super.key});

  @override
  State<MixerConsole> createState() => _MixerConsoleState();
}

class _MixerConsoleState extends State<MixerConsole> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: XAirService.instance,
      builder: (context, _) {
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          itemCount: 16,
          itemBuilder: (context, index) {
            final channel = index + 1;
            return _buildFaderStrip(channel);
          },
        );
      },
    );
  }

  Widget _buildFaderStrip(int channel) {
    final faderValue = XAirService.instance.getFader(channel);
    final isMuted = XAirService.instance.getMute(channel);

    return Container(
      width: 60,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Darker background for strip
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: MixerFader(
        channelNumber: channel,
        value: faderValue,
        isMuted: isMuted,
        label: 'CH $channel',
        onChanged: (val) {
          XAirService.instance.setFader(channel, val);
        },
        onMuteChanged: (muted) {
          XAirService.instance.setMute(channel, muted);
        },
      ),
    );
  }
}
