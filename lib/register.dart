import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      final UserCredential cred = await auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      final User? createdUser = cred.user;
      await createdUser?.reload();
      final User? currentUser = FirebaseAuth.instance.currentUser;
      final String? uid = currentUser?.uid ?? createdUser?.uid;
      if (uid == null) throw Exception('Failed to create user (no uid)');

      try {
        await currentUser?.updateDisplayName(_nameCtrl.text.trim());
        await currentUser?.reload();
      } catch (_) {}

      final Map<String, dynamic> profile = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await firestore.collection('users').doc(uid).set(profile);

      try {
        final saved = await firestore.collection('users').doc(uid).get();
        debugPrint(
            'Saved user profile for uid: $uid, exists: ${saved.exists}, data: ${saved.data()}');
      } catch (e) {
        debugPrint('Warning: could not read back saved user doc: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully')));
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      if (e.code == 'email-already-in-use') message = 'Email already in use';
      if (e.code == 'weak-password') message = 'Password is too weak';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$message: ${e.message ?? e.code}')));
    } catch (e, st) {
      debugPrint('Register error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final email = v.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone is required';
    final phone = v.trim();
    final phoneRegex = RegExp(r'^[0-9]{7,15}$');
    if (!phoneRegex.hasMatch(phone)) return 'Enter a valid phone number';
    return null;
  }

  String? _validateAddress(String? v) {
    if (v == null || v.trim().isEmpty) return 'Address is required';
    if (v.trim().length < 5) return 'Enter a more detailed address';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 6,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(labelText: 'Address'),
                    keyboardType: TextInputType.streetAddress,
                    textInputAction: TextInputAction.done,
                    validator: _validateAddress,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Create account'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Back to login')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
