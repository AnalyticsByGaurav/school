import 'package:flutter/material.dart';
import '../api/client.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  List<dynamic> _complaints = [];

  final _subjectCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  String _category  = 'other';
  String _priority  = 'medium';
  bool _submitting  = false;
  String _submitMsg = '';

  final _categories = ['academics', 'facility', 'transport', 'staff', 'other'];
  final _priorities = ['low', 'medium', 'high'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    final res = await Api.get('api/complaints.php');
    if (!mounted) return;
    if (res['success'] == true) {
      final d = res['data'] as Map<String, dynamic>?;
      _complaints = d?['complaints'] as List<dynamic>? ?? [];
    }
    setState(() { _loading = false; });
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      setState(() => _submitMsg = 'Subject and description are required');
      return;
    }
    setState(() { _submitting = true; _submitMsg = ''; });
    final res = await Api.post('api/complaints.php', {
      'category': _category,
      'subject': _subjectCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'priority': _priority,
    });
    if (!mounted) return;
    if (res['success'] == true) {
      _subjectCtrl.clear(); _descCtrl.clear();
      setState(() { _submitting = false; _submitMsg = 'Complaint submitted successfully!'; });
      _load();
    } else {
      setState(() { _submitting = false; _submitMsg = res['message'] as String? ?? 'Failed'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
        bottom: TabBar(controller: _tabs, labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: const [
          Tab(text: 'My Complaints'),
          Tab(text: 'Submit'),
        ]),
      ),
      body: TabBarView(controller: _tabs, children: [_buildList(), _buildForm()]),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_complaints.isEmpty) return const Center(child: Text('No complaints submitted'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _complaints.length,
      itemBuilder: (_, i) {
        final c = _complaints[i] as Map<String, dynamic>;
        final status = c['status'] as String? ?? 'pending';
        Color sc = Colors.orange;
        if (status == 'resolved') sc = Colors.green;
        else if (status == 'rejected') sc = Colors.red;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(c['subject'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(status.toUpperCase(), style: TextStyle(color: sc, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ]),
              if ((c['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(c['description'] as String, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ],
              const SizedBox(height: 4),
              Text(c['created_at'] as String? ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_submitMsg.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _submitMsg.contains('!') ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_submitMsg),
          ),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
          items: _categories.map((c) => DropdownMenuItem(value: c,
              child: Text(c[0].toUpperCase() + c.substring(1)))).toList(),
          onChanged: (v) => setState(() => _category = v!),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _subjectCtrl,
          decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descCtrl,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _priority,
          decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
          items: _priorities.map((p) => DropdownMenuItem(value: p,
              child: Text(p[0].toUpperCase() + p.substring(1)))).toList(),
          onChanged: (v) => setState(() => _priority = v!),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Complaint'),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}
