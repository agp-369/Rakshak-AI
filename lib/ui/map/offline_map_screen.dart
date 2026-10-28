import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:offline_tiles/offline_tiles.dart';

import '../../models/hazard_pin.dart';
import '../../models/map_pack.dart';
import '../../services/gps_service.dart';
import '../../services/hazard_service.dart';
import '../../services/localization.dart';
import '../../services/map_pack_service.dart';
import '../../services/track_service.dart';
import '../../theme/app_theme.dart';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final _mapController = MapController();
  final _gps = GpsService();
  final _packService = MapPackService();
  final _hazardService = HazardService();
  final _trackService = TrackService();

  OfflineTileManager? _tileManager;
  MapPack? _activePack;
  LatLng? _center;
  LatLng? _current;
  LatLng? _target;
  double _accuracy = 0;
  DateTime? _fixTime;
  List<LatLng> _trail = [];
  List<HazardPin> _hazards = [];
  StreamSubscription<Position>? _posSub;
  DateTime _lastTrackSave = DateTime.fromMillisecondsSinceEpoch(0);
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _gps.initialize();
      _trail = await _trackService.load();
      _hazards = await _hazardService.load();
      final packs = await _packService.availablePacks();
      if (packs.isEmpty) {
        setState(() {
          _loading = false;
          _error = AppLang.hindi
              ? 'कोई ऑफ़लाइन मैप पैक नहीं मिला'
              : 'No offline map pack found';
        });
        return;
      }
      final activeId = await _packService.getActivePackId();
      _activePack =
          packs.firstWhere((p) => p.id == activeId, orElse: () => packs.first);
      final path = await _packService.resolvePathForPack(_activePack!);
      if (path == null) {
        setState(() {
          _loading = false;
          _error =
              AppLang.hindi ? 'मैप फ़ाइल नहीं मिली' : 'Map file not found';
        });
        return;
      }
      _tileManager = OfflineTileManager(
        tileSource: TileSourceType.mbtiles,
        mbtilesPath: path,
        allowOnlineFallback: false,
      );

      _center = await _getInitialCenter();
      _startLocation();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<LatLng> _getInitialCenter() async {
    try {
      final pos = await _gps.getCurrentPosition();
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      if (_gps.lastKnown != null) {
        return LatLng(_gps.lastKnown!.latitude, _gps.lastKnown!.longitude);
      }
      return const LatLng(30.3165, 78.0322);
    }
  }

  void _startLocation() {
    _posSub?.cancel();
    try {
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen(_onPosition);
    } catch (e) {
      debugPrint('[OfflineMapScreen] location stream error: $e');
    }
  }

  void _onPosition(Position pos) {
    final pt = LatLng(pos.latitude, pos.longitude);
    _trail = List<LatLng>.of(_trail);
    final moved = _trail.isEmpty || _dist(_trail.last, pt) > 8;
    if (moved) {
      _trail.add(pt);
      if (_trail.length > 600) _trail.removeAt(0);
    }
    final now = DateTime.now();
    if (moved && now.difference(_lastTrackSave).inSeconds >= 10) {
      _lastTrackSave = now;
      unawaited(_trackService.save(_trail));
    }
    if (mounted) {
      setState(() {
        _current = pt;
        _accuracy = pos.accuracy;
        _fixTime = DateTime.now();
      });
    }
  }

  double _dist(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final deg = math.atan2(y, x) * 180 / math.pi;
    return (deg + 360) % 360;
  }

  String _compassLabel(double bearing) {
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = (((bearing + 22.5) % 360) / 45).floor() % 8;
    return labels[idx];
  }

  void _goToCurrent() {
    if (_current != null) _mapController.move(_current!, 15.5);
  }

  void _backtrack() {
    if (_trail.length < 2) {
      _snack(AppLang.hindi
          ? 'अभी कोई ट्रैक नहीं। GPS चालू रखें।'
          : 'No trail yet. Keep GPS on.');
      return;
    }
    final recent = _trail.length > 20
        ? _trail.sublist(_trail.length - 20)
        : List<LatLng>.of(_trail);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(recent),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  void _setTarget(LatLng point) {
    setState(() => _target = point);
  }

  void _clearTarget() {
    setState(() => _target = null);
  }

  String _fixAge() {
    if (_fixTime == null) return '--';
    final diff = DateTime.now().difference(_fixTime!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    return '${diff.inMinutes}m';
  }

  bool get _outsidePack {
    if (_current == null || _activePack == null) return false;
    final parts = _activePack!.bounds.split(',');
    if (parts.length != 4) return false;
    final west = double.tryParse(parts[0]);
    final south = double.tryParse(parts[1]);
    final east = double.tryParse(parts[2]);
    final north = double.tryParse(parts[3]);
    if (west == null || south == null || east == null || north == null) {
      return false;
    }
    final p = _current!;
    return p.latitude < south ||
        p.latitude > north ||
        p.longitude < west ||
        p.longitude > east;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reportHazard() async {
    if (_current == null) {
      _snack(AppLang.hindi
          ? 'पहले GPS फ़िक्स का इंतज़ार करें।'
          : 'Wait for a GPS fix first.');
      return;
    }
    final result = await showModalBottomSheet<({HazardType type, String note})>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      builder: (ctx) => const _HazardSheet(),
    );
    if (result == null || !mounted) return;
    final pin = HazardPin(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      latitude: _current!.latitude,
      longitude: _current!.longitude,
      type: result.type,
      note: result.note,
      createdAt: DateTime.now(),
    );
    final pins = await _hazardService.add(pin);
    if (mounted) setState(() => _hazards = pins);
  }

  Future<void> _showHazard(HazardPin pin) async {
    final hi = AppLang.hindi;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          hi ? pin.type.labelHi() : pin.type.labelEn(),
          style: const TextStyle(color: AppTheme.saffronLight),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: AppTheme.white),
            ),
            if (pin.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(pin.note, style: const TextStyle(color: AppTheme.grey)),
            ],
            const SizedBox(height: 8),
            Text(
              hi
                  ? 'यह पिन केवल इस फ़ोन में सेव है।'
                  : 'This pin is stored on this phone only.',
              style: const TextStyle(color: AppTheme.grey, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final pins = await _hazardService.remove(pin.id);
              if (mounted) setState(() => _hazards = pins);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(hi ? 'हटाएं' : 'Delete',
                style: const TextStyle(color: AppTheme.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(hi ? 'बंद करें' : 'Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _tileManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hi = AppLang.hindi;
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.navy,
        appBar: AppBar(title: Text(hi ? 'ऑफ़लाइन मैप' : 'OFFLINE MAP')),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.saffron),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.navy,
        appBar: AppBar(title: Text(hi ? 'ऑफ़लाइन मैप' : 'OFFLINE MAP')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              style: const TextStyle(color: AppTheme.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (_center == null || _tileManager == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(
          hi
              ? 'मैप • ${_activePack?.region ?? ''}'
              : 'MAP • ${_activePack?.region ?? ''}',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          Center(
            child: Text(
              '±${_accuracy.toStringAsFixed(0)}m • ${_fixAge()}',
              style: const TextStyle(fontSize: 10, color: AppTheme.grey),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_alert_outlined),
            tooltip: hi ? 'खतरा दर्ज करें' : 'Report hazard',
            onPressed: _reportHazard,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center!,
              initialZoom: 14,
              minZoom: _activePack?.minZoom.toDouble() ?? 12,
              maxZoom: _activePack?.maxZoom.toDouble() ?? 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onLongPress: (tapPosition, point) => _setTarget(point),
            ),
            children: [
              TileLayer(
                tileProvider: _tileManager!.tileProvider,
                maxZoom: _activePack?.maxZoom.toDouble() ?? 15,
                minZoom: _activePack?.minZoom.toDouble() ?? 12,
              ),
              if (_trail.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _trail,
                      color: AppTheme.saffron.withValues(alpha: 0.7),
                      strokeWidth: 3,
                    ),
                  ],
                ),
              if (_current != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _current!,
                      radius: _accuracy.clamp(3, 80),
                      useRadiusInMeter: true,
                      color: AppTheme.tealLight.withValues(alpha: 0.16),
                      borderColor: AppTheme.tealLight.withValues(alpha: 0.45),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              if (_current != null && _target != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_current!, _target!],
                      color: AppTheme.chakraBlue,
                      strokeWidth: 2,
                      pattern: StrokePattern.dashed(segments: const [10, 8]),
                    ),
                  ],
                ),
              if (_hazards.isNotEmpty)
                MarkerLayer(
                  markers: _hazards
                      .map(
                        (h) => Marker(
                          point: LatLng(h.latitude, h.longitude),
                          width: 34,
                          height: 34,
                          child: GestureDetector(
                            onTap: () => _showHazard(h),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _hazardColor(h.type),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: AppTheme.white, width: 2),
                              ),
                              child: Icon(
                                _hazardIcon(h.type),
                                size: 16,
                                color: AppTheme.white,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              if (_target != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _target!,
                      width: 34,
                      height: 34,
                      child: const Icon(
                        Icons.flag,
                        color: AppTheme.chakraBlue,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              if (_current != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _current!,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.tealLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation,
                          color: AppTheme.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_target != null && _current != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _TargetBanner(
                distanceMeters: _dist(_current!, _target!),
                bearing: _bearing(_current!, _target!),
                direction: _compassLabel(_bearing(_current!, _target!)),
                onClear: _clearTarget,
                hi: hi,
              ),
            ),
          if (_outsidePack)
            Positioned(
              top: _target != null ? 86 : 12,
              left: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.saffron.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hi
                      ? 'आप पैक के कवरेज से बाहर हैं — केवल आपका ट्रैक दिखेगा'
                      : 'Outside pack coverage — only your track is visible',
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 84,
            child: FloatingActionButton(
              heroTag: 'hazard_fab',
              mini: true,
              backgroundColor: AppTheme.red,
              onPressed: _reportHazard,
              child: const Icon(Icons.add_location_alt_outlined, size: 20),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2E33)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_activePack?.attribution ?? ''} • ${_activePack?.license ?? ''}',
                          style: const TextStyle(
                              fontSize: 8, color: AppTheme.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          hi
                              ? 'नक्शे पर लंबा दबाएं: गंतव्य • ${_hazards.length} खतरे'
                              : 'Long-press map: target • ${_hazards.length} hazards',
                          style: const TextStyle(
                              fontSize: 9, color: AppTheme.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _goToCurrent,
                    icon: const Icon(Icons.my_location, size: 15),
                    label: Text(hi ? 'मैं' : 'Me'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.saffronLight,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _backtrack,
                    icon: const Icon(Icons.route, size: 15),
                    label: Text(hi ? 'वापस' : 'Back'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _hazardColor(HazardType type) {
    switch (type) {
      case HazardType.flood:
        return AppTheme.chakraBlue;
      case HazardType.landslide:
        return const Color(0xFF8D6E63);
      case HazardType.fire:
        return AppTheme.red;
      case HazardType.roadblock:
        return AppTheme.yellow;
      case HazardType.other:
        return AppTheme.grey;
    }
  }

  IconData _hazardIcon(HazardType type) {
    switch (type) {
      case HazardType.flood:
        return Icons.water;
      case HazardType.landslide:
        return Icons.landscape;
      case HazardType.fire:
        return Icons.local_fire_department;
      case HazardType.roadblock:
        return Icons.block;
      case HazardType.other:
        return Icons.warning_amber;
    }
  }
}

class _TargetBanner extends StatelessWidget {
  final double distanceMeters;
  final double bearing;
  final String direction;
  final VoidCallback onClear;
  final bool hi;

  const _TargetBanner({
    required this.distanceMeters,
    required this.bearing,
    required this.direction,
    required this.onClear,
    required this.hi,
  });

  @override
  Widget build(BuildContext context) {
    final km = distanceMeters >= 1000;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.chakraBlue.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: bearing * math.pi / 180,
            child: const Icon(Icons.navigation, color: AppTheme.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hi ? 'सीधा गंतव्य' : 'Straight-line target',
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${km ? (distanceMeters / 1000).toStringAsFixed(2) : distanceMeters.toStringAsFixed(0)} ${km ? "km" : "m"} • $direction ${bearing.toStringAsFixed(0)}°',
                  style: const TextStyle(color: AppTheme.white, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, color: AppTheme.white, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _HazardSheet extends StatefulWidget {
  const _HazardSheet();

  @override
  State<_HazardSheet> createState() => _HazardSheetState();
}

class _HazardSheetState extends State<_HazardSheet> {
  HazardType _type = HazardType.flood;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hi = AppLang.hindi;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hi ? 'खतरा दर्ज करें' : 'Report hazard',
            style: const TextStyle(
              color: AppTheme.saffronLight,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hi
                ? 'आपकी वर्तमान लोकेशन पर पिन लगेगा। केवल इस फ़ोन में सेव।'
                : 'Pins your current location. Stored on this phone only.',
            style: const TextStyle(color: AppTheme.grey, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HazardType.values.map((t) {
              return ChoiceChip(
                selected: _type == t,
                label: Text(hi ? t.labelHi() : t.labelEn()),
                selectedColor: AppTheme.saffron,
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: hi ? 'नोट (वैकल्पिक)' : 'Note (optional)',
              hintText: hi ? 'जैसे: पुल डूबा हुआ है' : 'e.g. bridge under water',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(
                context,
                (type: _type, note: _note.text.trim()),
              ),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(hi ? 'पिन लगाएं' : 'Place pin'),
            ),
          ),
        ],
      ),
    );
  }
}
