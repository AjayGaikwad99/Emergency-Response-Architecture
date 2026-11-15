import 'package:flutter/material.dart';
import 'native_bridge.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({Key? key}) : super(key: key);

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _accepted = false;
  bool _isProcessing = false;
  String _status = '';

  Future<void> _onEnablePressed() async {
    if (!_accepted) {
      setState(() => _status = 'Please read and accept the terms to continue.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Requesting permissions...';
    });

    final ok = await NativeBridge.enableMonitoring();

    setState(() {
      _isProcessing = false;
      _status = ok ? 'Monitoring enabled' : 'Failed to enable monitoring';
    });
  }

  Future<void> _onDisablePressed() async {
    setState(() {
      _isProcessing = true;
      _status = 'Stopping monitoring...';
    });

    final ok = await NativeBridge.disableMonitoring();

    setState(() {
      _isProcessing = false;
      _status = ok ? 'Monitoring stopped' : 'Failed to stop monitoring';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Monitoring'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'What this feature does',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'When enabled, the app will record a short 4 second audio/video clip and capture your location '
              'if an emergency trigger occurs. The app runs a foreground service and shows a persistent notification while active. '
              'Recorded clips and location are uploaded to the server you authorize for emergency routing.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Permissions required',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
                '• Microphone\n• Camera\n• Location (foreground and optional background)\n• Network access'),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _accepted,
                  onChanged: (v) => setState(() {
                    _accepted = v ?? false;
                    _status = '';
                  }),
                ),
                const Expanded(
                  child: Text(
                    'I understand and consent to short recordings and location uploads for emergency routing.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isProcessing) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _onEnablePressed,
                    child: const Text('Enable automatic emergency monitoring'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _onDisablePressed,
                    child: const Text('Disable monitoring'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            const Text(
              'You can disable monitoring at any time. This feature must be enabled explicitly and will show a persistent notification while active.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
