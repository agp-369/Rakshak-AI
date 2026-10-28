import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ContactEntry {
  final String id;
  final String name;
  final String phone;

  const ContactEntry({
    required this.id,
    required this.name,
    required this.phone,
  });

  String get initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class ContactsService {
  static const _channel = MethodChannel('rakshak_ai/device');

  static final ContactsService _instance = ContactsService._internal();
  factory ContactsService() => _instance;
  ContactsService._internal();

  Future<bool> hasPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasContactsPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestContactsPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<ContactEntry>> getContacts() async {
    try {
      final list = await _channel.invokeListMethod<dynamic>('getContacts');
      if (list == null) return [];
      return list.map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        return ContactEntry(
          id: m['id'] as String? ?? '',
          name: m['name'] as String? ?? '',
          phone: m['phone'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('[ContactsService] getContacts error: $e');
      return [];
    }
  }
}
