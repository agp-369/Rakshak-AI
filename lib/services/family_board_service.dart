import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakshak_ai/services/gps_service.dart';

/// Status of a family member on the board.
enum MemberStatus { unknown, safe, needHelp, moving }

extension MemberStatusLabel on MemberStatus {
  String get label {
    switch (this) {
      case MemberStatus.safe:
        return 'SAFE';
      case MemberStatus.needHelp:
        return 'NEEDS HELP';
      case MemberStatus.moving:
        return 'MOVING TO SAFETY';
      case MemberStatus.unknown:
        return 'NO CONTACT';
    }
  }

  String get labelHi {
    switch (this) {
      case MemberStatus.safe:
        return 'सुरक्षित';
      case MemberStatus.needHelp:
        return 'मदद चाहिए';
      case MemberStatus.moving:
        return 'सुरक्षित स्थान पर जा रहे';
      case MemberStatus.unknown:
        return 'संपर्क नहीं';
    }
  }
}

/// A family member entry on the offline family board.
class FamilyMember {
  final String id;
  final String name;
  final String phone;
  MemberStatus status;
  double? latitude;
  double? longitude;
  DateTime? lastUpdate;
  String? note;

  FamilyMember({
    required this.id,
    required this.name,
    required this.phone,
    this.status = MemberStatus.unknown,
    this.latitude,
    this.longitude,
    this.lastUpdate,
    this.note,
  });

  bool get hasLocation => latitude != null && longitude != null;

  String get timeAgo {
    if (lastUpdate == null) return 'never';
    final diff = DateTime.now().difference(lastUpdate!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'status': status.name,
        'latitude': latitude,
        'longitude': longitude,
        'lastUpdate': lastUpdate?.toIso8601String(),
        'note': note,
      };

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        status: MemberStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => MemberStatus.unknown,
        ),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        lastUpdate: DateTime.tryParse(json['lastUpdate'] as String? ?? ''),
        note: json['note'] as String?,
      );

  FamilyMember copyWith({
    MemberStatus? status,
    double? latitude,
    double? longitude,
    DateTime? lastUpdate,
    String? note,
  }) =>
      FamilyMember(
        id: id,
        name: name,
        phone: phone,
        status: status ?? this.status,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        lastUpdate: lastUpdate ?? this.lastUpdate,
        note: note ?? this.note,
      );
}

/// Offline-first family board. Each member's status is stored locally
/// and updated when: (1) the user taps on their behalf, or (2) an
/// inbound SMS beacon is manually logged, or (3) the app later gains
/// a background SMS listener. No internet required — ever.
class FamilyBoardService {
  static const _key = 'family_board';

  static final FamilyBoardService _instance = FamilyBoardService._internal();
  factory FamilyBoardService() => _instance;
  FamilyBoardService._internal();

  Future<List<FamilyMember>> getMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addMember(String name, String phone) async {
    final members = await getMembers();
    members.add(FamilyMember(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      phone: phone,
    ));
    await _save(members);
  }

  Future<void> removeMember(String id) async {
    final members = await getMembers();
    members.removeWhere((m) => m.id == id);
    await _save(members);
  }

  /// Update a member's status. Pass location to attach current GPS.
  Future<void> updateStatus(
    String id, {
    required MemberStatus status,
    GeoPoint? location,
    String? note,
  }) async {
    final members = await getMembers();
    final idx = members.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    members[idx] = members[idx].copyWith(
      status: status,
      latitude: location?.latitude,
      longitude: location?.longitude,
      lastUpdate: DateTime.now(),
      note: note,
    );
    await _save(members);
  }

  /// Update my own status (the phone owner is implicitly a member).
  Future<void> updateMyStatus({
    required MemberStatus status,
    GeoPoint? location,
    String? note,
  }) async {
    final members = await getMembers();
    var meIdx = members.indexWhere((m) => m.id == 'self');
    if (meIdx == -1) {
      members.insert(0, FamilyMember(id: 'self', name: 'Me', phone: ''));
      meIdx = 0;
    }
    members[meIdx] = members[meIdx].copyWith(
      status: status,
      latitude: location?.latitude,
      longitude: location?.longitude,
      lastUpdate: DateTime.now(),
      note: note,
    );
    await _save(members);
  }

  Future<void> _save(List<FamilyMember> members) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(members.map((m) => m.toJson()).toList()));
  }
}
