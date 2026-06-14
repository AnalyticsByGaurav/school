import 'package:flutter/material.dart';
import '../utils/session.dart';
import '../api/client.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'notices_screen.dart';
import 'attendance_screen.dart';
import 'homework_screen.dart';
import 'fees_screen.dart';
import 'results_screen.dart';
import 'timetable_screen.dart';
import 'materials_screen.dart';
import 'leave_screen.dart';
import 'complaints_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  final List<Widget> _tabs = const [
    DashboardScreen(),
    NoticesScreen(),
    AttendanceScreen(),
    HomeworkScreen(),
    ProfileScreen(),
  ];

  void _goto(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _logout() async {
    Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitle()),
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(index: _tab, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Notices'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Homework'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  String _tabTitle() {
    const titles = ['Dashboard', 'Notices', 'Attendance', 'Homework', 'Profile'];
    return titles[_tab];
  }

  Widget _buildDrawer() {
    final role = Session.roleName.isNotEmpty ? Session.roleName : Session.userRole;
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1A56DB)),
            accountName: Text(Session.userName.isNotEmpty ? Session.userName : 'User'),
            accountEmail: Text(Session.userEmail),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                Session.userName.isNotEmpty ? Session.userName[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB)),
              ),
            ),
            otherAccountsPictures: [
              Chip(
                label: Text(role, style: const TextStyle(fontSize: 11, color: Colors.white)),
                backgroundColor: Colors.white24,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(Icons.dashboard, 'Dashboard', () { Navigator.pop(context); setState(() => _tab = 0); }),
                _drawerItem(Icons.notifications, 'Notices', () { Navigator.pop(context); setState(() => _tab = 1); }),
                _drawerItem(Icons.check_circle, 'Attendance', () { Navigator.pop(context); setState(() => _tab = 2); }),
                _drawerItem(Icons.book, 'Homework', () { Navigator.pop(context); setState(() => _tab = 3); }),
                _drawerItem(Icons.payments, 'Fees', () => _goto(const FeesScreen())),
                _drawerItem(Icons.bar_chart, 'Results', () => _goto(const ResultsScreen())),
                _drawerItem(Icons.schedule, 'Timetable', () => _goto(const TimetableScreen())),
                _drawerItem(Icons.folder_open, 'Study Materials', () => _goto(const MaterialsScreen())),
                _drawerItem(Icons.beach_access, 'Leave', () => _goto(const LeaveScreen())),
                _drawerItem(Icons.report_problem_outlined, 'Complaints', () => _goto(const ComplaintsScreen())),
                _drawerItem(Icons.calendar_month, 'Calendar', () => _goto(const CalendarScreen())),
                _drawerItem(Icons.person, 'Profile', () { Navigator.pop(context); setState(() => _tab = 4); }),
                const Divider(),
                _drawerItem(Icons.logout, 'Logout', _logout, color: Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ListTile _drawerItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
      dense: true,
    );
  }
}
