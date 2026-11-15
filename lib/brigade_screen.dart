import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'brigade_map_detail.dart';
import 'login_screen.dart';
import 'tracker.dart';

class BrigadeScreen extends StatefulWidget {
  const BrigadeScreen({super.key});

  @override
  State<BrigadeScreen> createState() => _BrigadeScreenState();
}

class _BrigadeScreenState extends State<BrigadeScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _formatTimestamp(Object? ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      return '${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}';
    }
    if (ts is DateTime) {
      final dt = ts.toLocal();
      return '${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}';
    }
    return ts?.toString() ?? '';
  }

  String _locationText(dynamic loc) {
    try {
      if (loc is GeoPoint) {
        return '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}';
      } else if (loc is Map) {
        final dynamic la = loc['lat'] ?? loc['latitude'];
        final dynamic lo = loc['lng'] ?? loc['longitude'];
        if (la is num && lo is num) {
          return '${la.toDouble().toStringAsFixed(5)}, ${lo.toDouble().toStringAsFixed(5)}';
        }
      } else if (loc is String) {
        return loc;
      }
    } catch (_) {}
    return 'Unknown';
  }

  ll.LatLng? _toLatLng(dynamic loc) {
    try {
      if (loc is GeoPoint) {
        return ll.LatLng(loc.latitude, loc.longitude);
      } else if (loc is Map) {
        final dynamic la = loc['lat'] ?? loc['latitude'];
        final dynamic lo = loc['lng'] ?? loc['longitude'];
        if (la is num && lo is num) {
          return ll.LatLng(la.toDouble(), lo.toDouble());
        }
        if (loc['location'] is GeoPoint) {
          final gp = loc['location'] as GeoPoint;
          return ll.LatLng(gp.latitude, gp.longitude);
        }
      } else if (loc is String) {
        final parts = loc.split(',');
        if (parts.length >= 2) {
          final a = double.tryParse(parts[0].trim());
          final b = double.tryParse(parts[1].trim());
          if (a != null && b != null) return ll.LatLng(a, b);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _acceptAlert(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sign in required')));
      return;
    }

    final brigadeId = user.uid;
    final brigadeName = user.displayName ?? 'Brigade';

    final alertRef = _db.collection('alerts').doc(doc.id);
    final trackingRef = _db.collection('trackings').doc(doc.id);

    try {
      await _db.runTransaction((tx) async {
        final snapshot = await tx.get(alertRef);
        if (!snapshot.exists) throw Exception('Alert no longer exists');
        final data = snapshot.data();
        if (data != null && data['acceptedBy'] != null) {
          throw Exception('Already accepted');
        }
        tx.update(alertRef, {
          'acceptedBy': brigadeId,
          'acceptedAt': FieldValue.serverTimestamp(),
          'status': 'accepted',
        });
        tx.set(
            trackingRef,
            {
              'alertId': doc.id,
              'brigadeId': brigadeId,
              'brigadeName': brigadeName,
              'status': 'active',
              'startedAt': FieldValue.serverTimestamp(),
              'current': null,
              'path': [],
            },
            SetOptions(merge: true));
      });

      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TrackerScreen(
          alertId: doc.id,
          isBrigade: true,
          brigadeId: brigadeId,
          brigadeName: brigadeName,
        ),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Widget _buildAlertTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String message =
        (data['message'] ?? data['description'] ?? 'No message').toString();
    final createdAt = data['createdAt'];
    final locationField =
        data['location'] ?? data['currentLocation'] ?? data['locations_latest'];
    final locationText = _locationText(locationField);

    final String? userId = (data['reportedBy'] is String)
        ? data['reportedBy'] as String
        : (data['userId'] is String ? data['userId'] as String : null);

    String? thumbUrl;
    try {
      final photos = data['photos'];
      if (photos is List && photos.isNotEmpty) {
        final first = photos.first;
        if (first is Map && first['url'] is String) {
          thumbUrl = first['url'] as String;
        }
      } else if (data['photoUrl'] is String) {
        thumbUrl = data['photoUrl'] as String;
      }
    } catch (_) {
      thumbUrl = null;
    }

    final acceptedBy = data['acceptedBy'] as String?;
    final isAccepted = acceptedBy != null && acceptedBy.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: thumbUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  thumbUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.grey),
                ),
              )
            : const Icon(Icons.report, color: Colors.redAccent),
        title: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle:
            Text('Location: $locationText\n${_formatTimestamp(createdAt)}'),
        isThreeLine: true,
        trailing: isAccepted
            ? const Chip(label: Text('Accepted'), backgroundColor: Colors.green)
            : ElevatedButton(
                child: const Text('Accept'),
                onPressed: () => _acceptAlert(doc),
              ),
        onLongPress: () => _showUserInfo(context, userId),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BrigadeMapDetailScreen(
              alertId: doc.id,
              userId: userId,
              alertLocation: _toLatLng(locationField),
            ),
          ));
        },
      ),
    );
  }

  Future<void> _showUserInfo(BuildContext context, String? uid) async {}

  @override
  Widget build(BuildContext context) {
    final alertsStream = _db
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brigade Dashboard'),
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: alertsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No messages/alerts'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              return _buildAlertTile(docs[index]);
            },
          );
        },
      ),
    );
  }
}
