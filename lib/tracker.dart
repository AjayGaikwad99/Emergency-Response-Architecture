import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TrackerScreen extends StatefulWidget {
  final String alertId;
  final bool isBrigade;
  final String? brigadeId;
  final String? brigadeName;

  const TrackerScreen({
    super.key,
    required this.alertId,
    required this.isBrigade,
    this.brigadeId,
    this.brigadeName,
  });

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<Position>? _posSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _trackingSub;

  LatLng? _currentPoint;
  final List<LatLng> _path = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.isBrigade) {
      _startSending();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _trackingSub?.cancel();
    super.dispose();
  }

  Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _startSending() async {
    final ok = await _ensurePermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
      return;
    }

    final ref = _db.collection('trackings').doc(widget.alertId);
    await ref.set({
      'alertId': widget.alertId,
      'brigadeId': widget.brigadeId ?? '',
      'brigadeName': widget.brigadeName ?? '',
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      final initial = await Geolocator.getCurrentPosition();
      final gp = GeoPoint(initial.latitude, initial.longitude);
      setState(() {
        _currentPoint = LatLng(gp.latitude, gp.longitude);
        _path.add(_currentPoint!);
        _sending = true;
      });
      await ref.set({'current': gp}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Initial position error: $e');
    }

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      final gp = GeoPoint(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _currentPoint = LatLng(gp.latitude, gp.longitude);
        _path.add(_currentPoint!);
        _sending = true;
      });

      await ref.set({
        'current': gp,
        'path': FieldValue.arrayUnion([gp]),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _startListening() async {
    final ref = _db.collection('trackings').doc(widget.alertId);

    _trackingSub = ref.snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final current = data['current'] as GeoPoint?;
      if (current != null && mounted) {
        setState(() {
          _currentPoint = LatLng(current.latitude, current.longitude);
          _path.add(_currentPoint!);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBrigade
            ? (_sending ? 'Sending live location...' : 'Ready to send')
            : 'Live tracker'),
      ),
      body: _currentPoint == null
          ? const Center(child: Text('Waiting for location...'))
          : FlutterMap(
              options: MapOptions(
                initialCenter: _currentPoint!,
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.yourcompany.fire_alert_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 40),
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _path,
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
