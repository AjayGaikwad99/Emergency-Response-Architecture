import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';

import 'report_screen.dart';
import 'brigade_screen.dart';
import 'register.dart';
import 'change_password_screen.dart';

enum FiremanPose { pointing, hose, whistle }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _isBrigade = false;
  bool _loading = false;
  bool _obscurePass = true;
  bool _showChangePasswordButton = false;

  FiremanPose _pose = FiremanPose.pointing;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) {
        setState(() => _pose = FiremanPose.pointing);
      }
    });
    _passFocus.addListener(() {
      if (_passFocus.hasFocus) {
        setState(() => _pose = FiremanPose.hose);
      }
    });
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final auth = FirebaseAuth.instance;
      await auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      _showSnack('Signed in successfully', Colors.green);
      _showToast('Welcome back!');
      if (_isBrigade) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BrigadeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ReportScreen()),
        );
      }
    } catch (e) {
      setState(() => _pose = FiremanPose.whistle); // whistle on failure
      _showSnack('Sign in failed: $e', Colors.red);
      _showToast('Login failed');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter your email to reset password', Colors.red);
      _showToast('Email required');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack(
        'Password reset email sent. Open your inbox to change password.',
        Colors.green,
      );
      _showToast('Check your inbox');
      setState(() {
        _showChangePasswordButton = true;
      });
    } catch (e) {
      _showSnack('Reset failed: $e', Colors.red);
      _showToast('Reset failed');
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  Widget _buildFireman() {
    String asset;
    switch (_pose) {
      case FiremanPose.hose:
        asset = 'assets/animations/Fireman using hose.json';
        break;
      case FiremanPose.whistle:
        asset = 'assets/animations/Fireman using whistle.json';
        break;
      case FiremanPose.pointing:
      default:
        asset = 'assets/animations/Fire.json';
    }

    return SizedBox(
      height: 200,
      child: Lottie.asset(asset, repeat: true, fit: BoxFit.contain),
    );
  }

  Gradient _getBackground() {
    switch (_pose) {
      case FiremanPose.pointing:
        return const LinearGradient(
          colors: [Colors.grey, Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case FiremanPose.hose:
        return const LinearGradient(
          colors: [Colors.grey, Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case FiremanPose.whistle:
        return const LinearGradient(
          colors: [Colors.grey, Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
    }
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFireman(),
        const SizedBox(height: 20),
        TextField(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          focusNode: _passFocus,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscurePass = !_obscurePass;
                });
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _resetPassword,
            child: const Text('Forgot Password?'),
          ),
        ),
        if (_showChangePasswordButton)
          OutlinedButton.icon(
            icon: const Icon(Icons.lock_reset),
            label: const Text('Change Password'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
        Row(
          children: [
            Checkbox(
              value: _isBrigade,
              onChanged: (v) => setState(() => _isBrigade = v ?? false),
            ),
            const Text('Login as Brigade'),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _signIn,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Sign In'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _loading
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Register'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: _getBackground(),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
