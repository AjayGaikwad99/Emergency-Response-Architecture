import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import 'rounded_action_button.dart';
import 'location_service.dart';
import 'media_service.dart';
import 'login_screen.dart';
import 'chatbot_widget.dart';
import 'tracker.dart';
import 'fire_detection_page.dart';
import 'gamification.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final locService = LocationService();
  final media = MediaService();

  Position? _pos;
  File? _photo;
  File? _video;
  bool _sending = false;
  final _desc = TextEditingController();

  bool _confirmedReal = false;
  bool _acceptedFalseAlarmFine = false;

  bool _aiConsent = false;

  ChatbotResult? _lastChatbotResult;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';

  double _uploadProgress = 0.0;

  String? _currentAssignmentId;

  @override
  void initState() {
    super.initState();
    media.initRecorder();
    _captureLocation();
    _speech = stt.SpeechToText();
  }

  Future<void> _captureLocation() async {
    try {
      final p = await locService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _pos = p);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    }
  }

  Future<void> _pickPhoto() async {
    final f = await media.pickImageFromCamera();
    if (f != null && mounted) setState(() => _photo = f);
  }

  Future<void> _pickVideo() async {
    final f = await media.pickVideoFromCamera();
    if (f != null && mounted) setState(() => _video = f);
  }

  Future<String?> _uploadFileToStorage(File file, String storagePath) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final uploadTask = ref.putFile(file,
          SettableMetadata(contentType: _contentTypeForPath(storagePath)));

      uploadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          final progress = event.bytesTransferred / event.totalBytes;
          if (mounted) setState(() => _uploadProgress = progress);
        }
      });

      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Upload failed for $storagePath: $e');
      return null;
    } finally {
      if (mounted) setState(() => _uploadProgress = 0.0);
    }
  }

  String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    return 'application/octet-stream';
  }

  String _extractPhone(Map<String, dynamic> data) {
    final candidates = [
      'phone',
      'mobile',
      'telephone',
      'contact',
      'phoneNumber'
    ];
    for (final k in candidates) {
      final v = data[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  String _extractAddress(Map<String, dynamic> data) {
    final candidates = [
      'address',
      'locationAddress',
      'reportedAddress',
      'addr',
      'location'
    ];
    for (final k in candidates) {
      final v = data[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is Map) {
        final la = v['address'] ?? v['addr'] ?? v['locationAddress'];
        if (la is String && la.trim().isNotEmpty) return la.trim();
      }
    }
    return '';
  }

  Future<void> _ensureUserProfileExists(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      final snap = await userRef.get();
      if (!snap.exists) {
        final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        final fallback = <String, dynamic>{
          'name': FirebaseAuth.instance.currentUser?.displayName ?? '',
          'email': authEmail,
          'phone': '',
          'address': '',
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'fallbackCreated': true,
        };
        await userRef.set(fallback);
        debugPrint('Created fallback users/$uid profile: $fallback');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile created from account info')),
          );
        }
      } else {
        debugPrint('users/$uid exists, no fallback needed.');
      }
    } catch (e) {
      debugPrint('Failed to ensure users/$uid exists: $e');
    }
  }

  Future<bool> _showTermsDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Terms & Privacy'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Please read and accept the terms before submitting an alert.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Only use this emergency reporting feature for real emergencies.',
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Submitting false or prank reports may cause unnecessary risk and resource use.',
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• If you intentionally submit a false or prank report, you acknowledge that a penalty of ₹1000 may be applied and you accept responsibility for that penalty.',
                    ),
                    SizedBox(height: 12),
                    Text(
                      'By tapping "I accept", you confirm you understand these terms.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('I accept'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _openChatbot() async {
    final result = await Navigator.push<ChatbotResult?>(
      context,
      MaterialPageRoute(builder: (_) => const ChatbotWidget()),
    );

    if (result != null) {
      setState(() {
        _lastChatbotResult = result;
        if (result.summary != null && result.summary!.trim().isNotEmpty) {
          _desc.text = result.summary!;
        }
      });

      final actions = result.suggestedActions ?? {};
      if (actions['call_police'] == true) {
        final num = actions['police_number'] as String? ?? '100';
        _confirmAndCall('Police', num);
      } else if (actions['call_ambulance'] == true) {
        final num = actions['ambulance_number'] as String? ?? '102';
        _confirmAndCall('Ambulance', num);
      }
    }
  }

  Future<void> _confirmAndCall(String label, String number) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Call $label?'),
              content: Text('Do you want to call $label at $number now?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Call')),
              ],
            );
          },
        ) ??
        false;

    if (ok) {
      final uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open dialer on this device')));
      }
    }
  }

  Future<void> _sendAlert({String? autoReason}) async {
    if (_pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for location...')),
      );
      return;
    }

    if (!_confirmedReal && !_acceptedFalseAlarmFine) {
      final accepted = await _showTermsDialog();
      if (!accepted) return;

      final confirmReal = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                title: const Text('Confirm report type'),
                content: const Text(
                    'Is this a real emergency? If you select "No (for fun)", you must accept a penalty of ₹1000.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes, real emergency'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No (for fun)'),
                  ),
                ],
              );
            },
          ) ??
          true;

      if (confirmReal) {
        setState(() => _confirmedReal = true);
      } else {
        final fineAccepted = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Penalty acknowledgement'),
                  content: const Text(
                      'You chose to submit a non-emergency report. By proceeding you acknowledge and accept a penalty of ₹1000 for false/prank reports. Do you accept?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('I accept the ₹1000 penalty'),
                    ),
                  ],
                );
              },
            ) ??
            false;

        if (!fineAccepted) return;
        setState(() => _acceptedFalseAlarmFine = true);
      }
    }

    if (!_aiConsent && _lastChatbotResult != null) {
      final consent = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('AI processing consent'),
                content: const Text(
                    'The assistant suggested a summary or actions. Do you consent to send this text and any attached media to the AI backend for analysis?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No')),
                  ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Yes, I consent')),
                ],
              );
            },
          ) ??
          false;
      if (!consent) {
        setState(() => _lastChatbotResult = null);
      } else {
        setState(() => _aiConsent = true);
      }
    }

    setState(() {
      _sending = true;
      _uploadProgress = 0.0;
    });

    try {
      final auth = FirebaseAuth.instance;
      final uid = auth.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      String reporterEmail = auth.currentUser?.email ?? '';
      String reporterPhone = '';
      String reporterAddress = '';

      bool profileFound = false;
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final userDoc = await userRef.get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          if (data['email'] is String &&
              (data['email'] as String).trim().isNotEmpty) {
            reporterEmail = (data['email'] as String).trim();
          }
          reporterPhone = _extractPhone(data);
          reporterAddress = _extractAddress(data);
          profileFound = true;
        } else {
          await _ensureUserProfileExists(uid);
          final retry = await userRef.get();
          if (retry.exists && retry.data() != null) {
            final data = retry.data()!;
            if (data['email'] is String &&
                (data['email'] as String).trim().isNotEmpty) {
              reporterEmail = (data['email'] as String).trim();
            }
            reporterPhone = _extractPhone(data);
            reporterAddress = _extractAddress(data);
            profileFound = true;
          }
        }
      } catch (e) {
        debugPrint('Warning: failed to read users/$uid: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not read profile; using account email')),
          );
        }
      }

      if (!profileFound && (reporterEmail.isEmpty)) {
        reporterEmail = auth.currentUser?.email ?? '';
      }

      final idTime = DateTime.now().millisecondsSinceEpoch.toString();

      final alertData = <String, dynamic>{
        'reportedBy': uid,
        'reporterId': uid,
        'reporterEmail': reporterEmail,
        'reporterPhone': reporterPhone,
        'reporterAddress': reporterAddress,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
        'location': {'lat': _pos!.latitude, 'lng': _pos!.longitude},
        'description': autoReason ?? _desc.text,
        'photos': [],
        'videos': [],
      };

      if (_acceptedFalseAlarmFine) {
        alertData['falseAlarmAcknowledged'] = true;
        alertData['penaltyAmount'] = 1000;
      } else {
        alertData['falseAlarmAcknowledged'] = false;
      }

      if (_lastChatbotResult != null && _aiConsent) {
        alertData['aiAnalysis'] = {
          'intent': _lastChatbotResult!.intent,
          'summary': _lastChatbotResult!.summary,
          'suggestedActions': _lastChatbotResult!.suggestedActions,
          'timestamp': FieldValue.serverTimestamp(),
        };
      }

      final alertRef =
          await FirebaseFirestore.instance.collection('alerts').add(alertData);
      final alertId = alertRef.id;

      String? photoUrl;
      Map<String, dynamic>? photoMeta;
      if (_photo != null) {
        final filename = '${idTime}_photo.jpg';
        final storagePath = 'alerts/$alertId/photos/$filename';
        final url = await _uploadFileToStorage(_photo!, storagePath);
        if (url != null) {
          photoUrl = url;
          photoMeta = {
            'id': filename,
            'url': url,
            'path': storagePath,
            'uploader': uid,
            'uploadedAt': FieldValue.serverTimestamp(),
          };
          await FirebaseFirestore.instance
              .collection('alerts')
              .doc(alertId)
              .collection('photos')
              .doc(filename)
              .set(photoMeta);
          await alertRef.set({
            'photos': FieldValue.arrayUnion([photoMeta])
          }, SetOptions(merge: true));
        }
      }

      String? videoUrl;
      Map<String, dynamic>? videoMeta;
      if (_video != null) {
        final filename = '${idTime}_video.mp4';
        final storagePath = 'alerts/$alertId/videos/$filename';
        final url = await _uploadFileToStorage(_video!, storagePath);
        if (url != null) {
          videoUrl = url;
          videoMeta = {
            'id': filename,
            'url': url,
            'path': storagePath,
            'uploader': uid,
            'uploadedAt': FieldValue.serverTimestamp(),
          };
          await FirebaseFirestore.instance
              .collection('alerts')
              .doc(alertId)
              .collection('videos')
              .doc(filename)
              .set(videoMeta);
          await alertRef.set({
            'videos': FieldValue.arrayUnion([videoMeta])
          }, SetOptions(merge: true));
        }
      }

      final updateMap = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (photoUrl != null) updateMap['photoUrl'] = photoUrl;
      if (videoUrl != null) updateMap['videoUrl'] = videoUrl;
      if (photoMeta != null)
        updateMap['photos'] = FieldValue.arrayUnion([photoMeta]);
      if (videoMeta != null)
        updateMap['videos'] = FieldValue.arrayUnion([videoMeta]);

      if (updateMap.isNotEmpty) {
        await alertRef.update(updateMap);
      }

      final updatedDoc = await alertRef.get();
      if (updatedDoc.exists) {
        final data = updatedDoc.data();
        if (data != null && data['assignedVehicleId'] is String) {
          setState(
              () => _currentAssignmentId = data['assignedVehicleId'] as String);
        } else {
          setState(() => _currentAssignmentId = alertId);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alert sent (ID: $alertId)')),
      );

      setState(() {
        _photo = null;
        _video = null;
        _desc.clear();
        _confirmedReal = false;
        _acceptedFalseAlarmFine = false;
        _aiConsent = false;
        _lastChatbotResult = null;
      });
    } catch (e, st) {
      debugPrint('Send alert failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e')),
      );
    } finally {
      if (mounted)
        setState(() {
          _sending = false;
          _uploadProgress = 0.0;
        });
    }
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      final available =
          await _speech.initialize(onStatus: (s) {}, onError: (e) {});
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Speech unavailable')));
        return;
      }
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        if (!mounted) return;
        setState(() => _lastWords = result.recognizedWords);
        final text = _lastWords.toLowerCase();
        if (text.contains('help') ||
            text.contains('fire') ||
            text.contains('emergency')) {
          _speech.stop();
          setState(() => _isListening = false);
          _sendAlert(autoReason: 'AI assistant detected: "$_lastWords"');
        }
      });
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    media.dispose();
    try {
      _speech.stop();
    } catch (_) {}
    super.dispose();
  }

  Widget _mediaRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Photo'),
        ),
        ElevatedButton.icon(
          onPressed: _pickVideo,
          icon: const Icon(Icons.videocam),
          label: const Text('Video'),
        ),
        ElevatedButton.icon(
          onPressed: _openChatbot,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Assistant'),
        ),
      ],
    );
  }

  Widget _buildPickedPreview() {
    return Column(
      children: [
        if (_photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(_photo!, height: 160, fit: BoxFit.cover),
          ),
        if (_video != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text('Video attached'),
          ),
      ],
    );
  }

  Widget _termsTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: _confirmedReal,
          onChanged: (v) {
            setState(() {
              _confirmedReal = v ?? false;
              if (_confirmedReal) _acceptedFalseAlarmFine = false;
            });
          },
          title: const Text('CLICK HERE FOR IMMEDIATE HELP 👉'),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => _showTermsDialog(),
              child: const Text('View Terms & Privacy'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _confirmedReal
                    ? 'You confirmed this is a real emergency. For more detail view Terms & Privacy.'
                    : '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChatbotSuggestions() {
    final actions = _lastChatbotResult?.suggestedActions;
    if (actions == null || actions.isEmpty) return const SizedBox.shrink();

    final List<Widget> rows = [];

    if (actions['call_police'] == true) {
      final num = actions['police_number'] as String? ?? '100';
      rows.add(ListTile(
        leading: const Icon(Icons.local_police, color: Colors.red),
        title: const Text('Suggested: Call Police'),
        subtitle: Text('Number: $num'),
        trailing: ElevatedButton(
          onPressed: () => _confirmAndCall('Police', num),
          child: const Text('Call'),
        ),
      ));
    }

    if (actions['call_ambulance'] == true) {
      final num = actions['ambulance_number'] as String? ?? '102';
      rows.add(ListTile(
        leading: const Icon(Icons.local_hospital, color: Colors.red),
        title: const Text('Suggested: Call Ambulance'),
        subtitle: Text('Number: $num'),
        trailing: ElevatedButton(
          onPressed: () => _confirmAndCall('Ambulance', num),
          child: const Text('Call'),
        ),
      ));
    }

    if (actions['safetyTips'] is List) {
      final tips = (actions['safetyTips'] as List).cast<String>();
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Safety tips',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...tips.map((t) => Text('• $t')).toList(),
          ],
        ),
      ));
    }

    return Card(
      color: Colors.orange.shade50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: rows),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coords = _pos == null
        ? 'Locating...'
        : '${_pos!.latitude.toStringAsFixed(5)}, ${_pos!.longitude.toStringAsFixed(5)}';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Report Emergency'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.red),
                      title: const Text('Your Location'),
                      subtitle: Text(coords),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _captureLocation,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPickedPreview(),
                  const SizedBox(height: 8),
                  _mediaRow(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _desc,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  _termsTile(),
                  const SizedBox(height: 12),
                  if (_lastChatbotResult != null) _buildChatbotSuggestions(),
                  if (_uploadProgress > 0.0 && _uploadProgress < 1.0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(value: _uploadProgress),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.map),
                    label: const Text("Fire Escape"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FireDetectionPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.emoji_events),
                    label: const Text("Earn Rewards"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GamificationScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: RoundedActionButton(
                        onPressed: _sending ? null : () => _sendAlert(),
                        child: _sending
                            ? const SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.warning, size: 28),
                                  SizedBox(height: 4),
                                  Text('EMERGENCY',
                                      style: TextStyle(fontSize: 10)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.track_changes),
                        label: const Text('Open Tracker'),
                        onPressed: () {
                          final alertId = _currentAssignmentId ?? 'vehicle_123';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrackerScreen(
                                alertId: alertId,
                                isBrigade: false,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _toggleListening,
                    icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                    label: Text(_isListening ? 'Stop Listening' : 'Say fire'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastWords,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
