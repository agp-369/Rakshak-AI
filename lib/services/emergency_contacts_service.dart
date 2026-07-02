import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContact {
  final String name;
  final String nameHindi;
  final String phone;
  final String description;
  final IconData icon;

  const EmergencyContact({
    required this.name,
    required this.nameHindi,
    required this.phone,
    required this.description,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'nameHindi': nameHindi,
    'phone': phone,
    'description': description,
    'icon': icon.codePoint,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    // ignore: non_const_argument_for_const_parameter
    final icon = IconData(json['icon'] as int,
      fontFamily: 'MaterialIcons');
    return EmergencyContact(
      name: json['name'] as String,
      nameHindi: json['nameHindi'] as String? ?? '',
      phone: json['phone'] as String,
      description: json['description'] as String? ?? '',
      icon: icon,
    );
  }
}

final List<EmergencyContact> defaultContacts = [
  EmergencyContact(name: 'Ambulance', nameHindi: 'एम्बुलेंस', phone: '108', description: 'Medical Emergency — Free throughout India', icon: Icons.local_hospital),
  EmergencyContact(name: 'Police', nameHindi: 'पुलिस', phone: '100', description: 'Law & order emergency', icon: Icons.local_police),
  EmergencyContact(name: 'Fire Brigade', nameHindi: 'दमकल', phone: '101', description: 'Fire, gas leak, rescue', icon: Icons.fire_truck),
  EmergencyContact(name: 'Disaster Relief', nameHindi: 'आपदा राहत', phone: '1078', description: 'NDMA — National Disaster Helpline', icon: Icons.warning),
  EmergencyContact(name: 'Women Helpline', nameHindi: 'महिला हेल्पलाइन', phone: '1091', description: 'Women in distress', icon: Icons.female),
  EmergencyContact(name: 'Child Helpline', nameHindi: 'बाल हेल्पलाइन', phone: '1098', description: 'Children in distress', icon: Icons.child_care),
  EmergencyContact(name: 'Emergency', nameHindi: 'आपातकालीन', phone: '112', description: 'Pan-India emergency (police/fire/medical)', icon: Icons.sos),
  EmergencyContact(name: 'Railway Helpline', nameHindi: 'रेलवे हेल्पलाइन', phone: '139', description: 'Railway emergency / inquiry', icon: Icons.train),
  EmergencyContact(name: 'Road Accident', nameHindi: 'सड़क दुर्घटना', phone: '1033', description: 'Road accident emergency', icon: Icons.directions_car),
  EmergencyContact(name: 'Poison Control', nameHindi: 'विष नियंत्रण', phone: '1066', description: 'Poisoning / overdose', icon: Icons.medication),
];

class EmergencyContactsService {
  static const _key = 'emergency_contacts';

  Future<List<EmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return List.from(defaultContacts);
    final list = jsonDecode(raw) as List;
    return list.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(contacts.map((c) => c.toJson()).toList()));
  }

  Future<void> resetDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
