import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/emergency_contacts_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  Future<void> _dial(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('EMERGENCY CONTACTS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
            Text('आपातकालीन संपर्क', style: TextStyle(fontSize: 11, color: AppTheme.grey)),
          ],
        ),
        iconTheme: const IconThemeData(color: AppTheme.saffronLight),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: defaultContacts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final c = defaultContacts[i];
          final isEmergency = c.phone.length <= 3;
          return Container(
            decoration: BoxDecoration(
              color: isEmergency ? AppTheme.red.withValues(alpha: 0.05) : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isEmergency ? AppTheme.red.withValues(alpha: 0.3) : AppTheme.surfaceLight,
              ),
            ),
            child: InkWell(
              onTap: () => _dial(c.phone),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: (isEmergency ? AppTheme.red : AppTheme.saffron).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(c.icon, color: isEmergency ? AppTheme.red : AppTheme.saffronLight, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c.name.toUpperCase(), style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                              const SizedBox(width: 8),
                              Text(c.nameHindi, style: const TextStyle(color: AppTheme.grey, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(c.description, style: const TextStyle(color: AppTheme.grey, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isEmergency ? AppTheme.red.withValues(alpha: 0.15) : AppTheme.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c.phone,
                        style: TextStyle(
                          color: isEmergency ? AppTheme.red : AppTheme.teal,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
