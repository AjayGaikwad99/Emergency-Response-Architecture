import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateAlertScreen extends StatefulWidget {
  const CreateAlertScreen({super.key});

  @override
  State<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends State<CreateAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAlert() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final user = auth.currentUser;

      if (user == null) {
        throw Exception('You must be signed in to create an alert.');
      }

      String reporterEmail = user.email ?? '';
      String reporterPhone = '';
      String reporterAddress = '';

      try {
        final userDoc = await firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          if (data['email'] is String && (data['email'] as String).isNotEmpty) {
            reporterEmail = data['email'] as String;
          }
          if (data['phone'] is String && (data['phone'] as String).isNotEmpty) {
            reporterPhone = data['phone'] as String;
          }
          if (data['address'] is String &&
              (data['address'] as String).isNotEmpty) {
            reporterAddress = data['address'] as String;
          }
        }
      } catch (e) {
        debugPrint('Warning: failed to read users/${user.uid}: $e');
      }

      GeoPoint? location;
      final latText = _latCtrl.text.trim();
      final lngText = _lngCtrl.text.trim();
      if (latText.isNotEmpty && lngText.isNotEmpty) {
        final lat = double.tryParse(latText);
        final lng = double.tryParse(lngText);
        if (lat != null && lng != null) {
          location = GeoPoint(lat, lng);
        }
      }

      final alertData = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'reportedBy': user.uid,
        'reporterEmail': reporterEmail,
        'reporterPhone': reporterPhone,
        'reporterAddress': reporterAddress,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (location != null) {
        alertData['location'] = location;
      }

      final docRef = await firestore.collection('alerts').add(alertData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert created successfully')),
      );

      Navigator.of(context).pop({'alertId': docRef.id});
    } catch (e, st) {
      debugPrint('Create alert failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create alert: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateRequired(String? v) {
    if (v == null || v.trim().isEmpty) return 'This field is required';
    return null;
  }

  String? _validateLat(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final n = double.tryParse(v.trim());
    if (n == null || n < -90 || n > 90) return 'Enter valid latitude';
    return null;
  }

  String? _validateLng(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final n = double.tryParse(v.trim());
    if (n == null || n < -180 || n > 180) return 'Enter valid longitude';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Alert')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: _validateRequired,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Message / Description'),
                  validator: _validateRequired,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Latitude (optional)'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: _validateLat,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Longitude (optional)'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: _validateLng,
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitAlert,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Alert'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
