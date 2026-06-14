import 'package:flutter/material.dart';
import '../api/client.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});
  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _data;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final res = await Api.get('api/fees.php');
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() { _data = res['data'] as Map<String, dynamic>?; _loading = false; });
    } else {
      setState(() { _error = res['message'] as String? ?? 'Failed'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees'), backgroundColor: const Color(0xFF1A56DB), foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  Text(_error, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final summary = _data?['summary'] as Map<String, dynamic>? ?? {};
    final history = _data?['history'] as List<dynamic>? ?? [];
    final due     = (summary['total_due']     as num?)?.toDouble() ?? 0;
    final paid    = (summary['total_paid']    as num?)?.toDouble() ?? 0;
    final balance = (summary['total_balance'] as num?)?.toDouble() ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary
          Row(children: [
            _amtCard('Total Due',  due,     Colors.blue),
            const SizedBox(width: 12),
            _amtCard('Paid',       paid,    Colors.green),
            const SizedBox(width: 12),
            _amtCard('Balance',    balance, balance > 0 ? Colors.red : Colors.green),
          ]),
          const SizedBox(height: 20),
          const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No payment records')))
          else
            ...history.map((r) {
              final row = r as Map<String, dynamic>;
              final status = row['status'] as String? ?? '';
              final isPaid = status == 'paid';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(row['fee_head'] as String? ?? 'Fee'),
                  subtitle: Text(row['payment_date'] as String? ?? ''),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹${(row['total_amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(status.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: isPaid ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _amtCard(String label, double amount, Color color) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Text('₹${amount.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );
}
