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

// ─────────────────────────────────────────────────────────────────────────────
// Role helpers (used throughout this file)
// ─────────────────────────────────────────────────────────────────────────────
bool get _isStudent  => Session.userRole == 'student';
bool get _isParent   => Session.userRole == 'parent';
bool get _isTeacher  => Session.userRole == 'teacher';
bool get _isAdmin    => ['admin', 'principal', 'super_admin'].contains(Session.userRole);
bool get _isStaff    => !_isStudent && !_isParent; // teacher + admin

// ─────────────────────────────────────────────────────────────────────────────
// Role-based menu item definition
// ─────────────────────────────────────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String label;
  final Widget screen;
  final bool visible;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.screen,
    this.visible = true,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom-nav tab definition (fixed 5 slots)
// ─────────────────────────────────────────────────────────────────────────────
class _NavTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;

  const _NavTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screen,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  // ── Bottom-nav tabs (role-aware) ────────────────────────────────────────
  late final List<_NavTab> _navTabs = _buildNavTabs();

  List<_NavTab> _buildNavTabs() {
    final tabs = <_NavTab>[];

    // Dashboard — everyone
    tabs.add(const _NavTab(
      icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard,
      label: 'Home', screen: DashboardScreen(),
    ));

    // Notices — everyone
    tabs.add(const _NavTab(
      icon: Icons.notifications_outlined, selectedIcon: Icons.notifications,
      label: 'Notices', screen: NoticesScreen(),
    ));

    // Attendance — everyone (screen adapts by role)
    tabs.add(const _NavTab(
      icon: Icons.check_circle_outline, selectedIcon: Icons.check_circle,
      label: 'Attendance', screen: AttendanceScreen(),
    ));

    // 4th tab: role-specific quick access
    if (_isStudent || _isParent) {
      // Students/parents access fees directly
      tabs.add(const _NavTab(
        icon: Icons.payments_outlined, selectedIcon: Icons.payments,
        label: 'Fees', screen: FeesScreen(),
      ));
    } else {
      // Teacher/admin: homework assign + timetable more useful
      tabs.add(const _NavTab(
        icon: Icons.book_outlined, selectedIcon: Icons.book,
        label: 'Homework', screen: HomeworkScreen(),
      ));
    }

    // Profile — everyone
    tabs.add(const _NavTab(
      icon: Icons.person_outline, selectedIcon: Icons.person,
      label: 'Profile', screen: ProfileScreen(),
    ));

    return tabs;
  }

  // ── Drawer menu items (role-filtered) ─────────────────────────────────────
  List<_MenuItem> get _drawerItems => [
    _MenuItem(
      icon: Icons.dashboard, label: 'Dashboard',
      screen: const DashboardScreen(),
    ),
    _MenuItem(
      icon: Icons.notifications, label: 'Notices',
      screen: const NoticesScreen(),
    ),
    _MenuItem(
      icon: Icons.check_circle, label: 'Attendance',
      screen: const AttendanceScreen(),
    ),
    _MenuItem(
      icon: Icons.book, label: 'Homework',
      screen: const HomeworkScreen(),
    ),
    _MenuItem(
      icon: Icons.payments, label: 'Fees',
      screen: const FeesScreen(),
      // Teacher doesn't deal with fees
      visible: !_isTeacher,
    ),
    _MenuItem(
      icon: Icons.bar_chart, label: 'Results',
      screen: const ResultsScreen(),
    ),
    _MenuItem(
      icon: Icons.schedule, label: 'Timetable',
      screen: const TimetableScreen(),
    ),
    _MenuItem(
      icon: Icons.folder_open, label: 'Study Materials',
      screen: const MaterialsScreen(),
      // Parents don't use study materials
      visible: !_isParent,
    ),
    _MenuItem(
      icon: Icons.beach_access, label: 'Leave',
      screen: const LeaveScreen(),
      // Parents don't apply leave themselves
      visible: !_isParent,
    ),
    _MenuItem(
      icon: Icons.report_problem_outlined, label: 'Complaints',
      screen: const ComplaintsScreen(),
      // Teachers don't file/view complaints in this flow
      visible: !_isTeacher,
    ),
    _MenuItem(
      icon: Icons.calendar_month, label: 'Calendar',
      screen: const CalendarScreen(),
    ),
    _MenuItem(
      icon: Icons.person, label: 'Profile',
      screen: const ProfileScreen(),
    ),
  ];

  // ── Navigation helpers ────────────────────────────────────────────────────
  void _goToScreen(Widget screen) {
    Navigator.pop(context); // close drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _switchTab(int i) {
    Navigator.pop(context); // close drawer
    setState(() => _tab = i);
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screens = _navTabs.map((t) => t.screen).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_navTabs[_tab].label),
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: _navTabs.map((t) => NavigationDestination(
          icon: Icon(t.icon),
          selectedIcon: Icon(t.selectedIcon),
          label: t.label,
        )).toList(),
      ),
    );
  }

  Widget _buildDrawer() {
    final role = Session.roleName.isNotEmpty ? Session.roleName : Session.userRole;
    final visibleItems = _drawerItems.where((m) => m.visible).toList();

    return Drawer(
      child: Column(children: [
        UserAccountsDrawerHeader(
          decoration: const BoxDecoration(color: Color(0xFF1A56DB)),
          accountName: Text(
              Session.userName.isNotEmpty ? Session.userName : 'User'),
          accountEmail: Text(Session.userEmail),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              Session.userName.isNotEmpty
                  ? Session.userName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A56DB)),
            ),
          ),
          otherAccountsPictures: [
            Chip(
              label: Text(role,
                  style: const TextStyle(fontSize: 11, color: Colors.white)),
              backgroundColor: Colors.white24,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ...visibleItems.map((item) {
                // Check if this item maps to one of the bottom-nav tabs
                final tabIdx = _navTabs.indexWhere(
                    (t) => t.label == item.label);
                return ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  onTap: tabIdx >= 0
                      ? () => _switchTab(tabIdx)
                      : () => _goToScreen(item.screen),
                  dense: true,
                );
              }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout',
                    style: TextStyle(color: Colors.red)),
                onTap: _logout,
                dense: true,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
