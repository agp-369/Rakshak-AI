import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/ai_engine.dart';
import 'package:rakshak_ai/services/localization.dart';
import 'package:rakshak_ai/ui/main_shell.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RakshakApp());
}

class RakshakApp extends StatelessWidget {
  const RakshakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rakshak — Offline Disaster Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _StartupScreen(),
    );
  }
}

/// v2 startup: instant. Loads language pref and goes straight to the shell.
/// The on-device model loads in the BACKGROUND after navigation — it never
/// blocks a life-safety action, and every feature has a rule fallback.
class _StartupScreen extends StatefulWidget {
  const _StartupScreen();
  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await AppLang.load();
    // AI is opt-in in field-first v2; do not block startup.
    unawaited(AiEngine().initializeInBackground());
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.saffron, AppTheme.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.saffron.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.shield_moon_outlined,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 28),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppTheme.saffronLight, AppTheme.saffron, AppTheme.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'RAKSHAK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Offline Disaster Survival Companion',
              style: TextStyle(
                color: AppTheme.grey,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ऑफ़लाइन आपदा साथी',
              style: TextStyle(
                color: AppTheme.saffronLight,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
