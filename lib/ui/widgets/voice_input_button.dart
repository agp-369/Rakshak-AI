import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/voice_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

class VoiceInputButton extends StatefulWidget {
  final ValueChanged<String> onResult;
  final VoidCallback? onError;
  final double size;

  const VoiceInputButton({
    super.key,
    required this.onResult,
    this.onError,
    this.size = 42,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  final _voice = VoiceService();
  bool _isListening = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voice.stopListening();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _voice.stopListening();
      _pulseController.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final started = await _voice.startListening(
      onResult: (text) {
        _pulseController.stop();
        if (mounted) {
          setState(() => _isListening = false);
          widget.onResult(text);
        }
      },
      onError: () {
        _pulseController.stop();
        if (mounted) {
          setState(() => _isListening = false);
          widget.onError?.call();
        }
      },
    );

    if (started && mounted) {
      setState(() => _isListening = true);
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening
                  ? AppTheme.red.withValues(
                      alpha: 0.15 + _pulseAnim.value * 0.2)
                  : AppTheme.surfaceLight,
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: AppTheme.red.withValues(
                            alpha: 0.2 + _pulseAnim.value * 0.3),
                        blurRadius: 8 + _pulseAnim.value * 10,
                        spreadRadius: 2 + _pulseAnim.value * 4,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? AppTheme.red : AppTheme.grey,
              size: widget.size * 0.45,
            ),
          );
        },
      ),
    );
  }
}
