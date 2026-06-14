import 'package:flutter/material.dart';
import '../api/client.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});
  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  String _error = '';
  List<dynamic> _applications = [];
  List<dynamic> _types = [];

  // Apply form
  String? _selType;
  final _fromCtrl = TextEditingController();
  final _toCtrl   = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  String _submitMsg = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final resTypes = await Api.get('api/leave.php', params: {'types': 1});
    final resApps  = await Api.get('api/leave.php');
    if (!mounted) return;
    if (resTypes['success'] == true) {
      final d = resTypes['data'] as Map<String, dynamic>?;
      _types = d?['types'] as List<dynamic>? ?? [];
      if (_types.isNotEmpty) _selType = (_types[0] as Map)['name'] as String?;
    }
    if (resApps['success'] == true) {
      final d = resApps['data'] as Map<String, dynamic>?;
      _applications = d?['applications'] as List<dynamic>? ?? [];
    } else {
      _error = resApps['message'] as String? ?? 'Failed';
    }
    setState(() { _loading = false; });
  }

  Future<void> _apply() async {
    if (_fromCtrl.text.isEmpty || _toCtrl.text.isEmpty || _reasonCtrl.text.isEmpty) {
      setState(() => _submitMsg = 'All fields are required');
      return;
    }
    final type = _types.firstWhere((t) => (t as Map)['name'] == _selType, orElse: () => null);
    if (type == null) return;
    setState(() { _submitting = true; _submitMsg = ''; });
    final res = await Api.post('api/leave.php', {
      'leave_type_id': (type as Map)['id'],
      'from_date': _fromCtrl.text,
      'to_date': _toCtrl.text,
      'reason': _reasonCtrl.text,
    });
    if (!mounted) return;
    if (res['success'] == true) {
      _fromCtrl.clear(); _toCtrl.clear(); _reasonCtrl.clear();
      setState(() { _submitting = false; _submitMsg = 'Application submitted!'; });
      _load();
    } else {
      setState(() { _submitting = false; _submitMsg = res['message'] as String? ?? 'Failed'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave'),
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
        bottom: TabBar(controller: _tabs, labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: const [
          Tab(text: 'My Applications'),
          Tab(text: 'Apply'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_buildList(), _buildApply()],
            ),
    );
  }

  Widget _buildList() {
    if (_error.isNotEmpty) return Center(child: Text(_error, style: const TextStyle(color: Colors.grey)));
    if (_applications.isEmpty) return const Center(child: Text('No leave applications'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _applications.length,
      itemBuilder: (_, i) {
        final a = _applications[i] as Map<String, dynamic>;
        final status = a['status'] as String? ?? 'pending';
        Color sc = Colors.orange;
        if (status == 'approved') sc = Colors.green;
        else if (status == 'rejected') sc = Colors.red;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(a['leave_type'] as String? ?? 'Leave'),
            subtitle: Text('${a['from_date']} to ${a['to_date']} (${a['total_days']} days)'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(status.toUpperCase(), style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildApply() {
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
          value: _selType,
          decoration: const InputDecoration(labelText: 'Leave Type', border: OutlineInputBorder()),
          items: _types.map((t) => DropdownMenuItem<String>(
            value: (t as Map)['name'] as String,
            child: Text((t)['name'] as String),
          )).toList(),
          onChanged: (v) => setState(() => _selType = v),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _fromCtrl,
          decoration: const InputDecoration(labelText: 'From Date (YYYY-MM-DD)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
          keyboardType: TextInputType.datetime,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _toCtrl,
          decoration: const InputDecoration(labelText: 'To Date (YYYY-MM-DD)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
          keyboardType: TextInputType.datetime,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _apply,
            child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Application'),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }
}
