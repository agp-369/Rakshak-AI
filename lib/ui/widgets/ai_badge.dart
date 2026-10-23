import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/ai_engine.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

/// Small, honest provenance badge. Every AI output in Rakshak is labelled
/// so users know whether they are reading model reasoning or a fixed,
/// human-written rule. Trust is a safety feature.
class AiBadge extends StatelessWidget {
  final AiSource source;
  final bool compact;

  const AiBadge({super.key, required this.source, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isAi = source == AiSource.ai;
    final color = isAi ? AppTheme.tealLight : AppTheme.grey;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAi ? Icons.auto_awesome : Icons.verified_outlined,
              size: compact ? 10 : 11, color: color),
          const SizedBox(width: 4),
          Text(
            isAi ? 'ON-DEVICE AI' : 'VERIFIED RULE',
            style: TextStyle(
                color: color,
                fontSize: compact ? 8 : 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

/// Live model status pill: loading / ready / rules-only.
class AiStatusChip extends StatelessWidget {
  final AiState state;
  final bool hindi;

  const AiStatusChip({super.key, required this.state, required this.hindi});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    late final IconData icon;
    switch (state) {
      case AiState.ready:
        color = AppTheme.tealLight;
        label = hindi ? 'AI तैयार' : 'AI ready';
        icon = Icons.auto_awesome;
        break;
      case AiState.loading:
        color = AppTheme.yellow;
        label = hindi ? 'AI लोड हो रहा है' : 'AI loading';
        icon = Icons.hourglass_top;
        break;
      case AiState.error:
        color = AppTheme.saffronLight;
        label = hindi ? 'सुरक्षित नियम मोड' : 'Rule mode';
        icon = Icons.shield_outlined;
        break;
      case AiState.unavailable:
        color = AppTheme.grey;
        label = hindi ? 'सुरक्षित नियम मोड' : 'Rule mode';
        icon = Icons.shield_outlined;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
