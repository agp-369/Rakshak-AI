class MapPack {
  final String id;
  final String name;
  final String fileName;
  final String region;
  final String bounds;
  final int minZoom;
  final int maxZoom;
  final String attribution;
  final String license;
  final int? sizeBytes;

  MapPack({
    required this.id,
    required this.name,
    required this.fileName,
    required this.region,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    required this.attribution,
    required this.license,
    this.sizeBytes,
  });

  factory MapPack.fromJson(Map<String, dynamic> json) {
    return MapPack(
      id: json['id'] as String,
      name: json['name'] as String,
      fileName: json['fileName'] as String,
      region: json['region'] as String,
      bounds: json['bounds'] as String,
      minZoom: json['minZoom'] as int,
      maxZoom: json['maxZoom'] as int,
      attribution: json['attribution'] as String,
      license: json['license'] as String,
      sizeBytes: json['sizeBytes'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'fileName': fileName,
        'region': region,
        'bounds': bounds,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'attribution': attribution,
        'license': license,
        'sizeBytes': sizeBytes,
      };

  String get sizeLabel {
    if (sizeBytes == null) return 'unknown';
    final mb = sizeBytes! / (1024 * 1024);
    if (mb < 1) return '${(sizeBytes! / 1024).toStringAsFixed(0)} KB';
    return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  }
}
