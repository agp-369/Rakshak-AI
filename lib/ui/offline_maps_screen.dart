import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<Map<String, dynamic>> _bookmarks = [];

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
    _loadBookmarks();
  }

  Future<void> _loadPosition() async {
    try {
      final pos = await _gps.getCurrentPosition();
      setState(() {
        _position = pos;
        _status = 'Location acquired';
      });
    } catch (_) {
      setState(() => _status = 'GPS unavailable — use manual mark');
    }
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('map_bookmarks');
    if (raw != null) {
      setState(() => _bookmarks = List<Map<String, dynamic>>.from(json.decode(raw)));
    }
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_bookmarks', json.encode(_bookmarks));
  }

  Future<void> _markCurrentLocation() async {
    GeoPoint? pos = _position;
    if (pos == null) {
      try {
        pos = await _gps.getCurrentPosition();
      } catch (_) {}
    }
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot get GPS position. Try again.')),
        );
      }
      return;
    }

    final nameController = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:       Text('Mark ${_selectedCategory.toUpperCase()}', style: TextStyle(color: AppTheme.saffronLight)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Location name / notes'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;

    _bookmarks.add({
      'name': nameController.text.isNotEmpty ? nameController.text : '$_selectedCategory #${_bookmarks.length + 1}',
      'lat': pos.latitude,
      'lon': pos.longitude,
      'category': _selectedCategory,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _saveBookmarks();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedCategory.toUpperCase()} marked at current position')),
      );
    }
  }

  Future<void> _deleteBookmark(int index) async {
    _bookmarks.removeAt(index);
    await _saveBookmarks();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _bookmarks.where((b) => b['category'] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(Strings.offlineMaps.toUpperCase(), style: const TextStyle(letterSpacing: 2)),
      ),
      body: Column(
        children: [
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

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
                      Icon(_iconFromString(cat['icon']!), size: 14,
                          color: selected ? Colors.black : AppTheme.saffronLight),
                      const SizedBox(width: 4),
                      Text(cat['label']!),
                    ],
                  ),
                  selected: selected,
                  onSelected: (v) => setState(() => _selectedCategory = cat['key']!),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markCurrentLocation,
                    icon: const Icon(Icons.add_location, size: 18),
                    label: Text('MARK ${_selectedCategory.toUpperCase()}'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.surfaceLight),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 48, color: AppTheme.grey.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No ${_selectedCategory.toUpperCase()} locations marked',
                          style: const TextStyle(color: AppTheme.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use "MARK" button to save locations as you discover them',
                          style: TextStyle(color: AppTheme.grey.withValues(alpha: 0.6), fontSize: 10),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final b = filtered[index];
                      return Dismissible(
                        key: ValueKey(b['timestamp']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline, color: AppTheme.red),
                        ),
                        onDismissed: (_) => _deleteBookmark(_bookmarks.indexOf(b)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.surfaceLight),
                          ),
                          child: Row(
                            children: [
                              Icon(_iconFromString(b['category'] as String),
                                  size: 20, color: AppTheme.saffronLight),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b['name'] as String,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(b['lat'] as double).toStringAsFixed(4)}, ${(b['lon'] as double).toStringAsFixed(4)}',
                                      style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.grey),
                                onPressed: () => _deleteBookmark(_bookmarks.indexOf(b)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.surfaceLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 12, color: AppTheme.teal),
                const SizedBox(width: 6),
                Text(
                  '${_bookmarks.length} locations marked · OFFLINE',
                  style: const TextStyle(fontSize: 9, color: AppTheme.grey, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
