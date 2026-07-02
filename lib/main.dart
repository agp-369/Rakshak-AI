import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/gemma_service.dart';
import 'package:rakshak_ai/ui/main_shell.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RakshakAIApp());
}

class RakshakAIApp extends StatelessWidget {
  const RakshakAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rakshak AI - भारत का रक्षक',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _SplashScreen(),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  String _status = 'Rakshak AI प्रारंभ हो रहा है...';
  bool _hasError = false;
  bool _ready = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _init();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await DeviceCapabilities.initialize();
      await FlutterGemma.initialize();
      if (!mounted) return;
      setState(() => _status = 'AI इंजन शुरू हो रहा है...');

      final gemma = GemmaInferenceService();
      await gemma.initialize(onStatus: (msg) {
        if (mounted) setState(() => _status = msg);
      }).timeout(const Duration(minutes: 5));
      if (!mounted) return;

      setState(() => _ready = true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        final msg = e.toString();
        _status = msg.length > 300 ? msg.substring(0, 300) : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated radar/scan ring
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(140, 140),
                    painter: _RadarPainter(
                      progress: _scanController.value,
                      isReady: _ready,
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
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
                              blurRadius: 30 + _pulseController.value * 15,
                              spreadRadius: 5 + _pulseController.value * 5,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.healing_outlined, color: Colors.white, size: 40),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Title with gradient text
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.saffronLight, AppTheme.saffron, AppTheme.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'RAKSHAK  AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'भारत का आपदा सुरक्षा कवच',
                style: TextStyle(
                  color: AppTheme.saffronLight,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Offline AI Disaster Response for India',
                style: TextStyle(
                  color: AppTheme.grey,
                  fontSize: 10,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),

              // Tricolor indicator bar
              Container(
                width: 120,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [AppTheme.saffron, Colors.white, AppTheme.green],
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),

              const SizedBox(height: 48),
              if (_hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.red, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.red, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _status = 'पुनः प्रयास कर रहा है...';
                          });
                          _init();
                        },
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _ready ? AppTheme.teal : AppTheme.saffron,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final bool isReady;

  _RadarPainter({required this.progress, required this.isReady});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer ring
    final ringPaint = Paint()
      ..color = (isReady ? AppTheme.teal : AppTheme.saffron).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 4, ringPaint);

    // Scanning arc
    final arcPaint = Paint()
      ..color = (isReady ? AppTheme.teal : AppTheme.saffronLight).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -1.5708 + progress * 6.2832 - 0.5,
      0.5,
      true,
      arcPaint,
    );

    // Scan line
    final linePaint = Paint()
      ..color = (isReady ? AppTheme.teal : AppTheme.saffronLight).withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    final angle = -1.5708 + progress * 6.2832;
    canvas.drawLine(
      center,
      Offset(center.dx + (radius - 4) * math.cos(angle), center.dy + (radius - 4) * math.sin(angle)),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.progress != progress;
}
