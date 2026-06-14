import 'package:flutter/material.dart';
import '../api/client.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _items = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final res = await Api.get('api/materials.php');
    if (!mounted) return;
    if (res['success'] == true) {
      final d = res['data'] as Map<String, dynamic>?;
      setState(() { _items = d?['materials'] as List<dynamic>? ?? []; _loading = false; });
    } else {
      setState(() { _error = res['message'] as String? ?? 'Failed'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Materials'), backgroundColor: const Color(0xFF1A56DB), foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  Text(_error), const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : _items.isEmpty
                  ? const Center(child: Text('No materials available'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final m = _items[i] as Map<String, dynamic>;
                          final type = m['type'] as String? ?? 'document';
                          IconData icon = Icons.insert_drive_file;
                          Color color = Colors.blue;
                          if (type == 'video') { icon = Icons.video_library; color = Colors.red; }
                          else if (type == 'link') { icon = Icons.link; color = Colors.green; }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.1),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              title: Text(m['title'] as String? ?? ''),
                              subtitle: Text([
                                m['subject_name'] as String?,
                                m['class_name'] as String?,
                                m['uploaded_by_name'] as String?,
                              ].where((s) => s != null && s.isNotEmpty).join(' • ')),
                              trailing: const Icon(Icons.download_outlined, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
