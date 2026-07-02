import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SafePerson {
  final String name;
  final String location;
  final DateTime timestamp;
  final String note;
  final bool isSafe;

  SafePerson({
    required this.name,
    required this.location,
    required this.timestamp,
    this.note = '',
    this.isSafe = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'location': location,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
    'isSafe': isSafe,
  };

  factory SafePerson.fromJson(Map<String, dynamic> json) => SafePerson(
    name: json['name'] as String,
    location: json['location'] as String? ?? '',
    timestamp: DateTime.parse(json['timestamp'] as String),
    note: json['note'] as String? ?? '',
    isSafe: json['isSafe'] as bool? ?? true,
  );

  String get durationAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class ImSafeService {
  static const _key = 'im_safe_people';

  Future<List<SafePerson>> getPeople() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => SafePerson.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addPerson(SafePerson person) async {
    final people = await getPeople();
    people.add(person);
    await _save(people);
  }

  Future<void> removePerson(String name) async {
    final people = await getPeople();
    people.removeWhere((p) => p.name == name);
    await _save(people);
  }

  Future<void> markSelfSafe({required String location, String note = ''}) async {
    final person = SafePerson(
      name: 'Me',
      location: location,
      timestamp: DateTime.now(),
      note: note,
    );
    // Replace existing "Me" entry
    final people = await getPeople();
    people.removeWhere((p) => p.name == 'Me');
    people.add(person);
    await _save(people);
  }

  Future<bool> isSelfSafe() async {
    final people = await getPeople();
    return people.any((p) => p.name == 'Me');
  }

  Future<List<SafePerson>> search(String query) async {
    if (query.isEmpty) return [];
    final people = await getPeople();
    final q = query.toLowerCase();
    return people.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _save(List<SafePerson> people) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(people.map((p) => p.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
