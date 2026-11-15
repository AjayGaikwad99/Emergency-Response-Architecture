import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPoint {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
}

class GpsService {
  GpsService._internal();
  static final GpsService instance = GpsService._internal();

  StreamSubscription<Position>? _positionSub;
  final StreamController<LocationPoint> _controller =
      StreamController<LocationPoint>.broadcast();

  Stream<LocationPoint> get onLocationChanged => _controller.stream;

  Future<bool> ensurePermissionAndService(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required')),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to initialize location service')),
        );
      }
      return false;
    }
  }

  Future<void> startListening({
    LocationAccuracy desiredAccuracy = LocationAccuracy.best,
    int distanceFilterMeters = 5,
  }) async {
    if (_positionSub != null) return;

    final locationSettings = LocationSettings(
      accuracy: desiredAccuracy,
      distanceFilter: distanceFilterMeters,
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position pos) {
        final point = LocationPoint(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          timestamp: pos.timestamp,
        );
        if (!_controller.isClosed) _controller.add(point);
      },
      onError: (err) {
        debugPrint('GpsService position stream error: $err');
      },
      cancelOnError: false,
    );
  }

  Future<void> stopListening() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  Future<LocationPoint?> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.best,
  }) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
      );
      return LocationPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        timestamp: pos.timestamp,
      );
    } catch (e) {
      debugPrint('GpsService getCurrentLocation error: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await stopListening();
    await _controller.close();
  }
}
