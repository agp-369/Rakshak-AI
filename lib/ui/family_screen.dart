import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/contacts_service.dart';
import 'package:rakshak_ai/services/family_board_service.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/contact_picker_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Offline family board. Everyone's status is stored on this phone and
/// updated by SMS beacons (or manual taps). Answers the question that
/// goes unanswered in every Indian disaster: "is my family alive?"
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _service = FamilyBoardService();
  List<FamilyMember> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final members = await _service.getMembers();
    if (mounted) {
      setState(() {
        _members = members;
        _loading = false;
      });
    }
  }

  Color _statusColor(MemberStatus s) {
    switch (s) {
      case MemberStatus.safe:
        return AppTheme.green;
      case MemberStatus.needHelp:
        return AppTheme.red;
      case MemberStatus.moving:
        return AppTheme.saffron;
      case MemberStatus.unknown:
        return AppTheme.grey;
    }
  }

  Future<void> _importFromContacts() async {
    final selected = await Navigator.push<List<ContactEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(existingMembers: _members),
      ),
    );
    if (selected != null && selected.isNotEmpty) {
      for (final c in selected) {
        await _service.addMember(c.name, c.phone);
      }
      await _load();
      if (mounted) {
        final hi = AppLang.hindi;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hi
                  ? '${selected.length} सदस्य परिवार बोर्ड में जोड़े गए'
                  : '${selected.length} family member(s) imported from contacts',
            ),
            backgroundColor: AppTheme.tealLight,
          ),
        );
      }
    }
  }

  Future<void> _addMember() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add family member',
            style: TextStyle(color: AppTheme.saffronLight, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name / नाम'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Phone / फ़ोन'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true &&
        nameCtrl.text.trim().isNotEmpty &&
        phoneCtrl.text.trim().isNotEmpty) {
      await _service.addMember(nameCtrl.text.trim(), phoneCtrl.text.trim());
      await _load();
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
  }

  Future<void> _editStatus(FamilyMember m) async {
    final selected = await showModalBottomSheet<MemberStatus>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('${m.name} — status',
                style: const TextStyle(
                    color: AppTheme.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...MemberStatus.values.map((s) => ListTile(
                  leading: Icon(Icons.circle,
                      color: _statusColor(s), size: 14),
                  title: Text('${s.label} / ${s.labelHi}',
                      style: const TextStyle(color: AppTheme.white)),
                  onTap: () => Navigator.pop(ctx, s),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected != null) {
      GeoPoint? location;
      try {
        location = await GpsService().getCurrentPosition();
      } catch (_) {}
      await _service.updateStatus(m.id, status: selected, location: location);
      await _load();
    }
  }

  Future<void> _call(String phone) async {
    if (phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(Uri.parse('tel:$cleanPhone'));
      }
    } catch (_) {
      await launchUrl(Uri.parse('tel:$cleanPhone'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLang.hindi;
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(lang ? 'परिवार बोर्ड' : 'Family Board',
            style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts, color: AppTheme.saffronLight),
            onPressed: _importFromContacts,
            tooltip: lang ? 'संपर्क से चुनें' : 'Import from Contacts',
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _addMember,
            tooltip: lang ? 'मैन्युअल जोड़ें' : 'Add manually',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _members.isEmpty
              ? _EmptyFamily(
                  lang: lang,
                  onAddManual: _addMember,
                  onImportContacts: _importFromContacts,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.surfaceLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: AppTheme.tealLight, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              lang
                                  ? 'इस बोर्ड पर परिवार की स्थिति बिना इंटरनेट भी सेव रहती है। बीकन संदेश सीधे इन नंबरों पर जाते हैं।'
                                  : "Each person's status is saved offline. SMS beacons automatically go to these verified numbers.",
                              style: const TextStyle(color: AppTheme.grey, fontSize: 11, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.saffronLight,
                              side: const BorderSide(color: AppTheme.saffronLight),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _importFromContacts,
                            icon: const Icon(Icons.contacts, size: 16),
                            label: Text(lang ? 'संपर्क से आयात' : 'Import Contacts', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.white,
                              side: const BorderSide(color: AppTheme.surfaceLight),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _addMember,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(lang ? 'नया नंबर' : 'Add New', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._members.map((m) => _MemberCard(
                          member: m,
                          color: _statusColor(m.status),
                          lang: lang,
                          onTap: () => _editStatus(m),
                          onCall: () => _call(m.phone),
                        )),
                    const SizedBox(height: 30),
                  ],
                ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final FamilyMember member;
  final Color color;
  final bool lang;
  final VoidCallback onTap;
  final VoidCallback onCall;

  const _MemberCard({
    required this.member,
    required this.color,
    required this.lang,
    required this.onTap,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final isSelf = member.id == 'self';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          isSelf ? (lang ? 'मैं' : 'Me') : member.name,
          style: const TextStyle(
              color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${member.status.label} · ${member.status.labelHi}',
              style: TextStyle(color: color, fontSize: 12),
            ),
            if (member.phone.isNotEmpty)
              Text(
                member.phone,
                style: const TextStyle(color: AppTheme.grey, fontSize: 11),
              ),
            Text(
              member.hasLocation
                  ? '${member.latitude!.toStringAsFixed(4)}, ${member.longitude!.toStringAsFixed(4)} · ${member.timeAgo}'
                  : (lang
                      ? 'स्थान नहीं · ${member.timeAgo}'
                      : 'No location · ${member.timeAgo}'),
              style: const TextStyle(color: AppTheme.grey, fontSize: 10),
            ),
          ],
        ),
        trailing: !isSelf && member.phone.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.phone, color: AppTheme.saffronLight, size: 22),
                tooltip: lang ? 'कॉल करें' : 'Call',
                onPressed: onCall,
              )
            : const Icon(Icons.chevron_right, color: AppTheme.grey),
      ),
    );
  }
}

class _EmptyFamily extends StatelessWidget {
  final bool lang;
  final VoidCallback onAddManual;
  final VoidCallback onImportContacts;

  const _EmptyFamily({
    required this.lang,
    required this.onAddManual,
    required this.onImportContacts,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.family_restroom, color: AppTheme.grey, size: 54),
            const SizedBox(height: 16),
            Text(
              lang ? 'कोई सदस्य नहीं' : 'No family members yet',
              style: const TextStyle(color: AppTheme.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              lang
                  ? 'परिवार जोड़ें ताकि आपातकाल में एक टैप में बीकन भेजा जा सके और उनकी स्थिति ट्रैक हो सके।'
                  : 'Add your close family members so 1-tap SOS beacons reach them and their safety status is tracked offline.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.grey, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.saffron,
                foregroundColor: AppTheme.navy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: onImportContacts,
              icon: const Icon(Icons.contacts, size: 18),
              label: Text(
                lang ? 'फोन संपर्कों से चुनें' : 'Choose from Contacts',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.white,
                side: const BorderSide(color: AppTheme.surfaceLight),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: onAddManual,
              icon: const Icon(Icons.person_add, size: 16),
              label: Text(lang ? 'मैन्युअल नाम/नंबर जोड़ें' : 'Add Manually'),
            ),
          ],
        ),
      ),
    );
  }
}
