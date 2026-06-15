import 'package:flutter/material.dart';
import '../api/client.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _days = [];
  String _type = 'student';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final res = await Api.get('api/timetable.php');
    if (!mounted) return;
    if (res['success'] == true) {
      final d = res['data'] as Map<String, dynamic>?;
      setState(() {
        _days  = d?['days'] as List<dynamic>? ?? [];
        _type  = d?['type'] as String? ?? 'student';
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['message'] as String? ?? 'Failed to load timetable';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(_error, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : _days.isEmpty
                  ? const Center(child: Text('No timetable available'))
                  : DefaultTabController(
                      length: _days.length,
                      child: Column(children: [
                        TabBar(
                          isScrollable: true,
                          labelColor: const Color(0xFF1A56DB),
                          tabs: _days.map((d) =>
                              Tab(text: (d as Map)['day_name'] as String? ?? ''))
                              .toList(),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: _days.map((d) {
                              final day = d as Map<String, dynamic>;
                              final periods = day['periods'] as List<dynamic>? ?? [];
                              if (periods.isEmpty) {
                                return const Center(child: Text('No classes'));
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: periods.length,
                                itemBuilder: (_, i) {
                                  final p = periods[i] as Map<String, dynamic>;
                                  final isBreak = (p['is_break'] as int?) == 1;
                                  if (isBreak) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(children: [
                                        const Expanded(child: Divider()),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(
                                            '${p['period_name']} (${p['start_time']} - ${p['end_time']})',
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                        ),
                                        const Expanded(child: Divider()),
                                      ]),
                                    );
                                  }
                                  // Subtitle: teacher sees class/section; student sees teacher name
                                  final subtitle = _type == 'teacher'
                                      ? '${p['class_name'] ?? ''} — ${p['section_name'] ?? ''}'
                                      : (p['teacher_name'] as String? ?? '');
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            const Color(0xFF1A56DB).withOpacity(0.1),
                                        child: Text(
                                          p['period_name'] as String? ?? '',
                                          style: const TextStyle(
                                              fontSize: 11, color: Color(0xFF1A56DB)),
                                        ),
                                      ),
                                      title: Text(
                                        p['subject_name'] as String? ?? 'Free',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                                      trailing: Text(
                                        '${p['start_time']} -\n${p['end_time']}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ]),
                    ),
    );
  }
}
