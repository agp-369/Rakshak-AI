import 'package:flutter/material.dart';
import 'package:rakshak_ai/services/im_safe_service.dart';
import 'package:rakshak_ai/services/gps_service.dart';
import 'package:rakshak_ai/theme/app_theme.dart';

class ImSafeScreen extends StatefulWidget {
  const ImSafeScreen({super.key});
  @override
  State<ImSafeScreen> createState() => _ImSafeScreenState();
}

class _ImSafeScreenState extends State<ImSafeScreen> {
  final _service = ImSafeService();
  final _gps = GpsService();
  final _searchCtrl = TextEditingController();
  List<SafePerson> _people = [];
  bool _loading = true;
  bool _selfSafe = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final people = await _service.getPeople();
    if (!mounted) return;
    setState(() {
      _people = people;
      _selfSafe = people.any((p) => p.name == 'Me');
      _loading = false;
    });
  }

  Future<void> _markSelfSafe() async {
    String location = 'Unknown';
    try {
      final loc = await _gps.getLastKnownPosition();
      if (loc != null) {
        location = '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';
      }
    } catch (_) {}
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('I\'M SAFE', style: TextStyle(color: AppTheme.teal, fontWeight: FontWeight.bold, letterSpacing: 2)),
        content: const Text('Mark yourself as safe? Your location will be shared.\n\nFamily members can search for you by name.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.grey))),
          ElevatedButton(
            onPressed: () async {
              await _service.markSelfSafe(location: location, note: 'Marked safe');
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.teal),
            child: const Text('YES, I\'M SAFE'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchFamily() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    final results = await _service.search(q);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('SEARCH RESULTS', style: TextStyle(color: AppTheme.saffronLight, letterSpacing: 1)),
        content: results.isEmpty
            ? const Text('No one found with that name.\n\nAsk your family to mark themselves safe in the app.', style: TextStyle(color: AppTheme.grey))
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: Icon(Icons.check_circle, color: results[i].isSafe ? AppTheme.teal : AppTheme.grey),
                    title: Text(results[i].name, style: const TextStyle(color: AppTheme.white)),
                    subtitle: Text('${results[i].location} • ${results[i].durationAgo}', style: const TextStyle(color: AppTheme.grey, fontSize: 11)),
                  ),
                ),
              ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: AppTheme.grey)))],
      ),
    );
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
            Text("I'M SAFE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
            Text('Family Reunification · मैं सुरक्षित हूँ', style: TextStyle(fontSize: 11, color: AppTheme.grey)),
          ],
        ),
        iconTheme: const IconThemeData(color: AppTheme.saffronLight),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSelfSafeCard(),
                const SizedBox(height: 24),
                _buildSearchSection(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(width: 3, height: 16, color: AppTheme.saffron, margin: const EdgeInsets.only(right: 10)),
                    const Text('MARKED SAFE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.saffronLight, letterSpacing: 2)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_people.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.surfaceLight),
                    ),
                    child: const Center(child: Text('No one has checked in yet.\nTap "I\'M SAFE" above to be the first.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.grey, fontSize: 12))),
                  )
                else
                  ..._people.map((p) => _buildPersonCard(p)),
              ],
            ),
    );
  }

  Widget _buildSelfSafeCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _selfSafe
              ? [AppTheme.teal.withValues(alpha: 0.15), AppTheme.surface]
              : [AppTheme.saffron.withValues(alpha: 0.05), AppTheme.surface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _selfSafe ? AppTheme.teal.withValues(alpha: 0.4) : AppTheme.surfaceLight,
        ),
      ),
      child: InkWell(
        onTap: _selfSafe ? null : _markSelfSafe,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                _selfSafe ? Icons.check_circle : Icons.radar,
                color: _selfSafe ? AppTheme.teal : AppTheme.saffronLight,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _selfSafe ? 'YOU ARE MARKED SAFE' : 'TAP TO MARK YOURSELF SAFE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _selfSafe ? AppTheme.teal : AppTheme.saffronLight,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selfSafe ? 'Your family can search for you by name' : 'Let your family know you are okay',
                style: const TextStyle(color: AppTheme.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 16, color: AppTheme.teal, margin: const EdgeInsets.only(right: 10)),
            const Text('FIND FAMILY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.teal, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  hintStyle: const TextStyle(color: AppTheme.grey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.grey, size: 20),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.teal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _searchFamily,
                icon: const Icon(Icons.person_search, color: Colors.white),
                tooltip: 'Search',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonCard(SafePerson p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.isSafe ? AppTheme.teal.withValues(alpha: 0.3) : AppTheme.surfaceLight),
      ),
      child: ListTile(
        leading: Icon(Icons.check_circle_outline, color: p.isSafe ? AppTheme.teal : AppTheme.grey),
        title: Text(p.name, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        subtitle: Text('${p.location} • ${p.durationAgo}', style: const TextStyle(color: AppTheme.grey, fontSize: 11)),
        trailing: p.name == 'Me'
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.grey, size: 20),
                onPressed: () async {
                  await _service.removePerson('Me');
                  _load();
                },
              )
            : null,
      ),
    );
  }
}
