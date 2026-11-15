import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_init.dart';
import 'login_screen.dart';
import 'consent_screen.dart';
import 'report_screen.dart';
import 'brigade_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initFirebase();
  } catch (e, stack) {
    debugPrint('Firebase init error: $e');
    debugPrintStack(stackTrace: stack);
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Uncaught Flutter error: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _isBrigadeUser(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['isBrigade'] == true) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking brigade flag: $e');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire Alert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD32F2F),
          secondary: const Color(0xFFFFA000),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            final user = snapshot.data!;
            return FutureBuilder<bool>(
              future: _isBrigadeUser(user),
              builder: (context, brigadeSnap) {
                if (brigadeSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (brigadeSnap.hasData && brigadeSnap.data == true) {
                  return const BrigadeScreen();
                } else {
                  return const ReportScreen();
                }
              },
            );
          }

          return const LoginScreen();
        },
      ),
      routes: {
        '/consent': (context) => const ConsentScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }
}
