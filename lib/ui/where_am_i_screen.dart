import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/services/location_descriptor_service.dart';
import 'package:rakshak_ai/services/voice_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

/// "Where Am I" — exact coordinates, direction from landmark, village,
/// district, and state format for emergency broadcast and radio relay.
class WhereAmIScreen extends StatefulWidget {
  const WhereAmIScreen({super.key});

  @override
  State<WhereAmIScreen> createState() => _WhereAmIScreenState();
}

class _WhereAmIScreenState extends State<WhereAmIScreen> {
  final _gps = GpsService();
  final _descriptor = LocationDescriptorService();
  final _voice = VoiceService();

  GeoPoint? _point;
  LocationDescription? _description;
  bool _loading = true;
  bool _permanentlyDenied = false;
  bool _speaking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await _gps.initialize();
    if (!ok && _gps.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _loading = false;
          _permanentlyDenied = true;
        });
      }
      return;
    }

    try {
      final point = await _gps.getCurrentPosition();
      final desc = await _descriptor.describeLocation(point);
      if (mounted) {
        setState(() {
          _point = point;
          _description = desc;
        });
      }
    } catch (e) {
      if (mounted) {
        final last = _gps.lastKnown;
        if (last != null) {
          final desc = await _descriptor.describeLocation(last);
          setState(() {
            _point = last;
            _description = desc;
            _error = null;
          });
        } else {
          setState(() => _error = e.toString());
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyCoordinates() async {
    if (_point == null) return;
    final text = '${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      final hi = AppLang.hindi;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hi ? 'निर्देशांक कॉपी किए गए: $text' : 'Coordinates copied: $text')),
      );
    }
  }

  Future<void> _copyFullLocation() async {
    if (_point == null || _description == null) return;
    final hi = AppLang.hindi;
    final text = hi ? _description!.formattedHi() : _description!.formattedEn();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hi ? 'पूरा पता कॉपी किया गया' : 'Full location copied'),
          backgroundColor: AppTheme.tealLight,
        ),
      );
    }
  }

  Future<void> _copyRadioScript() async {
    if (_description == null) return;
    final hi = AppLang.hindi;
    final text = hi ? _description!.radioScriptHi() : _description!.radioScriptEn();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hi ? 'रेडियो बचाव संदेश कॉपी किया गया' : 'Radio distress script copied'),
          backgroundColor: AppTheme.saffron,
        ),
      );
    }
  }

  Future<void> _toggleSpeak() async {
    if (_description == null) return;
    if (_speaking) {
      await _voice.stopSpeaking();
      setState(() => _speaking = false);
      return;
    }

    final hi = AppLang.hindi;
    final text = hi ? _description!.radioScriptHi() : _description!.radioScriptEn();
    _voice.setLanguage(hi ? VoiceLanguage.hindi : VoiceLanguage.english);

    setState(() => _speaking = true);
    await _voice.speak(text);
    if (mounted) {
      setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi = AppLang.hindi;

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(
          hi ? 'मेरा स्थान और लैंडमार्क' : 'WHERE AM I',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _locate,
            tooltip: hi ? 'रिफ्रेश' : 'Refresh GPS',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.saffronLight))
          : _permanentlyDenied
              ? _PermissionPrompt(gps: _gps, lang: hi)
              : _point == null
                  ? _NoFix(lang: hi, error: _error, onRetry: _locate)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Human-readable Landmark & Direction Card
                        if (_description != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.teal.withValues(alpha: 0.25),
                                  AppTheme.surface,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.tealLight.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.near_me, color: AppTheme.tealLight, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      hi ? 'सटीक लैंडमार्क और दिशा' : 'LANDMARK & DIRECTION',
                                      style: const TextStyle(
                                        color: AppTheme.tealLight,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _description!.isFromOnline
                                            ? AppTheme.green.withValues(alpha: 0.2)
                                            : AppTheme.saffron.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _description!.isFromOnline
                                            ? (hi ? 'सत्यापित पता' : 'Live Geocoded')
                                            : (hi ? 'ऑफ़लाइन लैंडमार्क' : 'Offline POI'),
                                        style: TextStyle(
                                          color: _description!.isFromOnline ? AppTheme.green : AppTheme.saffronLight,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  hi ? _description!.directionFromLandmarkHi : _description!.directionFromLandmarkEn,
                                  style: const TextStyle(
                                    color: AppTheme.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Divider(color: AppTheme.surfaceLight, height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.location_city, color: AppTheme.grey, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${hi ? "गाँव / क्षेत्र" : "Village/Area"}: ${hi ? _description!.villageOrLocalityHi : _description!.villageOrLocalityEn}',
                                        style: const TextStyle(color: AppTheme.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.map, color: AppTheme.grey, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${hi ? "ज़िला व राज्य" : "District & State"}: ${hi ? _description!.districtHi : _description!.districtEn}, ${hi ? _description!.stateHi : _description!.stateEn}',
                                        style: const TextStyle(color: AppTheme.grey, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.tealLight,
                                    side: const BorderSide(color: AppTheme.tealLight),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  onPressed: _copyFullLocation,
                                  icon: const Icon(Icons.copy, size: 14),
                                  label: Text(hi ? 'पूरा लैंडमार्क पता कॉपी करें' : 'Copy Full Formatted Location'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Radio distress broadcast script card
                        if (_description != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.saffronLight.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.radio, color: AppTheme.saffronLight, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      hi ? 'राहत दल / 112 को बोलने के लिए संदेश' : 'RADIO / 112 PHRASE TO READ',
                                      style: const TextStyle(
                                        color: AppTheme.saffronLight,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.navy,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    hi ? _description!.radioScriptHi() : _description!.radioScriptEn(),
                                    style: const TextStyle(
                                      color: AppTheme.white,
                                      fontSize: 12.5,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.saffron,
                                          foregroundColor: AppTheme.navy,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        onPressed: _copyRadioScript,
                                        icon: const Icon(Icons.copy, size: 14),
                                        label: Text(
                                          hi ? 'संदेश कॉपी करें' : 'Copy Script',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _speaking ? AppTheme.red : AppTheme.white,
                                          side: BorderSide(color: _speaking ? AppTheme.red : AppTheme.surfaceLight),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        onPressed: _toggleSpeak,
                                        icon: Icon(_speaking ? Icons.stop : Icons.volume_up, size: 16),
                                        label: Text(
                                          _speaking ? (hi ? 'रोकें' : 'Stop') : (hi ? 'बोलकर सुनाएं' : 'Read Aloud'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // GPS Numerical Coordinates Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.surfaceLight),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.gps_fixed, color: AppTheme.tealLight, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    hi ? 'जीपीएस निर्देशांक' : 'RAW GPS COORDINATES',
                                    style: const TextStyle(
                                      color: AppTheme.grey,
                                      fontSize: 11,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _CoordRow(
                                label: hi ? 'अक्षांश (LATITUDE)' : 'LATITUDE',
                                value: _point!.latitude.toStringAsFixed(5),
                              ),
                              const SizedBox(height: 10),
                              _CoordRow(
                                label: hi ? 'देशांतर (LONGITUDE)' : 'LONGITUDE',
                                value: _point!.longitude.toStringAsFixed(5),
                              ),
                              if (_point!.accuracy > 0) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.navy,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${hi ? "जीपीएस सटीकता" : "GPS Accuracy"}: ± ${_point!.accuracy.toStringAsFixed(0)} m',
                                    style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _copyCoordinates,
                                    icon: const Icon(Icons.copy, size: 15),
                                    label: Text(hi ? 'नंबर कॉपी करें' : 'Copy Numbers'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _locate,
                                    icon: const Icon(Icons.refresh, size: 15),
                                    label: Text(hi ? 'अपडेट' : 'Refresh'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
    );
  }
}

class _CoordRow extends StatelessWidget {
  final String label;
  final String value;
  const _CoordRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.grey, fontSize: 10, letterSpacing: 1.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  final GpsService gps;
  final bool lang;
  const _PermissionPrompt({required this.gps, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, color: AppTheme.saffron, size: 54),
            const SizedBox(height: 16),
            Text(
              lang ? 'लोकेशन अनुमति बंद है' : 'Location permission is off',
              style: const TextStyle(color: AppTheme.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              lang
                  ? 'सेटिंग्स में जाकर लोकेशन चालू करें ताकि आपका सटीक स्थान और निकटतम लैंडमार्क मिल सके।'
                  : 'Enable location in settings so your position, nearest landmark, and village can be found.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.grey, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => gps.openAppSettings(),
              child: Text(lang ? 'सेटिंग्स खोलें' : 'Open settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFix extends StatelessWidget {
  final bool lang;
  final String? error;
  final VoidCallback onRetry;
  const _NoFix({required this.lang, this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gps_off, color: AppTheme.grey, size: 54),
            const SizedBox(height: 16),
            Text(
              lang ? 'स्थान नहीं मिला' : 'No location fix yet',
              style: const TextStyle(color: AppTheme.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              lang
                  ? 'खुले आसमान के नीचे जाएं और दोबारा कोशिश करें ताकि उपग्रह से सिग्नल मिल सके।'
                  : 'Move to open sky and try again to get satellite signals.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.grey, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(lang ? 'दोबारा कोशिश' : 'Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
