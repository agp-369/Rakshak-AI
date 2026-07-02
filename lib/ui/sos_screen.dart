import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  final GpsService _gps = GpsService();
  bool _isBroadcasting = false;
  bool _hasAlerted = false;
  String _message = '';
  Timer? _blinkTimer;
  late AnimationController _pulseController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _startSOS() async {
    HapticFeedback.heavyImpact();

    setState(() {
      _isBroadcasting = true;
      _message = 'Generating emergency report...';
    });
    _pulseController.repeat(reverse: true);

    try {
      final latLng = await _gps.getCurrentPosition();

      setState(() {
        _message =
            'EMERGENCY REPORT\n'
            'Location: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}\n'
            'Time: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} IST\n'
            'Status: Help requested — share coordinates with responders.';
        _hasAlerted = true;
      });
    } catch (e) {
      setState(() {
        _message =
            'EMERGENCY REPORT\n'
            'Time: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} IST\n'
            'GPS unavailable. Share your location verbally with responders.';
        _hasAlerted = true;
      });
    }
  }

  void _stopSOS() {
    _pulseController.stop();
    _blinkTimer?.cancel();
    setState(() => _isBroadcasting = false);
  }

  void _shareSOS() {
    if (_message.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard — paste into SMS/WhatsApp to alert responders')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(Strings.sos.toUpperCase(), style: const TextStyle(letterSpacing: 2)),
        backgroundColor: AppTheme.red.withValues(alpha: 0.9),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isBroadcasting)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 180 + _pulseController.value * 60,
                          height: 180 + _pulseController.value * 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.red
                                .withValues(alpha: 0.25 - _pulseController.value * 0.15),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.red.withValues(alpha: 0.3 + _glowController.value * 0.3),
                                  blurRadius: 20 + _glowController.value * 15,
                                  spreadRadius: 4 + _glowController.value * 6,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.sos, size: 80, color: Colors.white),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.red.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Icon(Icons.sos, size: 80, color: AppTheme.red),
                    ),

                  const SizedBox(height: 24),
                  Text(
                    _isBroadcasting ? 'BROADCASTING ACTIVE' : 'EMERGENCY BEACON',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  if (_isBroadcasting)
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'HELP SIGNAL ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.red.withValues(alpha: 0.6 + _glowController.value * 0.4),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  if (_message.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
                      ),
                      child: SelectableText(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.white, fontSize: 13, height: 1.5),
                      ),
                    ),

                  const SizedBox(height: 24),
                  if (_hasAlerted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.green, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'READY FOR MESH TRANSMISSION',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.green,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                onPressed: _isBroadcasting ? _stopSOS : _startSOS,
                icon: Icon(_isBroadcasting ? Icons.stop : Icons.sos, color: Colors.white),
                label: Text(_isBroadcasting ? 'STOP BEACON' : 'ACTIVATE SOS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBroadcasting ? AppTheme.grey : AppTheme.red,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: _isBroadcasting ? 0 : 8,
                  shadowColor: AppTheme.red.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          if (_isBroadcasting && _message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _shareSOS,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('SHARE LOCATION'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.white,
                    side: BorderSide(color: AppTheme.white.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
