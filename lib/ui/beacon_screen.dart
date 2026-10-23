import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/ai_engine.dart';
import 'package:rakshak_ai/services/beacon_service.dart';
import 'package:rakshak_ai/services/emergency_contacts_service.dart';
import 'package:rakshak_ai/services/family_board_service.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/widgets/ai_badge.dart';
import 'package:rakshak_ai/ui/widgets/voice_input_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// The beacon screen. Three giant buttons, each sends an SMS with GPS to
/// every recipient in the beacon list. Designed for a panicking user:
/// no typing, no menus, one tap. Voice works too.
class BeaconScreen extends StatefulWidget {
  const BeaconScreen({super.key});

  @override
  State<BeaconScreen> createState() => _BeaconScreenState();
}

class _BeaconScreenState extends State<BeaconScreen> {
  final _beacon = BeaconService();
  final _gps = GpsService();
  final _family = FamilyBoardService();

  List<EmergencyContact>? _contacts;
  bool _sending = false;
  String? _statusMsg;
  Color _statusColor = AppTheme.grey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await EmergencyContactsService().getContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts.where((c) => c.phone.length >= 3).toList();
    });
    // Attempt to get a fresh GPS fix (non-blocking).
    _gps.initialize();
  }

  /// Recipients for beacon SMS: family board members with phone numbers.
  /// Falls back to a sensible default (108) if no family added yet.
  Future<List<String>> _recipients() async {
    final members = await _family.getMembers();
    final numbers = members
        .where((m) => m.phone.trim().isNotEmpty && m.id != 'self')
        .map((m) => m.phone.trim())
        .toSet()
        .toList();
    if (numbers.isEmpty) {
      return ['108'];
    }
    return numbers;
  }

  Future<void> _sendBeacon(BeaconType type) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _statusMsg = 'भेजा जा रहा है... / Sending...';
      _statusColor = AppTheme.grey;
    });

    final recipients = await _recipients();
    GeoPoint? location;
    try {
      location = await _gps.getCurrentPosition();
    } catch (_) {
      location = _gps.lastKnown;
    }

    final ok = await _beacon.send(
      type: type,
      recipients: recipients,
      location: location,
    );

    // Update family board with my status.
    final MemberStatus status;
    switch (type) {
      case BeaconType.safe:
        status = MemberStatus.safe;
        break;
      case BeaconType.needHelp:
        status = MemberStatus.needHelp;
        break;
      case BeaconType.evacuate:
        status = MemberStatus.moving;
        break;
    }
    await _family.updateMyStatus(status: status, location: location);

    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _statusMsg =
            '${type.labelEn} भेजा गया → ${recipients.length} ${AppLang.hindi ? "लोगों को" : "people"}';
        _statusColor = type.colorValue == BeaconType.safe.colorValue
            ? AppTheme.green
            : AppTheme.saffronLight;
      } else {
        _statusMsg =
            'कुछ भेज नहीं पाए — SMS ऐप से भेजें या retry दबाएं / Some failed — retry';
        _statusColor = AppTheme.red;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_statusMsg!),
        backgroundColor: _statusColor,
      ));
    }
  }

  Future<void> _retryQueue() async {
    final sent = await _beacon.retryQueued();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sent > 0
          ? '$sent queued beacon(s) sent'
          : 'No queued beacons / कुछ नहीं बचा'),
    ));
  }

  /// Voice -> on-device AI -> structured, confirmable beacon.
  /// The model reads panic speech (Hindi, English, mixed) and extracts
  /// intent, injuries, trapped status and number of people. If the model
  /// is not loaded, the keyword parser still produces a safe result.
  Future<void> _handleVoice(String text) async {
    final lang = AppLang.hindi;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 20),
      content: Row(
        children: [
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(lang
                ? 'AI आपकी बात समझ रहा है…'
                : 'AI is understanding what you said…'),
          ),
        ],
      ),
    ));

    final result = await AiEngine().parseDistress(text, hindi: lang);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();

    final type = _beaconTypeFor(result.intent);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VoiceSheet(
        spoken: text,
        result: result,
        type: type,
        lang: lang,
        onSend: (t) {
          Navigator.pop(ctx);
          _sendBeacon(t);
        },
      ),
    );
  }

  BeaconType? _beaconTypeFor(String intent) {
    switch (intent) {
      case 'beacon_safe':
        return BeaconType.safe;
      case 'beacon_help':
        return BeaconType.needHelp;
      case 'beacon_evac':
        return BeaconType.evacuate;
      default:
        return null;
    }
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLang.hindi;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          lang ? 'एक टैप में परिवार को बताएं' : 'Tell your family in one tap',
          style: const TextStyle(
              color: AppTheme.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          lang
              ? 'SMS भेजा जाएगा — इंटरनेट की ज़रूरत नहीं। GPS अपने आप जुड़ेगा।'
              : 'Sends SMS — no internet needed. Your GPS is attached automatically.',
          style: const TextStyle(color: AppTheme.grey, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _gps.lastKnown != null
                    ? 'GPS: ${_gps.lastKnown}'
                    : (lang ? 'GPS तैयार हो रहा है...' : 'Getting GPS...'),
                style: const TextStyle(color: AppTheme.tealLight, fontSize: 11),
              ),
            ),
            VoiceInputButton(
              onResult: _handleVoice,
              onError: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(AppLang.hindi
                      ? 'माइक नहीं चला — बटन दबाकर बीकन भेजें'
                      : 'Mic unavailable — tap a beacon button'),
                ));
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _BeaconButton(
          type: BeaconType.safe,
          onTap: _sending ? null : () => _sendBeacon(BeaconType.safe),
          subtitle: lang
              ? 'मैं ठीक हूँ, सुरक्षित हूँ'
              : "I'm okay and safe",
        ),
        const SizedBox(height: 12),
        _BeaconButton(
          type: BeaconType.needHelp,
          onTap: _sending ? null : () => _sendBeacon(BeaconType.needHelp),
          subtitle: lang
              ? 'फंसा हूँ / चोट लगी है — मदद भेजें'
              : 'Trapped or injured — send help',
        ),
        const SizedBox(height: 12),
        _BeaconButton(
          type: BeaconType.evacuate,
          onTap: _sending ? null : () => _sendBeacon(BeaconType.evacuate),
          subtitle: lang
              ? 'यहाँ खतरा है — सब निकल जाएं'
              : 'Danger here — everyone leave',
        ),
        const SizedBox(height: 20),
        if (_statusMsg != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _statusColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  _statusColor == AppTheme.red
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: _statusColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_statusMsg!,
                      style: TextStyle(color: _statusColor, fontSize: 12)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _retryQueue,
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(lang ? 'भेज नहीं पाए? दोबारा भेजें' : 'Failed? Retry queue'),
        ),
        const SizedBox(height: 20),
        const Divider(color: AppTheme.surfaceLight),
        const SizedBox(height: 8),
        Text(
          lang ? 'आपातकालीन कॉल' : 'Emergency calls',
          style: const TextStyle(
              color: AppTheme.saffronLight,
              fontSize: 13,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_contacts == null)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _contacts!
                .map((c) => ActionChip(
                      backgroundColor: AppTheme.surfaceLight,
                      avatar: Icon(c.icon,
                          size: 16, color: AppTheme.saffronLight),
                      label: Text(c.phone,
                          style: const TextStyle(
                              color: AppTheme.white, fontSize: 12)),
                      onPressed: () => _callNumber(c.phone),
                    ))
                .toList(),
          ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _BeaconButton extends StatelessWidget {
  final BeaconType type;
  final VoidCallback? onTap;
  final String subtitle;

  const _BeaconButton({
    required this.type,
    required this.onTap,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(type.colorValue);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(_iconFor(type), color: Colors.white, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${type.labelEn}  ·  ${type.labelHi}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(BeaconType type) {
    switch (type) {
      case BeaconType.safe:
        return Icons.verified_user;
      case BeaconType.needHelp:
        return Icons.sos;
      case BeaconType.evacuate:
        return Icons.directions_run;
    }
  }
}

/// Confirmation sheet after voice input. Shows what the AI understood
/// before anything is sent — one tap to confirm, never auto-send.
class _VoiceSheet extends StatelessWidget {
  final String spoken;
  final DistressResult result;
  final BeaconType? type;
  final bool lang;
  final ValueChanged<BeaconType> onSend;

  const _VoiceSheet({
    required this.spoken,
    required this.result,
    required this.type,
    required this.lang,
    required this.onSend,
  });

  String get _intentLabel {
    switch (result.intent) {
      case 'beacon_safe':
        return lang ? 'सुरक्षित हूँ' : 'SAFE';
      case 'beacon_help':
        return lang ? 'मदद चाहिए' : 'NEED HELP';
      case 'beacon_evac':
        return lang ? 'यहाँ से निकलना है' : 'EVACUATE';
      case 'open_survival':
        return lang ? 'बचाव निर्देश' : 'Survival guide';
      default:
        return lang ? 'साफ़ नहीं समझा' : 'Not clear';
    }
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = type == null ? AppTheme.grey : Color(type!.colorValue);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.mic, color: AppTheme.tealLight, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lang ? 'AI ने यह समझा' : 'This is what AI understood',
                    style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                AiBadge(source: result.source),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '"$spoken"',
              style: const TextStyle(
                  color: AppTheme.grey,
                  fontSize: 12,
                  height: 1.4,
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),
            if (result.summary.trim().isNotEmpty &&
                result.summary.trim() != spoken.trim())
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  result.summary,
                  style: const TextStyle(
                      color: AppTheme.white, fontSize: 12, height: 1.4),
                ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(Icons.label_outline, _intentLabel, color),
                if (result.injured)
                  _chip(Icons.healing, lang ? 'चोट' : 'injured', AppTheme.red),
                if (result.trapped)
                  _chip(Icons.lock_outline, lang ? 'फंसे' : 'trapped',
                      AppTheme.saffronLight),
                if (result.people > 1)
                  _chip(Icons.groups, '${result.people} ${lang ? "लोग" : "people"}',
                      AppTheme.chakraBlue),
                if (result.landmark != null && result.landmark!.isNotEmpty)
                  _chip(Icons.place, result.landmark!, AppTheme.tealLight),
              ],
            ),
            const SizedBox(height: 18),
            if (type != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onSend(type!),
                  icon: const Icon(Icons.send, size: 16),
                  label: Text(
                    '${lang ? "भेजें" : "Send"}: ${type!.labelEn} · ${type!.labelHi}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              )
            else ...[
              Text(
                lang
                    ? 'साफ़ समझ नहीं आया। नीचे से चुनें:'
                    : 'Not clear enough. Choose below:',
                style: const TextStyle(color: AppTheme.grey, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ...BeaconType.values.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => onSend(t),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(t.colorValue),
                          side: BorderSide(color: Color(t.colorValue)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('${t.labelEn} · ${t.labelHi}'),
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(lang ? 'रद्द करें' : 'Cancel',
                    style: const TextStyle(color: AppTheme.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
