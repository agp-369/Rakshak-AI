import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// GPS coordinates
class GeoPoint {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final String source;

  GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0,
    DateTime? timestamp,
    this.source = 'gps',
  }) : timestamp = timestamp ?? DateTime.now();

  String toJson() => jsonEncode({
        'lat': latitude,
        'lon': longitude,
        'accuracy': accuracy,
        'source': source,
      });

  @override
  String toString() => '$latitude, $longitude (±${accuracy}m)';
}

/// Offline-first GPS service with caching and fallback.
class GpsService {
  static final GpsService _instance = GpsService._internal();
  factory GpsService() => _instance;
  GpsService._internal();

  GeoPoint? _lastKnown;
  LocationPermission? _permission;

  GeoPoint? get lastKnown => _lastKnown;
  bool get hasLocation => _lastKnown != null;

  /// Initialize GPS service and request permissions.
  Future<bool> initialize() async {
    try {
      await Geolocator.isLocationServiceEnabled();
      _permission = await Geolocator.checkPermission();

      if (_permission == LocationPermission.denied) {
        _permission = await Geolocator.requestPermission();
      }

      if (_permission == LocationPermission.whileInUse ||
          _permission == LocationPermission.always) {
        // Get last known position for immediate availability
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          _lastKnown = GeoPoint(
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: pos.accuracy,
            timestamp: pos.timestamp,
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[!] GPS init error: $e');
      return false;
    }
  }

  /// Get current position with fallback to last known.
  Future<GeoPoint> getCurrentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      _lastKnown = GeoPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        source: 'gps',
      );
      return _lastKnown!;
    } catch (e) {
      if (_lastKnown != null) return _lastKnown!;
      rethrow;
    }
  }

  /// Convenience: returns last known Position-like map or null.
  Future<GeoPoint?> getLastKnownPosition() async => _lastKnown;

  /// Distance in meters between two points (Haversine).
  static double distanceBetween(GeoPoint a, GeoPoint b) {
    return Geolocator.distanceBetween(
      a.latitude, a.longitude,
      b.latitude, b.longitude,
    );
  }
}
