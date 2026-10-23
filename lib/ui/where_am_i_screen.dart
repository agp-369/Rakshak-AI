import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

/// "Where Am I" — giant, readable coordinates and a share action.
/// During a disaster you relay your location over radio or by phone to
/// rescue teams — this screen makes it unmissable and copyable.
class WhereAmIScreen extends StatefulWidget {
  const WhereAmIScreen({super.key});

  @override
  State<WhereAmIScreen> createState() => _WhereAmIScreenState();
}

class _WhereAmIScreenState extends State<WhereAmIScreen> {
  final _gps = GpsService();
  GeoPoint? _point;
  bool _loading = true;
  bool _permanentlyDenied = false;
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
      setState(() {
        _loading = false;
        _permanentlyDenied = true;
      });
      return;
    }
    try {
      final point = await _gps.getCurrentPosition();
      if (mounted) setState(() => _point = point);
    } catch (e) {
      if (mounted) {
        setState(() {
          _point = _gps.lastKnown;
          _error = _point == null ? e.toString() : null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    if (_point == null) return;
    await Clipboard.setData(ClipboardData(
      text:
          '${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}',
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordinates copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLang.hindi;
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(lang ? 'मैं कहाँ हूँ' : 'Where Am I',
            style: const TextStyle(fontSize: 15)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _permanentlyDenied
                ? _PermissionPrompt(gps: _gps, lang: lang)
                : _point == null
                    ? _NoFix(lang: lang, error: _error, onRetry: _locate)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.my_location,
                              color: AppTheme.tealLight, size: 56),
                          const SizedBox(height: 24),
                          Text(
                            lang ? 'मेरा स्थान' : 'MY LOCATION',
                            style: const TextStyle(
                                color: AppTheme.grey,
                                fontSize: 12,
                                letterSpacing: 2),
                          ),
                          const SizedBox(height: 12),
                          _CoordText(
                            label: 'LATITUDE',
                            value: _point!.latitude.toStringAsFixed(5),
                          ),
                          const SizedBox(height: 10),
                          _CoordText(
                            label: 'LONGITUDE',
                            value: _point!.longitude.toStringAsFixed(5),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            lang
                                ? 'रेडियो या फ़ोन पर राहत दल को यही नंबर बताएं।'
                                : 'Read these numbers to rescue teams on radio or phone.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppTheme.grey, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _copy,
                                icon: const Icon(Icons.copy, size: 16),
                                label: Text(lang ? 'कॉपी' : 'Copy'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _locate,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: Text(lang ? 'अपडेट' : 'Refresh'),
                              ),
                            ],
                          ),
                          if (_point!.accuracy > 0) ...[
                            const SizedBox(height: 12),
                            Text(
                              '± ${_point!.accuracy.toStringAsFixed(0)} m',
                              style: const TextStyle(
                                  color: AppTheme.grey, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
      ),
    );
  }
}

class _CoordText extends StatelessWidget {
  final String label;
  final String value;
  const _CoordText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.grey, fontSize: 10, letterSpacing: 2)),
        Text(
          value,
          style: const TextStyle(
              color: AppTheme.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 2),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, color: AppTheme.saffron, size: 48),
          const SizedBox(height: 16),
          Text(
            lang ? 'लोकेशन अनुमति बंद है' : 'Location permission is off',
            style: const TextStyle(color: AppTheme.white, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            lang
                ? 'सेटिंग्स में जाकर लोकेशन चालू करें ताकि आपका स्थान मिल सके।'
                : 'Enable location in settings so your position can be found.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.grey, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => gps.openAppSettings(),
            child: Text(lang ? 'सेटिंग्स खोलें' : 'Open settings'),
          ),
        ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gps_off, color: AppTheme.grey, size: 48),
          const SizedBox(height: 16),
          Text(
            lang ? 'स्थान नहीं मिला' : 'No location fix yet',
            style: const TextStyle(color: AppTheme.white, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            lang
                ? 'खुले आसमान के नीचे जाएं और दोबारा कोशिश करें।'
                : 'Move to open sky and try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.grey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(lang ? 'दोबारा कोशिश' : 'Try again'),
          ),
        ],
      ),
    );
  }
}
