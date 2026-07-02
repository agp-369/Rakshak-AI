import 'package:flutter/material.dart';
import 'package:rakshak_ai/data/first_aid_protocols.dart';
import 'package:rakshak_ai/theme/app_theme.dart';
import 'package:rakshak_ai/ui/protocol_detail_screen.dart';

class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({super.key});
  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _FirstAidScreenState extends State<FirstAidScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<FirstAidProtocol> get _filtered {
    if (_searchQuery.isEmpty) return allProtocols;
    final q = _searchQuery.toLowerCase();
    return allProtocols.where((p) =>
      p.title.toLowerCase().contains(q) ||
      p.titleHindi.contains(q) ||
      p.category.toLowerCase().contains(q)
    ).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('FIRST AID', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
            Text('प्राथमिक चिकित्सा', style: TextStyle(fontSize: 11, color: AppTheme.grey)),
          ],
        ),
        iconTheme: const IconThemeData(color: AppTheme.saffronLight),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search in Hindi / English...',
                hintStyle: const TextStyle(color: AppTheme.grey, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.grey, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.grey, size: 18),
                        onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              '${_filtered.length} protocols • Tap for step-by-step guidance',
              style: const TextStyle(color: AppTheme.grey, fontSize: 10, letterSpacing: 1),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _buildCard(_filtered[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(FirstAidProtocol p) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProtocolDetailScreen(protocol: p))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: p.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(p.icon, color: p.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.white, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(p.titleHindi, style: const TextStyle(color: AppTheme.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _severityChip(p.severity),
                        const SizedBox(width: 8),
                        Text(p.category, style: const TextStyle(color: AppTheme.grey, fontSize: 9, letterSpacing: 1)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _severityChip(String s) {
    final color = s == 'CRITICAL' ? AppTheme.red : s == 'SERIOUS' ? AppTheme.saffronLight : AppTheme.saffron;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(s, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }
}
