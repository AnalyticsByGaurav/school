import 'package:flutter/material.dart';
import '../api/client.dart';
import '../utils/session.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});
  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen>
    with SingleTickerProviderStateMixin {
  static bool get _isStaff =>
      !['student', 'parent'].contains(Session.userRole);

  late TabController _tabs;
  bool _loading = true;
  String _error = '';
  List<dynamic> _applications = [];
  List<dynamic> _types = [];

  // Apply form
  int?   _selTypeId;
  final _fromCtrl   = TextEditingController();
  final _toCtrl     = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool   _submitting  = false;
  String _submitMsg   = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });

    final resTypes = await Api.get('api/leave.php', params: {'types': 1});
    final resApps  = await Api.get('api/leave.php');
    if (!mounted) return;

    if (resTypes['success'] == true) {
      final d = resTypes['data'] as Map<String, dynamic>?;
      _types = d?['types'] as List<dynamic>? ?? [];
      if (_types.isNotEmpty && _selTypeId == null) {
        _selTypeId = (_types[0] as Map)['id'] as int?;
      }
    }
    if (resApps['success'] == true) {
      final d = resApps['data'] as Map<String, dynamic>?;
      _applications = d?['applications'] as List<dynamic>? ?? [];
    } else {
      _error = resApps['message'] as String? ?? 'Failed to load';
    }
    setState(() { _loading = false; });
  }

  Future<void> _pickDate(TextEditingController ctrl, {DateTime? firstDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: firstDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ctrl.text = picked.toIso8601String().substring(0, 10);
    }
  }

  Future<void> _apply() async {
    if (_selTypeId == null || _fromCtrl.text.isEmpty ||
        _toCtrl.text.isEmpty || _reasonCtrl.text.trim().isEmpty) {
      setState(() => _submitMsg = 'All fields are required');
      return;
    }
    if (_fromCtrl.text.compareTo(_toCtrl.text) > 0) {
      setState(() => _submitMsg = 'From date cannot be after To date');
      return;
    }
    setState(() { _submitting = true; _submitMsg = ''; });
    final res = await Api.post('api/leave.php', {
      'leave_type_id': _selTypeId,
      'from_date':     _fromCtrl.text,
      'to_date':       _toCtrl.text,
      'reason':        _reasonCtrl.text.trim(),
    });
    if (!mounted) return;
    if (res['success'] == true) {
      _fromCtrl.clear(); _toCtrl.clear(); _reasonCtrl.clear();
      setState(() { _submitting = false; _submitMsg = 'Application submitted successfully!'; });
      _tabs.animateTo(0);
      _load();
    } else {
      setState(() {
        _submitting = false;
        _submitMsg  = res['message'] as String? ?? 'Failed to submit';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave'),
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'My Applications'),
            Tab(text: 'Apply'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_buildList(), _buildApply()],
            ),
    );
  }

  // ── My Applications list ──────────────────────────────────────────────────
  Widget _buildList() {
    if (_error.isNotEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.grey),
        const SizedBox(height: 8),
        Text(_error, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }
    if (_applications.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.beach_access, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('No leave applications yet', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
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
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(
                    a['leave_type'] as String? ?? 'Leave',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: sc.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                          color: sc, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${a['from_date']} → ${a['to_date']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(width: 8),
                  Text('(${a['total_days']} day${(a['total_days'] as int? ?? 1) > 1 ? 's' : ''})',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
                if ((a['reason'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(a['reason'] as String,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if ((a['remarks'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text('Remarks: ${a['remarks']}',
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Apply form ─────────────────────────────────────────────────────────────
  Widget _buildApply() {
    if (!_isStaff) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Leave applications are for staff members only.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_submitMsg.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _submitMsg.contains('successfully')
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(
                _submitMsg.contains('successfully')
                    ? Icons.check_circle
                    : Icons.error_outline,
                color: _submitMsg.contains('successfully')
                    ? Colors.green
                    : Colors.red,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_submitMsg)),
            ]),
          ),

        // Leave type dropdown
        if (_types.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('No leave types configured. Contact admin.',
                  style: TextStyle(color: Colors.orange)),
            ]),
          )
        else
          DropdownButtonFormField<int>(
            value: _selTypeId,
            decoration: const InputDecoration(
                labelText: 'Leave Type *', border: OutlineInputBorder()),
            items: _types.map((t) {
              final m = t as Map<String, dynamic>;
              final days = (m['days_allowed'] as int?) ?? 0;
              final paid = (m['is_paid'] as int?) == 1 ? 'Paid' : 'Unpaid';
              return DropdownMenuItem<int>(
                value: m['id'] as int,
                child: Text('${m['name']} ($days days · $paid)'),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selTypeId = v),
          ),
        const SizedBox(height: 16),

        // From date
        TextFormField(
          controller: _fromCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'From Date *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () => _pickDate(_fromCtrl),
        ),
        const SizedBox(height: 16),

        // To date
        TextFormField(
          controller: _toCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'To Date *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () {
            DateTime? firstDate;
            if (_fromCtrl.text.isNotEmpty) {
              firstDate = DateTime.tryParse(_fromCtrl.text);
            }
            _pickDate(_toCtrl, firstDate: firstDate);
          },
        ),
        const SizedBox(height: 16),

        // Reason
        TextFormField(
          controller: _reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Reason *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _apply,
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Submit Application'),
          ),
        ),
      ]),
    );
  }
}
