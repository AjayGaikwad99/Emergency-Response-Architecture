import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp();
  debugPrint('Firebase initialized');
}
