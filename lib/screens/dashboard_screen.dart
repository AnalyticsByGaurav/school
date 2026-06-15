import 'package:flutter/material.dart';
import '../api/client.dart';
import '../utils/session.dart';
import 'attendance_screen.dart';
import 'fees_screen.dart';
import 'results_screen.dart';
import 'timetable_screen.dart';
import 'materials_screen.dart';
import 'leave_screen.dart';
import 'homework_screen.dart';
import 'notices_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _data;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final res = await Api.get('api/dashboard.php');
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() { _data = res['data'] as Map<String, dynamic>?; _loading = false; });
    } else {
      setState(() { _error = res['message'] as String? ?? 'Failed to load'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() => ListView(children: [
    Padding(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _load, child: const Text('Retry')),
      ]),
    ),
  ]);

  Widget _buildContent() {
    final d = _data!;
    final user = d['user'] as Map<String, dynamic>? ?? {};
    final student = d['student'] as Map<String, dynamic>?;
    final att = d['attendance_today'] as Map<String, dynamic>?;
    final unread = d['unread_notices'] as int? ?? 0;
    final pendingFees = (d['pending_fees'] as num?)?.toDouble() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Welcome back!', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              Session.userName.isNotEmpty ? Session.userName : (user['name'] as String? ?? 'User'),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (student != null && student['class_name'] != null)
              Text(student['class_name'] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),
        // Stats row
        Row(children: [
          _statCard('Today', att?['status'] ?? '--', Icons.check_circle_outline, Colors.green),
          const SizedBox(width: 12),
          _statCard('Notices', '$unread unread', Icons.notifications_outlined, Colors.orange),
          const SizedBox(width: 12),
          _statCard('Fees Due', pendingFees > 0 ? '₹${pendingFees.toStringAsFixed(0)}' : 'Clear', Icons.payments_outlined,
              pendingFees > 0 ? Colors.red : Colors.green),
        ]),
        const SizedBox(height: 16),
        // Quick links
        const Text('Quick Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 1,
          children: [
            _quickLink(Icons.check_circle,  'Attendance', Colors.teal,   const AttendanceScreen()),
            _quickLink(Icons.payments,       'Fees',       Colors.indigo, const FeesScreen()),
            _quickLink(Icons.bar_chart,      'Results',    Colors.purple, const ResultsScreen()),
            _quickLink(Icons.schedule,       'Timetable',  Colors.orange, const TimetableScreen()),
            _quickLink(Icons.book,           'Homework',   Colors.blue,   const HomeworkScreen()),
            _quickLink(Icons.beach_access,   'Leave',      Colors.pink,   const LeaveScreen()),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      ),
    );
  }

  Widget _quickLink(IconData icon, String label, Color color, Widget screen) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
