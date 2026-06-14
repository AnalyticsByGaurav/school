import 'package:flutter/material.dart';
import '../api/client.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _data;
  final now = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final res = await Api.get('api/attendance.php', params: {'month': month});
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() { _data = res['data'] as Map<String, dynamic>?; _loading = false; });
    } else {
      setState(() { _error = res['message'] as String? ?? 'Failed'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
      const SizedBox(height: 8),
      Text(_error, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 12),
      FilledButton(onPressed: _load, child: const Text('Retry')),
    ]));

    final records = _data?['records'] as List<dynamic>? ?? [];
    final summary = _data?['summary'] as Map<String, dynamic>? ?? {};
    final present = summary['present'] as int? ?? 0;
    final absent  = summary['absent']  as int? ?? 0;
    final late    = summary['late']    as int? ?? 0;
    final total   = present + absent + late;
    final pct     = total > 0 ? (present / total * 100).toStringAsFixed(1) : '0';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Card(
            color: const Color(0xFF1A56DB),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text('$pct%', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                const Text('Attendance This Month', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _stat('Present', present, Colors.green),
                  _stat('Absent', absent, Colors.red),
                  _stat('Late', late, Colors.orange),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Daily Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...records.map((r) {
            final rec = r as Map<String, dynamic>;
            final status = rec['date'] as String? ?? '';
            final s = rec['status'] as String? ?? '';
            Color c = Colors.grey;
            if (s == 'present') c = Colors.green;
            else if (s == 'absent') c = Colors.red;
            else if (s == 'late') c = Colors.orange;
            return ListTile(
              dense: true,
              title: Text(rec['date'] as String? ?? ''),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(s.toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _stat(String label, int val, Color c) => Column(children: [
    Text('$val', style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);
}
