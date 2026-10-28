import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rakshak_ai/services/emergency_contacts_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  Future<void> _dial(BuildContext context, String phone) async {
    // Strict sanitization: only digits and a single leading '+' are allowed.
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 3 || digitsOnly.length > 15) {
      if (context.mounted) {
        final hi = AppLang.hindi;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hi ? 'अमान्य फ़ोन नंबर' : 'Invalid phone number'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
      return;
    }
    final cleanPhone = phone.trim().startsWith('+')
        ? '+$digitsOnly'
        : digitsOnly;
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    HapticFeedback.lightImpact();

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        final fallbackLaunched = await launchUrl(Uri.parse('tel:$cleanPhone'));
        if (!fallbackLaunched) {
          throw Exception('Dialer launch failed');
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanPhone));
      if (context.mounted) {
        final hi = AppLang.hindi;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hi
                  ? 'डायलर नहीं खुल सका। नंबर $cleanPhone कॉपी कर लिया गया है।'
                  : 'Dialer unavailable. Number $cleanPhone copied to clipboard.',
            ),
            backgroundColor: AppTheme.saffron,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi = AppLang.hindi;

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hi ? 'आपातकालीन हेल्पलाइन' : 'EMERGENCY HELPLINES',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            Text(
              hi ? 'कॉल करने के लिए किसी भी नंबर पर टैप करें' : 'Tap any number to open dialer directly',
              style: const TextStyle(fontSize: 11, color: AppTheme.grey),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppTheme.saffronLight),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.tealLight.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app, color: AppTheme.tealLight, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hi
                        ? 'किसी भी कार्ड या नंबर पर क्लिक करें — यह सीधे फोन डायलर में नंबर दर्ज कर देगा, बस कॉल बटन दबाना होगा।'
                        : 'Click any card or number — it automatically opens your phone dialer with the number pre-filled. You just need to tap call.',
                    style: const TextStyle(color: AppTheme.white, fontSize: 11.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...defaultContacts.map((c) {
            final isEmergency = c.phone.length <= 3;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isEmergency ? AppTheme.red.withValues(alpha: 0.06) : AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isEmergency ? AppTheme.red.withValues(alpha: 0.35) : AppTheme.surfaceLight,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _dial(context, c.phone),
                  borderRadius: BorderRadius.circular(14),
                  splashColor: (isEmergency ? AppTheme.red : AppTheme.tealLight).withValues(alpha: 0.2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (isEmergency ? AppTheme.red : AppTheme.saffron).withValues(alpha: 0.15),
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
                                  Text(
                                    c.name.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(c.nameHindi, style: const TextStyle(color: AppTheme.grey, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(c.description, style: const TextStyle(color: AppTheme.grey, fontSize: 10.5)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEmergency ? AppTheme.red : AppTheme.teal,
                            foregroundColor: AppTheme.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => _dial(context, c.phone),
                          icon: const Icon(Icons.call, size: 14),
                          label: Text(
                            c.phone,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
