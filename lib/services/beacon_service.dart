import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'gps_service.dart';

/// The three beacon states a person can send. Designed so a panicking
/// user picks one of three giant buttons — no typing, no navigation.
enum BeaconType {
  safe('SAFE', 'मैं सुरक्षित हूँ', 0xFF2F9E44),
  needHelp('NEED HELP', 'मुझे मदद चाहिए', 0xFFE03131),
  evacuate('EVACUATE NOW', 'तुरंत खाली करें', 0xFFE8590C);

  final String labelEn;
  final String labelHi;
  final int colorValue;
  const BeaconType(this.labelEn, this.labelHi, this.colorValue);
}

/// One sent (or queued) beacon record.
class BeaconRecord {
  final String id;
  final BeaconType type;
  final String message;
  final List<String> recipients;
  final DateTime timestamp;
  final bool delivered;
  final double? latitude;
  final double? longitude;

  BeaconRecord({
    required this.id,
    required this.type,
    required this.message,
    required this.recipients,
    required this.timestamp,
    this.delivered = false,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'message': message,
        'recipients': recipients,
        'timestamp': timestamp.toIso8601String(),
        'delivered': delivered,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory BeaconRecord.fromJson(Map<String, dynamic> json) => BeaconRecord(
        id: json['id'] as String,
        type: BeaconType.values.firstWhere((e) => e.name == json['type'],
            orElse: () => BeaconType.needHelp),
        message: json['message'] as String? ?? '',
        recipients: (json['recipients'] as List?)?.cast<String>() ?? const [],
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        delivered: json['delivered'] as bool? ?? false,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

/// Sends beacons via direct SMS (works when data/internet is dead).
/// Falls back to the sms: composer if the platform channel fails
/// (e.g. permission denied). Queues failed sends and retries.
class BeaconService {
  static const _channel = MethodChannel('rakshak_ai/device');
  static const _historyKey = 'beacon_history';
  static const _queueKey = 'beacon_queue';

  static final BeaconService _instance = BeaconService._internal();
  factory BeaconService() => _instance;
  BeaconService._internal();

  /// Compose the beacon text. Coordinates are included when available —
  /// this is the single most valuable payload (rescue teams can act on it).
  String composeMessage(BeaconType type, {GeoPoint? location, String? note}) {
    final buf = StringBuffer('[RAKSHAK] ${type.labelEn}: ');
    if (note != null && note.trim().isNotEmpty) {
      buf.write('${note.trim()} ');
    }
    if (location != null) {
      buf.write(
          'GPS ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}');
    } else {
      buf.write('location unavailable');
    }
    buf.write(' ${DateTime.now().toString().substring(0, 16)}');
    return buf.toString();
  }

  /// Send a beacon to all [recipients]. Returns true when every send succeeded.
  /// Failed sends are queued for later retry.
  Future<bool> send({
    required BeaconType type,
    required List<String> recipients,
    String? note,
    GeoPoint? location,
  }) async {
    if (recipients.isEmpty) return false;

    final message = composeMessage(type, location: location, note: note);
    var allOk = true;

    for (final number in recipients) {
      final ok = await _sendSms(number, message);
      if (!ok) allOk = false;
    }

    final record = BeaconRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      message: message,
      recipients: recipients,
      timestamp: DateTime.now(),
      delivered: allOk,
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
    await _appendToHistory(record);
    if (!allOk) await _enqueue(record);

    return allOk;
  }

  Future<bool> _sendSms(String number, String message) async {
    try {
      await _channel.invokeMethod('sendSms', {
        'number': number,
        'message': message,
      });
      return true;
    } catch (e) {
      debugPrint('[!] Direct SMS failed for $number: $e — trying composer');
      // Fallback: open the SMS composer prefilled (user taps send).
      try {
        final uri = Uri(
          scheme: 'sms',
          path: number,
          queryParameters: {'body': message},
        );
        return await launchUrl(uri);
      } catch (e2) {
        debugPrint('[!] SMS composer also failed: $e2');
        return false;
      }
    }
  }

  /// Retry all queued (undelivered) beacons. Called on app resume and
  /// from the beacon screen's retry button.
  Future<int> retryQueued() async {
    final queued = await getQueue();
    if (queued.isEmpty) return 0;

    var sent = 0;
    final remaining = <BeaconRecord>[];
    for (final record in queued) {
      var allOk = true;
      for (final number in record.recipients) {
        final ok = await _sendSms(number, record.message);
        if (!ok) allOk = false;
      }
      if (allOk) {
        sent++;
        await _markDelivered(record.id);
      } else {
        remaining.add(record);
      }
    }
    await _saveQueue(remaining);
    return sent;
  }

  Future<List<BeaconRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => BeaconRecord.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<List<BeaconRecord>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => BeaconRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_queueKey);
  }

  Future<void> _appendToHistory(BeaconRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.insert(0, record);
    // Keep last 100 records only.
    final trimmed = history.take(100).toList();
    await prefs.setString(
        _historyKey, jsonEncode(trimmed.map((r) => r.toJson()).toList()));
  }

  Future<void> _enqueue(BeaconRecord record) async {
    final queue = await getQueue();
    queue.add(record);
    await _saveQueue(queue);
  }

  Future<void> _saveQueue(List<BeaconRecord> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _queueKey, jsonEncode(queue.map((r) => r.toJson()).toList()));
  }

  Future<void> _markDelivered(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    final idx = history.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final old = history[idx];
    history[idx] = BeaconRecord(
      id: old.id,
      type: old.type,
      message: old.message,
      recipients: old.recipients,
      timestamp: old.timestamp,
      delivered: true,
      latitude: old.latitude,
      longitude: old.longitude,
    );
    await prefs.setString(
        _historyKey, jsonEncode(history.map((r) => r.toJson()).toList()));
  }
}
