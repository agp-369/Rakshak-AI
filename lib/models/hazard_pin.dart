enum HazardType { flood, landslide, fire, roadblock, other }

extension HazardTypeExt on HazardType {
  String get id => name;

  String labelHi() {
    switch (this) {
      case HazardType.flood:
        return 'बाढ़';
      case HazardType.landslide:
        return 'भूस्खलन';
      case HazardType.fire:
        return 'आग';
      case HazardType.roadblock:
        return 'रास्ता बंद';
      case HazardType.other:
        return 'अन्य खतरा';
    }
  }

  String labelEn() {
    switch (this) {
      case HazardType.flood:
        return 'Flood';
      case HazardType.landslide:
        return 'Landslide';
      case HazardType.fire:
        return 'Fire';
      case HazardType.roadblock:
        return 'Road blocked';
      case HazardType.other:
        return 'Other hazard';
    }
  }

  static HazardType fromId(String? id) {
    return HazardType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => HazardType.other,
    );
  }
}

class HazardPin {
  final String id;
  final double latitude;
  final double longitude;
  final HazardType type;
  final String note;
  final DateTime createdAt;

  HazardPin({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.note = '',
    required this.createdAt,
  });

  factory HazardPin.fromJson(Map<String, dynamic> json) {
    return HazardPin(
      id: json['id'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      type: HazardTypeExt.fromId(json['type'] as String?),
      note: (json['note'] as String?) ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': latitude,
        'lon': longitude,
        'type': type.id,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };
}
