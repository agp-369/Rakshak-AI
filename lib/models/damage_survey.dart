enum StructureType { residential, commercial, publicInfra, agricultural }

extension StructureTypeExt on StructureType {
  String get labelEn {
    switch (this) {
      case StructureType.residential: return 'Residential House';
      case StructureType.commercial: return 'Shop / Commercial';
      case StructureType.publicInfra: return 'School / Hospital / Bridge';
      case StructureType.agricultural: return 'Farm / Livestock Shed';
    }
  }

  String get labelHi {
    switch (this) {
      case StructureType.residential: return 'आवासीय मकान';
      case StructureType.commercial: return 'दुकान / व्यावसायिक';
      case StructureType.publicInfra: return 'स्कूल / अस्पताल / पुल';
      case StructureType.agricultural: return 'खेत / पशु शेड';
    }
  }
}

enum DamageSeverity { minor, partial, severe, destroyed }

extension DamageSeverityExt on DamageSeverity {
  String get labelEn {
    switch (this) {
      case DamageSeverity.minor: return 'Minor (< 25%)';
      case DamageSeverity.partial: return 'Partial (25% - 50%)';
      case DamageSeverity.severe: return 'Severe (50% - 75%)';
      case DamageSeverity.destroyed: return 'Completely Destroyed (> 75%)';
    }
  }

  String get labelHi {
    switch (this) {
      case DamageSeverity.minor: return 'मामूली क्षति (< २५%)';
      case DamageSeverity.partial: return 'आंशिक क्षति (२५% - ५०%)';
      case DamageSeverity.severe: return 'गंभीर क्षति (५०% - ७५%)';
      case DamageSeverity.destroyed: return 'पूर्णतः ध्वस्त (> ७५%)';
    }
  }
}

class DamageSurveyRecord {
  final String id;
  final String imagePath;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracy;
  final String landmarkAndVillage;
  final String beneficiaryName;
  final String houseId;
  final StructureType structureType;
  final DamageSeverity damageSeverity;
  final double? waterMarkMeters;
  final bool isHabitable;
  final String notes;
  final bool synced;

  const DamageSurveyRecord({
    required this.id,
    required this.imagePath,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.landmarkAndVillage,
    required this.beneficiaryName,
    required this.houseId,
    required this.structureType,
    required this.damageSeverity,
    this.waterMarkMeters,
    required this.isHabitable,
    required this.notes,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'landmarkAndVillage': landmarkAndVillage,
    'beneficiaryName': beneficiaryName,
    'houseId': houseId,
    'structureType': structureType.name,
    'damageSeverity': damageSeverity.name,
    'waterMarkMeters': waterMarkMeters,
    'isHabitable': isHabitable,
    'notes': notes,
    'synced': synced,
  };

  factory DamageSurveyRecord.fromJson(Map<String, dynamic> json) => DamageSurveyRecord(
    id: json['id'] as String,
    imagePath: json['imagePath'] as String? ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
    landmarkAndVillage: json['landmarkAndVillage'] as String? ?? '',
    beneficiaryName: json['beneficiaryName'] as String? ?? '',
    houseId: json['houseId'] as String? ?? '',
    structureType: StructureType.values.firstWhere(
      (e) => e.name == json['structureType'],
      orElse: () => StructureType.residential,
    ),
    damageSeverity: DamageSeverity.values.firstWhere(
      (e) => e.name == json['damageSeverity'],
      orElse: () => DamageSeverity.partial,
    ),
    waterMarkMeters: (json['waterMarkMeters'] as num?)?.toDouble(),
    isHabitable: json['isHabitable'] as bool? ?? false,
    notes: json['notes'] as String? ?? '',
    synced: json['synced'] as bool? ?? false,
  );
}
