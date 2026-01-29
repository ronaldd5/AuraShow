part of '../dashboard_screen.dart';

// Needs to be imports on the main file, but for now we rely on them being available
// because this is a part file. However, for 'MixerConsole', we already imported it
// in dashboard_screen.dart.

extension MixerExtensions on DashboardScreenState {
  Widget _buildMixerView() {
    return Column(
      children: [
        _buildMixerToolbar(),
        Expanded(child: _buildMixerConsole()),
      ],
    );
  }

  Widget _buildMixerToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: XAirService.instance,
            builder: (context, _) {
              final connected = XAirService.instance.isConnected;
              return Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected ? Colors.green : Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: (connected ? Colors.green : Colors.red)
                              .withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    connected ? 'XR16 Connected' : 'Disconnected',
                    style: TextStyle(
                      color: connected ? Colors.green : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (connected && XAirService.instance.mixerIp != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '(${XAirService.instance.mixerIp})',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              final ip = XAirService.instance.mixerIp;
              final window = await DesktopMultiWindow.createWindow(
                jsonEncode({'type': 'mixer', 'ip': ip}),
              );
              window
                ..setFrame(const Offset(0, 0) & const Size(1200, 750))
                ..center()
                ..setTitle('Audio Mixer')
                ..show();
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            tooltip: 'Detach Mixer',
          ),
          if (XAirService.instance.isConnected)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  XAirService.instance.pushAll();
                  _showSnack('Synced to Mixer');
                },
                icon: const Icon(Icons.sync, size: 14),
                label: const Text('Push to Mixer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              _showConnectionDialog();
            },
            icon: const Icon(Icons.cast_connected, size: 14),
            label: const Text('Connect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectionDialog() {
    final controller = TextEditingController(text: '192.168.1.50');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.carbonBlack,
        title: const Text('Connect to Behringer XR16'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the IP address of your mixer. Ensure you are on the same network.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.black26,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              XAirService.instance.connect(); // Auto-scan
              Navigator.pop(context);
              _showSnack('Scanning for XR16...');
            },
            child: const Text('Auto Scan'),
          ),
          TextButton(
            onPressed: () {
              XAirService.instance.connectToIp(controller.text);
              Navigator.pop(context);
            },
            child: Text('Connect', style: TextStyle(color: accentBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildMixerConsole() {
    return const MixerConsole();
  }
}
