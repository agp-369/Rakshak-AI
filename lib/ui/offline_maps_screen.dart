import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

class OfflineMapsScreen extends StatefulWidget {
  const OfflineMapsScreen({super.key});

  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends State<OfflineMapsScreen> {
  final GpsService _gps = GpsService();
  String _status = 'Initializing...';
  GeoPoint? _position;
  String _selectedCategory = 'shelter';
  String? _disclaimerShown;

  final List<Map<String, String>> _categories = [
    {'key': 'shelter', 'label': 'Shelters', 'icon': 'house'},
    {'key': 'hospital', 'label': 'Hospitals', 'icon': 'local_hospital'},
    {'key': 'water', 'label': 'Water', 'icon': 'water_drop'},
    {'key': 'food', 'label': 'Food', 'icon': 'restaurant'},
    {'key': 'fuel', 'label': 'Fuel', 'icon': 'local_gas_station'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final pos = await _gps.getCurrentPosition();
    setState(() {
      _position = pos;
      _status = pos.source == 'fallback'
          ? 'Using approximate location'
          : 'Location acquired';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('OFFLINE MAP', style: TextStyle(letterSpacing: 2)),
      ),
      body: Column(
        children: [
          // Location banner
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.surface,
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppTheme.saffronLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _position != null
                        ? '${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}'
                        : _status,
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16, color: AppTheme.saffronLight),
                  onPressed: _loadPosition,
                ),
              ],
            ),
          ),

          // Category chips
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat['key'];
                return ChoiceChip(
                  backgroundColor: AppTheme.surface,
                  selectedColor: AppTheme.saffron,
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: 11,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconFromString(cat['icon']!),
                        size: 14,
                        color: selected ? Colors.black : AppTheme.saffronLight,
                      ),
                      const SizedBox(width: 4),
                      Text(cat['label']!),
                    ],
                  ),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      _selectedCategory = cat['key']!;
                      _disclaimerShown = null;
                    });
                  },
                );
              }).toList(),
            ),
          ),

          // Search button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _position == null ? null : _showDisclaimer,
              icon: const Icon(Icons.search, size: 18),
              label: Text('FIND NEARBY ${_selectedCategory.toUpperCase()}S'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),

          // Disclaimer (shown once per category)
          if (_disclaimerShown != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.saffronLight, size: 16),
                        SizedBox(width: 10),
                        Text(
                          'OFFLINE MAP DATA',
                          style: TextStyle(
                            color: AppTheme.saffronLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_disclaimerShown!,
                        style: const TextStyle(color: AppTheme.white, fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            ),

          const Spacer(),

          // Offline mode indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 14, color: AppTheme.grey),
                SizedBox(width: 8),
                Text('OFFLINE GEODATA ACTIVE',
                    style: TextStyle(fontSize: 9, color: AppTheme.grey, letterSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDisclaimer() {
    setState(() {
      _disclaimerShown =
        'Offline map data is not bundled with this app to keep the APK size small. '
        'Pre-download OpenStreetMap tiles using OSMAnd or Organic Maps before going offline.\n\n'
        'Current position: ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}\n'
        'Category: $_selectedCategory\n\n'
        'Tip: Mark known shelter/hospital locations in the triage log as you discover them.';
    });
  }

  IconData _iconFromString(String name) {
    switch (name) {
      case 'house': return Icons.house;
      case 'local_hospital': return Icons.local_hospital;
      case 'water_drop': return Icons.water_drop;
      case 'restaurant': return Icons.restaurant;
      case 'local_gas_station': return Icons.local_gas_station;
      default: return Icons.place;
    }
  }
}
