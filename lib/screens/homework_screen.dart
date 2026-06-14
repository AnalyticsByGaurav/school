import 'package:flutter/material.dart';
import '../api/client.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});
  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _items = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final res = await Api.get('api/homework.php');
    if (!mounted) return;
    if (res['success'] == true) {
      final d = res['data'] as Map<String, dynamic>?;
      setState(() { _items = d?['homework'] as List<dynamic>? ?? []; _loading = false; });
    } else {
      setState(() { _error = res['message'] as String? ?? 'Failed'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
      Text(_error, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 12),
      FilledButton(onPressed: _load, child: const Text('Retry')),
    ]));
    if (_items.isEmpty) return const Center(child: Text('No homework assigned'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final h = _items[i] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Row(children: [
                  if (h['subject_name'] != null)
                    _chip(h['subject_name'] as String, Colors.blue),
                  if (h['class_name'] != null)
                    _chip(h['class_name'] as String, Colors.purple),
                ]),
                if ((h['description'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(h['description'] as String, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text('Due: ${h['due_date'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    margin: const EdgeInsets.only(right: 6, top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}
