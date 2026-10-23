import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/family_board_service.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
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
    await launchUrl(Uri(scheme: 'tel', path: phone));
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
            icon: const Icon(Icons.person_add),
            onPressed: _addMember,
            tooltip: 'Add member',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _members.isEmpty
              ? _EmptyFamily(lang: lang, onAdd: _addMember)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      lang
                          ? 'इस बोर्ड पर हर व्यक्ति की स्थिति सेव रहती है — इंटरनेट के बिना भी।'
                          : "Each person's status is saved on this phone — even without internet.",
                      style: const TextStyle(
                          color: AppTheme.grey, fontSize: 12, height: 1.4),
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
                icon: const Icon(Icons.phone, color: AppTheme.saffronLight, size: 20),
                onPressed: onCall,
              )
            : const Icon(Icons.chevron_right, color: AppTheme.grey),
      ),
    );
  }
}

class _EmptyFamily extends StatelessWidget {
  final bool lang;
  final VoidCallback onAdd;
  const _EmptyFamily({required this.lang, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.family_restroom, color: AppTheme.grey, size: 48),
            const SizedBox(height: 16),
            Text(
              lang ? 'कोई सदस्य नहीं' : 'No family members yet',
              style: const TextStyle(color: AppTheme.white, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              lang
                  ? 'परिवार जोड़ें ताकि बीकन उन्हें भेज सकें और उनकी स्थिति देख सकें।'
                  : 'Add family so beacons go to them and you can track their status.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.grey, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add, size: 18),
              label: Text(lang ? 'सदस्य जोड़ें' : 'Add member'),
            ),
          ],
        ),
      ),
    );
  }
}
