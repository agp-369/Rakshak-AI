import 'package:flutter/material.dart';
import 'package:rakshak_ai/data/first_aid_protocols.dart';
import 'package:rakshak_ai/services/voice_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

class ProtocolDetailScreen extends StatefulWidget {
  final FirstAidProtocol protocol;
  const ProtocolDetailScreen({super.key, required this.protocol});
  @override
  State<ProtocolDetailScreen> createState() => _ProtocolDetailScreenState();
}

class _ProtocolDetailScreenState extends State<ProtocolDetailScreen> {
  final _voice = VoiceService();
  bool _isSpeaking = false;

  String get _fullText {
    final buf = StringBuffer();
    buf.writeln(widget.protocol.title);
    buf.writeln(widget.protocol.summary);
    buf.writeln('Steps:');
    for (int i = 0; i < widget.protocol.steps.length; i++) {
      buf.writeln('${i + 1}. ${widget.protocol.steps[i].text}');
    }
    if (widget.protocol.doNot.isNotEmpty) {
      buf.writeln('Do not:');
      for (final d in widget.protocol.doNot) {
        buf.writeln(d);
      }
    }
    buf.writeln('When to seek help: ${widget.protocol.seekHelp}');
    return buf.toString();
  }

  Future<void> _toggleReadAloud() async {
    if (_isSpeaking) {
      await _voice.stopSpeaking();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      final ok = await _voice.speak(_fullText);
      if (mounted) setState(() => _isSpeaking = ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.protocol.title.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(widget.protocol.titleHindi, style: const TextStyle(fontSize: 11, color: AppTheme.grey)),
          ],
        ),
        iconTheme: const IconThemeData(color: AppTheme.saffronLight),
        actions: [
          IconButton(
            icon: Icon(
              _isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
              color: _isSpeaking ? AppTheme.teal : AppTheme.grey,
            ),
            onPressed: _toggleReadAloud,
            tooltip: _isSpeaking ? 'Stop Reading' : 'Read Aloud',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSeverityHeader(),
            const SizedBox(height: 20),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildSectionTitle('STEP-BY-STEP GUIDE'),
            const SizedBox(height: 12),
            ...List.generate(widget.protocol.steps.length, (i) => _buildStep(i + 1, widget.protocol.steps[i])),
            if (widget.protocol.doNot.isNotEmpty) ...[
              const SizedBox(height: 28),
              _buildSectionTitle('DO NOT'),
              const SizedBox(height: 12),
              ...widget.protocol.doNot.map((d) => _buildDoNot(d)),
            ],
            const SizedBox(height: 28),
            _buildSectionTitle('WHEN TO SEEK HELP'),
            const SizedBox(height: 12),
            _buildHelpCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityHeader() {
    Color bg;
    String label;
    switch (widget.protocol.severity) {
      case 'CRITICAL':
        bg = AppTheme.red; label = 'LIFE-THREATENING EMERGENCY — ACT NOW';
        break;
      case 'SERIOUS':
        bg = AppTheme.saffronDark; label = 'SERIOUS — SEEK MEDICAL HELP';
        break;
      default:
        bg = AppTheme.saffron; label = 'MODERATE — MONITOR CLOSELY';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bg.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: bg, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: bg, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.protocol.color.withValues(alpha: 0.08), AppTheme.surface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.protocol.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: widget.protocol.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.protocol.icon, color: widget.protocol.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(widget.protocol.summary, style: const TextStyle(color: AppTheme.grey, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: widget.protocol.color, margin: const EdgeInsets.only(right: 10)),
        Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: widget.protocol.color, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildStep(int number, FirstAidStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.protocol.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$number', style: TextStyle(color: widget.protocol.color, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.surfaceLight),
              ),
              child: Row(
                children: [
                  Icon(step.icon, color: widget.protocol.color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(step.text, style: const TextStyle(color: AppTheme.white, fontSize: 12, height: 1.3))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoNot(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, color: AppTheme.red, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppTheme.grey, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_hospital, color: AppTheme.teal, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.protocol.seekHelp, style: const TextStyle(color: AppTheme.white, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}
