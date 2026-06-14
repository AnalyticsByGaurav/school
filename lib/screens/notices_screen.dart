import 'package:flutter/material.dart';
import '../api/client.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});
  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _notices = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final res = await Api.get('api/notices.php');
    if (!mounted) return;
    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>?;
      setState(() { _notices = data?['notices'] as List<dynamic>? ?? []; _loading = false; });
    } else {
      setState(() { _error = res['message'] as String? ?? 'Failed'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return _err();
    if (_notices.isEmpty) return const Center(child: Text('No notices'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _notices.length,
        itemBuilder: (_, i) {
          final n = _notices[i] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56DB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(n['category'] as String? ?? 'General',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF1A56DB), fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text(n['created_at'] as String? ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
                const SizedBox(height: 8),
                Text(n['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if ((n['content'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(n['content'] as String, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _err() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
    const SizedBox(height: 8),
    Text(_error, style: const TextStyle(color: Colors.grey)),
    const SizedBox(height: 12),
    FilledButton(onPressed: _load, child: const Text('Retry')),
  ]));
}
