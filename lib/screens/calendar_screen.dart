import 'package:flutter/material.dart';
import '../api/client.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _items = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final res = await Api.get('api/calendar.php', params: {'upcoming': 1});
    if (!mounted) return;
    if (res['success'] == true) {
      final d = res['data'] as Map<String, dynamic>?;
      setState(() { _items = d?['items'] as List<dynamic>? ?? []; _loading = false; });
    } else {
      setState(() { _error = res['message'] as String? ?? 'Failed'; _loading = false; });
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF1A56DB);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1A56DB);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar'), backgroundColor: const Color(0xFF1A56DB), foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  Text(_error), const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : _items.isEmpty
                  ? const Center(child: Text('No upcoming events'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final item = _items[i] as Map<String, dynamic>;
                          final color = _parseColor(item['color'] as String?);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                            child: Text(item['type'] as String? ?? '', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                                          ),
                                          const Spacer(),
                                          Text(item['date'] as String? ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ]),
                                        const SizedBox(height: 6),
                                        Text(item['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        if ((item['description'] as String?)?.isNotEmpty == true) ...[
                                          const SizedBox(height: 4),
                                          Text(item['description'] as String, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                        ],
                                        if (item['venue'] != null) ...[
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            const Icon(Icons.location_on, size: 13, color: Colors.grey),
                                            const SizedBox(width: 3),
                                            Text(item['venue'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ]),
                                        ],
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
