import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'fire_detector.dart';

class FireDetectionPage extends StatefulWidget {
  const FireDetectionPage({Key? key}) : super(key: key);

  @override
  State<FireDetectionPage> createState() => _FireDetectionPageState();
}

class _FireDetectionPageState extends State<FireDetectionPage> {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  double _fireRatio = 0.0;
  String _direction = "Clear";
  double _threshold = 0.05; // adjustable via slider

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller.initialize();
      setState(() {
        _isCameraInitialized = true;
      });

      _controller.startImageStream((CameraImage image) {
        final result = FireDetector.detect(image);
        setState(() {
          _fireRatio = result["ratio"];
          _direction = result["direction"];
        });

        if (_fireRatio > _threshold) {
          _showPopup();
        }
      });
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  void _showPopup() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "🔥 Fire detected! Ratio: ${(_fireRatio * 100).toStringAsFixed(2)}% | $_direction",
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool fireDetected = _fireRatio > _threshold;

    return Scaffold(
      appBar: AppBar(title: const Text("Fire Detection")),
      body: Stack(
        children: [
          if (_isCameraInitialized) CameraPreview(_controller),
          Positioned(
            bottom: 80,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                "Fire Ratio: ${(_fireRatio * 100).toStringAsFixed(2)}% | Direction: $_direction",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          if (fireDetected)
            Container(
              color: Colors.red.withOpacity(0.6),
              child: Center(
                child: Text(
                  "🔥 $_direction 🔥",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                const Text(
                  "Detection Threshold",
                  style: TextStyle(color: Colors.white),
                ),
                Slider(
                  value: _threshold,
                  min: 0.01,
                  max: 0.2,
                  divisions: 20,
                  label: _threshold.toStringAsFixed(2),
                  onChanged: (val) {
                    setState(() {
                      _threshold = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
