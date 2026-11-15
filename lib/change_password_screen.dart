import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureEmail = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  Future<void> _changePassword() async {
    final email = _emailCtrl.text.trim();
    final oldPass = _oldPassCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();

    if (email.isEmpty || oldPass.isEmpty || newPass.isEmpty) {
      _showSnack('All fields are required', Colors.red);
      _showToast('Fill in all fields');
      return;
    }
    if (newPass.length < 6) {
      _showSnack('Password must be at least 6 characters', Colors.red);
      _showToast('Weak password');
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = FirebaseAuth.instance;

      final userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: oldPass,
      );
      final user = userCredential.user;

      if (user == null) {
        _showSnack('User not found', Colors.red);
        return;
      }

      await user.updatePassword(newPass);

      _showSnack('Password updated successfully', Colors.green);
      _showToast('Password changed');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = 'Update failed';
      if (e.code == 'wrong-password') {
        msg = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        msg = 'New password is too weak';
      } else if (e.code == 'user-not-found') {
        msg = 'No user found for this email';
      } else if (e.code == 'requires-recent-login') {
        msg = 'Session expired. Please log in again.';
        await FirebaseAuth.instance.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      _showSnack(msg, Colors.red);
      _showToast(msg);
    } catch (e) {
      _showSnack('Update failed: $e', Colors.red);
      _showToast('Password change failed');
    } finally {
      setState(() => _loading = false);
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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              obscureText: _obscureEmail,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureEmail ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureEmail = !_obscureEmail),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _oldPassCtrl,
              obscureText: _obscureOld,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOld ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscureOld = !_obscureOld),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPassCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _changePassword,
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
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }
}
