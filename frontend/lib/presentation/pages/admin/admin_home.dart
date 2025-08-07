import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import '../auth/login_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_users_page.dart';
import 'admin_listings_review_page.dart';
import 'admin_reports_page.dart';
import 'admin_settings_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  final _pages = const [
    AdminDashboardPage(),           // 0 bottom
    AdminUsersPage(),               // 1 bottom
    AdminListingsReviewPage(),      // 2 bottom (Reviews)
    AdminSettingsPage(),            // 3 drawer
    AdminReportsPage(),             // 4 drawer
  ];

  final _titles = const [
    'Dashboard',
    'Users',
    'Reviews',
    'Settings',
    'Reports',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final name = auth.userName ?? 'User';
    final email = auth.userEmail ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(color: Colors.teal),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(email, style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  )
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 4);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthViewModel>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index > 2 ? 0 : _index,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), label: 'Reviews'),
        ],
      ),
    );
  }
}
