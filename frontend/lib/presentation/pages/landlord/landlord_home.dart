import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import 'landlord_dashboard_page.dart';
import 'landlord_listings_page.dart';
import 'landlord_new_listing_page.dart';
import 'landlord_bookings_page.dart';
import 'landlord_profile_page.dart';
import 'landlord_verification_page.dart';
import '../auth/login_page.dart';
import '../../widgets/notification_bell.dart';

class LandlordHome extends StatefulWidget {
  const LandlordHome({super.key});

  @override
  State<LandlordHome> createState() => _LandlordHomeState();
}

class _LandlordHomeState extends State<LandlordHome> {
  int _index = 0;

  final _pages = const [
    LandlordDashboardPage(), // 0
    LandlordListingsPage(),  // 1
    LandlordProfilePage(),   // 2 bottom
    LandlordNewListingPage(), // 3 drawer
    LandlordBookingsPage(),   // 4 drawer
    LandlordVerificationPage(), // 5 drawer
  ];

  final _titles = const [
    'Dashboard',
    'Listings',
    'Profile',
    'New Listing',
    'Bookings',
    'Verification',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final name = auth.userName ?? 'User';
    final email = auth.userEmail ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: const [NotificationBell()],
      ),
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
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('New Listing'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_online_outlined),
              title: const Text('Bookings'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Verification'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 5);
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
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: 'Listings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
