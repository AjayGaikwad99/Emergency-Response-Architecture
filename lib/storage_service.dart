import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile(File file, String remotePath) async {
    final ref = _storage.ref().child(remotePath);
    final task = ref.putFile(file);
    await task.whenComplete(() => null);
    return ref.getDownloadURL();
  }
}
