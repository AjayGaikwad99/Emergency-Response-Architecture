import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';

class MediaService {
  final ImagePicker _picker = ImagePicker();
  final FlutterSoundRecorder _rec = FlutterSoundRecorder();
  bool _inited = false;

  Future<void> initRecorder() async {
    if (!_inited) {
      await _rec.openRecorder();
      _inited = true;
    }
  }

  Future<File?> pickImageFromCamera() async {
    final XFile? f = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    return f == null ? null : File(f.path);
  }

  Future<File?> pickVideoFromCamera() async {
    final XFile? f = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    return f == null ? null : File(f.path);
  }

  Future<void> dispose() async {
    if (_inited) {
      await _rec.closeRecorder();
      _inited = false;
    }
  }
}
