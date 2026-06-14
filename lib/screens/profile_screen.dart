import 'package:flutter/material.dart';
import '../api/client.dart';
import '../utils/session.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _student;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final res = await Api.get('api/profile.php');
    if (!mounted) return;
    if (res['success'] == true) {
      final d = res['data'] as Map<String, dynamic>?;
      setState(() {
        _profile = d?['profile'] as Map<String, dynamic>?;
        _student = d?['student'] as Map<String, dynamic>?;
        _loading = false;
      });
    } else {
      setState(() { _error = res['message'] as String? ?? 'Failed'; _loading = false; });
    }
  }

  Future<void> _logout() async {
    await Api.post('api/auth/logout.php', {});
    await Session.clear();
    Api.reset();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
      Text(_error), const SizedBox(height: 12),
      FilledButton(onPressed: _load, child: const Text('Retry')),
    ]));

    final p = _profile ?? {};
    final name  = p['name']  as String? ?? Session.userName;
    final email = p['email'] as String? ?? Session.userEmail;
    final role  = p['role_name'] as String? ?? Session.roleName;
    final photo = p['photo_url'] as String?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + name
          Column(children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF1A56DB),
              backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
              child: (photo == null || photo.isEmpty)
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A56DB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(role, style: const TextStyle(color: Color(0xFF1A56DB), fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 24),
          // Info cards
          Card(child: Column(children: [
            _infoTile(Icons.email_outlined, 'Email', email),
            if (p['mobile'] != null) _infoTile(Icons.phone_outlined, 'Mobile', p['mobile'] as String),
            if (p['school_name'] != null) _infoTile(Icons.school_outlined, 'School', p['school_name'] as String),
            if (p['last_login'] != null) _infoTile(Icons.access_time, 'Last Login', p['last_login'] as String),
          ])),
          if (_student != null) ...[
            const SizedBox(height: 16),
            const Text('Student Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(child: Column(children: [
              if (_student!['admission_number'] != null) _infoTile(Icons.badge_outlined, 'Admission No.', _student!['admission_number'] as String),
              if (_student!['class_name'] != null) _infoTile(Icons.class_outlined, 'Class', '${_student!['class_name']} ${_student!['section_name'] ?? ''}'),
              if (_student!['roll_number'] != null) _infoTile(Icons.format_list_numbered, 'Roll No.', _student!['roll_number'] as String),
            ])),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () { Navigator.pop(context); _logout(); },
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Logout', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) => ListTile(
    dense: true,
    leading: Icon(icon, color: const Color(0xFF1A56DB), size: 20),
    title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    subtitle: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
  );
}
