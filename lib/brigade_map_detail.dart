import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'call_util.dart';

class BrigadeMapDetailScreen extends StatefulWidget {
  final String alertId;
  final String? userId;
  final ll.LatLng? alertLocation;

  const BrigadeMapDetailScreen({
    super.key,
    required this.alertId,
    this.userId,
    this.alertLocation,
  });

  @override
  State<BrigadeMapDetailScreen> createState() => _BrigadeMapDetailScreenState();
}

class _BrigadeMapDetailScreenState extends State<BrigadeMapDetailScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fm.MapController _mapController = fm.MapController();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  DocumentSnapshot<Map<String, dynamic>>? _userSnapshot;
  Map<String, dynamic>? _alertData;
  ll.LatLng? _userLatLng;
  ll.LatLng? _alertLatLng;
  String _userName = 'User';
  bool _loading = true;
  String? _error;
  double _desiredZoom = 5.0;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      ll.LatLng? alertLoc = widget.alertLocation;
      String? uid = widget.userId;

      final alertSnap =
          await _db.collection('alerts').doc(widget.alertId).get();
      if (alertSnap.exists) {
        final data = alertSnap.data();
        _alertData = data;
        debugPrint('Alert loaded: ${widget.alertId} -> ${data}');
        if (alertLoc == null) {
          alertLoc = _extractLatLngFromField(data?['location'] ??
              data?['currentLocation'] ??
              data?['locations_latest']);
        }
        if (uid == null) {
          final dynamic reportedBy = data?['reportedBy'];
          final dynamic userIdField = data?['userId'];
          if (reportedBy is String && reportedBy.isNotEmpty)
            uid = reportedBy;
          else if (userIdField is String && userIdField.isNotEmpty)
            uid = userIdField;
        }
      } else {
        _alertData = null;
        debugPrint('Alert not found: ${widget.alertId}');
      }

      _alertLatLng = alertLoc;

      if (uid != null && uid.isNotEmpty) {
        await _subscribeToUser(uid);
      } else {
        String? email = _extractStringField(
            _alertData, ['reporterEmail', 'email', 'reportedEmail']);
        String? phone = _extractStringField(
            _alertData, ['reporterPhone', 'phone', 'reportedPhone']);
        if (email != null) {
          final q = await _db
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            uid = q.docs.first.id;
            await _subscribeToUser(uid);
          } else {
            debugPrint('No user found by email: $email');
          }
        }
        if (uid == null && phone != null) {
          final q = await _db
              .collection('users')
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            uid = q.docs.first.id;
            await _subscribeToUser(uid);
          } else {
            debugPrint('No user found by phone: $phone');
          }
        }
      }

      final ll.LatLng center =
          _userLatLng ?? _alertLatLng ?? ll.LatLng(20.5937, 78.9629);
      _desiredZoom = (_userLatLng != null || _alertLatLng != null) ? 15.0 : 5.0;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _moveMapSafely(center, _desiredZoom));

      if (mounted) setState(() => _loading = false);
    } catch (e, st) {
      debugPrint('Init failed: $e\n$st');
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Initialization failed: $e';
        });
    }
  }

  Future<void> _subscribeToUser(String uid) async {
    await _userSub?.cancel();
    _userSub =
        _db.collection('users').doc(uid).snapshots().listen((snap) async {
      if (!mounted) return;
      _userSnapshot = snap;
      debugPrint(
          'User snapshot for $uid: exists=${snap.exists}, data=${snap.data()}');

      if (snap.exists && snap.data() != null) {
        _extractLocationAndName(snap.data());
        if (mounted)
          setState(() {
            _loading = false;
            _error = null;
          });
        return;
      }

      try {
        final one = await _db.collection('users').doc(uid).get();
        debugPrint(
            'One-time get users/$uid: exists=${one.exists}, data=${one.data()}');
        if (one.exists && one.data() != null) {
          _userSnapshot = one;
          _extractLocationAndName(one.data());
          if (mounted)
            setState(() {
              _loading = false;
              _error = null;
            });
          return;
        } else {
          if (mounted)
            setState(() {
              _loading = false;
              _error = 'User profile not found';
            });
        }
      } catch (e) {
        debugPrint('One-time get failed for users/$uid: $e');
        if (mounted)
          setState(() {
            _loading = false;
            _error = 'Failed to load user profile: $e';
          });
      }
    }, onError: (e) {
      debugPrint('Realtime subscription error for users/$uid: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load user data: $e';
        _loading = false;
      });
    });
  }

  void _extractLocationAndName(Map<String, dynamic>? data) {
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _userLatLng = null;
        _userName = 'User';
      });
      return;
    }

    final name = data['name'] ??
        data['displayName'] ??
        data['fullName'] ??
        data['username'];
    _userName = name?.toString() ?? 'User';

    GeoPoint? gp;
    final dynamic currentLocationField = data['currentLocation'];
    final dynamic locationField = data['location'];
    final dynamic locationsLatest = data['locations_latest'];

    if (currentLocationField is GeoPoint)
      gp = currentLocationField;
    else if (locationField is GeoPoint)
      gp = locationField;
    else if (locationsLatest is Map<String, dynamic> &&
        locationsLatest['location'] is GeoPoint)
      gp = locationsLatest['location'] as GeoPoint;

    if (gp != null) {
      _userLatLng = ll.LatLng(gp.latitude, gp.longitude);
      _desiredZoom = 15.0;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _moveMapSafely(_userLatLng!, _desiredZoom));
    }
  }

  ll.LatLng? _extractLatLngFromField(dynamic loc) {
    try {
      if (loc is GeoPoint) return ll.LatLng(loc.latitude, loc.longitude);
      if (loc is Map) {
        final dynamic la = loc['lat'] ?? loc['latitude'];
        final dynamic lo = loc['lng'] ?? loc['longitude'];
        if (la is num && lo is num)
          return ll.LatLng(la.toDouble(), lo.toDouble());
        if (loc['location'] is GeoPoint) {
          final gp = loc['location'] as GeoPoint;
          return ll.LatLng(gp.latitude, gp.longitude);
        }
      }
      if (loc is String) {
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

  String? _extractStringField(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final k in keys) {
      final v = data[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  void _moveMapSafely(ll.LatLng target, double zoom) {
    try {
      _mapController.move(target, zoom);
    } catch (_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        try {
          _mapController.move(target, zoom);
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Widget _buildProfileCard() {
    final Map<String, dynamic>? userData = _userSnapshot?.data();
    if (userData != null) {
      final email =
          (userData['email'] is String) ? userData['email'] as String : '';
      final phone =
          (userData['phone'] is String) ? userData['phone'] as String : '';
      final address =
          (userData['address'] is String) ? userData['address'] as String : '';

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_userName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Email: ${email.isNotEmpty ? email : '—'}'),
            const SizedBox(height: 4),
            Text('Phone: ${phone.isNotEmpty ? phone : '—'}'),
            const SizedBox(height: 6),
            Text('Address: ${address.isNotEmpty ? address : '—'}'),
          ]),
        ),
      );
    }

    final ad = _alertData;
    final reporterName =
        _extractStringField(ad, ['reporterName', 'name', 'reportedName']) ??
            'Reporter';
    final reporterEmail =
        _extractStringField(ad, ['reporterEmail', 'email', 'reportedEmail']) ??
            '';
    final reporterPhone =
        _extractStringField(ad, ['reporterPhone', 'phone', 'reportedPhone']) ??
            '';
    final reporterAddress = _extractStringField(
            ad, ['reporterAddress', 'address', 'reportedAddress']) ??
        '';
    final message = ad?['message'] ?? ad?['description'] ?? 'No message';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reporterName,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Message: ${message.toString()}'),
          const SizedBox(height: 6),
          Text('Email: ${reporterEmail.isNotEmpty ? reporterEmail : '—'}'),
          const SizedBox(height: 4),
          Text('Phone: ${reporterPhone.isNotEmpty ? reporterPhone : '—'}'),
          const SizedBox(height: 6),
          Text(
              'Address: ${reporterAddress.isNotEmpty ? reporterAddress : '—'}'),
        ]),
      ),
    );
  }

  Widget _buildMapArea() {
    return fm.FlutterMap(
      mapController: _mapController,
      options: const fm.MapOptions(),
      children: [
        fm.TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.fire_alert',
        ),
      ],
    );
  }

  Future<void> _markResolved() async {
    try {
      await _db.collection('alerts').doc(widget.alertId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Marked resolved')));
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('Failed to mark resolved: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark resolved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ll.LatLng mapCenter =
        _userLatLng ?? _alertLatLng ?? ll.LatLng(20.5937, 78.9629);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _moveMapSafely(mapCenter, _desiredZoom));

    return Scaffold(
      appBar: AppBar(title: const Text('User Details & Live Location')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    _buildProfileCard(),
                    Expanded(
                        child: Stack(children: [
                      Positioned.fill(child: _buildMapArea()),
                      const Align(
                          alignment: Alignment.center,
                          child: Icon(Icons.location_on,
                              color: Colors.redAccent, size: 40)),
                      Positioned(
                          top: 12,
                          left: 12,
                          child: Card(
                              color: Colors.white70,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          _userSnapshot != null
                                              ? 'User location'
                                              : (_alertLatLng != null
                                                  ? 'Alert location'
                                                  : 'Location'),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                          '${mapCenter.latitude.toStringAsFixed(6)}, ${mapCenter.longitude.toStringAsFixed(6)}',
                                          style: const TextStyle(fontSize: 12)),
                                    ]),
                              ))),
                      Positioned(
                          right: 12,
                          bottom: 12,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            FloatingActionButton.small(
                                heroTag: 'recenter',
                                onPressed: () {
                                  final target =
                                      _userLatLng ?? _alertLatLng ?? mapCenter;
                                  _moveMapSafely(target, 15.0);
                                  setState(() => _desiredZoom = 15.0);
                                },
                                child: const Icon(Icons.my_location)),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                                heroTag: 'zoom_in',
                                onPressed: () {
                                  final newZoom =
                                      (_desiredZoom + 1.0).clamp(1.0, 18.0);
                                  _moveMapSafely(mapCenter, newZoom);
                                  setState(() => _desiredZoom = newZoom);
                                },
                                child: const Icon(Icons.zoom_in)),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                                heroTag: 'zoom_out',
                                onPressed: () {
                                  final newZoom =
                                      (_desiredZoom - 1.0).clamp(1.0, 18.0);
                                  _moveMapSafely(mapCenter, newZoom);
                                  setState(() => _desiredZoom = newZoom);
                                },
                                child: const Icon(Icons.zoom_out)),
                          ])),
                    ])),
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(children: [
                          Expanded(
                            child: ElevatedButton.icon(
                                icon: const Icon(Icons.call),
                                label: const Text('Call user'),
                                onPressed: () async {
                                  final phone = _userSnapshot
                                          ?.data()?['phone']
                                          ?.toString() ??
                                      _extractStringField(_alertData, [
                                        'reporterPhone',
                                        'phone',
                                        'reportedPhone'
                                      ]);

                                  if (phone == null || phone.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Phone not available')),
                                    );
                                    return;
                                  }

                                  await CallUtils.callUser(context, phone);
                                }),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check),
                                  label: const Text('Mark resolved'),
                                  onPressed: _markResolved)),
                        ])),
                  ],
                ),
    );
  }
}
